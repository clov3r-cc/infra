# Tailscale セットアップ手順書

## 1. 目次

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [1. 目次](#1-目次)
- [2. 目的・概要](#2-目的概要)
- [3. 前提条件](#3-前提条件)
- [4. 作業手順](#4-作業手順)
  - [4.1. ホスト）4.5.1. LXCコンテナに用いるイメージリストを更新する](#41-ホスト451-lxcコンテナに用いるイメージリストを更新する)
  - [4.2. ホスト）LXCコンテナに用いるイメージを取得する](#42-ホストlxcコンテナに用いるイメージを取得する)
  - [4.3. ホスト）LXCコンテナを作成する](#43-ホストlxcコンテナを作成する)
  - [4.4. コンテナ）コンテナのパッケージを最新化する](#44-コンテナコンテナのパッケージを最新化する)
  - [4.5. コンテナ）作業用ユーザを追加する](#45-コンテナ作業用ユーザを追加する)
  - [4.6. コンテナ）SSHサーバの設定をする](#46-コンテナsshサーバの設定をする)
  - [4.7. ホスト）コンテナを特権モードで動作させる](#47-ホストコンテナを特権モードで動作させる)
  - [4.8. コンテナ）`Tailscale`をセットアップする](#48-コンテナtailscaleをセットアップする)
  - [4.9. `Tailscale`でExit Nodeの設定をする](#49-tailscaleでexit-nodeの設定をする)
  - [4.10. `Tailscale`の鍵の有効期限を無効化をする](#410-tailscaleの鍵の有効期限を無効化をする)
- [5. 完了条件](#5-完了条件)

<!-- /code_chunk_output -->

## 2. 目的・概要

`Tailscale`を稼働させるLXCコンテナを作成する手順書です。

## 3. 前提条件

- `Proxmox`のセットアップまで完了していること

## 4. 作業手順

### 4.1. ホスト）4.5.1. LXCコンテナに用いるイメージリストを更新する

1. LXCコンテナのリストを更新する

    ```shell
    ssh proxmox-01

    sudo pveam update
    # update successful と表示されればOK
    ```

### 4.2. ホスト）LXCコンテナに用いるイメージを取得する

1. LXCコンテナ用のイメージテンプレートを取得する

    ここでは、Debianの2025年1月現在のLTSであるDebian 12.xのイメージを使用する。

    ```shell
    # Debianのバージョン
    $ DEBIAN_MAJOR_VER=12
    $ IMAGE_TEMPLATE=$(sudo pveam available | grep system | grep "debian-${DEBIAN_MAJOR_VER}-standard" | awk '{print $2}')
    # ダウンロードする先のProxmox上ストレージ
    $ STORAGE=local
    $ sudo pveam download "$STORAGE" "$IMAGE_TEMPLATE"
    ...
    download of (URL) to (path) finished
    ```

### 4.3. ホスト）LXCコンテナを作成する

1. LXCコンテナを作成する

    ```shell
    ### rootユーザのパスワードを格納する
    ROOT_PASSWORD_TXT=root-password.txt
    # pwgen options:
    # -c アルファベット大文字を1つ以上
    # -n 数字を1つ以上
    # -s 完全にランダムで覚えにくいパスワードを生成する
    # -y 記号を1つ以上
    # -B 曖昧で間違えにくい文字を含まない
    # NOTE: pwgen コマンドはファイルへのリダイレクトなどの場合は、1個しかパスワードを生成しない
    pwgen -cnsyB 16 > "$ROOT_PASSWORD_TXT"
    ROOT_PASSWORD=$(cat "$ROOT_PASSWORD_TXT")
    # メモ用にコンソールにパスワードを出力
    echo "$ROOT_PASSWORD"

    ### SSH公開鍵をGitHubからとってくる
    SSH_PUBLIC_KEY_TXT=ssh-public-key.txt
    curl -o "$SSH_PUBLIC_KEY_TXT" https://github.com/Lucky3028.keys

    ### LXCコンテナを作成する
    VM_ID=101
    sudo pct create "$VM_ID" "local:vztmpl/${IMAGE_TEMPLATE}" \
      --arch amd64 \
      --ostype debian \
      --hostname tailscale-01 \
      --unprivileged 1 \
      --features nesting=1 \
      --password "$ROOT_PASSWORD" \
      --ssh-public-keys "$SSH_PUBLIC_KEY_TXT" \
      --rootfs "local-lvm:10" \
      --cores 1 \
      --memory 256 \
      --swap 0 \
      --net0 name=eth0,bridge=vmbr0,ip=192.168.20.3/24,gw=192.168.20.1,firewall=1 \
      --onboot 1 \
      --timezone Asia/Tokyo \
      --start 1
    # エラーが表示されなければOK

    # 不要なファイルを削除
    rm "$ROOT_PASSWORD_TXT"

    exit
    ```

### 4.4. コンテナ）コンテナのパッケージを最新化する

1. パッケージの更新と必要なパッケージのインストールを行う

    ```shell
    ssh root@192.168.20.3

    apt update && apt upgrade -y && apt dist-upgrade -y && \
      apt install curl sudo vim -y
    ```

### 4.5. コンテナ）作業用ユーザを追加する

1. 作業用ユーザを追加

    ```shell
    $ USERNAME=lucky #適宜ユーザ名は変更する
    $ adduser "$USERNAME" --comment ''
    Adding user `lucky' ...
    Adding new group `lucky' (1000) ...
    Adding new user `lucky' (1000) with group `lucky (1000)' ...
    Creating home directory `/home/lucky' ...
    Copying files from `/etc/skel' ...
    New password:
    Retype new password:
    passwd: password updated successfully
    Adding new user `lucky' to supplemental / extra groups `users' ...
    Adding user `lucky' to group `users' ...
    ```

2. 作業用ユーザを`sudoers`グループに追加する

    ```shell
    $ gpasswd -a "$USERNAME" sudo
    Adding user lucky to group sudo
    $ groups "$USERNAME"
    lucky : lucky sudo users
    ```

### 4.6. コンテナ）SSHサーバの設定をする

1. `sshd`の設定を変更する

    ```shell
    ### root ユーザでのログインを禁止する
    sed -i -E 's/^#?PermitRootLogin .*$/PermitRootLogin no/' /etc/ssh/sshd_config

    ### パスワード認証を禁止する
    sed -i -E 's/^#?PasswordAuthentication .*$/PasswordAuthentication no/' /etc/ssh/sshd_config
    ```

2. 作業用ユーザにSSH公開鍵の設定をする

    ```shell
    su - "$USERNAME"
    mkdir ~/.ssh
    chmod 700 ~/.ssh
    curl https://github.com/Lucky3028.keys > ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    exit
    ```

3. 設定変更を反映させる

    ```shell
    sshd -t # 出力が何も無いことを確認する

    ### LXCコンテナ特有の問題なのか、ポートの変更をするにはssh.socketも再起動させる必要がある
    ### ref. https://forum.proxmox.com/threads/ssh-doesnt-work-as-expected-in-lxc.54691/page-2
    systemctl disable ssh.socket
    systemctl enable ssh
    systemctl reboot
    ```

4. 別ターミナルで、以下のことを確認する
    - 作業用ユーザとして公開鍵認証でSSH接続できること
    - 作業用ユーザとしてパスワード認証でSSH接続できないこと
    - `root`ユーザでSSH接続できないこと

    ```shell
    ssh -i ~/.ssh/id_ed25519 lucky@192.168.20.3 # will OK
    ssh lucky@192.168.20.3 # will fail
    ssh root@192.168.20.3 # will fail
    ```

5. コンテナを停止する

    ```shell
    ssh -p 60000 lucky@192.168.20.3

    sudo systemctl poweroff
    ```

### 4.7. ホスト）コンテナを特権モードで動作させる

1. ProxmoxホストにSSH接続する

    ```shell
    ssh proxmox-01
    ```

2. 特権モードで動作させるために、以下の書き込みをする

    ```shell
    cat << EOF | sudo tee -a /etc/pve/lxc/101.conf > /dev/null

    lxc.cgroup2.devices.allow: c 10:200 rwm
    lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
    EOF
    ```

3. コンテナを起動する

    ```shell
    sudo pct start 101
    exit
    ```

### 4.8. コンテナ）`Tailscale`をセットアップする

1. コンテナにIPフォワーディングを許可する

    ```shell
    ssh tailscale-01

    sudo sed -i 's/^#net.ipv4.ip_forward=1$/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    sudo sed -i 's/^#net.ipv6.conf.all.forwarding=1$/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf

    ### 再起動させる
    sudo systemctl reboot
    ```

2. `Tailscale`をインストールする

    ```shell
    ssh tailscale-01

    curl -fsSL https://tailscale.com/install.sh | sh
    sudo tailscale up --advertise-routes=192.168.20.0/24 --advertise-exit-node --accept-routes

    exit
    ```

### 4.9. `Tailscale`でExit Nodeの設定をする

1. [Tailscale](https://login.tailscale.com/admin/machines)を開く。
2. `tailscale-0` > `Edit route settings...`を押下する
3. `Subnet routes` > `192.168.20.0/24` と `Exit node` > `Use as exit node` にチェックを入れる
4. `Save`を押下する

### 4.10. `Tailscale`の鍵の有効期限を無効化をする

ref. <https://tailscale.com/kb/1028/key-expiry>

1. `tailscale-0` > `Disable key expiry`を押下する

## 5. 完了条件

- LXCコンテナに対するSSH接続において、`root`ユーザとしてログインできないこと
- LXCコンテナに対するSSH接続において、作業用ユーザが作成されていて、そのユーザとしてログインできること
- `Tailscale`により、インターネットからセキュアにネットワーク内にアクセスできること
