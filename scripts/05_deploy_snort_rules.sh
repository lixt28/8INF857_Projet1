#!/usr/bin/env bash
set -e
SNORT_ETC=/usr/local/etc/snort
sudo mkdir -p "$SNORT_ETC/rules"
sudo cp configs/snort/local.rules "$SNORT_ETC/rules/local.rules"
sudo cp configs/snort/snort.lua "$SNORT_ETC/snort.lua"
sudo mkdir -p /var/log/snort
sudo chown root:root /var/log/snort || true
echo "Règles déployées. Lance Snort (ex):"
echo "sudo /usr/local/snort/bin/snort -c /usr/local/etc/snort/snort.lua -i enp0s3 -A alert_json -l /var/log/snort -k none"
