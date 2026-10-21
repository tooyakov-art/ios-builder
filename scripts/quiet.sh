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
fi
exit "$code"
