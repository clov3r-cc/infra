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
  - [4.3. パスワードレス sudo 認証を有効にする](#43-パスワードレス-sudo-認証を有効にする)
  - [4.4. 作業用ユーザを追加する](#44-作業用ユーザを追加する)
  - [4.5. CI/CD用ユーザを追加する](#45-cicd用ユーザを追加する)
  - [4.6. VMのフェンシング用ユーザを追加する](#46-vmのフェンシング用ユーザを追加する)
  - [4.7. SSHサーバの設定をする](#47-sshサーバの設定をする)
  - [4.8. cloud-init の準備をする](#48-cloud-init-の準備をする)
    - [4.8.1. Debian の VM テンプレートを作成する](#481-debian-の-vm-テンプレートを作成する)
    - [4.8.2. Alma Linux の VM テンプレートを作成する](#482-alma-linux-の-vm-テンプレートを作成する)
  - [4.9. ネットワークブリッジを作成する](#49-ネットワークブリッジを作成する)
    - [4.9.1. Linux Bond を追加する](#491-linux-bond-を追加する)
    - [4.9.2. 内部通信に用いる NW を追加する](#492-内部通信に用いる-nw-を追加する)
    - [4.9.3. Zabbix Server のハートビートに用いる NW を追加する](#493-zabbix-server-のハートビートに用いる-nw-を追加する)
  - [4.10. イーサネットポートを有効にする](#410-イーサネットポートを有効にする)
- [5. 完了条件](#5-完了条件)

<!-- /code_chunk_output -->

## 2. 目的・概要

`Proxmox`起動後の初期設定をする手順書です。

## 3. 前提条件

- `Proxmox 9.x`がインストール済みで、起動していること
- ホスト名: `prd-pve-01`

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
      apt install guestfs-tools sudo pwgen vim -y
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

### 4.3. パスワードレス sudo 認証を有効にする

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

### 4.4. 作業用ユーザを追加する

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

### 4.5. CI/CD用ユーザを追加する

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
    | Pool.Audit                 | プールの参照                                                    |
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

    pveum role modify "$MACHINEUSER_ROLE" --privs Datastore.Allocate,Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Pool.Allocate,Pool.Audit,SDN.Audit,SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.PowerMgmt
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
    │ full-tokenid │ machine-user@pve!tf                  │
    ├──────────────┼──────────────────────────────────────┤
    │ info         │ {"privsep":0}                        │
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

### 4.6. VMのフェンシング用ユーザを追加する

1. ユーザに割り当てるロールを作成する

    |     権限     |             説明              |
    | ------------ | ----------------------------- |
    | VM.Audit     | VM の参照                     |
    | VM.PowerMgmt | VM の起動・停止など電源の管理 |

    ```shell
    STONITHAGENTUSER_ROLE='StonithAgent'

    # ロールが存在しないことを確認する。何も出力されなければ OK
    pveum role list | grep "$STONITHAGENTUSER_ROLE"

    pveum role add "$STONITHAGENTUSER_ROLE" -privs "VM.PowerMgmt,VM.Audit"
    # 何も出力されなければ OK

    # ロールが存在することを確認する。追加したロールと権限が表示されれば OK
    pveum role list | grep "$STONITHAGENTUSER_ROLE"
    ```

2. Proxmox上のユーザを作成する

    ```shell
    # @pve でレルムに Proxmox VE authentication server を指定する
    STONITHAGENTUSER_USERNAME='stonith@pve'

    # ユーザが存在しないことを確認する。何も出力されなければ OK
    pveum user list | grep "$STONITHAGENTUSER_USERNAME"

    pveum user add "$STONITHAGENTUSER_USERNAME"
    # 何も出力されなければ OK

    # ユーザが存在することを確認する。出力があれば OK
    pveum user list | grep "$STONITHAGENTUSER_USERNAME"
    ```

3. ユーザにロールを紐づける

    ```shell
    ZABBIX_SERVER_VM_ID_LIST=(401 402)
    for id in "${ZABBIX_SERVER_VM_ID_LIST[@]}" ; do
      pveum acl modify "/vms/$id" -user "$STONITHAGENTUSER_USERNAME" -role "$STONITHAGENTUSER_ROLE"
    done
    # 何も出力されなければ OK
    ```

4. API トークンを作成する

    ```shell
    # トークンが存在しないことを確認する。何も出力されなければ OK
    $ pveum user token list "$STONITHAGENTUSER_USERNAME"

    # zabbix-stonith はトークンの ID
    # -privsep 0 で、トークンの権限をユーザの権限と共通化（権限分離をしない）
    $ pveum user token add "$STONITHAGENTUSER_USERNAME" zabbix-stonith -privsep 0
    # トークンのシークレット値が出力されるので、メモしておく
    ┌──────────────┬──────────────────────────────────────┐
    │ key          │ value                                │
    ╞══════════════╪══════════════════════════════════════╡
    │ full-tokenid │ stonith@pve!zabbix-stonith           │
    ├──────────────┼──────────────────────────────────────┤
    │ info         │ {"privsep":"0"}                      │
    ├──────────────┼──────────────────────────────────────┤
    │ value        │ (シークレット値)                      │
    └──────────────┴──────────────────────────────────────┘

    # トークンが存在することを確認する。作成したトークンが出力されば OK
    $ pveum user token list "$STONITHAGENTUSER_USERNAME"
    ┌────────────────┬─────────┬────────┬─────────┐
    │ tokenid        │ comment │ expire │ privsep │
    ╞════════════════╪═════════╪════════╪═════════╡
    │ zabbix-stonith │         │      0 │ 0       │
    └────────────────┴─────────┴────────┴─────────┘    ```

### 4.7. SSHサーバの設定をする

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

### 4.8. cloud-init の準備をする

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

#### 4.8.1. Debian の VM テンプレートを作成する

ここでは、Debian 13 (x86_64) の Generic Cloud イメージ をダウンロードすることします。

1. イメージをダウンロードする

    ダウンロード先URLは、[Debian 公式サイト](https://cloud.debian.org/images/cloud/) を参照してください。

    ```shell
    ssh prd-pve-01
    MAJOR_VER='13'
    MAJOR_VER_CODENAME='trixie'
    QCOW_NAME="debian-$MAJOR_VER-generic-amd64.qcow2"
    curl -o "$QCOW_NAME" "https://cloud.debian.org/images/cloud/$MAJOR_VER_CODENAME/latest/$QCOW_NAME"    # エラーが出力されなければ OK

    # チェックサムを照合
    | DOWNLOADED_CHECKSUM=$(curl -sS "https://cloud.debian.org/images/cloud/$MAJOR_VER_CODENAME/latest/SHA512SUMS" | grep "$QCOW_NAME" | awk '{print $1}') |
    | FILE_CHECKSUM=$(sha512sum "$QCOW_NAME"                                                                       | awk '{print $1}') |                   |
    if [ "$DOWNLOADED_CHECKSUM" = "$FILE_CHECKSUM" ]; then echo 'OK.'; else echo 'CHECKSUM UNMATCHED!!'; fi
    # OK. と出力されればよい
    ```

2. アップロードしたイメージを移動する

    ```shell
    ISO_DIR='/var/lib/vz/template/iso'
    sudo mv "$QCOW_NAME" "$ISO_DIR/"
    # エラーが出力されなければ OK
    ```

3. VM のテンプレートを作成する

    ```shell
    sudo virt-customize -a "$ISO_DIR/$QCOW_NAME" --run-command 'echo -n >/etc/machine-id'

    VM_TMPL_ID=901
    VM_TMPL_NAME="debian-$MAJOR_VER"
    VM_DISK_STORAGE=local-lvm
    sudo qm destroy "$VM_TMPL_ID" --purge || true
    sudo qm create $VM_TMPL_ID \
      --name $VM_TMPL_NAME \
      --ostype l26 \
      --machine q35 \
      --sockets 1 \
      --cores 1 \
      --cpu x86-64-v3 \
      --memory 1024 \
      --scsihw virtio-scsi-single \
      --virtio0 "${VM_DISK_STORAGE}:0,import-from=$ISO_DIR/$QCOW_NAME",discard=on \
      --bootdisk virtio0 \
      --ide2 "${VM_DISK_STORAGE}:cloudinit" \
      --net0 virtio,bridge=vmbr0 \
      --serial0 socket --vga serial0 \
      --onboot 1 \
      --agent enabled=1,fstrim_cloned_disks=1
    sudo qm template $VM_TMPL_ID
    ```

#### 4.8.2. Alma Linux の VM テンプレートを作成する

ここでは、Alma Linux 10.0 (x86_64) の Generic Cloud イメージ をダウンロードすることします。

1. イメージをダウンロードする

    ダウンロード先URLは、[産業サイバーセキュリティセンターの Alma Linux ISO ミラー](https://ftp.udx.icscoe.jp/Linux/almalinux/10.0/cloud/x86_64/images/) を参照してください。

    ```shell
    ssh prd-pve-01
    MAJOR_VER='10'
    VER="${MAJOR_VER}.1"
    QCOW_NAME="Alma-$VER.x86_64.qcow2"
    curl -o "$QCOW_NAME" "https://ftp.udx.icscoe.jp/Linux/almalinux/$VER/cloud/x86_64/images/AlmaLinux-${MAJOR_VER}-GenericCloud-latest.x86_64.qcow2"
    # エラーが出力されなければ OK

    # チェックサムを照合
    | DOWNLOADED_CHECKSUM=$(curl -sS "https://repo.almalinux.org/almalinux/${MAJOR_VER}/cloud/x86_64/images/CHECKSUM" | grep "GenericCloud-$VER" | awk '{print $1}') |
    | FILE_CHECKSUM=$(sha256sum "$QCOW_NAME"                                                                          | awk '{print $1}')        |                   |
    if [ "$DOWNLOADED_CHECKSUM" = "$FILE_CHECKSUM" ]; then echo 'OK.'; else echo 'CHECKSUM UNMATCHED!!'; fi
    # OK. と出力されればよい
    ```

2. アップロードしたイメージを移動する

    ```shell
    ISO_DIR='/var/lib/vz/template/iso'
    sudo mv "$QCOW_NAME" "$ISO_DIR/"
    # エラーが出力されなければ OK
    ```

3. VM のテンプレートを作成する

    ```shell
    sudo virt-customize -a "$ISO_DIR/$QCOW_NAME" --run-command 'echo -n >/etc/machine-id'

    VM_TMPL_ID=902
    VM_TMPL_NAME="alma-$VER"
    VM_DISK_STORAGE=local-lvm
    sudo qm destroy "$VM_TMPL_ID" --purge || true
    sudo qm create $VM_TMPL_ID --name $VM_TMPL_NAME --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
    sudo qm set $VM_TMPL_ID --scsihw virtio-scsi-single
    sudo qm set $VM_TMPL_ID --virtio0 "${VM_DISK_STORAGE}:0,import-from=$ISO_DIR/$QCOW_NAME"
    sudo qm set $VM_TMPL_ID --boot c --bootdisk virtio0
    sudo qm set $VM_TMPL_ID --ide2 "${VM_DISK_STORAGE}:cloudinit"
    sudo qm set $VM_TMPL_ID --serial0 socket --vga serial0
    sudo qm set $VM_TMPL_ID --agent enabled=1,fstrim_cloned_disks=1
    sudo qm template $VM_TMPL_ID
    # WARNING: Combining activation change with other commands is not advised.
    # という警告は無視できる
    ```

### 4.9. ネットワークブリッジを作成する

#### 4.9.1. Linux Bond を追加する

1. Proxmox Web UI にログインする

    ブラウザで `https://192.168.20.2:8006` にアクセスし、ログインする

2. ノードを選択する

    左側のメニューから `prd-pve-01` ノードを選択する

3. ネットワーク設定画面を開く

    `システム` > `ネットワーク` をクリックする

4. ブリッジポートの設定を一旦削除する

    1. `vmbr0`を選択する
    2. `編集`ボタンをクリックする
    3. `ブリッジポート`を空にする
    4. `OK`ボタンをクリックする

5. `Linux Bond` を作成する

    1. `作成` > `Linux Bond` をクリックする
    2. 以下の設定を入力する
        - 名前: `bond0`
        - 自動起動: チェックあり
        - スレーブ: `enp2s0 enxc8a362a24690`
        - モード: `balance-xor`
    3. `作成` ボタンをクリックする

6. ブリッジポートを設定する

    1. `vmbr0`を選択する
    2. `編集`ボタンをクリックする
    3. 以下の設定を入力する
        - 自動起動: チェックあり
        - VLAN aware: チェックあり
        - ブリッジポート: `bond0`
    4. `詳細設定`にチェックを入れる
    5. `VLAN IDs`に`2-4094`を指定する
    6. `OK`ボタンをクリックする

7. 設定を適用する

    1. 画面上部の `設定を適用` ボタンをクリックする
    2. 確認ダイアログで `OK` をクリックする

8. `Linux Bond` が作成されたことを確認する

    以下を確認する

    - `bond0` が表示されていること
    - `vmbr0` のブリッジポートが `bond0` であること

#### 4.9.2. 内部通信に用いる NW を追加する

1. Proxmox Web UI にログインする

    ブラウザで `https://192.168.20.2:8006` にアクセスし、ログインする

2. ノードを選択する

    左側のメニューから `prd-pve-01` ノードを選択する

3. ネットワーク設定画面を開く

    `システム` > `ネットワーク` をクリックする

4. ブリッジを作成する

    1. `作成` > `Linux Bridge` をクリックする
    2. 以下の設定を入力する
        - 名前: `vmbr1`
        - 自動起動: チェックあり
        - コメント: `内部通信NW`
    3. `作成` ボタンをクリックする

5. 設定を適用する

    1. 画面上部の `設定を適用` ボタンをクリックする
    2. 確認ダイアログで `OK` をクリックする

6. ブリッジが作成されたことを確認する

    ネットワーク設定画面で `vmbr1` が表示されていることを確認する

#### 4.9.3. Zabbix Server のハートビートに用いる NW を追加する

1. Proxmox Web UI にログインする

    ブラウザで `https://192.168.20.2:8006` にアクセスし、ログインする

2. ノードを選択する

    左側のメニューから `prd-pve-01` ノードを選択する

3. ネットワーク設定画面を開く

    `システム` > `ネットワーク` をクリックする

4. ブリッジを作成する

    1. `作成` > `Linux Bridge` をクリックする
    2. 以下の設定を入力する
        - 名前: `vmbr2`
        - 自動起動: チェックあり
        - コメント: `Zabbix Server内部用NW`
    3. `作成` ボタンをクリックする

5. 設定を適用する

    1. 画面上部の `設定を適用` ボタンをクリックする
    2. 確認ダイアログで `OK` をクリックする

6. ブリッジが作成されたことを確認する

    ネットワーク設定画面で `vmbr2` が表示されていることを確認する

### 4.10. イーサネットポートを有効にする

1. 現在のイーサネットポートの状態を確認する

    ```shell
    $ ip link
    ...
    # State が DOWN
    3: enxc8a362a24690: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master vmbr1 state DOWN mode DEFAULT group default qlen 1000
        link/ether c8:a3:62:a2:46:90 brd ff:ff:ff:ff:ff:ff
    ...
    $
    ```

2. ポートをリンクアップさせる

    ```shell
    sudo ip link set enxc8a362a24690 up
    ```

3. 現在のイーサネットポートの状態を確認する

    `State`が`UP`であることを確認する

    ```shell
    $ ip link
    ...
    # State が UP
    3: enxc8a362a24690: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master vmbr1 state UP mode DEFAULT group default qlen 1000
        link/ether c8:a3:62:a2:46:90 brd ff:ff:ff:ff:ff:ff
    ...
    $
    ```

## 5. 完了条件

- パッケージの更新が行えること
- `Proxmox`ホストに対するSSH接続において、`root`ユーザとしてログインできないこと
- `Proxmox`ホストに対するSSH接続において、作業用ユーザが作成されていて、そのユーザとしてログインできること
- `Proxmox`ホストに対するSSH接続において、CI/CD用ユーザが作成されていて、そのユーザとしてログインできること
- cloud-init に使用する VM のテンプレートとスニペットの設定がされていること
- `Linux Bond`が作成されていること
- `Linux Bridge`が作成されていること
- パスワードを用いずに`sudo`コマンドを実行できること
