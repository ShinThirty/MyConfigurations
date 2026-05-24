#!/usr/bin/env bash
set -euo pipefail

LOCAL_DB="$HOME/.local/share/keepass/shinthirty.kdbx"
SMB_DB="/Volumes/tp-share/Password/shinthirty.kdbx"
BACKUP_DIR="$HOME/.local/share/keepass/backups"

[[ -f "$SMB_DB" ]] || { echo "SMB not mounted at /Volumes/tp-share" >&2; exit 1; }

if [[ ! -f "$LOCAL_DB" ]]; then
  echo "Local DB missing — seeding from SMB..."
  mkdir -p "$(dirname "$LOCAL_DB")"
  cp "$SMB_DB" "$LOCAL_DB"
  echo "Initialized $LOCAL_DB"
  exit 0
fi

mkdir -p "$BACKUP_DIR"
ts=$(date +%Y%m%d-%H%M%S)
cp "$SMB_DB"   "$BACKUP_DIR/smb-$ts.kdbx"
cp "$LOCAL_DB" "$BACKUP_DIR/local-$ts.kdbx"

read -rsp "Master password: " PASS; echo

# Pull: merge SMB into local (local picks up Linux/iPhone changes)
printf '%s' "$PASS" | keepassxc-cli merge --same-credentials "$LOCAL_DB" "$SMB_DB"

# Push: merge local into SMB (SMB picks up Mac offline edits)
printf '%s' "$PASS" | keepassxc-cli merge --same-credentials "$SMB_DB" "$LOCAL_DB"

unset PASS

echo "Sync complete."
