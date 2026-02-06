# Tailscale セットアップ手順書

## 1. 目次

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [1. 目次](#1-目次)
- [2. 目的・概要](#2-目的概要)
- [3. 前提条件](#3-前提条件)
- [4. 作業手順](#4-作業手順)
  - [4.1. ホスト）VMに用いるイメージを取得する](#41-ホストvmに用いるイメージを取得する)
  - [4.2. ホスト）VMを作成する](#42-ホストvmを作成する)
  - [4.3. ホスト）Debianのインストールをする](#43-ホストdebianのインストールをする)
  - [4.4. VM）必要なパッケージのインストールを行う](#44-vm必要なパッケージのインストールを行う)
  - [4.5. コンテナ）パスワードレス`sudo`認証を有効にする](#45-コンテナパスワードレスsudo認証を有効にする)
  - [4.6. VM）作業用ユーザをセットアップする](#46-vm作業用ユーザをセットアップする)
  - [4.7. VM）SSHサーバの設定をする](#47-vmsshサーバの設定をする)
  - [4.8. `/etc/network/interfaces`からnetplanに移行する](#48-etcnetworkinterfacesからnetplanに移行する)
  - [4.9. VM）`Tailscale`をセットアップする](#49-vmtailscaleをセットアップする)
  - [4.10. `Tailscale`で経路の広告（アドバタイズ）を設定する](#410-tailscaleで経路の広告アドバタイズを設定する)
  - [4.11. `Tailscale`の鍵の有効期限を無効化をする](#411-tailscaleの鍵の有効期限を無効化をする)
  - [4.12. `Tailscale`クライアントとしてタグをつける](#412-tailscaleクライアントとしてタグをつける)
- [5. 完了条件](#5-完了条件)

<!-- /code_chunk_output -->

## 2. 目的・概要

`Tailscale`を稼働させるVMを作成する手順書です。（LXCコンテナだと動作が不安定になるので、VMを使用します。）

## 3. 前提条件

- `Proxmox`のセットアップまで完了していること

## 4. 作業手順

### 4.1. ホスト）VMに用いるイメージを取得する

1. VMのISOイメージを取得する

    ここでは、Debianの2026年2月現在のLTSであるDebian 13.3.0のイメージを使用する。

    ```shell
    ssh prod-prox-01

    IMAGE_NAME=debian-13.3.0-amd64-netinst.iso
    sudo wget -O "/var/lib/vz/template/iso/$IMAGE_NAME" "https://chuangtzu.ftp.acc.umu.se/debian-cd/current/amd64/iso-cd/$IMAGE_NAME"
    ```

### 4.2. ホスト）VMを作成する

1. VMを作成する

    ```shell
    ### VMを作成する
    VM_ID=101
    sudo qm create "$VM_ID" \
      --name prod-tail-01 \
      --ostype l26 \
      --sockets 1 \
      --cores 1 \
      --cpu x86-64-v3 \
      --memory 2048 \
      --scsihw virtio-scsi-single \
      --scsi0 local-lvm:15,format=raw \
      --ide0 "local:iso/$IMAGE_NAME,media=cdrom" \
      --net0 virtio,bridge=vmbr1 \
      --agent 1 \
      --boot "order=scsi0;ide0;net0" \
      --onboot 1
    # エラーが表示されなければOK
    sudo qm start "$VM_ID"
    sudo qm status "$VM_ID"
    # status: running と表示されればOK

    exit
    ```

### 4.3. ホスト）Debianのインストールをする

以下を選択、入力して、Continueを選択し続ける。

- 言語: en-US
- ネットワーク構成: Static
  - IPアドレス: 192.168.21.3/24
  - デフォルトゲートウェイ: 192.168.21.1
  - ネームサーバ: 192.168.21.1
- ホスト名: prod-tail-01
- ドメイン名: （空欄）
- rootのパスワード: （適宜）
- 追加ユーザ
  - ユーザ名: lucky
  - パスワード: （適宜）
- 時計: Pacific
- ディスク構成
  - Guided - use entire disk
  - SCSi 0
  - All files in one partition
  - Finish partitioning and write changes to disk
- 追加のインストールメディア: No
- パッケージマネージャの構成
  - アーカイブミラーの国: Japan
  - アーカイブミラーのURL: `ftp.jp.debian.org`
  - HTTPプロキシ: （空欄）
- パッケージの利用状況調査: No
- インストールするパッケージ
  - SSH server
  - standard system utilities
  - ※Debian desktop environmentやGNOMEのチェックは外す（CLIのみの構成にする）
- ブートローダー
  - GRUBを使用するか: Yes
  - どのデバイスにインストールするか: /dev/sda

インストール完了の画面が出たら、CD/DVDメディアを削除してContinueを選択する

### 4.4. VM）必要なパッケージのインストールを行う

1. パッケージの更新と必要なパッケージのインストールを行う

    ```shell
    ssh lucky@192.168.21.3

    su -

    apt update && apt upgrade -y && apt dist-upgrade -y && \
      apt install curl sudo vim -y
    ```

### 4.5. コンテナ）パスワードレス`sudo`認証を有効にする

1. `libpam-ssh-agent-auth`をインストールする

    ```shell
    apt update && apt install -y libpam-ssh-agent-auth
    # エラーが出力されなければ OK
    ```

2. `SSH Agent`用の環境変数を保持する設定をする

    ```shell
    EDITOR=vim visudo
    # 以下内容を追加

    # Keep SSH_AUTH_SOCK to forward ssh-agent
    Defaults env_keep += "SSH_AUTH_SOCK"

    :wq
    ```

3. `sudo`の認証に公開鍵を用いる設定をする

    ```shell
    vim /etc/pam.d/sudo
    # 以下内容を冒頭に追加

    # Use pubkey
    auth sufficient pam_ssh_agent_auth.so file=~/.ssh/authorized_keys

    :wq
    ```

### 4.6. VM）作業用ユーザをセットアップする

1. 作業用ユーザを`sudo`グループに追加する

    ```shell
    $ USERNAME=lucky #適宜ユーザ名は変更する
    $ gpasswd -a "$USERNAME" sudo
    Adding user lucky to group sudo
    $ groups "$USERNAME"
    lucky : lucky cdrom floppy sudo audio dip video plugdev users netdev
    ```

### 4.7. VM）SSHサーバの設定をする

1. `sshd`の設定を変更する

    ```shell
    ### root ユーザでのログインを禁止する
    sed -i -E 's/^#?PermitRootLogin .*$/PermitRootLogin no/' /etc/ssh/sshd_config

    ### パスワード認証を禁止する
    sed -i -E 's/^#?PasswordAuthentication .*$/PasswordAuthentication no/' /etc/ssh/sshd_config
    ```

2. 作業用ユーザにSSH公開鍵の設定をする

    ```shell
    exit

    mkdir ~/.ssh
    chmod 700 ~/.ssh
    curl -sS https://github.com/Lucky3028.keys > ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys

    su -
    ```

3. 設定変更を反映させる

    ```shell
    sshd -t # 出力が何も無いことを確認する

    systemctl reboot
    ```

4. 別ターミナルで、以下のことを確認する
    - 作業用ユーザとして公開鍵認証でSSH接続できること
    - 作業用ユーザとしてパスワード認証でSSH接続できないこと
    - `root`ユーザでSSH接続できないこと

    ```shell
    ssh -i ~/.ssh/id_ed25519 lucky@192.168.21.3 # will OK
    ssh -o PubkeyAuthentication=no lucky@192.168.21.3 # will fail
    ssh root@192.168.21.3 # will fail
    ```

### 4.8. `/etc/network/interfaces`からnetplanに移行する

1. 必要なパッケージをインストールする

    ```shell
    ssh prod-tail-01

    sudo apt install --no-install-recommends -y netplan.io
    ```

2. 設定ファイルを作成する

    ```shell
    cat << EOF | sudo tee /etc/netplan/99-config.yaml
    network:
      version: 2
      # systemd-networkdを明示的に使用
      renderer: networkd
      ethernets:
        ens18:
          addresses:
            - 192.168.21.3/24
          routes:
            - to: default
              via: 192.168.21.1
          nameservers:
            addresses:
              - 192.168.21.1
    EOF
    sudo chmod 600 /etc/netplan/99-config.yaml
    ```

3. netplanの設定を確認する

    ```bash
    # systemd-networkdを有効にして起動させる
    sudo systemctl enable --now systemd-networkd

    sudo netplan try --timeout 20

    # 別ターミナルを開いて
    ssh prod-tail-01
    # 接続できること
    ip -4 a
    # IPアドレスが想定通りであること
    ip r
    # デフォルトゲートウェイが設定されていること
    # を確認する
    # 別ターミナルを閉じる
    exit
    ```

4. netplanの設定を反映する

    ```bash
    sudo netplan apply
    ```

### 4.9. VM）`Tailscale`をセットアップする

1. VMにIPフォワーディングを許可する

    ```shell
    echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
    sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

    ### 再起動させる
    sudo systemctl reboot
    ```

2. `Tailscale`をインストールする

    ```shell
    ssh prod-tail-01

    curl -fsSL https://tailscale.com/install.sh | sh
    sudo tailscale up --advertise-routes=192.168.21.0/24 --accept-routes

    exit
    ```

### 4.10. `Tailscale`で経路の広告（アドバタイズ）を設定する

1. [Tailscale](https://login.tailscale.com/admin/machines)を開く。
2. `prod-tail-01` > `Edit route settings...`を押下する
3. `Subnet routes` > `192.168.21.0/24` にチェックを入れる
4. `Save`を押下する

### 4.11. `Tailscale`の鍵の有効期限を無効化をする

ref. <https://tailscale.com/kb/1028/key-expiry>

1. `prod-tail-01` > `Disable key expiry`を押下する

### 4.12. `Tailscale`クライアントとしてタグをつける

1. `prod-tail-01` > `Edit ACL tags...`を押下する
2. `Add tags` > `tag:pve`を選択する
3. `Save`を押下する

## 5. 完了条件

- VMに対するSSH接続において、`root`ユーザとしてログインできないこと
- VMに対するSSH接続において、作業用ユーザが作成されていて、そのユーザとしてログインできること
- パスワードを用いずに`sudo`コマンドを実行できること
- `Tailscale`により、インターネットからセキュアにネットワーク内にアクセスできること
- `Tailscale`において、`prod-tail-01`に以下の設定をしていること
  - 鍵の有効期限なし
  - サブネット広告あり
  - `tag:pve`付き
