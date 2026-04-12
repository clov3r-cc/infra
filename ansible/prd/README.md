# `infra`/`ansible`/`prd`

本番環境のサーバー設定管理を行う Ansible プロジェクトです。

## 構成

### インベントリ

|       ファイル        |                                                                    説明                                                                    |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `inventory_src.yaml`  | `cloud.terraform.terraform_provider` プラグインを使い、[`terraform/prd`](../../terraform/prd/) の State からホスト情報を動的に取得します。 |
| `inventory_vyos.yaml` | VyOS ルーターのインベントリです。                                                                                                          |

### プレイブック

|        ファイル         | 対象ホストグループ |
| ----------------------- | ------------------ |
| `cloud-server.yaml`     | `cloud_server`     |
| `dns-server.yaml`       | `dns_server`       |
| `pve-server.yaml`       | `pve_server`       |
| `tailscale-server.yaml` | `tailscale_server` |
| `vyos.yaml`             | `vyos_router`      |
| `zabbix-server.yaml`    | `zabbix_server`    |

## 実行方法

`ansible/prd/` ディレクトリ上で実行します。

```bash
cd ansible/prd

# 依存コレクションのインストール
uv run ansible-galaxy collection install -r requirements.yml

# インベントリの確認
uv run ansible-inventory -i inventory_src.yaml --list

# プレイブックの実行
uv run ansible-playbook -i inventory_src.yaml <playbook>.yaml
```

または `mise` タスクを利用できます。

```bash
# インベントリ一覧の表示
mise run show-inventory

# プレイブックの実行
mise run play-ansible <playbook>.yaml

# 全ホストへの疎通確認
mise run ping
```

## Vault

機密情報は [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) で暗号化しています。
パスワードは `files/get_vault_password.sh` から取得します（`ansible.cfg` に設定済み）。
