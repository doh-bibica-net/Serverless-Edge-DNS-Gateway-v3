#!/bin/bash

# Định nghĩa đường dẫn tương đối trong Github Workspace
DIR="rules"
BLOCK_OUT="./$DIR/blocklists.txt"
ALLOW_OUT="./$DIR/allowlists.txt"
BLOCK_TMP="/tmp/blocklists.tmp"
ALLOW_TMP="/tmp/allowlists.tmp"

# Tạo thư mục rules nếu chưa có
mkdir -p "./$DIR"

# Cleanup khi script exit
trap "rm -f $BLOCK_TMP $ALLOW_TMP; exit" INT TERM EXIT

extract_domains() {
  awk '{
    if (/^[[:space:]]*$/ || /^[!#]/) next
    line = tolower($0)
    sub(/^@@\|\|?/, "", line)
    sub(/^\|\|?/, "", line)
    sub(/\^.*/, "", line)
    sub(/[#!].*/, "", line)
    sub(/\/.*/, "", line)
    sub(/:.*/, "", line)
    sub(/^[0-9.]+[[:space:]]+/, "", line)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
    if (line ~ /^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$/ && !seen[line]++) print line
  }'
}

echo "Downloading and processing blocklists..."
{
  # EXTERNAL_BLOCKLIST_START
  curl -fsSL --max-time 60 \
  https://adguardteam.github.io/HostlistsRegistry/assets/filter_16.txt \
  https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt \
  https://raw.githubusercontent.com/bibicadotnet/AdGuard-Home-blocklists/refs/heads/main/byme.txt \
  https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts \
  https://badmojr.github.io/1Hosts/Lite/adblock.txt
  # EXTERNAL_BLOCKLIST_END
  
  # Gộp thêm domain mày gõ tay trên Admin
  if [ -f "rules/custom_blocklists.txt" ]; then
    cat "rules/custom_blocklists.txt"
  fi
} | extract_domains > "$BLOCK_TMP"

echo "Downloading and processing allowlists..."
{
  # EXTERNAL_ALLOWLIST_START
  curl -fsSL --max-time 60 \
  https://raw.githubusercontent.com/bibicadotnet/AdGuard-Home-blocklists/refs/heads/main/whitelist.txt
  # EXTERNAL_ALLOWLIST_END
  
  # Gộp thêm domain mày gõ tay trên Admin
  if [ -f "rules/custom_allowlists.txt" ]; then
    cat "rules/custom_allowlists.txt"
  fi
} | extract_domains > "$ALLOW_TMP"

# Di chuyển file tmp vào thư mục đích
mv "$BLOCK_TMP" "$BLOCK_OUT"
mv "$ALLOW_TMP" "$ALLOW_OUT"

echo "Done. Files saved to $BLOCK_OUT and $ALLOW_OUT"

# Chỉ sinh stats cho các list nặng (quảng cáo)
BLOCK_COUNT=$(wc -l < "$BLOCK_OUT" | tr -d ' ' || echo 0)
ALLOW_COUNT=$(wc -l < "$ALLOW_OUT" | tr -d ' ' || echo 0)

cat <<EOF > database/stats.json
{
  "blocklistSize": ${BLOCK_COUNT:-0},
  "allowlistSize": ${ALLOW_COUNT:-0},
  "_updated": $(date +%s%3N)
}
EOF
