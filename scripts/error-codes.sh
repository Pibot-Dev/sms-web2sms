#!/usr/bin/env bash
# error-codes.sh — Decode web2sms.ro error codes
# Usage: source error-codes.sh; decode_error <code> <message>

decode_error() {
  local CODE="$1"
  local MSG="$2"
  local RETRY="no"
  local DESC=""

  case "$CODE" in
    0)
      DESC="OK — Success"
      ;;
    268435457) # 0x10000001
      DESC="AUTH_REQUIRED — Invalid authentication or account disabled"
      ;;
    268435458) # 0x10000002
      case "$MSG" in
        *NOT_IMPLEMENTED*) DESC="NOT_IMPLEMENTED — Method not supported" ;;
        *INVALID_MSISDN*)  DESC="INVALID_MSISDN — Invalid phone number" ;;
        *)                 DESC="Invalid request (0x10000002)" ;;
      esac
      ;;
    268435459) # 0x10000003
      case "$MSG" in
        *NO_NONCE*)          DESC="Missing nonce parameter" ;;
        *WRONG_NONCE*)       DESC="Invalid nonce value" ;;
        *NO_API_KEY*)        DESC="Missing API key" ;;
        *INVALID*API_KEY*)   DESC="Invalid API key" ;;
        *WRONG_SIGNATURE*)   DESC="Invalid signature" ;;
        *EMPTY_MESSAGE*)     DESC="Empty message body" ;;
        *ID_NOT_PROVIDED*)   DESC="Message ID not provided" ;;
        *WRONG_VALIDITY*)    DESC="Invalid validity parameter" ;;
        *)                   DESC="INVALID_REQUEST_DATA — Check request parameters" ;;
      esac
      ;;
    268435460) # 0x10000004
      DESC="OVERLIMIT — Message limit exceeded. Contact provider."
      ;;
    268435462) # 0x10000006
      DESC="INVALID_ACCOUNT_TYPE — Contact provider."
      ;;
    268435463) # 0x10000007
      case "$MSG" in
        *PREPAID*) DESC="ACCOUNT_PREPAID_DISABLED — Prepaid account disabled" ;;
        *)         DESC="ACCOUNT_DISABLED — Account is closed" ;;
      esac
      ;;
    268435464) # 0x10000008
      DESC="FAILED_CREATE_SMS_SENDER — Contact provider for reconfiguration."
      ;;
    268435465) # 0x10000009
      DESC="REGISTER_SMS — Could not save message to database."
      ;;
    268435466) # 0x1000000A
      DESC="BLACK_LISTED — Recipient number is blacklisted."
      ;;
    268435471) # 0x1000000F
      DESC="OUTSIDE_LIMIT — Message outside configured account limits."
      RETRY="yes"
      ;;
    268435472) # 0x10000010
      DESC="INVALID_PARAMETER — Check request parameters."
      ;;
    268435473) # 0x10000011
      DESC="INVALID_MSGID — Invalid message ID."
      ;;
    268435474) # 0x10000012
      case "$MSG" in
        *POSTPAID*) DESC="POSTPAID_ONLY — Access restricted to postpaid accounts." ;;
        *)          DESC="REQUEST_LIMIT_EXCEEDED — Too many concurrent requests."
                    RETRY="yes" ;;
      esac
      ;;
    268435475) # 0x10000013-14
      DESC="VALIDITY_ERROR — Check schedule/validity parameters."
      ;;
    268435476) # 0x10000015
      DESC="DUPLICATE_ENTRY — Anti-spam filter triggered. Message already sent."
      ;;
    268435520) # 0x10000040
      DESC="NO_VCN_OR_SENDER — Account misconfigured. Contact provider."
      ;;
    268435584) # 0x10000080
      DESC="INTERNAL_ERROR — Contact provider."
      ;;
    268435712) # 0x10000100
      DESC="MESSAGE_NOT_ALLOWED — Message content blocked by operators."
      ;;
    268435968) # 0x10000200
      DESC="OUTSIDE_TIME_LIMIT — Message outside allowed time window."
      RETRY="yes"
      ;;
    1073741825) # 0x40000001
      DESC="MAINTENANCE — System under maintenance."
      RETRY="yes"
      ;;
    *)
      DESC="UNKNOWN_ERROR ($CODE) — $MSG"
      ;;
  esac

  echo "$DESC"
  if [ "$RETRY" = "yes" ]; then
    echo "(retry recommended)"
  fi
}
