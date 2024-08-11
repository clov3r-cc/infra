# `infra`/`terraform`

Terraform で管理しているインフラの設定をまとめているディレクトリです。

## 管理リソース

- Cloudflare [^1]
  - DNS レコード
  - Cloudflare Pages のプロジェクト
  - Cloudflare Pages のプロジェクトに割り当てるカスタムドメイン

## リリース方法

Terraform CLI を用いて行います。
`.tfstate` ファイルの保存・同期は Terraform Cloud で行っています。

[^1]: Cloudflare Workers は、Worker のスクリプトの内容を直書きしなければいけないこと、個別のプロジェクトで設定等を管理したほうが都合がつきやすいことを理由に、管理の対象外としています。
