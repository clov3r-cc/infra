#!/bin/bash
set -euo pipefail

reposync --download-metadata --delete --newest-only --repoid=baseos --download-path=/var/www/html/repos/
reposync --download-metadata --delete --newest-only --repoid=appstream --download-path=/var/www/html/repos/
reposync --download-metadata --delete --newest-only --repoid=crb --download-path=/var/www/html/repos/
reposync --download-metadata --delete --newest-only --repoid=extras --download-path=/var/www/html/repos/
reposync --download-metadata --delete --newest-only --repoid='copr:copr.fedorainfracloud.org:noa:rust' --download-path=/var/www/html/repos/copr-noa-rust/
