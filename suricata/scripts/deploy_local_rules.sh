# suricata/scripts/deploy_local_rules.sh
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_RULES="${1:-${REPO_ROOT}/configs/local.rules}"  # <-- argument 1 si fourni
DEST="/etc/suricata/rules"

if [ ! -f "$LOCAL_RULES" ]; then
  printf "ERROR: local.rules introuvable: %s\n" "$LOCAL_RULES" >&2
  exit 1
fi

sudo mkdir -p "$DEST"
sudo cp -f "$LOCAL_RULES" "$DEST/local.rules"
sudo chown root:root "$DEST/local.rules"
sudo chmod 0644 "$DEST/local.rules"
sudo systemctl restart suricata || true
