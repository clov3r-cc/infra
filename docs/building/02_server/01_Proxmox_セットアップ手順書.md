# Proxmox セットアップ手順書

## 1. 目次

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [1. 目次](#1-目次)
- [2. 目的・概要](#2-目的概要)
- [3. 前提条件](#3-前提条件)
- [4. 作業手順](#4-作業手順)
  - [4.1. エンタープライズ向けリポジトリへの参照を非エンタープライズ向けのものに変更する](#41-エンタープライズ向けリポジトリへの参照を非エンタープライズ向けのものに変更する)
  - [4.2. rootのパスワードを任意のものに変更する](#42-rootのパスワードを任意のものに変更する)
  - [4.3. 作業用ユーザを追加する](#43-作業用ユーザを追加する)
  - [4.4. SSHサーバの設定をする](#44-sshサーバの設定をする)
- [5. 完了条件](#5-完了条件)

<!-- /code_chunk_output -->

## 2. 目的・概要

`Proxmox`起動後の初期設定をする手順書です。

## 3. 前提条件

- `Proxmox`がインストール済みで、起動していること
- ホスト名: `lucky-proxmox-01`

## 4. 作業手順

### 4.1. エンタープライズ向けリポジトリへの参照を非エンタープライズ向けのものに変更する

1. `Proxmox`ホストにSSH接続する

    ```shell
    ssh root@192.168.20.2
    ```

2. エンタープライズ向けリポジトリへの参照を無効化する

    ```shell
    cd /etc/apt/sources.list.d/
    sed -i 's@^deb https://enterprise.proxmox.com@# deb https://enterprise.proxmox.com@' ./sources.list.d/pve-enterprise.list
    sed -i 's@^deb https://enterprise.proxmox.com@# deb https://enterprise.proxmox.com@' ./sources.list.d/ceph.list
    ```

3. 非エンタープライズ向けリポジトリへの参照を有効化する

    ```shell
    cat <<EOF >> sources.list

    # PVE pve-no-subscription repository provided by proxmox.com,
    # NOT recommended for production use
    deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
    EOF
    ```

    ```shell
    cat <<EOF >> sources.list.d/ceph.list

    deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription
    deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription
    deb http://download.proxmox.com/debian/ceph-squid bookworm no-subscription
    EOF
    ```

4. パッケージの更新と必要なパッケージのインストールを行う

    ```shell
    apt update && apt upgrade -y && apt dist-upgrade -y && \
      apt install sudo vim -y
    ```

### 4.2. rootのパスワードを任意のものに変更する

1. パスワードを変更する

    ```bash
    $ passwd
    New password:
    Retype new password:
    passwd: password updated successfully
    ```

### 4.3. 作業用ユーザを追加する

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

### 4.4. SSHサーバの設定をする

**注意: SSHポートの値はコマンドで参照している変数を参照します。適宜変更してください。**

1. sshdの設定を変更する

    ```shell
    ### ポートを変更する
    NEW_SSH_PORT=60000 # 適宜ポートは変更する
    sed -i -E "s/^#?Port .*$/Port ${NEW_SSH_PORT}/" /etc/ssh/sshd_config

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
    systemctl restart sshd
    ```

4. 別ターミナルで、以下のことを確認する
    - 作業用ユーザとして公開鍵認証でSSH接続できること
    - 作業用ユーザとしてパスワード認証でSSH接続できないこと
    - `root`ユーザでSSH接続できないこと

    ```shell
    ssh -i ~/.ssh/id_ed25519 lucky@192.168.20.2 # will OK
    ssh lucky@192.168.20.2 # will fail
    ssh root@192.168.20.2 # will fail
    ```

## 5. 完了条件

- `Proxmox`ホストに対するSSH接続において、`root`ユーザとしてログインできないこと
- `Proxmox`ホストに対するSSH接続において、作業用ユーザが作成されていて、そのユーザとしてログインできること
