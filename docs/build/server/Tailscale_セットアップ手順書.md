# Tailscale セットアップ手順書

## 1. 目次

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [1. 目次](#1-目次)
- [2. 目的・概要](#2-目的概要)
- [3. 前提条件](#3-前提条件)
- [4. 作業手順](#4-作業手順)
  - [4.1. ホスト）VMを作成する](#41-ホストvmを作成する)
  - [4.2. VM）初期設定をする](#42-vm初期設定をする)
  - [4.3. VM）`Tailscale`を起動する](#43-vmtailscaleを起動する)
  - [4.4. `Tailscale`で経路の広告（アドバタイズ）を設定する](#44-tailscaleで経路の広告アドバタイズを設定する)
  - [4.5. `Tailscale`の鍵の有効期限を無効化をする](#45-tailscaleの鍵の有効期限を無効化をする)
  - [4.6. `Tailscale`クライアントとしてタグをつける](#46-tailscaleクライアントとしてタグをつける)
- [5. 完了条件](#5-完了条件)

<!-- /code_chunk_output -->

## 2. 目的・概要

`Tailscale`を稼働させるVMを作成する手順書です。（LXCコンテナだと動作が不安定になるので、VMを使用します。）

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
    DEFAULT_GW=192.168.20.17
    SERVERS_CSV="$WORK_DIR/servers.csv"

    cat <<EOF > "$SERVERS_CSV"
    # hostname, vmid, ipaddr/subnetmask
    # vmhost1, 8999, 192.0.1.30/24
    prd-tal-01,201,192.168.20.20/28
    prd-tal-02,202,192.168.20.21/28
    EOF

    function create_tailscale_vm() {
      local IFS=','
      while read -r LINE; do
        if [[ -z "$LINE" || "$LINE" =~ ^# ]]; then
            continue
        fi
        set -- $LINE
        HOSTNAME=$1
        VM_ID=$2
        NIC=$3

        echo '----------'
        echo "$VM_ID)"
        sudo qm stop $VM_ID || true
        sudo qm destroy $VM_ID --purge || true
        sudo qm clone "$VM_TMPL_ID" "$VM_ID" --name "$HOSTNAME"
        sudo qm set $VM_ID --sshkeys "$CI_USER_SSH_PUBKEY_PATH" \
          --ciuser "$CI_USERNAME" \
          --net0 virtio,bridge=vmbr1,firewall=1 \
          --ipconfig0 "ip=$NIC,gw=$DEFAULT_GW" \
          --nameserver "$DEFAULT_GW"
        sudo qm disk resize $VM_ID virtio0 10G

        sudo qm start "$VM_ID"
        sudo qm status "$VM_ID"
        echo '----------'
      done <"$SERVERS_CSV"
    }

    create_tailscale_vm
    # status: running とそれぞれのVMで表示されればOK

    cd
    rm -r "$WORK_DIR"

    exit
    ```

### 4.2. VM）初期設定をする

以下の設定が自動で適用される。

- IPフォワーディングの設定
- `Tailscale`のインストール
- `nftables`のファイアウォール設定

```shell
uv run ansible-playbook -i ansible/inventory_tailscale.yaml ansible/tailscale-server.yaml
```

### 4.3. VM）`Tailscale`を起動する

1. `Tailscale`を起動する

    ```shell
    ssh prd-tal-**
    sudo tailscale up --advertise-routes=192.168.20.0/29,192.168.20.16/28,192.168.21.0/24,192.168.22.0/24
    ```

### 4.4. `Tailscale`で経路の広告（アドバタイズ）を設定する

1. [Tailscale](https://login.tailscale.com/admin/machines)を開く。
2. `prd-tal-**` > `Edit route settings...`を押下する
3. `Subnet routes` で、以下にチェックを入れる
     - `192.168.20.0/29`
     - `192.168.20.16/28`
     - `192.168.21.0/24`
     - `192.168.22.0/24`
4. `Save`を押下する

### 4.5. `Tailscale`の鍵の有効期限を無効化をする

ref. <https://tailscale.com/kb/1028/key-expiry>

1. `prd-tal-**` > `Disable key expiry`を押下する

### 4.6. `Tailscale`クライアントとしてタグをつける

1. `prd-tal-**` > `Edit ACL tags...`を押下する
2. `Add tags` > `tag:pve`を選択する
3. `Save`を押下する

## 5. 完了条件

- VMに対するSSH接続において、`root`ユーザとしてログインできないこと
- VMに対するSSH接続において、作業用ユーザが作成されていて、そのユーザとしてログインできること
- パスワードを用いずに`sudo`コマンドを実行できること
- `Tailscale`により、インターネットからセキュアにネットワーク内にアクセスできること
- `Tailscale`において、`prd-tal-**`に以下の設定をしていること
  - 鍵の有効期限なし
  - サブネット広告あり
  - `tag:pve`付き
