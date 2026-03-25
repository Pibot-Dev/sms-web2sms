#!/usr/bin/env bash
# check-balance.sh — Check web2sms.ro prepaid balance
# Usage: check-balance.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/error-codes.sh"

ENV_FILE="$SCRIPT_DIR/../.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

API_KEY="${WEB2SMS_API_KEY:?WEB2SMS_API_KEY not set}"
SECRET="${WEB2SMS_SECRET:?WEB2SMS_SECRET not set}"

NONCE="$(date +%s)"
METHOD="BALANCE"
URL="/prepaid/message"

# Calculate SHA-512 signature
STRING_TO_HASH="${API_KEY}${NONCE}${METHOD}${URL}${SECRET}"
SIGNATURE=$(echo -n "$STRING_TO_HASH" | sha512sum | awk '{print $1}')

PAYLOAD="{\"apiKey\":\"${API_KEY}\",\"nonce\":\"${NONCE}\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X BALANCE "https://www.web2sms.ro/prepaid/message" \
  -u "${API_KEY}:${SIGNATURE}" \
  -H "Content-Type: application/json" \
  -H "Accept-Encoding: gzip, deflate" \
  --compressed \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

ERROR_CODE=$(echo "$BODY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('code',''))" 2>/dev/null || echo "-1")
BALANCE=$(echo "$BODY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('message','unknown'))" 2>/dev/null || echo "parse error")

if [[ "$ERROR_CODE" == "0" ]]; then
  echo "✅ Balance: $BALANCE credits"
  exit 0
else
  ERROR_DESC=$(decode_error "$ERROR_CODE" "$BALANCE")
  echo "❌ Balance check failed (HTTP $HTTP_CODE)"
  echo "Error: $ERROR_DESC"
  exit 1
fi
