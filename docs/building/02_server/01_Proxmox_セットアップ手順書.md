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
  - [4.5. CI/CD用ユーザを追加する](#45-cicd用ユーザを追加する)
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

    cp ./pve-enterprise.list ./pve-enterprise.list.orig
    cp ./ceph.list ./ceph.list.orig

    sed -i 's@^deb https://enterprise.proxmox.com@# deb https://enterprise.proxmox.com@' ./pve-enterprise.list
    sed -i 's@^deb https://enterprise.proxmox.com@# deb https://enterprise.proxmox.com@' ./ceph.list

    # 上記2点の差分のみが表示されることを確認する
    diff -s ./pve-enterprise.list ./pve-enterprise.list.orig
    diff -s ./ceph.list ./ceph.list.orig

    rm *.list.orig
    ```

3. 非エンタープライズ向けリポジトリへの参照を有効化する

    ```shell
    # No such file or directory と出力されることを確認する
    $ ls pve-no-subscription.list
    ls: cannot access 'pve-no-subscription.list': No such file or directory

    $ cat <<EOF > ./pve-no-subscription.list

    # pve-no-subscription repository provided by proxmox.com
    deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
    EOF

    # 出力があることを確認する
    $ ls pve-no-subscription.list
    ```

    ```shell
    # 出力がないことを確認する。出力が何も無ければ OK
    grep 'no-subscription' ./ceph.list

    cat <<EOF >> ./ceph.list

    # no-subscription repository provided by proxmox.com
    deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription
    deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription
    deb http://download.proxmox.com/debian/ceph-squid bookworm no-subscription
    EOF

    # 出力があることを確認する
    grep 'no-subscription' ./ceph.list
    ```

4. パッケージの更新と必要なパッケージのインストールを行う

    ```shell
    apt update && apt upgrade -y && apt dist-upgrade -y && \
      apt install sudo vim -y
    # エラーが表示されなければ OK
    ```

### 4.2. rootのパスワードを任意のものに変更する

1. パスワードを変更する

    ```bash
    $ passwd
    New password:
    Retype new password:
    # 下記が表示されれば OK
    passwd: password updated successfully
    ```

### 4.3. 作業用ユーザを追加する

1. 作業用ユーザを追加

    ```shell
    $ USERNAME=lucky #適宜ユーザ名は変更する

    # ユーザが存在しないことを確認する。出力が何も無ければ OK
    $ grep "$USERNAME" /etc/passwd

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

    # ユーザが存在することを確認する
    $ grep "$USERNAME" /etc/passwd
    ```

2. 作業用ユーザを`sudoers`グループに追加する

    ```shell
    # ユーザが sudo グループに所属していないことを確認する
    $ groups "$USERNAME"
    lucky : lucky users

    $ gpasswd -a "$USERNAME" sudo
    Adding user lucky to group sudo

    # ユーザが sudo グループに所属していることを確認する
    $ groups "$USERNAME"
    lucky : lucky sudo users
    ```

### 4.4. SSHサーバの設定をする

**注意: SSHポートの値はコマンドで参照している変数を参照します。適宜変更してください。**

1. sshdの設定を変更する

    ```shell
    cd /etc/ssh/
    cp ./sshd_config ./sshd_config.orig

    # ポートを変更する
    NEW_SSH_PORT=60000 # 適宜ポートは変更する
    sed -i -E "s/^#?Port .*$/Port ${NEW_SSH_PORT}/" ./sshd_config

    # root ユーザでのログインを禁止する
    sed -i -E 's/^#?PermitRootLogin .*$/PermitRootLogin no/' ./sshd_config

    # パスワード認証を禁止する
    sed -i -E 's/^#?PasswordAuthentication .*$/PasswordAuthentication no/' ./sshd_config

    # 上記3点の差分のみが表示されることを確認する
    diff -s ./sshd_config ./sshd_config.orig
    # 設定を検証する。出力が何も無ければ OK
    sshd -t

    rm ./sshd_config.orig
    ```

2. 作業用ユーザにSSH公開鍵の設定をする

    ```shell
    $ su - "$USERNAME"

    $ mkdir ~/.ssh
    $ chmod 700 ~/.ssh
    $ curl https://github.com/Lucky3028.keys > ~/.ssh/authorized_keys
    $ chmod 600 ~/.ssh/authorized_keys

    # それぞれ以下のように権限設定がされていることを確認する
    $ stat -c "%A %n" .ssh
    drwx------ .ssh
    $ stat -c "%A %n" .ssh/authorized_keys
    -rw------- .ssh/authorized_keys

    $ exit
    ```

3. 設定変更を反映させる

    ```shell
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

### 4.5. CI/CD用ユーザを追加する

1. `Proxmox`ホストにSSH接続する

    ```shell
    ssh proxmox-01
    ```

2. ユーザに割り当てるロールを作成する

    |            権限            |                              説明                               |
    | -------------------------- | --------------------------------------------------------------- |
    | Pool.Allocate              | プール設定の編集                                                |
    | Datastore.Allocate         | ディスク等のデータを格納するボリュームの編集                    |
    | Datastore.AllocateSpace    | ディスク等のデータを格納するボリュームの利用                    |
    | Datastore.AllocateTemplate | ディスク等のデータを格納するボリュームに ISO などをアップロード |
    | Datastore.Audit            | ディスク等のデータを格納するボリュームの参照                    |
    | SDN.Audit                  | ホスト NW の管理                                                |
    | SDN.Use                    | ホスト NW の利用                                                |
    | Sys.Audit                  | ホスト NW の参照                                                |
    | Sys.Console                | 各 VM コンソールへのアクセス                                    |
    | Sys.Modify                 | ホスト NW の編集                                                |
    | VM.Allocate                | VM の作成                                                       |
    | VM.Audit                   | VM の参照                                                       |
    | VM.Clone                   | VM のクローン                                                   |
    | VM.Config.CDROM            | CD/DVD の挿入・排出                                             |
    | VM.Config.CPU              | CPU 設定の編集                                                  |
    | VM.Config.Cloudinit        | Cloud-init 設定の編集                                           |
    | VM.Config.Disk             | ディスクの編集                                                  |
    | VM.Config.HWType           | エミュレートされた HW 設定の編集                                |
    | VM.Config.Memory           | メモリ設定の編集                                                |
    | VM.Config.Network          | NW 設定の編集                                                   |
    | VM.Config.Options          | その他 VM 設定の編集                                            |
    | VM.Migrate                 | VM を他ホストにマイグレーション                                 |
    | VM.Monitor                 | VM の状況を確認                                                 |
    | VM.PowerMgmt               | VM の起動・停止など電源の管理                                   |

    ```shell
    MACHINEUSER_ROLE='TFMachineUser'

    # ロールが存在しないことを確認する。何も出力されなければ OK
    sudo pveum role list | grep "$MACHINEUSER_ROLE"

    sudo pveum role add "$MACHINEUSER_ROLE"
    # 何も出力されなければ OK

    sudo pveum role modify TFMachineUser --privs Pool.Allocate,Datastore.Allocate,Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,SDN.Audit,Sys.Console,SDN.Use,Sys.Audit,Sys.Modify,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.Monitor,VM.PowerMgmt
    # 何も出力されなければ OK

    # ロールが存在することを確認する。追加したロールと権限が表示されれば OK
    sudo pveum role list | grep "$MACHINEUSER_ROLE"
    ```

3. ユーザを作成する

    ```shell
    # @pve でレルムに Proxmox VE authentication server を指定する
    MACHINEUSER_NAME='machine-user@pve'

    # ユーザが存在しないことを確認する。何も出力されなければ OK
    sudo pveum user list | grep "$MACHINEUSER_NAME"

    # pwgen options:
    # -c アルファベット大文字を1つ以上
    # -n 数字を1つ以上
    # -s 完全にランダムで覚えにくいパスワードを生成する
    # -y 記号を1つ以上
    # -B 曖昧で間違えにくい文字を含まない
    # NOTE: pwgen コマンドはファイルへのリダイレクトなどの場合は、1個しかパスワードを生成しない
    MACHINEUSER_PASSWORD=$(pwgen -cnsyB 16)
    sudo pveum user add "$MACHINEUSER_NAME" --password "$MACHINEUSER_PASSWORD"
    # 何も出力されなければ OK

    # ユーザが存在することを確認する。出力があれば OK
    sudo pveum user list | grep "$MACHINEUSER_NAME"

    # パスワードをメモする
    echo "$MACHINEUSER_PASSWORD"
    unset MACHINEUSER_PASSWORD
    ```

4. ユーザにロールを紐づける

    ```shell
    sudo pveum acl modify / -user "$MACHINEUSER_NAME" -role "$MACHINEUSER_ROLE"
    # 何も出力されなければ OK
    ```

5. API トークンを作成する

    ```shell
    # トークンが存在しないことを確認する。何も出力されなければ OK
    $ sudo pveum user token list "$MACHINEUSER_NAME"

    # tf はトークンの ID
    # -privsep 0 で、トークンの権限をユーザの権限と共通化（権限分離をしない）
    $ sudo pveum user token add "$MACHINEUSER_NAME" tf -privsep 0
    # トークンのシークレット値が出力されるので、メモしておく
    ┌──────────────┬──────────────────────────────────────┐
    │ key          │ value                                │
    ╞══════════════╪══════════════════════════════════════╡
    │ full-tokenid │ machine-user@pve!tf                  │
    ├──────────────┼──────────────────────────────────────┤
    │ info         │ {"privsep":1}                        │
    ├──────────────┼──────────────────────────────────────┤
    │ value        │ (シークレット値)                      │
    └──────────────┴──────────────────────────────────────┘

    # トークンが存在することを確認する。作成したトークンが出力されば OK
    $ sudo pveum user token list "$MACHINEUSER_NAME"
    ┌─────────┬─────────┬────────┬─────────┐
    │ tokenid │ comment │ expire │ privsep │
    ╞═════════╪═════════╪════════╪═════════╡
    │ tf      │         │      0 │ 0       │
    └─────────┴─────────┴────────┴─────────┘
    ```

## 5. 完了条件

- `Proxmox`ホストに対するSSH接続において、`root`ユーザとしてログインできないこと
- `Proxmox`ホストに対するSSH接続において、作業用ユーザが作成されていて、そのユーザとしてログインできること
