# `infra`/`terraform`

Terraform で管理しているインフラの設定をまとめているディレクトリです。

## 管理リソース

### Cloudflare[^1]

- DNS レコード
- Cloudflare Pages
  - プロジェクト
  - プロジェクトに割り当てるカスタムドメイン
- Cloudflare Zero Trust
  - Cloudflare Tunnel
  - Cloudflare Access
    - Application
    - Access Group
    - Access Policy

## リリース方法

Terraform CLI を用いて行います。
`.tfstate` ファイルの保存・同期は Terraform Cloud で行っています。

### リリースに必要な事前設定

各サービスのアカウント作成や Terraform Cloud の Project、Workspace の設定はここでは扱いません。

#### Terraform Cloud

1. [Account Settings > Tokens](https://app.terraform.io/app/settings/tokens) で、API トークンを発行してください。
2. [GitHub Actions > Repository Secrets](https://github.com/clov3r-cc/infra/settings/secrets/actions) で、`TERRAFORM_CLOUD_API_TOKEN`として設定してください。

#### Cloudflare

1. [マイ プロフィール > API トークン](https://dash.cloudflare.com/profile/api-tokens)で、以下のリソースに対するアクセス許可を持つ API トークンを発行してください。

    |  影響範囲  |                    リソース                     | 権限 |
    | ---------- | ----------------------------------------------- | ---- |
    | アカウント | Cloudflare Pages                                | 編集 |
    | アカウント | Cloudflare Tunnel                               | 編集 |
    | アカウント | Zero Trust                                      | 編集 |
    | アカウント | アクセス: 組織、ID プロバイダー、およびグループ | 編集 |
    | アカウント | アクセス: アプリおよびポリシー                  | 編集 |
    | ゾーン     | DNS                                             | 編集 |

2. [GitHub Actions > Repository Secrets](https://github.com/clov3r-cc/infra/settings/secrets/actions) で、`TF_VAR_CLOUDFLARE_API_TOKEN`として設定してください。

[^1]: Cloudflare Workers は、Worker のスクリプトの内容を直書きしなければいけないこと、個別のプロジェクトで設定等を管理したほうが都合がつきやすいことを理由に、管理の対象外としています。
