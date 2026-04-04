# VyOS 環境設定手順書

## 1. 目次

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [1. 目次](#1-目次)
- [2. 目的・概要](#2-目的概要)
- [3. 前提条件](#3-前提条件)
- [4. ノード別パラメータ](#4-ノード別パラメータ)
- [5. 作業手順](#5-作業手順)
  - [5.1. ISOイメージを取得する](#51-isoイメージを取得する)
  - [5.2. Proxmox VM を作成する](#52-proxmox-vm-を作成する)
  - [5.3. VyOS をインストールする](#53-vyos-をインストールする)
  - [5.4. 基本設定をする](#54-基本設定をする)
  - [5.5. 設定をする](#55-設定をする)
- [6. 完了条件](#6-完了条件)

<!-- /code_chunk_output -->

## 2. 目的・概要

ゾーンベースファイアウォール兼 HA ルーターとなる `prd-vyo-01` / `prd-vyo-02` の環境設定を行う手順書です。

VyOS rolling イメージを Proxmox 上の VM にインストールし、IPv4 ゾーンベースファイアウォールと VRRP による HA 構成を設定します。

## 3. 前提条件

- `prd-pve-01` に SSH でアクセスできること（`192.168.20.2`）

## 4. ノード別パラメータ

以下の表を参照し、各ノードに応じたパラメータを使用します。

|  パラメータ  |   `prd-vyo-01`    |   `prd-vyo-02`    |
| :----------- | ----------------- | ----------------- |
| Proxmox VMID | `101`             | `102`             |
| ホスト名     | `prd-vyo-01`      | `prd-vyo-02`      |
| eth0         | `192.168.20.4/29` | `192.168.20.5/29` |

## 5. 作業手順

### 5.1. ISOイメージを取得する

1. [VyOS nightly-build の GitHub Releases](https://github.com/vyos/vyos-nightly-build/releases) から最新の rolling イメージをダウンロードする

    - ファイル名の形式: `vyos-2026.03.05-0026-rolling-generic-amd64.iso`

2. ダウンロードした ISO を Proxmox のローカルストレージにアップロードする
: 作業端末から prd-pve-01 の Proxmox Web UI (<https://192.168.20.2:8006>) を開き、 local > ISO Images > Upload からアップロードする

### 5.2. Proxmox VM を作成する

```shell
ssh prd-pve-01
```

```shell
ISO_NAME="vyos-2026.03.05-0026-rolling-generic-amd64.iso"
SERVERS_CSV="$(mktemp)"

cat <<EOF > "$SERVERS_CSV"
# hostname,vmid
prd-vyo-01,101
prd-vyo-02,102
EOF

function create_vyos_vm() {
  local IFS=','
  while read -r LINE; do
    if [[ -z "$LINE" || "$LINE" =~ ^# ]]; then
      continue
    fi
    set -- $LINE
    HOSTNAME=$1
    VM_ID=$2

    echo '----------'
    echo "$VM_ID)"
    sudo qm create "$VM_ID" \
      --name "$HOSTNAME" \
      --memory 2048 \
      --cores 1 \
      --cpu kvm64 \
      --sockets 1 \
      --ostype l26 \
      --numa 0 \
      --scsihw virtio-scsi-single \
      --scsi0 local-lvm:10,iothread=1 \
      --net0 virtio,bridge=vmbr0,firewall=1 \
      --net1 virtio,bridge=vmbr1,firewall=1 \
      --net2 virtio,bridge=vmbr2,firewall=1 \
      --net3 virtio,bridge=vmbr3,firewall=1 \
      --serial0 socket \
      --onboot 1 \
      --ide2 "local:iso/$ISO_NAME,media=cdrom" \
      --boot "order=scsi0;ide2;net0"
    sudo qm start "$VM_ID"
    sudo qm status "$VM_ID"
    echo '----------'
  done <"$SERVERS_CSV"
}

create_vyos_vm
# status: running とそれぞれのVMで表示されればOK

rm "$SERVERS_CSV"
```

### 5.3. VyOS をインストールする

1. `prd-pve-01` からシリアルコンソールで接続する（推奨）、または Proxmox Web UI の `prd-vyo-0X` > `Console` を開く

    ```bash
    # prd-pve-01 上で実行（Ctrl+O で切断）
    sudo qm terminal 101  # または 102
    ```

2. VyOS が起動したら、デフォルト認証情報でログインする

    ```shell
    login: vyos
    password: vyos
    ```

3. ディスクにインストールする

    ```shell
    install image
    ```

    対話的なプロンプトにはすべてデフォルト（Enter）で応答する。管理者パスワードのみ任意の値を設定する。
    以下は出力例。

    ```shell
    vyos@vyos:~$ install image
    Welcome to VyOS installation!
    This command will install VyOS to your permanent storage.
    Would you like to continue? [y/N] y
    What would you like to name this image? (Default: 2026.03.05-0026-rolling)
    Please enter a password for the "vyos" user:
    Please confirm password for the "vyos" user:
    What console should be used by default? (K: KVM, S: Serial)? (Default: S) K
    Probing disks
    1 disk(s) found
    The following disks were found:
    Drive: /dev/sda (10.0 GB)
    Which one should be used for installation? (Default: /dev/sda)
    Installation will delete all data on the drive. Continue? [y/N] y
    Searching for data from previous installations
    No previous installation found
    Would you like to use all the free space on the drive? [Y/n]
    Creating partition table...
    The following config files are available for boot:
            1: /opt/vyatta/etc/config/config.boot
            2: /opt/vyatta/etc/config.boot.default
    Which file would you like as boot config? (Default: 1)
    Creating temporary directories
    Mounting new partitions
    Creating a configuration file
    Copying system image files
    Installing GRUB configuration files
    Installing GRUB to the drive
    Cleaning up
    Unmounting target filesystems
    Removing temporary files
    The image installed successfully; please reboot now.
    vyos@vyos:~$
    ```

4. インストール完了後、シャットダウンする

    ```shell
    poweroff
    ```

5. `prd-pve-01` から ISO を取り外し、起動する

    ```bash
    for VMID in 101 102; do
      sudo qm set $VMID --delete ide2
      sudo qm start $VMID
    done
    ```

6. 起動後にログインし、インストールされたイメージで起動していることを確認する

    ```shell
    show version
    ```

### 5.4. 基本設定をする

1. 設定モードに入り、インターフェース・ホスト名・SSH・公開鍵認証を設定します。
以下の `<...>` はノード別パラメータに従って置き換えてください。

    ```shell
    configure

    # インターフェース
    set interfaces ethernet eth0 address <eth0アドレス>

    # 公開鍵認証に使う公開鍵
    set system login user vyos authentication public-keys work type 'ssh-ed25519'
    set system login user vyos authentication public-keys work key 'AAAAC3NzaC1lZDI1NTE5AAAAIN1qNyXKdZGZQO3ulp99hfGyUniFVdQIpmoCQveLh9WZ'

    # デフォルトルート
    set protocols static route 0.0.0.0/0 next-hop 192.168.20.1

    # SSH を有効化
    set service ssh

    # ルータに MAC アドレスと IP アドレスに対応を学習させるため、ping 実行
    # これをしないと　SSH が届かない
    ping 192.168.20.1

    commit
    ```

### 5.5. 設定をする

1. ローカルの端末から以下 Playbook を実行する

    ```shell
    uv run ansible-playbook -i ansible/inventory_vyos.yaml ansible/vyos.yaml
    ```

2. 設定後、VRRP の状態を確認する（Playbook 内で自動検証される）:

    - `prd-vyo-01`: `MASTER`
    - `prd-vyo-02`: `BACKUP`

3. 意図しない通信遮断が起きていないことを確認する:

    ```shell
    show log firewall
    ```

## 6. 完了条件

- 両ノードに SSH でアクセスできること（WAN アドレス経由）
- 両ノードから `192.168.20.1`（WAN-GATEWAY）に ping が通ること
- VRRP の状態について、 `prd-vyo-01` が `MASTER`、`prd-vyo-02` が `BACKUP` と表示されること
- `show log firewall` で意図しない DROP が発生していないこと
