# Windows Server 2025 セットアップ手順書

## 1. 目次

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [1. 目次](#1-目次)
- [2. 目的・概要](#2-目的概要)
- [3. 前提条件](#3-前提条件)
- [4. 作業手順](#4-作業手順)
  - [4.1. パーティション作成コマンドを入れたISOを作成する](#41-パーティション作成コマンドを入れたisoを作成する)
  - [4.2. ISOをアップロードする](#42-isoをアップロードする)
    - [4.2.1. パーティション作成コマンドが入った ISO](#421-パーティション作成コマンドが入った-iso)
    - [4.2.2. virtio ドライバが入った ISO](#422-virtio-ドライバが入った-iso)
    - [4.2.3. Windows Server の ISO](#423-windows-server-の-iso)
  - [4.3. VMを作成する](#43-vmを作成する)
  - [4.4. Windows Server をインストールする](#44-windows-server-をインストールする)
  - [4.5. RDPを有効にする](#45-rdpを有効にする)
  - [4.6. MW をインストールする](#46-mw-をインストールする)
    - [4.6.1. 各種ドライバー](#461-各種ドライバー)
    - [4.6.2. QEMU Guest Agent](#462-qemu-guest-agent)
  - [4.7. Cloudbase-Init をインストール・設定する](#47-cloudbase-init-をインストール設定する)
    - [4.7.1. IPアドレス等を設定する](#471-ipアドレス等を設定する)
    - [4.7.2. Cloudbase-Init をインストールする](#472-cloudbase-init-をインストールする)
    - [4.7.3. Cloudbase-Init の設定ファイルを配置する](#473-cloudbase-init-の設定ファイルを配置する)
      - [4.7.3.1. cloudbase-init.conf](#4731-cloudbase-initconf)
      - [4.7.3.2. cloudbase-init-unattend.conf](#4732-cloudbase-init-unattendconf)
    - [4.7.4. シャットダウンする](#474-シャットダウンする)
    - [4.7.5. CD/DVD ドライブを外す](#475-cddvd-ドライブを外す)
    - [4.7.6. テンプレートに変換する](#476-テンプレートに変換する)
- [5. 完了条件](#5-完了条件)

<!-- /code_chunk_output -->

## 2. 目的・概要

Windows Server 2025 の VM のもととなる、VM テンプレートを作成する手順書です。

## 3. 前提条件

- Proxmox 9.x がインストール済みで、起動していること
- ホスト名: prod-prox-01

## 4. 作業手順

### 4.1. パーティション作成コマンドを入れたISOを作成する

そのまま新規インストールをすると、回復パーティションがプライマリのパーティションより後ろに作成されてしまう。前方にパーティションが作成されるように、インストール前に先にパーティションを作成しておく。
作成に必要なコマンドをテキストファイルとして、ISOの中に入れて、インストール時に利用する。
参考: [SE の雑記 - Windows Server 2022 で回復パーティションを前方に作成する](https://blog.engineer-memo.com/2022/05/22/windows-server-2022-%E3%81%A7%E5%9B%9E%E5%BE%A9%E3%83%91%E3%83%BC%E3%83%86%E3%82%A3%E3%82%B7%E3%83%A7%E3%83%B3%E3%82%92%E5%89%8D%E6%96%B9%E3%81%AB%E4%BD%9C%E6%88%90%E3%81%99%E3%82%8B/)

以下のコマンドを PowerShell で実行することで、CreatePartitions-UEFI.iso を作成する。

```pwsh
$workFolder = "$HOME\Desktop\iso_content"
$txtFolder = "$workFolder\src"
$isoPath = "$workFolder\CreatePartitions-UEFI.iso"

Remove-Item -Force $isoPath | Out-Null

New-Item -Type Directory $txtFolder | Out-Null

@"
select disk 0
clean
convert gpt

create partition msr size=16

create partition primary size=1536
format quick fs=ntfs label="Recovery"
assign letter="R"
set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"
gpt attributes=0x8000000000000001

create partition efi size=100
format quick fs=fat32 label="System"
assign letter="S"

create partition primary
format quick fs=ntfs label="Windows"
assign letter="W"

list volume
exit
"@ > "$txtFolder\CreatePartitions-UEFI.txt"

# ファイルシステムイメージを作成
$fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fsi.FileSystemsToCreate = 3  # UDF + ISO9660
$fsi.VolumeName = "CreatePartitions-UEFI-ISO"
$fsi.Root.AddTree($txtFolder, $false)

# ISOイメージを生成
$result = $fsi.CreateResultImage()
$stream = $result.ImageStream

# ストリームをファイルに書き込む
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public class IsoCreator {
    public static void WriteIStreamToFile(object comStream, string fileName) {
        IStream istream = comStream as IStream;
        FileStream fileStream = new FileStream(fileName, FileMode.Create);

        byte[] buffer = new byte[32768];
        IntPtr bytesReadPtr = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(int)));

        try {
            int bytesRead;
            long totalBytes = 0;

            do {
                istream.Read(buffer, buffer.Length, bytesReadPtr);
                bytesRead = Marshal.ReadInt32(bytesReadPtr);

                if (bytesRead > 0) {
                    fileStream.Write(buffer, 0, bytesRead);
                    totalBytes += bytesRead;
                }
            } while (bytesRead > 0);
        }
        finally {
            Marshal.FreeHGlobal(bytesReadPtr);
            fileStream.Close();
        }
    }
}
'@

[IsoCreator]::WriteIStreamToFile($stream, $isoPath)
```

### 4.2. ISOをアップロードする

#### 4.2.1. パーティション作成コマンドが入った ISO

```bash
sftp prod-prox-01:./ <<< $'put /mnt/c/Users/Lucky/Desktop/iso_content/CreatePartitions-UEFI.iso'
ssh prod-prox-01 'sudo mv CreatePartitions-UEFI.iso /var/lib/vz/template/iso/'
```

#### 4.2.2. virtio ドライバが入った ISO

VirtIO によって提供される仮想ディスクを標準でインストーラが読み込めないので、専用のドライバを含む ISO を利用する。

```bash
ssh prod-prox-01 'sudo wget --progress=bar:force https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso -O /var/lib/vz/template/iso/virtio-win.iso'
```

#### 4.2.3. Windows Server の ISO

x64、日本語版 Windows Server 2025 評価版のものを利用する。

```bash
ssh prod-prox-01 'sudo wget --progress=bar:force https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_ja-jp.iso -O /var/lib/vz/template/iso/26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_ja-jp.iso'
```

### 4.3. VMを作成する

```bash
ssh prod-prox-01

VM_ID=902
sudo qm create $VM_ID \
  --name winsrv-2025 \
  --ostype win11 \
  --machine q35 \
  --bios ovmf \
  --sockets 1 \
  --cores 2 \
  --cpu x86-64-v3 \
  --memory 4096 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:30,format=raw \
  --efidisk0 local-lvm:1,format=raw,efitype=4m,pre-enrolled-keys=1 \
  --tpmstate0 local-lvm:1,version=v2.0 \
  --ide2 local:iso/26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_ja-jp.iso,media=cdrom \
  --ide1 local:iso/CreatePartitions-UEFI.iso,media=cdrom \
  --ide0 local:iso/virtio-win.iso,media=cdrom \
  --net0 virtio,bridge=vmbr1 \
  --agent 1 \
  --boot "order=scsi0;ide2;ide1;ide0;net0" \
  --onboot 1
sudo qm start $VM_ID
sudo qm status $VM_ID
# status: running と表示されれば OK
```

### 4.4. Windows Server をインストールする

1. Proxmox Web GUI を開く
2. VM 903 のコンソールを開く
3. Windows Server のセットアップ画面が開始される
4. 言語設定が以下であることを確認して、次へ
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/01-lang.png)
5. キーボード設定が以下であることを確認して、次へ
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/02-keyboard.png)
6. Windows Server の新規インストールであること、データがすべて削除されることに同意する旨選択して、次へ
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/03-setup-option.png)
7. インストールするエディションが以下であることを確認して、次へ
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/04-edition.png)
8. ライセンス契約に同意して、次へ
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/05-license.png)
9. インストール先の選択画面になるので、ドライバーを読み込むため、Load Driver を選択
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/06-load-driver.png)
10. ドライバーのパスを指定するため、参照を選択
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/07-select-driver-path.png)
11. `D:\amd64\w11` を選択して、OK を選択
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/08-driver-path.png)
12. Red Hat VirtIO SCSI pass-through controller を選択して、インストールを選択
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/09-select-driver.png)
13. ディスク 0 の未割当領域が表示されたことを確認して、Shift + F10 キーを入力
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/10-disk-loaded.png)
14. コマンドプロンプトが表示されるので、以下を入力して、パーティションを作成
    - `F:`
    - `diskpart /s CreatePartitions-UEFI.txt`
    - `exit`
15. Refresh を選択して、ディスク一覧を再読み込み
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/11-refresh-disk.png)
16. ディスク 0 パーティション 4 を選択して、次へを選択
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/12-select-partition.png)
17. インストールを選択して、インストールを開始
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/13-start-install.png)
18. しばらく待つと、インストールが進む（少なくとも2回再起動される）
19. Administrator ユーザのパスワードを設定して、完了を選択
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/14-setup-admin-password.png)
20. ログイン画面が表示されるので、VNC の機能で、Ctrl + Alt + Del を入力
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/15-unlock-screen.png)
21. Administrator でログイン
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/16-login.png)
22. 初回ログインは診断データを送信するかどうか尋ねられるので、必須のみを選択して、同意を選択
![言語選択](./diagrams/winsrv2025_setup/install-winsrv2025/17-diangnose.png)

### 4.5. RDPを有効にする

1. ファイル名を指定して実行 から、`ms-settings:remotedesktop` を開く
2. リモートデスクトップ の横にあるトグルスイッチを選択
![言語選択](./diagrams/winsrv2025_setup/enable-rdp/01-enable-rdp.png)
3. 確認画面が出るので、確認を選択
![言語選択](./diagrams/winsrv2025_setup/enable-rdp/02-prompt.png)
4. リモートデスクトップ の横にあるトグルスイッチが有効であることを確認
![言語選択](./diagrams/winsrv2025_setup/enable-rdp/03-enabled-rdp.png)

### 4.6. MW をインストールする

#### 4.6.1. 各種ドライバー

1. ファイル名を指定して実行 から、`D:\virtio-win-gt-x64.msi` を指定して開く
2. インストールの開始画面が表示されるので、Next を選択
![言語選択](./diagrams/winsrv2025_setup/install-drivers/01-start-installation.png)
3. ライセンスの画面が表示されるので、チェックを入れて、Next を選択
![言語選択](./diagrams/winsrv2025_setup/install-drivers/02-license.png)
4. インストール内容の画面が表示されるので、すべてインストールすることになっていることを確認、Next を選択
![言語選択](./diagrams/winsrv2025_setup/install-drivers/03-install-contents.png)
5. インストール開始確認の画面が表示されるので、Install を選択
![言語選択](./diagrams/winsrv2025_setup/install-drivers/04-install.png)
6. インストール完了の画面が表示されるので、Finish を選択
![言語選択](./diagrams/winsrv2025_setup/install-drivers/05-completed-installation.png)
7. 再起動が必要という通知が表示されるので、再起動

#### 4.6.2. QEMU Guest Agent

1. ファイル名を指定して実行 から、`D:\guest-agent\qemu-qa-x86_x64.msi` を開く
2. 何も表示されないが、インストールは完了する
3. PowerShell を開き、以下コマンドを実行して、State が Running 、StartType が Automatic であればよい

    ```pwsh
    Get-Service QEMU-GA | Select-Object Name,DisplayName,Status,StartType | Format-List
    ```

### 4.7. Cloudbase-Init をインストール・設定する

#### 4.7.1. IPアドレス等を設定する

PowerShell を開き、以下コマンドを実行していく

```pwsh
Get-NetAdapter | Format-List
# イーサネットの ifIndex を見て、次の変数に設定
$ifIndex=6

Set-NetIPInterface -InterfaceIndex $ifIndex -Dhcp Disabled
New-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -IPAddress 192.168.21.10 -PrefixLength 24 -DefaultGateway 192.168.21.1
Set-DnsClientServerAddress  -InterfaceIndex $ifIndex -ServerAddress 192.168.21.1

Get-NetAdapter | Format-List
# 反映されていること、インターネットに接続できることを確認
```

#### 4.7.2. Cloudbase-Init をインストールする

1. PowerShell を開き、インストーラをダウンロード、実行する

    ```pwsh
    # 進捗度を非表示
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri https://cloudbase.it/downloads/CloudbaseInitSetup_1_1_6_x64.msi -OutFile CloudbaseInitSetup.msi
    # 進捗度を表示
    $ProgressPreference = 'Continue'

    .\CloudbaseInitSetup.msi
    ```

2. インストールの開始画面が表示されるので、Next を選択
![言語選択](./diagrams/winsrv2025_setup/install-cloudbase-init/01-start-installation.png)
3. ライセンスの画面が表示されるので、チェックを入れて、Next を選択
![言語選択](./diagrams/winsrv2025_setup/install-cloudbase-init/02-license.png)
4. インストール内容の画面が表示されるので、すべてインストールすることになっていることを確認、Next を選択
![言語選択](./diagrams/winsrv2025_setup/install-cloudbase-init/03-install-contents.png)
5. メタデータの設定画面が表示されるので、以下のように指定して、Next を選択
![言語選択](./diagrams/winsrv2025_setup/install-cloudbase-init/04-config-options.png)
6. インストール開始確認の画面が表示されるので、Install を選択
![言語選択](./diagrams/winsrv2025_setup/install-cloudbase-init/05-install.png)
7. インストール完了の画面が表示されるので、以下のようにチェックを入れる（**Finish はまだ選択しない**）
![言語選択](./diagrams/winsrv2025_setup/install-cloudbase-init/06-completed-installation.png)

#### 4.7.3. Cloudbase-Init の設定ファイルを配置する

`C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf` に、以下内容でそれぞれファイルを作成する

##### 4.7.3.1. cloudbase-init.conf

```text
[DEFAULT]
username=Administrator
groups=Administrators
inject_user_password=false
first_logon_behaviour=no
types=vfat,cdrom,iso
locations=partition,hdd,cdrom
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
verbose=true
debug=true
log_dir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
log_file=cloudbase-init.log
default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN
logging_serial_port_settings=
mtu_use_dhcp_config=true
ntp_use_dhcp_config=true
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
check_latest_version=false
metadata_services=cloudbaseinit.metadata.services.configdrive.ConfigDriveService
plugins=cloudbaseinit.plugins.common.mtu.MTUPlugin,
  cloudbaseinit.plugins.windows.ntpclient.NTPClientPlugin,
  cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin,
  cloudbaseinit.plugins.windows.createuser.CreateUserPlugin,
  cloudbaseinit.plugins.common.sshpublickeys.SetUserSSHPublicKeysPlugin,
  cloudbaseinit.plugins.common.networkconfig.NetworkConfigPlugin,
  cloudbaseinit.plugins.windows.extendvolumes.ExtendVolumesPlugin,
  cloudbaseinit.plugins.common.userdata.UserDataPlugin,
  cloudbaseinit.plugins.common.localscripts.LocalScriptsPlugin,
  cloudbaseinit.plugins.windows.winrmlistener.ConfigWinRMListenerPlugin
```

##### 4.7.3.2. cloudbase-init-unattend.conf

```text
[DEFAULT]
username=Administrator
groups=Administrators
inject_user_password=false
first_logon_behaviour=no
types=vfat,cdrom,iso
locations=partition,hdd,cdrom
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
verbose=true
debug=true
log_dir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
log_file=cloudbase-init-unattend.log
default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN
logging_serial_port_settings=
mtu_use_dhcp_config=true
ntp_use_dhcp_config=true
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
check_latest_version=false
metadata_services=cloudbaseinit.metadata.services.configdrive.ConfigDriveService
plugins=cloudbaseinit.plugins.common.mtu.MTUPlugin,
  cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin,
  cloudbaseinit.plugins.windows.extendvolumes.ExtendVolumesPlugin
allow_reboot=true
stop_service_on_exit=false
```

#### 4.7.4. シャットダウンする

1. Cloudbase-Init のインストール完了の画面が表示されているので、Finish を選択
  ![言語選択](./diagrams/winsrv2025_setup/install-cloudbase-init/06-completed-installation.png)

2. VM が停止したことを確認する

    ```bash
    uname -n
    # prod-prox-01

    sudo qm status $VM_ID
    # status: stopped と表示されれば OK
    ```

#### 4.7.5. CD/DVD ドライブを外す

```bash
for i in 0 1 2; do
  sudo qm set $VM_ID -delete ide${i}
done
```

#### 4.7.6. テンプレートに変換する

```bash
uname -n
# prod-prox-01
sudo qm template $VM_ID
```

## 5. 完了条件

- `Windows Server 2025`の `VM` のもととなる、`VM` テンプレートが作成されていること
