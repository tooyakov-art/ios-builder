# Выбирает симулятор iPhone на раннере: самый новый iOS, по возможности обычный «iPhone N».
# Вход — JSON `xcrun simctl list devices available -j` на stdin; выход — «udid версия-iOS имя».
import json
import re
import sys

best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for device in devices:
        name = device["name"]
        if not name.startswith("iPhone"):
            continue
        plain = 1 if re.fullmatch(r"iPhone \d+", name) else 0
        key = (version, plain, name)
        if best is None or key > best[0]:
            best = (key, device["udid"], "%d.%d" % version, name)

if best is None:
    sys.exit("нет доступного симулятора iPhone")
print(best[1], best[2], best[3])
