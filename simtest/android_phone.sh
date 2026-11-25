#!/usr/bin/env bash
# Поле номера OneTap на Android-эмуляторе (режим emutest) — тот же сценарий, что XCUITest на iPhone.
# Цифры идут через клавиатуру эмулятора (adb input keyevent → клавиатура → поле), что в поле — по дереву
# доступности (uiautomator dump), скрин после каждого шага. «Получить код» — только тестовый +7 700 000 19 19
# и только если в поле ровно он (реальным людям коды не шлём).
# Запуск: android_phone.sh <папка результата> <true|false — нажимать ли «Получить код»>
set -uo pipefail
OUT=$1
SUBMIT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
TEST=7000001919
mkdir -p "$OUT"
RES="$OUT/result-a.txt"
: >"$RES"
fail=0
n=0

log() { echo "SIMTEST[a]: $*"; echo "$*" >>"$RES"; }
dump() {
  local x
  for _ in 1 2 3; do
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    x=$(adb shell cat /sdcard/ui.xml 2>/dev/null)
    case "$x" in *"<node"*) printf '%s' "$x"; return 0 ;; esac
    sleep 0.5
  done
  printf '%s' "$x"
}
field() { dump | python3 "$HERE/ui_find.py" field 2>/dev/null || echo "<нет дерева>"; }
shot() { n=$((n + 1)); adb exec-out screencap -p >"$OUT/$(printf 'a-%02d-%s' "$n" "$1").png"; }
settled() {
  local a b
  a=$(field)
  for _ in 1 2 3; do sleep 0.3; b=$(field); [ "$a" = "$b" ] && break; a=$b; done
  printf '%s' "$a"
}
national() {
  local d
  d=$(printf '%s' "$1" | tr -cd '0-9')
  if [ ${#d} -eq 11 ] && { [ "${d:0:1}" = 7 ] || [ "${d:0:1}" = 8 ]; }; then d=${d:1}; fi
  printf '%s' "$d"
}
type_digits() {
  local step=$1 digits=$2 trace="" i ch
  for ((i = 0; i < ${#digits}; i++)); do
    ch=${digits:i:1}
    adb shell input keyevent "KEYCODE_$ch"
    sleep 0.3
    trace="$trace $ch→'$(settled)'"
  done
  log "$step:$trace"
}
erase() {
  local step=$1 trace="" v
  for _ in $(seq 1 16); do
    v=$(field)
    [ -z "$v" ] && break
    adb shell input keyevent KEYCODE_DEL
    sleep 0.3
    trace="$trace ⌫→'$(settled)'"
  done
  log "$step:$trace"
}
expect_number() {
  local v
  v=$(settled)
  if [ "$(national "$v")" = "$2" ]; then log "ОК $1: в поле '$v'"; return 0; fi
  log "ОШИБКА $1: в поле '$v', ждали +7$2"
  fail=1
  return 1
}
expect_empty() {
  local v
  v=$(settled)
  if [ -z "$v" ]; then log "ОК $1: в поле пусто"; else log "ОШИБКА $1: осталось '$v'"; fail=1; fi
}

adb shell am start -W -n kz.onetap.app/.MainActivity >/dev/null
opened=0
for _ in $(seq 1 90); do
  x=$(dump)
  if printf '%s' "$x" | grep -q 'EditText'; then opened=1; break; fi
  # системное окно эмулятора «… isn't responding» (не наше приложение) — жмём «Wait» и пробуем дальше
  if c=$(printf '%s' "$x" | python3 "$HERE/ui_find.py" tap "Wait" 2>/dev/null); then adb shell input tap $c; sleep 2; continue; fi
  if c=$(printf '%s' "$x" | python3 "$HERE/ui_find.py" tap "Вход" 2>/dev/null); then
    adb shell input tap $c
    sleep 3
  fi
  sleep 2
done
if [ $opened -ne 1 ]; then
  shot no-phone-field
  log "ОШИБКА: поле номера не открылось; на экране: $(dump | python3 "$HERE/ui_find.py" texts 2>/dev/null)"
  exit 1
fi
log "экран входа по номеру открыт; поле: $(dump | python3 "$HERE/ui_find.py" fieldinfo 2>/dev/null); клавиатура: $(adb shell dumpsys input_method | grep -m1 -o "mInputShown=[a-z]*")"
shot empty

type_digits "набор 7011234567" 7011234567
shot typed-7011234567
expect_number "набор 7011234567" 7011234567
erase "стирание после 7011234567"
shot erased
expect_empty "стирание после 7011234567"

type_digits "набор 7771234567" 7771234567
shot typed-7771234567
expect_number "набор 7771234567" 7771234567
erase "стирание после 7771234567"
expect_empty "стирание после 7771234567"

type_digits "набор тестового номера" $TEST
shot typed-test-number
if expect_number "набор тестового номера" $TEST; then exact=1; else exact=0; fi

if [ "$SUBMIT" != true ]; then
  log "«Получить код» не нажимаю: прогон без отправки"
elif [ $exact -ne 1 ]; then
  log "«Получить код» не нажимаю: в поле не тестовый номер — код мог бы уйти чужому"
else
  if c=$(dump | python3 "$HERE/ui_find.py" tap "Получить код" 2>/dev/null); then
    adb shell input tap $c
    log "нажал «Получить код» (тестовый номер +7 700 000 19 19)"
    ok=0
    for _ in $(seq 1 20); do
      sleep 2
      t=$(dump | python3 "$HERE/ui_find.py" texts 2>/dev/null)
      case "$t" in *"Код придёт в Telegram"* | *"Код отправлен в Telegram"* | *"Код из Telegram"* | *"Отправили код"*) ok=1; break ;; esac
    done
    shot code-screen
    if [ $ok -eq 1 ]; then log "ОК экран кода"; else log "ОШИБКА: экран кода не открылся; на экране: $t"; fail=1; fi
  else
    shot no-submit
    log "ОШИБКА: кнопка «Получить код» не найдена"
    fail=1
  fi
fi
exit $fail
