#!/bin/sh
find "$1" -maxdepth 1 -name '*.crt' ! -name '*.issuer.crt' 2>/dev/null | while read f; do key="${f%.crt}.key"; [ -f "$key" ] && basename "$f" .crt; done | awk 'BEGIN{printf "{\"data\":["; s=""} {printf "%s{\"{#CERT.DOMAIN}\":\"%s\"}",s,$0; s=","} END{printf "]}"}'
