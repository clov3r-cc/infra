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
  - [4.4. CI/CD用ユーザを追加する](#44-cicd用ユーザを追加する)
  - [4.5. SSHサーバの設定をする](#45-sshサーバの設定をする)
  - [4.6. cloud-init の準備をする](#46-cloud-init-の準備をする)
- [5. 完了条件](#5-完了条件)

<!-- /code_chunk_output -->

## 2. 目的・概要

`Proxmox`起動後の初期設定をする手順書です。

## 3. 前提条件

- `Proxmox 9.x`がインストール済みで、起動していること
- ホスト名: `pve-01`

## 4. 作業手順

### 4.1. エンタープライズ向けリポジトリへの参照を非エンタープライズ向けのものに変更する

1. `Proxmox`ホストにSSH接続する

    ```shell
    ssh root@192.168.20.2
    ```

2. エンタープライズ向けリポジトリへの参照を無効化する

    ```shell
    cd /etc/apt/sources.list.d/

    sed -i.bak 's/^/# /g' pve-enterprise.sources
    sed -i.bak 's/^/# /g' ceph.sources

    # 上記差分のみが表示されることを確認する
    diff -s ./pve-enterprise.sources ./pve-enterprise.sources.bak
    diff -s ./ceph.sources ./ceph.sources.bak

    rm *.sources.bak
    ```

3. 非エンタープライズ向けリポジトリへの参照を有効化する

    ```shell
    # No such file or directory と出力されることを確認する
    $ ls proxmox.sources
    ls: cannot access 'proxmox.sources': No such file or directory

    $ cat <<EOF > ./proxmox.sources
    Types: deb
    URIs: http://download.proxmox.com/debian/pve
    Suites: trixie
    Components: pve-no-subscription
    Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
    EOF

    # 出力があることを確認する
    $ ls proxmox.sources
    ```

    ```shell
    # 出力がないことを確認する。出力が何も無ければ OK
    grep 'no-subscription' ./ceph.sources

    cp ./ceph.sources ./ceph.sources.bak

    cat <<EOF >> ./ceph.sources

    # no-subscription repository provided by proxmox.com
    Types: deb
    URIs: http://download.proxmox.com/debian/ceph-squid
    Suites: trixie
    Components: no-subscription
    Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
    EOF

    # 上記差分のみが表示されることを確認する
    diff -s ./ceph.sources.bak ./ceph.sources

    rm ceph.sources.bak
    ```

4. パッケージの更新と必要なパッケージのインストールを行う

    ```shell
    apt update && apt upgrade -y && apt dist-upgrade -y && \
      apt install sudo pwgen vim -y
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

3. 作業用ユーザにSSH公開鍵の設定をする

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

### 4.4. CI/CD用ユーザを追加する

1. Linux上のユーザを追加する

    ```shell
    $ USERNAME=machine-user

    # ユーザが存在しないことを確認する。出力が何も無ければ OK
    $ grep "$USERNAME" /etc/passwd

    $ adduser "$USERNAME" --comment ''
    Adding user `machine-user' ...
    Adding new group `machine-user' (1001) ...
    Adding new user `machine-user' (1001) with group `machine-user (1001)' ...
    Creating home directory `/home/machine-user' ...
    Copying files from `/etc/skel' ...
    New password:
    Retype new password:
    passwd: password updated successfully
    Adding new user `machine-user' to supplemental / extra groups `users' ...
    Adding user `machine-user' to group `users' ...

    # ユーザが存在することを確認する
    $ grep "$USERNAME" /etc/passwd
    ```

2. 作業用ユーザを`sudoers`グループに追加する

    ```shell
    # ユーザが sudo グループに所属していないことを確認する
    $ groups "$USERNAME"
    machine-user : machine-user users

    $ gpasswd -a "$USERNAME" sudo
    Adding user machine-user to group sudo

    # ユーザが sudo グループに所属していることを確認する
    $ groups "$USERNAME"
    machine-user : machine-user sudo users
    ```

3. 作業用ユーザにSSH公開鍵の設定をする

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

4. ユーザに割り当てるロールを作成する

    |            権限            |                              説明                               |
    | -------------------------- | --------------------------------------------------------------- |
    | Datastore.Allocate         | ディスク等のデータを格納するボリュームの編集                    |
    | Datastore.AllocateSpace    | ディスク等のデータを格納するボリュームの利用                    |
    | Datastore.AllocateTemplate | ディスク等のデータを格納するボリュームに ISO などをアップロード |
    | Datastore.Audit            | ディスク等のデータを格納するボリュームの参照                    |
    | Pool.Allocate              | プールの作成・編集・削除                                        |
    | SDN.Audit                  | ホスト NW の参照                                                |
    | SDN.Use                    | ホスト NW の利用                                                |
    | Sys.Audit                  | ホスト NW の参照                                                |
    | Sys.Console                | 各 VM コンソールへのアクセス                                    |
    | Sys.Modify                 | ホスト NW の編集                                                |
    | VM.Allocate                | VM の作成・削除                                                 |
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
    | VM.PowerMgmt               | VM の起動・停止など電源の管理                                   |

    ```shell
    MACHINEUSER_ROLE='MachineUser'

    # ロールが存在しないことを確認する。何も出力されなければ OK
    pveum role list | grep "$MACHINEUSER_ROLE"

    pveum role add "$MACHINEUSER_ROLE"
    # 何も出力されなければ OK

    pveum role modify "$MACHINEUSER_ROLE" --privs Pool.Allocate,Datastore.Allocate,Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,SDN.Audit,Sys.Console,SDN.Use,Sys.Audit,Sys.Modify,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.Monitor,VM.PowerMgmt
    # 何も出力されなければ OK

    # ロールが存在することを確認する。追加したロールと権限が表示されれば OK
    pveum role list | grep "$MACHINEUSER_ROLE"
    ```

5. Proxmox上のユーザを作成する

    ```shell
    # @pve でレルムに Proxmox VE authentication server を指定する
    MACHINEUSER_USERNAME='machine-user@pve'

    # ユーザが存在しないことを確認する。何も出力されなければ OK
    pveum user list | grep "$MACHINEUSER_USERNAME"

    pveum user add "$MACHINEUSER_USERNAME"
    # 何も出力されなければ OK

    # ユーザが存在することを確認する。出力があれば OK
    pveum user list | grep "$MACHINEUSER_USERNAME"
    ```

6. ユーザにロールを紐づける

    ```shell
    pveum acl modify / -user "$MACHINEUSER_USERNAME" -role "$MACHINEUSER_ROLE"
    # 何も出力されなければ OK
    ```

7. API トークンを作成する

    ```shell
    # トークンが存在しないことを確認する。何も出力されなければ OK
    $ pveum user token list "$MACHINEUSER_USERNAME"

    # tf はトークンの ID
    # -privsep 0 で、トークンの権限をユーザの権限と共通化（権限分離をしない）
    $ pveum user token add "$MACHINEUSER_USERNAME" tf -privsep 0
    # トークンのシークレット値が出力されるので、メモしておく
    ┌──────────────┬──────────────────────────────────────┐
    │ key          │ value                                │
    ╞══════════════╪══════════════════════════════════════╡
    │ full-tokenid │ machine-user@pam!tf                  │
    ├──────────────┼──────────────────────────────────────┤
    │ info         │ {"privsep":1}                        │
    ├──────────────┼──────────────────────────────────────┤
    │ value        │ (シークレット値)                      │
    └──────────────┴──────────────────────────────────────┘

    # トークンが存在することを確認する。作成したトークンが出力されば OK
    $ pveum user token list "$MACHINEUSER_USERNAME"
    ┌─────────┬─────────┬────────┬─────────┐
    │ tokenid │ comment │ expire │ privsep │
    ╞═════════╪═════════╪════════╪═════════╡
    │ tf      │         │      0 │ 0       │
    └─────────┴─────────┴────────┴─────────┘
    ```

### 4.5. SSHサーバの設定をする

1. sshdの設定を変更する

    ```shell
    cd /etc/ssh/
    cp ./sshd_config ./sshd_config.orig

    # root ユーザでのログインを禁止する
    sed -i -E 's/^#?PermitRootLogin .*$/PermitRootLogin no/' ./sshd_config

    # パスワード認証を禁止する
    sed -i -E 's/^#?PasswordAuthentication .*$/PasswordAuthentication no/' ./sshd_config

    # 上記の差分のみが表示されることを確認する
    diff -s ./sshd_config ./sshd_config.orig
    # 設定を検証する。出力が何も無ければ OK
    sshd -t

    rm ./sshd_config.orig
    ```

2. 設定変更を反映させる

    ```shell
    systemctl restart sshd
    ```

3. 別ターミナルで、以下のことを確認する
    - 作業用ユーザとして公開鍵認証でSSH接続できること
    - 作業用ユーザとしてパスワード認証でSSH接続できないこと
    - CI/CD用ユーザとして公開鍵認証でSSH接続できること
    - CI/CD用ユーザとしてパスワード認証でSSH接続できないこと
    - `root`ユーザでSSH接続できないこと

    ```shell
    ssh -i ~/.ssh/id_ed25519 lucky@192.168.20.2 # will OK
    ssh lucky@192.168.20.2 # will fail
    ssh -i ~/.ssh/id_ed25519 machine-user@192.168.20.2 # will OK
    ssh machine-user@192.168.20.2 # will fail
    ssh root@192.168.20.2 # will fail
    ```

### 4.6. cloud-init の準備をする

1. snippets を有効化する

    ```shell
    $ sudo pvesm set local --content iso,backup,snippets,vztmpl
    # 何も出力されなければ OK

    # local が表示されれば OK
    $ sudo pvesm status -content snippets
    Name         Type     Status           Total            Used       Available        %
    local         dir     active        98497780         7374676        86073556    7.49%

    # snippets ディレクトリが表示されれば OK
    $ ls /var/lib/vz/
    dump  images  snippets  template
    ```

2. 作業端末に Red Hat Enterprise Linux の cloud-init 用イメージをダウンロードする

    ここでは、Red Hat Enterprise Linux 9.4 (x86_64) の KVM Guest Image をダウンロードすることします。

    ダウンロードは、[Red Hat Customer Portal](https://access.redhat.com/downloads/content/479/ver=/rhel---9/9.4/x86_64/product-software) から行うことができます。

    ダウンロード先を Windows 標準のダウンロードフォルダ、ダウンロードできたファイル名を`rhel-9.4-x86_64-kvm.qcow2`とします。

3. ダウンロードしたイメージを Proxmox ホストにアップロードする

    WSL 上の Ubuntu 24.04 からアップロードする手順を記載します。

    ```shell
    sftp proxmox-01:/tmp/ <<< $'put /mnt/c/Users/Lucky/Downloads/rhel-9.4-x86_64-kvm.qcow2'
    # エラーが出力されなければ OK
    ```

4. アップロードしたイメージを移動する

    ```shell
    sudo mv /tmp/rhel-9.4-x86_64-kvm.qcow2 /var/lib/vz/template/iso/
    # エラーが出力されなければ OK
    ```

5. VM のテンプレートを作成する

    ```shell
    ISO_DIR='/var/lib/vz/template/iso'
    ISO_NAME="rhel-9.4-x86_64-kvm.qcow2"

    echo 'Customizing iso...'
    sudo virt-customize -a "$ISO_DIR/$ISO_NAME" --run-command 'echo -n >/etc/machine-id'
    echo 'OK!!!'
    echo ''

    echo 'Creating VM template...'
    VM_TMPL_ID=901
    VM_TMPL_NAME="rhel-9.4"
    VM_DISK_STORAGE=local-lvm
    sudo qm destroy "$VM_TMPL_ID" --purge || true
    sudo qm create $VM_TMPL_ID --name $VM_TMPL_NAME --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
    sudo qm set $VM_TMPL_ID --scsihw virtio-scsi-single
    sudo qm set $VM_TMPL_ID --virtio0 "${VM_DISK_STORAGE}:0,import-from=$ISO_DIR/$ISO_NAME"
    sudo qm set $VM_TMPL_ID --boot c --bootdisk virtio0
    sudo qm set $VM_TMPL_ID --ide2 "${VM_DISK_STORAGE}:cloudinit"
    sudo qm set $VM_TMPL_ID --serial0 socket --vga serial0
    sudo qm set $VM_TMPL_ID --agent enabled=1,fstrim_cloned_disks=1
    sudo qm template $VM_TMPL_ID
    echo 'OK!!!'
    ```

## 5. 完了条件

- パッケージの更新が行えること
- `Proxmox`ホストに対するSSH接続において、`root`ユーザとしてログインできないこと
- `Proxmox`ホストに対するSSH接続において、作業用ユーザが作成されていて、そのユーザとしてログインできること
- `Proxmox`ホストに対するSSH接続において、CI/CD用ユーザが作成されていて、そのユーザとしてログインできること
- cloud-init に使用する VM のテンプレートとスニペットの設定がされていること
