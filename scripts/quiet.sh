#!/usr/bin/env bash
# Тихий запуск шага: весь вывод команды — в файл, в публичный лог только «ok / упал».
# Зачем: репозиторий публичный, логи видят все — в них не должно быть исходников, путей и списков зависимостей.
# Использование: scripts/quiet.sh <метка-латиницей> <команда> [аргументы...]
set -uo pipefail
label="$1"; shift
dir="${RUNNER_TEMP:?}/logs"
mkdir -p "$dir"
n=$(find "$dir" -type f | wc -l | tr -d ' ')
log="$dir/$(printf '%02d' "$n")-${label}.log"
start=$(date +%s)
"$@" >"$log" 2>&1
code=$?
dur=$(( $(date +%s) - start ))
if [ "$code" -eq 0 ]; then
  echo "ok: ${label} (${dur}s)"
else
  # идея: причину смотрим локально — лог шифруется сертификатом logs-recipient.pem (шаг «Зашифровать логи»)
  echo "::error title=${label}::шаг упал (код ${code}, ${dur}s). Полный лог — в зашифрованном артефакте logs-encrypted"
  # 25.11: ключа к шифрованному логу на сервере нет — в публичный лог только строки ошибок,
  # без исходников и путей приложения (lib/, test/, .dart) и без слов про пароли/ключи
  grep -E -i "error|failed|exception|provision|signing|certificate|unable to|not found|no such|requires|invalid" "$log" \
    | grep -v -E -i "\.dart|/lib/|/test/|password|passwd|token|secret|private|BEGIN " \
    | tail -n 25 | cut -c1-300 | sed 's/^/  │ /' || true
fi
exit "$code"
