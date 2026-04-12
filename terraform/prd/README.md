# `infra`/`terraform`/`prd`

本番環境のリソースを管理する Terraform プロジェクトです。

## 管理リソース

### Cloudflare[^1]

- DNS レコード
- Cloudflare Pages
  - プロジェクト
  - プロジェクトに割り当てるカスタムドメイン
- Cloudflare Zero Trust
  - Access Group

### Oracle Cloud

- VCN（仮想クラウドネットワーク）・サブネット・ルートテーブル・ネットワークセキュリティグループ
- インスタンス（クラウドサーバー）

### Proxmox VE

- VM（DNS サーバー、Zabbix サーバー）

### Ansible インベントリ

Ansible プロバイダーを用いて、Terraform で作成した VM のインベントリ（グループ・ホスト）を管理しています。
[`ansible/prd`](../../ansible/prd/) の動的インベントリとして参照されます。

## リリース方法

Terraform CLI を用いて行います。
`.tfstate` ファイルの保存・同期は Terraform Cloud で行っています。

### リリースに必要な事前設定

各サービスのアカウント作成や Terraform Cloud の Project、Workspace の設定はここでは扱いません。

#### Terraform Cloud

1. [Account Settings > Tokens](https://app.terraform.io/app/settings/tokens) で、API トークンを発行してください。
2. [GitHub Actions > Repository Secrets](https://github.com/clov3r-cc/infra/settings/secrets/actions) で、`TERRAFORM_CLOUD_API_TOKEN` として設定してください。

#### Cloudflare

1. [マイ プロフィール > API トークン](https://dash.cloudflare.com/profile/api-tokens) で、以下のリソースに対するアクセス許可を持つ API トークンを発行してください。

    |  影響範囲  |                    リソース                     | 権限 |
    | ---------- | ----------------------------------------------- | ---- |
    | アカウント | Cloudflare Pages                                | 編集 |
    | アカウント | Zero Trust                                      | 編集 |
    | アカウント | アクセス: 組織、ID プロバイダー、およびグループ | 編集 |
    | アカウント | アクセス: アプリおよびポリシー                  | 編集 |
    | アカウント | アクセス: サービストークン                      | 編集 |
    | ゾーン     | DNS                                             | 編集 |

2. [GitHub Actions > Repository Secrets](https://github.com/clov3r-cc/infra/settings/secrets/actions) で、`TF_VAR_CLOUDFLARE_API_TOKEN` として設定してください。

#### Proxmox VE

以下の変数を Terraform Cloud の Variables として設定してください。

|         変数名         |                          説明                           |
| ---------------------- | ------------------------------------------------------- |
| `pve_api_token_id`     | Proxmox VE API トークン ID                              |
| `pve_api_token_secret` | Proxmox VE API トークンシークレット                     |
| `pve_tls_insecure`     | TLS 検証を無効にするか（自己署名証明書の場合は `true`） |
| `pve_user_password`    | Proxmox VE ユーザーのパスワード                         |
| `vm_ssh_private_key`   | VM 接続用 SSH 秘密鍵（base64 エンコード済み）           |

#### Oracle Cloud

以下の変数を Terraform Cloud の Variables として設定してください。

|             変数名             |                  説明                   |
| ------------------------------ | --------------------------------------- |
| `oracle_cloud_api_fingerprint` | OCI API 秘密鍵のフィンガープリント      |
| `oracle_cloud_api_private_key` | OCI API 秘密鍵（base64 エンコード済み） |
| `oracle_cloud_user_id`         | Terraform が使用する OCI ユーザー ID    |

[^1]: Cloudflare Workers は、Worker のスクリプトの内容を直書きしなければいけないこと、個別のプロジェクトで設定等を管理したほうが都合がつきやすいことを理由に、管理の対象外としています。
