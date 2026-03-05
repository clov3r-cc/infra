# VyOS ファイアウォール通信要件

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [1. 概要](#1-概要)
- [2. ゾーン定義](#2-ゾーン定義)
- [3. 共通ポリシー](#3-共通ポリシー)
- [4. グループ定義](#4-グループ定義)
  - [4.1. network-group](#41-network-group)
  - [4.2. address-group](#42-address-group)
- [5. ゾーン間通信要件](#5-ゾーン間通信要件)
  - [5.1. WAN → LOCAL](#51-wan--local)
  - [5.2. WAN → DMZ](#52-wan--dmz)
  - [5.3. DMZ → WAN](#53-dmz--wan)
  - [5.4. DMZ → LOCAL](#54-dmz--local)
  - [5.5. INTERNAL → DMZ](#55-internal--dmz)
  - [5.6. INTERNAL → LOCAL](#56-internal--local)
  - [5.7. LOCAL → WAN](#57-local--wan)
  - [5.8. LOCAL → DMZ](#58-local--dmz)
  - [5.9. LOCAL → SERVICE](#59-local--service)
  - [5.10. LOCAL → INTERNAL](#510-local--internal)

<!-- /code_chunk_output -->

## 1. 概要

`prd-vyo` に設定するゾーンベースファイアウォールの通信要件を定義します。

VyOS を使用し、IPv4 ゾーンベースファイアウォールで実装します。

## 2. ゾーン定義

| ゾーン名 | インターフェース |      CIDR       |      用途       |
| :------: | :--------------: | :-------------: | --------------- |
|   WAN    |       eth0       | 192.168.20.0/29 | 上流 NW         |
|   DMZ    |       eth1       | 192.168.20.8/29 | DMZ (Tailscale) |
| SERVICE  |       eth2       | 192.168.21.0/24 | サービス NW     |
| INTERNAL |       eth3       | 192.168.22.0/24 | 内部 NW         |
|  LOCAL   |        -         |        -        | ルーター自身    |

## 3. 共通ポリシー

全ゾーンに共通で適用されます。

|    状態     | アクション |
| :---------: | :--------: |
| established |   accept   |
|   related   |   accept   |
|   invalid   |    drop    |

## 4. グループ定義

### 4.1. network-group

|   グループ名   |    メンバー     |    説明    |
| -------------- | --------------- | ---------- |
| `HOME-CLIENTS` | 192.168.10.0/24 | 管理者端末 |

### 4.2. address-group

|    グループ名     |           メンバー           |        説明         |
| ----------------- | ---------------------------- | ------------------- |
| `WAN-GATEWAY`     | 192.168.20.1                 | 上流ルーター        |
| `FW-WAN-VIP`      | 192.168.20.3                 | FW (WAN VIP)        |
| `FW-WAN-NODES`    | 192.168.20.4, 192.168.20.5   | FW 01/02 (WAN)      |
| `TAILSCALE-NODES` | 192.168.20.20, 192.168.20.21 | Tailscale ノード    |
| `FW-DMZ-VIP`      | 192.168.20.17                | FW (DMZ VIP)        |
| `FW-DMZ-NODES`    | 192.168.20.18, 192.168.20.19 | FW 01/02 (DMZ)      |
| `DNS-SERVERS`     | 192.168.20.22, 192.168.20.23 | DNS/Proxy サーバ    |
| `FW-INTERNAL-VIP` | 192.168.22.3                 | FW (INTERNAL VIP)   |
| `ZABBIX-SERVERS`  | 192.168.22.8, 192.168.22.9   | Zabbix サーバ       |
| `VRRP-MULTICAST`  | 224.0.0.18                   | VRRP マルチキャスト |

## 5. ゾーン間通信要件

未定義の通信はすべて **default-action: drop** で遮断されます。

以下の通信方向は意図的にルールがありません（直接アクセス不可）：

- WAN → SERVICE
- WAN → INTERNAL
- DMZ → SERVICE
- DMZ → INTERNAL
- SERVICE → WAN
- SERVICE → DMZ
- SERVICE → INTERNAL
- SERVICE → LOCAL
- INTERNAL → WAN
- INTERNAL → SERVICE

### 5.1. WAN → LOCAL

| Rule  |     送信元     | プロトコル | 送信先ポート | 送信先アドレス | 目的 |
| :---: | :------------: | :--------: | :----------: | :------------: | ---- |
|  10   | `HOME-CLIENTS` |    TCP     |      22      | `FW-WAN-NODES` | SSH  |
|  20   | `HOME-CLIENTS` |    ICMP    |      -       | `FW-WAN-NODES` | ICMP |
|  30   | `HOME-CLIENTS` |    ICMP    |      -       |  `FW-WAN-VIP`  | ICMP |
|  40   | `FW-WAN-NODES` | Proto 112  |      -       |       -        | VRRP |

### 5.2. WAN → DMZ

| Rule  |     送信元     | プロトコル | 送信先ポート |  送信先アドレス   | 目的 |
| :---: | :------------: | :--------: | :----------: | :---------------: | ---- |
|  10   | `HOME-CLIENTS` |    TCP     |      22      | `TAILSCALE-NODES` | SSH  |
|  20   | `HOME-CLIENTS` |    ICMP    |      -       | `TAILSCALE-NODES` | ICMP |

### 5.3. DMZ → WAN

[What firewall ports should I open to use Tailscale?](https://tailscale.com/docs/reference/faq/firewall-ports)

| Rule  |      送信元       | プロトコル | 送信元ポート | 送信先ポート | 送信先アドレス |                      目的                       |
| :---: | :---------------: | :--------: | :----------: | :----------: | :------------: | ----------------------------------------------- |
|  10   | `TAILSCALE-NODES` |    TCP     |     any      |     443      |      any       | Tailscale コントロールサーバー・DERP リレー接続 |
|  20   | `TAILSCALE-NODES` |    UDP     |    41641     |     any      |      any       | Tailscale WireGuard 直接トンネル                |
|  30   | `TAILSCALE-NODES` |    UDP     |     any      |     3478     |      any       | Tailscale STUN                                  |

### 5.4. DMZ → LOCAL

| Rule  |      送信元       | プロトコル | 送信先ポート | 送信先アドレス | 目的 |
| :---: | :---------------: | :--------: | :----------: | :------------: | ---- |
|  10   | `TAILSCALE-NODES` |    TCP     |      22      | `FW-DMZ-NODES` | SSH  |
|  20   | `TAILSCALE-NODES` |    UDP     |     123      |  `FW-DMZ-VIP`  | NTP  |
|  25   | `TAILSCALE-NODES` |  UDP/TCP   |      53      |  `FW-DMZ-VIP`  | DNS  |
|  30   |   `DNS-SERVERS`   |  UDP/TCP   |      53      |  `FW-DMZ-VIP`  | DNS  |
|  40   |   `DNS-SERVERS`   |    UDP     |     123      |  `FW-DMZ-VIP`  | NTP  |
|  50   | `TAILSCALE-NODES` |    ICMP    |      -       | `FW-DMZ-NODES` | ICMP |
|  60   |  `FW-DMZ-NODES`   | Proto 112  |      -       |       -        | VRRP |

### 5.5. INTERNAL → DMZ

| Rule  |      送信元      | プロトコル | 送信先ポート | 送信先アドレス | 目的 |
| :---: | :--------------: | :--------: | :----------: | :------------: | ---- |
|  10   | `ZABBIX-SERVERS` |  UDP/TCP   |      53      | `DNS-SERVERS`  | DNS  |

### 5.6. INTERNAL → LOCAL

| Rule  |      送信元      | プロトコル | 送信先ポート |  送信先アドレス   | 目的 |
| :---: | :--------------: | :--------: | :----------: | :---------------: | ---- |
|  10   | `ZABBIX-SERVERS` |    UDP     |     123      | `FW-INTERNAL-VIP` | NTP  |

### 5.7. LOCAL → WAN

| Rule  | 送信元 | プロトコル | 送信先ポート |         送信先アドレス          |               目的               |
| :---: | :----: | :--------: | :----------: | :-----------------------------: | -------------------------------- |
|  10   |   -    |    UDP     |     123      |          `WAN-GATEWAY`          | NTP                              |
|  20   |   -    |  UDP/TCP   |      53      |          `WAN-GATEWAY`          | DNS                              |
|  30   |   -    |    TCP     |     443      |          `github.com`           | VyOS イメージダウンロード        |
|  31   |   -    |    TCP     |     443      | `objects.githubusercontent.com` | VyOS イメージダウンロード（CDN） |
|  40   |   -    |    ICMP    |      -       |               any               | ICMP                             |
|  50   |   -    | Proto 112  |      -       |        `VRRP-MULTICAST`         | VRRP                             |

### 5.8. LOCAL → DMZ

| Rule  | 送信元 | プロトコル | 送信先ポート |  送信先アドレス  | 目的 |
| :---: | :----: | :--------: | :----------: | :--------------: | ---- |
|  10   |   -    | Proto 112  |      -       | `VRRP-MULTICAST` | VRRP |
|  20   |   -    |    ICMP    |      -       |       any        | ICMP |

> **Note**: VRRP（Proto 112）はマルチキャスト（224.0.0.18）を使った双方向独立送信のため、セッション追跡ができません。そのため DMZ-TO-LOCAL（受信側）と LOCAL-TO-DMZ（送信側）の両方向に明示的なルールが必要です。

### 5.9. LOCAL → SERVICE

| Rule  | 送信元 | プロトコル | 送信先ポート |  送信先アドレス  | 目的 |
| :---: | :----: | :--------: | :----------: | :--------------: | ---- |
|  10   |   -    | Proto 112  |      -       | `VRRP-MULTICAST` | VRRP |
|  20   |   -    |    ICMP    |      -       |       any        | ICMP |

### 5.10. LOCAL → INTERNAL

| Rule  | 送信元 | プロトコル | 送信先ポート |  送信先アドレス  | 目的 |
| :---: | :----: | :--------: | :----------: | :--------------: | ---- |
|  10   |   -    | Proto 112  |      -       | `VRRP-MULTICAST` | VRRP |
|  20   |   -    |    ICMP    |      -       |       any        | ICMP |
