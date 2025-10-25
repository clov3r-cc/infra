#!/usr/bin/env python3
"""
Get the latest Cloudflare Workers compatibility_date
"""
import re
import sys

def fetch_html():
    try:
        import requests
        response = requests.get(
            "https://developers.cloudflare.com/workers/configuration/compatibility-flags/",
            timeout=10
        )
        response.raise_for_status()
        return response.text
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def get_latest_date(html_content):
    dates = re.findall(
        r'<td><strong>Default as of</strong></td><td>(\d{4}-\d{2}-\d{2})</td>',
        html_content
    )
    if not dates:
        print("Error: No dates found", file=sys.stderr)
        sys.exit(1)
    return max(dates)

if __name__ == "__main__":
    html = fetch_html()
    print(get_latest_date(html))
