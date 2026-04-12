#!/bin/bash

set -eo pipefail

if [ -z "$BW_SESSION" ]; then
    echo "Error: BW_SESSION is not set. Please login first:" >&2
    echo "  export BW_SESSION=\$(bw unlock --raw)" >&2
    exit 1
fi

# Ansible Vault 暗号化パスワード(prd)
ITEM_ID=b1eeacab-ee1d-4049-a6a5-b3bc00fbe48f
bw get password "$ITEM_ID"
