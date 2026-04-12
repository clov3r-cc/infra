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

echo "=== repo-sync finished ==="
