#!/usr/bin/env bash
set -euo pipefail

# Déploiement conf & règles Snort 3 (compatibles)
# - copie snort.lua + local.rules depuis le dépôt
# - installe les fichiers Lua de base si présents
# - pointe file_id.rules_file vers /usr/local/etc/snort/file_magic.rules
# - corrige 2.x -> 3.x (icmp_type -> itype, retire nocase isolé)
# - HOME_NET peut être forcé via: export HOME_NET_CIDR='192.168.56.0/24'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_LUA="$REPO_ROOT/configs/snort/snort.lua"
SRC_RULES="$REPO_ROOT/configs/snort/local.rules"

DEST_ETC="/usr/local/etc/snort"
DEST_RULES="$DEST_ETC/rules"
DEST_LOG="/var/log/snort"
DEST_ALERT="$DEST_LOG/alert_json.txt"

CANDIDATE_ETC_1="/tmp/snort3/lua"
CANDIDATE_ETC_2="/tmp/snort3/etc"
CANDIDATE_ETC_3="/usr/local/snort/etc/snort"

need_file() {
  local name="$1" dest="$DEST_ETC/$name"
  [[ -f "$dest" ]] && return 0
  for d in "$CANDIDATE_ETC_1" "$CANDIDATE_ETC_2" "$CANDIDATE_ETC_3"; do
    [[ -n "${d:-}" && -f "$d/$name" ]] && { sudo cp -f "$d/$name" "$dest"; return 0; }
  done
  return 1
}

echo "==> Préparation des dossiers"
sudo install -d "$DEST_RULES" "$DEST_LOG"
sudo touch "$DEST_ALERT"
sudo chmod 755 "$DEST_ETC" "$DEST_RULES" || true
sudo chmod 666 "$DEST_ALERT"

echo "==> Copie snort.lua + local.rules"
[[ -f "$SRC_LUA"   ]] || { echo "ERR: $SRC_LUA manquant"; exit 1; }
[[ -f "$SRC_RULES" ]] || { echo "ERR: $SRC_RULES manquant"; exit 1; }
ts="$(date +%Y%m%d-%H%M%S)"
[[ -f "$DEST_ETC/snort.lua" ]]        && sudo cp -f "$DEST_ETC/snort.lua"        "$DEST_ETC/snort.lua.bak.$ts"
[[ -f "$DEST_RULES/local.rules" ]]    && sudo cp -f "$DEST_RULES/local.rules"    "$DEST_RULES/local.rules.bak.$ts"
sudo cp -f "$SRC_LUA"   "$DEST_ETC/snort.lua"
sudo cp -f "$SRC_RULES" "$DEST_RULES/local.rules"

echo "==> Fichiers Lua de base"
need_file "snort_defaults.lua" || echo "WARN: snort_defaults.lua introuvable (ok si déjà présent)."
need_file "file_magic.lua"     || echo "WARN: file_magic.lua introuvable (ok si déjà présent)."

# file_magic.rules : copie si trouvé, sinon placeholder
if [[ ! -f "$DEST_ETC/file_magic.rules" ]]; then
  if   [[ -f "$CANDIDATE_ETC_1/file_magic.rules" ]]; then sudo cp -f "$CANDIDATE_ETC_1/file_magic.rules" "$DEST_ETC/file_magic.rules"
  elif [[ -f "$CANDIDATE_ETC_2/file_magic.rules" ]]; then sudo cp -f "$CANDIDATE_ETC_2/file_magic.rules" "$DEST_ETC/file_magic.rules"
  elif [[ -f "$CANDIDATE_ETC_3/file_magic.rules" ]]; then sudo cp -f "$CANDIDATE_ETC_3/file_magic.rules" "$DEST_ETC/file_magic.rules"
  else echo '# placeholder' | sudo tee "$DEST_ETC/file_magic.rules" >/dev/null; fi
fi

echo "==> Chemins absolus & file_id.rules_file"
sudo sed -i -E "s|dofile\\('snort_defaults.lua'\\)|dofile('/usr/local/etc/snort/snort_defaults.lua')|g" "$DEST_ETC/snort.lua"
sudo sed -i -E "s|dofile\\('file_magic.lua'\\)|dofile('/usr/local/etc/snort/file_magic.lua')|g"       "$DEST_ETC/snort.lua"
if grep -qE '^\s*file_id\.rules_file\s*=' "$DEST_ETC/snort.lua"; then
  sudo sed -i -E "s|(^\s*file_id\.rules_file\s*=).*|\1 '/usr/local/etc/snort/file_magic.rules'|g" "$DEST_ETC/snort.lua"
else
  echo "file_id.rules_file = '/usr/local/etc/snort/file_magic.rules'" | sudo tee -a "$DEST_ETC/snort.lua" >/dev/null
fi

if [[ "${HOME_NET_CIDR:-}" != "" ]]; then
  echo "==> HOME_NET = '$HOME_NET_CIDR'"
  if grep -qE '^\s*HOME_NET\s*=' "$DEST_ETC/snort.lua"; then
    sudo sed -i -E "s|(^\s*HOME_NET\s*=).*|\1 '$HOME_NET_CIDR'|g" "$DEST_ETC/snort.lua"
  else
    echo "HOME_NET = '$HOME_NET_CIDR'" | sudo tee -a "$DEST_ETC/snort.lua" >/dev/null
  fi
fi

echo "==> Corrections local.rules (2.x -> 3.x)"
sudo sed -i 's/\bicmp_type\b/itype/g' "$DEST_RULES/local.rules"
sudo sed -i 's/;[[:space:]]*nocase;*/;/g' "$DEST_RULES/local.rules"
sudo sed -i 's/[[:space:]]*nocase;*$//g' "$DEST_RULES/local.rules"

echo "Règles déployées. Lance Snort (ex):"
echo "sudo /usr/local/snort/bin/snort --daq-dir /usr/local/lib/daq -c /usr/local/etc/snort/snort.lua -i enp0s3 -A alert_json -l /var/log/snort -k none -s 0"
