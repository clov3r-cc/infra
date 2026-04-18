# FW への要件を追加: $ARGUMENTS

## 目標

FW に通信要件を追加する。

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

ユーザからは次の要件が提示されています。: $ARGUMENTS
※要件が提示されていない場合はその旨をユーザに説明して、処理をそこで終了してください。

1. ユーザが希望している要件を理解して、要件を達成するのに必要な要素を考えてください。
2. 通信要件一覧のドキュメントを読み取り、どのゾーンにどのようなルールを追加すればいいのか考えてください。
3. 通信要件一覧のドキュメントと Ansible のファイル群に必要なルール等の定義を追加してください。
4. 追加した要件について、ユーザに説明してください。
