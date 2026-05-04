# FW の通信要件ドキュメントと実際の実装が一致しているか確認する

## 目標

通信要件ドキュメントと実際の FW 実装が一致しているか確認する。

## 前提条件

### 使用するファイル・ドキュメント

- 通信要件一覧: docs/design/FW通信要件.md
- ホスト名と IP アドレスの対照表: docs/design/IPアドレス管理.md
- ホスト名の定義と意味: docs/design/機器管理.md
- 通信要件一覧を ルータの設定に反映するための Ansible の group_vars を定義しているファイル群
  - ansible/prd/group_vars/router/fw_groups.yaml
  - ansible/prd/group_vars/router/fw_rulesets.yaml
  - ansible/prd/group_vars/router/fw_zone_policies.yaml
  - ansible/prd/group_vars/router/fw_zones.yaml
- 通信要件一覧をルータの設定に反映するための Ansible の Playbook: ansible/prd/roles/router/tasks/nftables.yaml
- 通信要件一覧をルータの設定に反映するための nftables の設定ファイルテンプレート: ansible/prd/roles/router/templates/nftables.conf.j2

### dnsmasq、keepalived との連携

特定のドメインへのアクセスのみ許可するため、dnsmasq で名前解決を実行した結果得られた IP アドレスを nftables に反映する仕組みを運用している。
また、名前解決の結果は稼働系と待機系で共有されないので、keepalived の稼働系切り替わり時に、自身が稼働系である場合に名前解決をあらかじめ実行し、nftables に連携するスクリプトを実行する。

- dnsmasq を構成するための Ansible の Playbook: ansible/prd/roles/router/tasks/dnsmasq.yaml
- dnsmasq の設定ファイルに用いるテンプレート: ansible/prd/roles/router/templates/dnsmasq-router.conf.j2
- dnsmasq によって名前解決された結果を nftables に反映するためのシェルスクリプトや nftables、keepalived の設定
  - ansible/prd/roles/router/templates/nftset-warmup.sh.j2
  - ansible/prd/roles/router/templates/dnsmasq-nftset.conf.j2
  - ansible/prd/roles/router/templates/keepalived.conf.j2

### FW のホスト

nftables を実行している Proxmox 上の専用仮想マシン（Debian）に適用する。
SSH接続するときは、以下のうち、いずれかのコマンドを使用する。

- ホスト名の前に「`__`」をつけて、「`ssh __prd-nft-01`」
（`$HOME/.ssh/config` によって設定は補完されるので、ホスト名以外の指定は不要）
- `ssh machine-user@（IPアドレス）`

## 手順（順番通り、記載された手順に厳密に従ってください）

1. 通信要件一覧のドキュメントを読み取り、どのゾーンにどのようなルールが存在するのか理解してください。
2. Ansible のファイル群を読み取り、どのゾーンにどのようなルールが存在するのか理解してください。
3. 1で読み取った内容と2で読み取った内容に差異がないかどうか見比べてください。
4. 差異があればその内容をユーザに説明し、修正するかどうかユーザに確認してください。ユーザからの同意があった場合は、ドキュメントないしファイルを修正してください。
   差異がなければ、その旨をユーザに説明してください。
