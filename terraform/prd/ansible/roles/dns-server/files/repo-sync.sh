#!/bin/bash
set -euo pipefail

exec > >(awk '{ print strftime("%Y/%m/%d %H:%M:%S"), $0; fflush() }') 2>&1

echo "=== repo-sync started ==="

reposync --download-metadata --delete --newest-only --repoid=baseos --download-path=/var/www/html/repos/
reposync --download-metadata --delete --newest-only --repoid=appstream --download-path=/var/www/html/repos/
reposync --download-metadata --delete --newest-only --repoid=crb --download-path=/var/www/html/repos/
reposync --download-metadata --delete --newest-only --repoid=extras --download-path=/var/www/html/repos/
reposync --download-metadata --delete --newest-only --repoid='copr:copr.fedorainfracloud.org:noa:rust' --download-path=/var/www/html/repos/copr-noa-rust/

echo "=== repo-sync finished ==="
