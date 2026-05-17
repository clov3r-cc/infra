# ルータ VM セットアップ手順書

## 1. 目次

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [1. 目次](#1-目次)
- [2. 目的・概要](#2-目的概要)
- [3. 前提条件](#3-前提条件)
- [4. 作業手順](#4-作業手順)
  - [4.1. ホスト）VMを作成する](#41-ホストvmを作成する)
  - [4.2. VM）初期設定をする](#42-vm初期設定をする)
- [5. 完了条件](#5-完了条件)

<!-- /code_chunk_output -->

## 2. 目的・概要

`nftables`を稼働させるVMを作成する手順書です。

## 3. 前提条件

- `Proxmox`のセットアップまで完了していること

## 4. 作業手順

### 4.1. ホスト）VMを作成する

1. ワークディレクトリを作成する

    ```shell
    ssh prd-pve-01
    WORK_DIR="$(mktemp -d)"
    cd "$WORK_DIR"
    ```

2. SSH 公開鍵を取得する

    ```shell
    CI_USER_SSH_PUBKEY_PATH="$WORK_DIR/ssh-keys"
    echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMHZ+snXDFNVK89sfKAq1ULEI5yRLxqWQHYiVTGUVlb8' > "$CI_USER_SSH_PUBKEY_PATH"
    ```

3. VMを作成する

    ```shell
    VM_TMPL_ID=901
    CI_USERNAME=machine-user
    DEFAULT_GW=192.168.20.1
    SERVERS_CSV="$WORK_DIR/servers.csv"

    cat <<EOF > "$SERVERS_CSV"
    # hostname, vmid, vmbr0 ip/subnet, vmbr1, vmbr2, vmbr3
    prd-nft-01,101,192.168.20.4/29,192.168.20.18/28,192.168.21.4/24,192.168.22.4/24
    prd-nft-02,102,192.168.20.5/29,192.168.20.19/28,192.168.21.5/24,192.168.22.5/24
    EOF

    function create_nftables_vm() {
      local IFS=','

      while read -r LINE; do
        if [[ -z "$LINE" || "$LINE" =~ ^# ]]; then
          continue
        fi

        set -- $LINE
        HOSTNAME=$1
        VM_ID=$2
        IP_ADDR__0=$3
        IP_ADDR__1=$4
        IP_ADDR__2=$5
        IP_ADDR__3=$6

        echo "$HOSTNAME"
        echo "$VM_ID"
        echo "$IP_ADDR__0"
        echo '----------'
        echo "$VM_ID)"

        sudo qm stop "$VM_ID" || true
        sudo qm destroy "$VM_ID" --purge || true
        sudo qm clone "$VM_TMPL_ID" "$VM_ID" --name "$HOSTNAME"
        sudo qm set "$VM_ID" \
          --sshkeys "$CI_USER_SSH_PUBKEY_PATH" \
          --ciuser "$CI_USERNAME" \
          --net0 virtio,bridge=vmbr0,firewall=1 \
          --ipconfig0 "ip=$IP_ADDR__0,gw=$DEFAULT_GW" \
          --net1 virtio,bridge=vmbr1,firewall=1 \
          --ipconfig1 "ip=$IP_ADDR__1" \
          --net2 virtio,bridge=vmbr2,firewall=1 \
          --ipconfig2 "ip=$IP_ADDR__2" \
          --net3 virtio,bridge=vmbr3,firewall=1 \
          --ipconfig3 "ip=$IP_ADDR__3" \
          --nameserver "$DEFAULT_GW"
        sudo qm disk resize "$VM_ID" virtio0 10G
        sudo qm start "$VM_ID"
        sudo qm status "$VM_ID"
        echo '----------'
      done < "$SERVERS_CSV"
    }

    create_nftables_vm
    # status: running とそれぞれのVMで表示されればOK

    cd
    rm -r "$WORK_DIR"

    exit
    ```

### 4.2. VM）初期設定をする

```shell
uv run ansible-playbook -i ansible/inventory_router.yaml ansible/router.yaml
```

## 5. 完了条件

- VMに対するSSH接続において、`root`ユーザとしてログインできないこと
- VMに対するSSH接続において、作業用ユーザが作成されていて、そのユーザとしてログインできること
- パスワードを用いずに`sudo`コマンドを実行できること
