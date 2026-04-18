# FW の通信要件ドキュメントと実際の実装が一致しているか確認する

## 目標

通信要件ドキュメントと実際の FW 実装が一致しているか確認する。

## 前提条件

### 使用するファイル・ドキュメント

- 通信要件一覧: docs/design/FW通信要件.md
- ホスト名と IP アドレスの対照表: docs/design/IPアドレス管理.md
- ホスト名の定義と意味: docs/design/機器管理.md
- 通信要件一覧を VyOS の設定に反映するための Ansible の group_vars を定義しているファイル群
  - ansible/prd/group_vars/vyos_router/fw_groups.yaml
  - ansible/prd/group_vars/vyos_router/fw_rulesets.yaml
  - ansible/prd/group_vars/vyos_router/fw_zone_policies.yaml
  - ansible/prd/group_vars/vyos_router/fw_zones.yaml
- 通信要件一覧を VyOS の設定に反映するための Ansible の Playbook: ansible/prd/roles/vyos/tasks/firewall.yaml

### FW のホスト

VyOS ルータを実行している Proxmox 上の仮想マシンに適用する。
SSH接続するときは、ホスト名の前に「`__`」をつけて、「`ssh __prd-vyo-01`」のようなコマンドで実施する。
（`$HOME/.ssh/config` によって設定は補完されるので、ホスト名以外の指定は不要）

## 手順（順番通り、記載された手順に厳密に従ってください）

1. 通信要件一覧のドキュメントを読み取り、どのゾーンにどのようなルールが存在するのか理解してください。
2. Ansible のファイル群を読み取り、どのゾーンにどのようなルールが存在するのか理解してください。
3. 1で読み取った内容と2で読み取った内容に差異がないかどうか見比べてください。
4. 差異があればその内容をユーザに説明し、修正するかどうかユーザに確認してください。ユーザからの同意があった場合は、ドキュメントないしファイルを修正してください。
   差異がなければ、その旨をユーザに説明してください。
