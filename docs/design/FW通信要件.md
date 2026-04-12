# VyOS ファイアウォール通信要件

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [1. 概要](#1-概要)
- [2. ゾーン定義](#2-ゾーン定義)
- [3. 共通ポリシー](#3-共通ポリシー)
- [4. グループ定義](#4-グループ定義)
  - [4.1. network-group](#41-network-group)
  - [4.2. address-group](#42-address-group)
- [5. ルール番号規則](#5-ルール番号規則)
  - [5.1. 番号帯](#51-番号帯)
  - [5.2. 番号間隔](#52-番号間隔)
  - [5.3. 同一番号帯内の順序](#53-同一番号帯内の順序)
- [6. ゾーン間通信要件](#6-ゾーン間通信要件)
  - [6.1. WAN → LOCAL](#61-wan--local)
  - [6.2. WAN → DMZ](#62-wan--dmz)
  - [6.3. DMZ → WAN](#63-dmz--wan)
  - [6.4. DMZ → LOCAL](#64-dmz--local)
  - [6.5. DMZ → INTERNAL](#65-dmz--internal)
  - [6.6. INTERNAL → WAN](#66-internal--wan)
  - [6.7. INTERNAL → DMZ](#67-internal--dmz)
  - [6.8. INTERNAL → LOCAL](#68-internal--local)
  - [6.9. LOCAL → WAN](#69-local--wan)
  - [6.10. LOCAL → DMZ](#610-local--dmz)
  - [6.11. LOCAL → SERVICE](#611-local--service)
  - [6.12. LOCAL → INTERNAL](#612-local--internal)

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

|    グループ名    |                                                                                                                       メンバー                                                                                                                       |                                   説明                                    |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `HOME-CLIENTS`   | 192.168.10.0/24                                                                                                                                                                                                                                      | 管理者端末                                                                |
| `CLOUDFLARE-IPS` | 173.245.48.0/20, 103.21.244.0/22, 103.22.200.0/22, 103.31.4.0/22, 141.101.64.0/18, 108.162.192.0/18, 190.93.240.0/20, 188.114.96.0/20, 197.234.240.0/22, 198.41.128.0/17, 162.158.0.0/15, 104.16.0.0/13, 104.24.0.0/14, 172.64.0.0/13, 131.0.72.0/22 | Cloudflare IPv4 アドレス範囲 (参照: <https://www.cloudflare.com/ips-v4/>) |

### 4.2. address-group

|    グループ名     |           メンバー           |        説明         |
| ----------------- | ---------------------------- | ------------------- |
| `WAN-GATEWAY`     | 192.168.20.1                 | 上流ルーター        |
| `PVE-NODES`       | 192.168.20.2                 | Proxmox ノード      |
| `FW-WAN-VIP`      | 192.168.20.3                 | FW (WAN VIP)        |
| `FW-WAN-NODES`    | 192.168.20.4, 192.168.20.5   | FW 01/02 (WAN)      |
| `FW-DMZ-VIP`      | 192.168.20.17                | FW (DMZ VIP)        |
| `FW-DMZ-NODES`    | 192.168.20.18, 192.168.20.19 | FW 01/02 (DMZ)      |
| `TAILSCALE-NODES` | 192.168.20.20, 192.168.20.21 | Tailscale ノード    |
| `DNS-SERVERS`     | 192.168.20.22, 192.168.20.23 | DNS/Proxy サーバ    |
| `ACCESS-SWITCHES` | 192.168.22.1                 | L2 スイッチ         |
| `FW-INTERNAL-VIP` | 192.168.22.3                 | FW (INTERNAL VIP)   |
| `NAS-SERVERS`     | 192.168.22.6                 | NAS サーバ          |
| `ZABBIX-SERVERS`  | 192.168.22.8, 192.168.22.9   | Zabbix サーバ       |
| `VRRP-MULTICAST`  | 224.0.0.18                   | VRRP マルチキャスト |

## 5. ルール番号規則

### 5.1. 番号帯

|   番号帯    |   カテゴリ   |                      例                      |
| ----------- | ------------ | -------------------------------------------- |
| **10–59**   | インフラ制御 | VRRP (Proto 112)、ICMP、UDP traceroute       |
| **100–149** | 管理アクセス | SSH (TCP 22)                                 |
| **200–299** | サービス     | NTP (UDP 123)、DNS (TCP/UDP 53)、HTTPS (443) |
| **950–999** | 明示的 drop  | silent drop など                             |

### 5.2. 番号間隔

|                    ケース                     |         間隔         |
| --------------------------------------------- | -------------------- |
| 通常（後で挿入余地を確保）                    | **10 刻み**          |
| 同一機能グループの連続ルール（FQDN 違いなど） | **1 刻み（連番）**   |
| 既存ルールの間への挿入                        | **5 刻み（中間値）** |

### 5.3. 同一番号帯内の順序

1. **プロトコル番号昇順**: ICMP (1) < TCP (6) < UDP (17) < tcp_udp < Proto 112 (VRRP)
   - ただし VRRP はインフラ制御として 10 番台先頭に固定（例外）
2. **同一プロトコル内**: 宛先ポート番号昇順
3. **accept ルールを先、drop ルールを後**（950 番台）

## 6. ゾーン間通信要件

未定義の通信はすべて **default-action: drop** で遮断されます。

以下の通信方向は意図的にルールがありません（直接アクセス不可）：

- WAN → SERVICE
- WAN → INTERNAL
- DMZ → SERVICE
- SERVICE → WAN
- SERVICE → DMZ
- SERVICE → INTERNAL
- SERVICE → LOCAL
- INTERNAL → WAN
- INTERNAL → SERVICE

### 6.1. WAN → LOCAL

| Rule  |     送信元     | プロトコル | 送信先ポート | 送信先アドレス |    目的    |
| :---: | :------------: | :--------: | :----------: | :------------: | ---------- |
|  10   | `FW-WAN-NODES` | Proto 112  |      -       |       -        | VRRP       |
|  20   | `HOME-CLIENTS` |    ICMP    |      -       | `FW-WAN-NODES` | ICMP       |
|  21   | `HOME-CLIENTS` |    ICMP    |      -       |  `FW-WAN-VIP`  | ICMP       |
|  30   | `HOME-CLIENTS` |    UDP     | 33434-33534  | `FW-WAN-NODES` | traceroute |
|  31   | `HOME-CLIENTS` |    UDP     | 33434-33534  |  `FW-WAN-VIP`  | traceroute |
|  100  | `HOME-CLIENTS` |    TCP     |      22      | `FW-WAN-NODES` | SSH        |

### 6.2. WAN → DMZ

| Rule  |     送信元     | プロトコル | 送信先ポート |  送信先アドレス   |    目的    |
| :---: | :------------: | :--------: | :----------: | :---------------: | ---------- |
|  10   | `HOME-CLIENTS` |    ICMP    |      -       | `TAILSCALE-NODES` | ICMP       |
|  20   | `HOME-CLIENTS` |    UDP     | 33434-33534  | `TAILSCALE-NODES` | traceroute |
|  100  | `HOME-CLIENTS` |    TCP     |      22      | `TAILSCALE-NODES` | SSH        |

### 6.3. DMZ → WAN

[What firewall ports should I open to use Tailscale?](https://tailscale.com/docs/reference/faq/firewall-ports)

| Rule  |      送信元       | アクション | プロトコル | 送信元ポート | 送信先ポート |            送信先アドレス            |                      目的                       |
| :---: | :---------------: | :--------: | :--------: | :----------: | :----------: | :----------------------------------: | ----------------------------------------------- |
|  10   | `TAILSCALE-NODES` |   accept   |    TCP     |     any      |     443      |                 any                  | Tailscale コントロールサーバー・DERP リレー接続 |
|  11   | `TAILSCALE-NODES` |   accept   |    TCP     |     any      |     8006     |             `PVE-NODES`              | Proxmox API                                     |
|  12   | `TAILSCALE-NODES` |   accept   |    TCP     |     any      |      22      |             `PVE-NODES`              | Proxmox SSH                                     |
|  20   | `TAILSCALE-NODES` |   accept   |    UDP     |    41641     |     any      |                 any                  | Tailscale WireGuard 直接トンネル                |
|  30   | `TAILSCALE-NODES` |   accept   |    UDP     |     any      |     3478     |                 any                  | Tailscale STUN                                  |
|  40   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |       `mirrors.almalinux.org`        | AlmaLinux dnf リポジトリ                        |
|  41   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |         `repo.almalinux.org`         | AlmaLinux repo 設定ファイル取得                 |
|  42   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |      80      |         `ftp.udx.icscoe.jp`          | AlmaLinux ミラー (ICS-COE)                      |
|  43   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |      80      |           `ftp.iij.ad.jp`            | AlmaLinux ミラー (IIJ)                          |
|  44   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |      80      |          `ftp.jaist.ac.jp`           | AlmaLinux ミラー (JAIST)                        |
|  45   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |      80      |          `ftp.sakura.ad.jp`          | AlmaLinux ミラー (さくら)                       |
|  46   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |      80      |            `ftp.riken.jp`            | AlmaLinux ミラー (理研)                         |
|  47   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |      80      |      `ftp.yz.yamagata-u.ac.jp`       | AlmaLinux ミラー (山形大)                       |
|  48   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |      80      |          `mirrors.xtom.jp`           | AlmaLinux ミラー (XTOM)                         |
|  49   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |      80      |     `alma.acidman.thelefty.org`      | AlmaLinux ミラー (Acidman)                      |
|  50   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |     `copr.fedorainfracloud.org`      | COPR repo 設定ファイル取得                      |
|  51   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      | `download.copr.fedorainfracloud.org` | COPR パッケージダウンロード                     |
|  52   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |         `static.adtidy.org`          | AdGuardHome アップデート確認                    |
|  53   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |       `adguardteam.github.io`        | AdGuardHome フィルタリストダウンロード          |
|  54   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |             `github.com`             | lego バイナリダウンロード                       |
|  55   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |   `objects.githubusercontent.com`    | lego バイナリダウンロード（CDN）                |
|  56   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |    `acme-v02.api.letsencrypt.org`    | Let's Encrypt ACME API                          |
|  57   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |         `api.cloudflare.com`         | Cloudflare API (DNS-01 チャレンジ)              |
|  58   |   `DNS-SERVERS`   |   accept   | TCP / UDP  |     any      |      53      |           `CLOUDFLARE-IPS`           | SSL 証明書更新に伴う DNS チャレンジ             |
|  59   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |            `easylist.to`             | AdGuardHome フィルタリストダウンロード          |
|  950  | `TAILSCALE-NODES` |    drop    |    TCP     |     any      |      80      |        `derp7e.tailscale.com`        | Tailscale キャプティブポータル検出 (ログ抑制)   |
|  951  | `TAILSCALE-NODES` |    drop    |    TCP     |     any      |      80      |        `derp7f.tailscale.com`        | Tailscale キャプティブポータル検出 (ログ抑制)   |
|  952  | `TAILSCALE-NODES` |    drop    |    TCP     |     any      |      80      |        `derp7g.tailscale.com`        | Tailscale キャプティブポータル検出 (ログ抑制)   |
|  953  | `TAILSCALE-NODES` |    drop    |    TCP     |     any      |      80      |        `derp7h.tailscale.com`        | Tailscale キャプティブポータル検出 (ログ抑制)   |

### 6.4. DMZ → LOCAL

| Rule  |      送信元       | アクション | プロトコル | 送信先ポート | 送信先アドレス |         目的         |
| :---: | :---------------: | :--------: | :--------: | :----------: | :------------: | -------------------- |
|  10   |  `FW-DMZ-NODES`   |   accept   | Proto 112  |      -       |       -        | VRRP                 |
|  20   | `TAILSCALE-NODES` |   accept   |    ICMP    |      -       | `FW-DMZ-NODES` | ICMP                 |
|  30   | `TAILSCALE-NODES` |   accept   |    UDP     | 33434-33534  | `FW-DMZ-NODES` | traceroute           |
|  100  | `TAILSCALE-NODES` |   accept   |    TCP     |      22      | `FW-DMZ-NODES` | SSH                  |
|  200  | `TAILSCALE-NODES` |   accept   |    UDP     |     123      |  `FW-DMZ-VIP`  | NTP                  |
|  201  |   `DNS-SERVERS`   |   accept   |    UDP     |     123      |  `FW-DMZ-VIP`  | NTP                  |
|  210  | `TAILSCALE-NODES` |   accept   |  UDP/TCP   |      53      |  `FW-DMZ-VIP`  | DNS                  |
|  211  |   `DNS-SERVERS`   |   accept   |  UDP/TCP   |      53      |  `FW-DMZ-VIP`  | DNS                  |
|  950  | `TAILSCALE-NODES` |    drop    |    UDP     |     5351     |       -        | NAT-PMP (ログ抑制)   |
|  951  | `TAILSCALE-NODES` |    drop    |    UDP     |     1900     |       -        | UPnP/SSDP (ログ抑制) |

### 6.5. DMZ → INTERNAL

| Rule  |      送信元       | プロトコル | 送信先ポート |  送信先アドレス   |     目的     |
| :---: | :---------------: | :--------: | :----------: | :---------------: | ------------ |
|  10   | `TAILSCALE-NODES` |    ICMP    |      -       |   `NAS-SERVERS`   | ICMP         |
|  15   | `TAILSCALE-NODES` |    UDP     | 33434-33534  |   `NAS-SERVERS`   | traceroute   |
|  20   | `TAILSCALE-NODES` |    TCP     |      22      | `ZABBIX-SERVERS`  | SSH          |
|  30   | `TAILSCALE-NODES` |    TCP     |      22      | `ACCESS-SWITCHES` | SSH          |
|  40   | `TAILSCALE-NODES` |    TCP     |     9999     |   `NAS-SERVERS`   | NAS サービス |

### 6.6. INTERNAL → WAN

| Rule  |    送信元     | プロトコル | 送信先ポート | 送信先アドレス |      目的       |
| :---: | :-----------: | :--------: | :----------: | :------------: | --------------- |
|  10   | `NAS-SERVERS` |    ICMP    |      -       |      any       | 接続確認 (ICMP) |
|  200  | `NAS-SERVERS` |    TCP     |     443      |      any       | NAS HTTPS API   |

### 6.7. INTERNAL → DMZ

| Rule  |      送信元      | プロトコル | 送信先ポート | 送信先アドレス |       目的       |
| :---: | :--------------: | :--------: | :----------: | :------------: | ---------------- |
|  10   | `ZABBIX-SERVERS` |  UDP/TCP   |      53      | `DNS-SERVERS`  | DNS              |
|  11   |  `NAS-SERVERS`   |  UDP/TCP   |      53      | `DNS-SERVERS`  | DNS              |
|  20   | `ZABBIX-SERVERS` |    TCP     |     443      | `DNS-SERVERS`  | リポジトリミラー |

### 6.8. INTERNAL → LOCAL

| Rule  |      送信元      | アクション | プロトコル | 送信先ポート |  送信先アドレス   |              目的               |
| :---: | :--------------: | :--------: | :--------: | :----------: | :---------------: | ------------------------------- |
|  10   | `ZABBIX-SERVERS` |   accept   |    UDP     |     123      | `FW-INTERNAL-VIP` | NTP                             |
|  20   |  `NAS-SERVERS`   |   accept   |    UDP     |     123      | `FW-INTERNAL-VIP` | NTP                             |
|  950  |  `NAS-SERVERS`   |    drop    |    UDP     |     137      | ブロードキャスト  | NetBIOS Name Service (ログ抑制) |
|  951  |  `NAS-SERVERS`   |    drop    |    UDP     |     138      | ブロードキャスト  | NetBIOS Datagram (ログ抑制)     |

### 6.9. LOCAL → WAN

| Rule  | 送信元 | プロトコル | 送信先ポート |         送信先アドレス          |               目的               |
| :---: | :----: | :--------: | :----------: | :-----------------------------: | -------------------------------- |
|  10   |   -    |    UDP     |     123      |          `WAN-GATEWAY`          | NTP                              |
|  20   |   -    |  UDP/TCP   |      53      |          `WAN-GATEWAY`          | DNS                              |
|  30   |   -    |    TCP     |     443      |          `github.com`           | VyOS イメージダウンロード        |
|  31   |   -    |    TCP     |     443      | `objects.githubusercontent.com` | VyOS イメージダウンロード（CDN） |
|  40   |   -    |    ICMP    |      -       |               any               | ICMP                             |
|  45   |   -    |    UDP     | 33434-33534  |               any               | traceroute                       |
|  50   |   -    | Proto 112  |      -       |        `VRRP-MULTICAST`         | VRRP                             |

### 6.10. LOCAL → DMZ

| Rule  | 送信元 | プロトコル | 送信先ポート |  送信先アドレス  |    目的    |
| :---: | :----: | :--------: | :----------: | :--------------: | ---------- |
|  10   |   -    | Proto 112  |      -       | `VRRP-MULTICAST` | VRRP       |
|  20   |   -    |    ICMP    |      -       |       any        | ICMP       |
|  25   |   -    |    UDP     | 33434-33534  |       any        | traceroute |

> **Note**: VRRP（Proto 112）はマルチキャスト（224.0.0.18）を使った双方向独立送信のため、セッション追跡ができません。そのため DMZ-TO-LOCAL（受信側）と LOCAL-TO-DMZ（送信側）の両方向に明示的なルールが必要です。

### 6.11. LOCAL → SERVICE

| Rule  | 送信元 | プロトコル | 送信先ポート |  送信先アドレス  |    目的    |
| :---: | :----: | :--------: | :----------: | :--------------: | ---------- |
|  10   |   -    | Proto 112  |      -       | `VRRP-MULTICAST` | VRRP       |
|  20   |   -    |    ICMP    |      -       |       any        | ICMP       |
|  25   |   -    |    UDP     | 33434-33534  |       any        | traceroute |

### 6.12. LOCAL → INTERNAL

| Rule  | 送信元 | プロトコル | 送信先ポート |  送信先アドレス  |    目的    |
| :---: | :----: | :--------: | :----------: | :--------------: | ---------- |
|  10   |   -    | Proto 112  |      -       | `VRRP-MULTICAST` | VRRP       |
|  20   |   -    |    ICMP    |      -       |       any        | ICMP       |
|  25   |   -    |    UDP     | 33434-33534  |       any        | traceroute |
