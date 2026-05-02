# VyOS ファイアウォール通信要件

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [1. 概要](#1-概要)
- [2. ゾーン定義](#2-ゾーン定義)
- [3. 共通ポリシー](#3-共通ポリシー)
- [4. グループ定義](#4-グループ定義)
  - [4.1. network-group](#41-network-group)
  - [4.2. address-group](#42-address-group)
  - [4.3. domain-group](#43-domain-group)
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
  - [6.6. SERVICE → LOCAL](#66-service--local)
  - [6.7. INTERNAL → WAN](#67-internal--wan)
  - [6.8. INTERNAL → DMZ](#68-internal--dmz)
  - [6.9. INTERNAL → LOCAL](#69-internal--local)
  - [6.10. LOCAL → WAN](#610-local--wan)
  - [6.11. LOCAL → DMZ](#611-local--dmz)
  - [6.12. LOCAL → SERVICE](#612-local--service)
  - [6.13. LOCAL → INTERNAL](#613-local--internal)

<!-- /code_chunk_output -->

## 1. 概要

`prd-vyo` に設定するゾーンベースファイアウォールの通信要件を定義します。

VyOS を使用し、IPv4 ゾーンベースファイアウォールで実装します。

## 2. ゾーン定義

| ゾーン名 | インターフェース |      CIDR       |     用途     |
| :------: | :--------------: | :-------------: | ------------ |
|   WAN    |       eth0       | 192.168.20.0/29 | 上流 NW      |
|   DMZ    |       eth1       | 192.168.20.8/29 | DMZ          |
| SERVICE  |       eth2       | 192.168.21.0/24 | サービス NW  |
| INTERNAL |       eth3       | 192.168.22.0/24 | 内部 NW      |
|  LOCAL   |        -         |        -        | ルーター自身 |

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

|     グループ名      |           メンバー           |        説明         |
| ------------------- | ---------------------------- | ------------------- |
| `WAN-GATEWAY`       | 192.168.20.1                 | 上流ルーター        |
| `PVE-NODES`         | 192.168.20.2                 | Proxmox ノード      |
| `FW-WAN-VIP`        | 192.168.20.3                 | FW (WAN VIP)        |
| `FW-WAN-NODES`      | 192.168.20.4, 192.168.20.5   | FW 01/02 (WAN)      |
| `FW-DMZ-VIP`        | 192.168.20.17                | FW (DMZ VIP)        |
| `FW-DMZ-NODES`      | 192.168.20.18, 192.168.20.19 | FW 01/02 (DMZ)      |
| `TAILSCALE-NODES`   | 192.168.20.20, 192.168.20.21 | Tailscale ノード    |
| `DNS-SERVERS`       | 192.168.20.22, 192.168.20.23 | DNS/Proxy サーバ    |
| `FW-SERVICE-VIP`    | 192.168.21.3                 | FW (SERVICE VIP)    |
| `FW-SERVICE-NODES`  | 192.168.21.4, 192.168.21.5   | FW 01/02 (SERVICE)  |
| `ACCESS-SWITCHES`   | 192.168.22.1                 | L2 スイッチ         |
| `FW-INTERNAL-VIP`   | 192.168.22.3                 | FW (INTERNAL VIP)   |
| `FW-INTERNAL-NODES` | 192.168.22.4, 192.168.22.5   | FW 01/02 (INTERNAL) |
| `NAS-SERVERS`       | 192.168.22.6                 | NAS サーバ          |
| `ZABBIX-SERVERS`    | 192.168.22.8, 192.168.22.9   | Zabbix サーバ       |
| `VRRP-MULTICAST`    | 224.0.0.18                   | VRRP マルチキャスト |

### 4.3. domain-group

|        グループ名        |                                                                                              メンバー                                                                                               |                        説明                        |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| `ALMALINUX-MIRRORS`      | `mirrors.almalinux.org, repo.almalinux.org, ftp.udx.icscoe.jp, ftp.iij.ad.jp, ftp.jaist.ac.jp, ftp.sakura.ad.jp, ftp.riken.jp, ftp.yz.yamagata-u.ac.jp, mirrors.xtom.jp, alma.acidman.thelefty.org` | AlmaLinux・MariaDB パッケージミラー                |
| `ELREPO-MIRRORS`         | `www.elrepo.org, elrepo.org, mirrors.elrepo.org, mirrors.coreix.net, mirror.rackspace.com, linux-mirrors.fnal.gov`                                                                                  | ELRepo パッケージミラー                            |
| `COPR`                   | `copr.fedorainfracloud.org, download.copr.fedorainfracloud.org`                                                                                                                                     | COPR パッケージリポジトリ                          |
| `ADGUARD`                | `static.adtidy.org, adguardteam.github.io`                                                                                                                                                          | AdGuardHome アップデート・フィルタリスト           |
| `GITHUB`                 | `github.com, objects.githubusercontent.com`                                                                                                                                                         | GitHub                                             |
| `LETSENCRYPT`            | `acme-v02.api.letsencrypt.org`                                                                                                                                                                      | Let's Encrypt ACME                                 |
| `CLOUDFLARE-API`         | `api.cloudflare.com`                                                                                                                                                                                | Cloudflare API                                     |
| `EASYLIST`               | `easylist.to`                                                                                                                                                                                       | AdGuardHome フィルタリスト                         |
| `DEBIAN-MIRRORS`         | `deb.debian.org, security.debian.org`                                                                                                                                                               | Debian パッケージミラー                            |
| `TAILSCALE-DERP-CAPTIVE` | `derp7e.tailscale.com, derp7f.tailscale.com, derp7g.tailscale.com, derp7h.tailscale.com`                                                                                                            | Tailscale キャプティブポータル検出用 DERP ドメイン |

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

Tailscale の通信要件: [What firewall ports should I open to use Tailscale?](https://tailscale.com/docs/reference/faq/firewall-ports)

| Rule  |      送信元       | アクション | プロトコル | 送信元ポート | 送信先ポート |      送信先アドレス      |                      目的                       |
| :---: | :---------------: | :--------: | :--------: | :----------: | :----------: | :----------------------: | ----------------------------------------------- |
|  10   | `TAILSCALE-NODES` |   accept   |    TCP     |     any      |     443      |           any            | Tailscale コントロールサーバー・DERP リレー接続 |
|  11   | `TAILSCALE-NODES` |   accept   |    TCP     |     any      |     8006     |       `PVE-NODES`        | Proxmox API                                     |
|  12   | `TAILSCALE-NODES` |   accept   |    TCP     |     any      |      22      |       `PVE-NODES`        | Proxmox SSH                                     |
|  20   | `TAILSCALE-NODES` |   accept   |    UDP     |    41641     |     any      |           any            | Tailscale WireGuard 直接トンネル                |
|  30   | `TAILSCALE-NODES` |   accept   |    UDP     |     any      |     3478     |           any            | Tailscale STUN                                  |
|  40   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |   80, 443    |   `ALMALINUX-MIRRORS`    | AlmaLinux・MariaDB パッケージミラー             |
|  41   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |   80, 443    |     `ELREPO-MIRRORS`     | ELRepo パッケージミラー                         |
|  42   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |          `COPR`          | COPR パッケージ取得                             |
|  43   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |        `ADGUARD`         | AdGuardHome アップデート・フィルタリスト        |
|  44   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |         `GITHUB`         | lego バイナリダウンロード                       |
|  45   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |      `LETSENCRYPT`       | Let's Encrypt ACME API                          |
|  46   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |     `CLOUDFLARE-API`     | Cloudflare API (DNS-01 チャレンジ)              |
|  47   |   `DNS-SERVERS`   |   accept   |    TCP     |     any      |     443      |        `EASYLIST`        | AdGuardHome フィルタリストダウンロード          |
|  50   |   `DNS-SERVERS`   |   accept   | TCP / UDP  |     any      |      53      |     `CLOUDFLARE-IPS`     | SSL 証明書更新に伴う DNS チャレンジ             |
|  950  | `TAILSCALE-NODES` |    drop    |    TCP     |     any      |      80      | `TAILSCALE-DERP-CAPTIVE` | Tailscale キャプティブポータル検出 (ログ抑制)   |

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

### 6.6. SERVICE → LOCAL

| Rule  |       送信元       | プロトコル | 送信先ポート | 送信先アドレス | 目的 |
| :---: | :----------------: | :--------: | :----------: | :------------: | ---- |
|  10   | `FW-SERVICE-NODES` | Proto 112  |      -       |       -        | VRRP |

### 6.7. INTERNAL → WAN

| Rule  |    送信元     | プロトコル | 送信先ポート | 送信先アドレス |      目的       |
| :---: | :-----------: | :--------: | :----------: | :------------: | --------------- |
|  10   | `NAS-SERVERS` |    ICMP    |      -       |      any       | 接続確認 (ICMP) |
|  200  | `NAS-SERVERS` |    TCP     |     443      |      any       | NAS HTTPS API   |

### 6.8. INTERNAL → DMZ

| Rule  |      送信元      | プロトコル | 送信先ポート | 送信先アドレス |       目的       |
| :---: | :--------------: | :--------: | :----------: | :------------: | ---------------- |
|  10   | `ZABBIX-SERVERS` |  UDP/TCP   |      53      | `DNS-SERVERS`  | DNS              |
|  11   |  `NAS-SERVERS`   |  UDP/TCP   |      53      | `DNS-SERVERS`  | DNS              |
|  20   | `ZABBIX-SERVERS` |    TCP     |     443      | `DNS-SERVERS`  | リポジトリミラー |

### 6.9. INTERNAL → LOCAL

| Rule  |       送信元        | アクション | プロトコル | 送信先ポート |  送信先アドレス   |              目的               |
| :---: | :-----------------: | :--------: | :--------: | :----------: | :---------------: | ------------------------------- |
|  10   | `FW-INTERNAL-NODES` |   accept   | Proto 112  |      -       |         -         | VRRP                            |
|  20   |  `ZABBIX-SERVERS`   |   accept   |    UDP     |     123      | `FW-INTERNAL-VIP` | NTP                             |
|  30   |    `NAS-SERVERS`    |   accept   |    UDP     |     123      | `FW-INTERNAL-VIP` | NTP                             |
|  950  |    `NAS-SERVERS`    |    drop    |    UDP     |     137      | ブロードキャスト  | NetBIOS Name Service (ログ抑制) |
|  951  |    `NAS-SERVERS`    |    drop    |    UDP     |     138      | ブロードキャスト  | NetBIOS Datagram (ログ抑制)     |

### 6.10. LOCAL → WAN

| Rule  | 送信元 | プロトコル | 送信先ポート |  送信先アドレス  |              目的              |
| :---: | :----: | :--------: | :----------: | :--------------: | ------------------------------ |
|  10   |   -    |    UDP     |     123      |  `WAN-GATEWAY`   | NTP                            |
|  20   |   -    |  UDP/TCP   |      53      |  `WAN-GATEWAY`   | DNS                            |
|  30   |   -    |    TCP     |     443      |     `GITHUB`     | イメージ・バイナリダウンロード |
|  35   |   -    |    TCP     |     443      | `DEBIAN-MIRRORS` | Debian パッケージ取得          |
|  40   |   -    |    ICMP    |      -       |       any        | ICMP                           |
|  45   |   -    |    UDP     | 33434-33534  |       any        | traceroute                     |
|  50   |   -    | Proto 112  |      -       | `VRRP-MULTICAST` | VRRP                           |

### 6.11. LOCAL → DMZ

| Rule  | 送信元 | プロトコル | 送信先ポート |  送信先アドレス  |    目的    |
| :---: | :----: | :--------: | :----------: | :--------------: | ---------- |
|  10   |   -    | Proto 112  |      -       | `VRRP-MULTICAST` | VRRP       |
|  20   |   -    |    ICMP    |      -       |       any        | ICMP       |
|  25   |   -    |    UDP     | 33434-33534  |       any        | traceroute |

> **Note**: VRRP（Proto 112）はマルチキャスト（224.0.0.18）を使った双方向独立送信のため、セッション追跡ができません。そのため DMZ-TO-LOCAL（受信側）と LOCAL-TO-DMZ（送信側）の両方向に明示的なルールが必要です。

### 6.12. LOCAL → SERVICE

| Rule  | 送信元 | プロトコル | 送信先ポート |  送信先アドレス  |    目的    |
| :---: | :----: | :--------: | :----------: | :--------------: | ---------- |
|  10   |   -    | Proto 112  |      -       | `VRRP-MULTICAST` | VRRP       |
|  20   |   -    |    ICMP    |      -       |       any        | ICMP       |
|  25   |   -    |    UDP     | 33434-33534  |       any        | traceroute |

### 6.13. LOCAL → INTERNAL

| Rule  | 送信元 | プロトコル | 送信先ポート |  送信先アドレス  |    目的    |
| :---: | :----: | :--------: | :----------: | :--------------: | ---------- |
|  10   |   -    | Proto 112  |      -       | `VRRP-MULTICAST` | VRRP       |
|  20   |   -    |    ICMP    |      -       |       any        | ICMP       |
|  25   |   -    |    UDP     | 33434-33534  |       any        | traceroute |
