#!/usr/bin/env bash
# Шифрует логи сборки открытым сертификатом logs-recipient.pem.
# Расшифровать может только владелец закрытого ключа (лежит локально, не в GitHub).
set -euo pipefail
cd "${RUNNER_TEMP:?}"
[ -d logs ] || { echo "логов нет"; exit 0; }
tar czf logs.tgz logs
OPENSSL=/opt/homebrew/opt/openssl@3/bin/openssl
[ -x "$OPENSSL" ] || OPENSSL=/usr/local/opt/openssl@3/bin/openssl
if [ -x "$OPENSSL" ]; then
  "$OPENSSL" cms -encrypt -aes256 -binary -outform DER -in logs.tgz -out logs.tgz.p7m "$GITHUB_WORKSPACE/logs-recipient.pem"
else
  # запасной путь: системный LibreSSL умеет smime (тот же формат CMS/PKCS#7)
  openssl smime -encrypt -aes256 -binary -outform DER -in logs.tgz -out logs.tgz.p7m "$GITHUB_WORKSPACE/logs-recipient.pem"
fi
rm -f logs.tgz
echo "зашифровано: $(wc -c < logs.tgz.p7m | tr -d ' ') байт"
