set -e

SNORT_ETC=/usr/local/etc/snort

sudo mkdir -p "$SNORT_ETC/rules"

sudo cp configs/snort/local.rules "$SNORT_ETC/rules/local.rules"

sudo cp "$SNORT_ETC/snort.lua" "$SNORT_ETC/snort.lua.bak_$(date +%Y-%m-%d_%H-%M-%S)"

sudo cp configs/snort/snort.lua "$SNORT_ETC/snort.lua"

sudo mkdir -p /var/log/snort

sudo chown root:root /var/log/snort || true
