#!/bin/bash
set -euo pipefail

exec > >(awk '{ print strftime("%Y/%m/%d %H:%M:%S"), $0; fflush() }') 2>&1

echo "=== repo-sync started ==="

DOWNLOAD_PATH="/var/www/html/repos"
REPO_IDS=(
  baseos
  appstream
  crb
  extras
  highavailability

  # 追加
  elrepo
  mariadb
  # COPRは配列に含めない
)

for repoid in "${REPO_IDS[@]}"; do
  reposync --download-metadata --delete --newest-only --repoid="$repoid" --download-path="${DOWNLOAD_PATH}/"
done
# COPR はダウンロード先のディレクトリを明示的に指定するため個別に実行
reposync --download-metadata --delete --newest-only --repoid='copr:copr.fedorainfracloud.org:noa:rust' --download-path="${DOWNLOAD_PATH}/copr-noa-rust/"

KEY_PATH="${DOWNLOAD_PATH}/keys"
mkdir -p "$KEY_PATH"
GPG_KEYS=(
  https://www.elrepo.org/RPM-GPG-KEY-v2-elrepo.org
  https://ftp.yz.yamagata-u.ac.jp/pub/dbms/mariadb/yum/RPM-GPG-KEY-MariaDB
)
for key_url in "${GPG_KEYS[@]}"; do
  echo "Downloading GPG key: $key_url"
  curl -fsSL "$key_url" -o "${KEY_PATH}/${key_url##*/}"
done

echo "=== repo-sync finished ==="
