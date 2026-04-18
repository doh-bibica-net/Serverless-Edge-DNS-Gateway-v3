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
  if [ -f "database/custom_urls.json" ]; then
    BLOCK_URLS=$(jq -r '.blocklist[]?' database/custom_urls.json | tr '\n' ' ')
    if [ -n "$BLOCK_URLS" ]; then
      curl -fsSL --max-time 60 $BLOCK_URLS
      echo ""
    fi
  fi
  if [ -f "database/custom_domains.json" ]; then
    jq -r '.blocklist[]?' database/custom_domains.json
  fi
} | extract_domains > "$BLOCK_TMP"

echo "Downloading and processing allowlists..."
{
  if [ -f "database/custom_urls.json" ]; then
    ALLOW_URLS=$(jq -r '.allowlist[]?' database/custom_urls.json | tr '\n' ' ')
    if [ -n "$ALLOW_URLS" ]; then
      curl -fsSL --max-time 60 $ALLOW_URLS
      echo ""
    fi
  fi
  if [ -f "database/custom_domains.json" ]; then
    jq -r '.allowlist[]?' database/custom_domains.json
  fi
} | extract_domains > "$ALLOW_TMP"

# Di chuyển file tmp vào thư mục đích
mv "$BLOCK_TMP" "$BLOCK_OUT"
mv "$ALLOW_TMP" "$ALLOW_OUT"

echo "Done. Files saved to $BLOCK_OUT and $ALLOW_OUT"

# Sinh file stats
BLOCK_COUNT=$(wc -l < "$BLOCK_OUT" | tr -d ' ' || echo 0)
ALLOW_COUNT=$(wc -l < "$ALLOW_OUT" | tr -d ' ' || echo 0)

cat <<EOF > database/stats.json
{
  "blocklistSize": ${BLOCK_COUNT:-0},
  "allowlistSize": ${ALLOW_COUNT:-0}
}
EOF
