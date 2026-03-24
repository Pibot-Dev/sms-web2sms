---
name: sms-web2sms
description: Send SMS messages and check delivery status via web2sms.ro, a Romanian SMS gateway. Use when the user asks to send an SMS, text message, or notify someone by phone number. Requires a web2sms.ro prepaid account with WEB2SMS_API_KEY and WEB2SMS_SECRET environment variables.
---

# SMS — web2sms.ro

Romanian SMS gateway integration using the [web2sms.ro REST API](https://www.web2sms.ro/documentatie-api-sms/).

## Required credentials

| Variable | Description |
|----------|-------------|
| `WEB2SMS_API_KEY` | API key from web2sms.ro dashboard |
| `WEB2SMS_SECRET` | API secret from web2sms.ro dashboard |
| `WEB2SMS_SENDER` | *(optional)* Custom sender ID |

Configure in OpenClaw:

```json5
{
  skills: {
    entries: {
      "sms-web2sms": {
        enabled: true,
        env: {
          WEB2SMS_API_KEY: "<your-api-key>",
          WEB2SMS_SECRET: "<your-secret>"
        }
      }
    }
  }
}
```

## Functions

### Send SMS

```bash
bash scripts/send-sms.sh "<phone>" "<message>"
```

- `phone` — recipient number, Romanian format: `0722XXXXXX` or `+40722XXXXXX`
- `message` — SMS body text
- Returns message ID on success (HTTP 201)
- Auth: SHA-512 HMAC signature per request
- Dependencies: `curl`, `python3`, `sha512sum`

### Check delivery status

```bash
bash scripts/check-status.sh "<message_id>"
```

- `message_id` — ID returned by send-sms.sh
- Status codes: `0` pending, `1` sent, `2` delivered, `3` failed
- Uses web2sms.ro SOAP API

## Disclaimer

This skill is not affiliated with [web2sms.ro](https://www.web2sms.ro). SMS costs are billed to your prepaid account. Always obtain explicit user permission before sending. Do not use for spam or bulk messaging. Comply with Romanian telecom regulations (ANCOM) and GDPR.
