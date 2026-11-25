# Разбор `uiautomator dump` (Android) для emutest. Читает XML со stdin.
#   ui_find.py tap <текст>   — «x y» центра первого узла, чей text/content-desc равен тексту (или начинается с него)
#   ui_find.py field         — текст первого поля ввода (EditText); пустое поле — пустая строка
#   ui_find.py texts         — все непустые text/content-desc через « | »
import re
import sys
import xml.etree.ElementTree as ET

mode = sys.argv[1]
arg = sys.argv[2] if len(sys.argv) > 2 else ""
raw = sys.stdin.read()
start = raw.find("<?xml")
root = ET.fromstring(raw[start:] if start >= 0 else raw)
nodes = list(root.iter("node"))


def center(node):
    m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
    if not m:
        return None
    x1, y1, x2, y2 = map(int, m.groups())
    return (x1 + x2) // 2, (y1 + y2) // 2


def labels(node):
    return [s.strip() for s in (node.get("text", ""), node.get("content-desc", "")) if s and s.strip()]


if mode == "tap":
    for exact in (True, False):
        for node in nodes:
            for label in labels(node):
                if (label == arg) if exact else label.startswith(arg):
                    c = center(node)
                    if c:
                        print(c[0], c[1])
                        sys.exit(0)
    sys.exit(1)
elif mode in ("field", "fieldinfo"):
    # текст поля как есть (подсказку не вычитаем: набранное «701 123 45 67» совпадает с подсказкой 0.2.1)
    for node in nodes:
        if node.get("class", "").endswith("EditText"):
            text = node.get("text", "")
            if mode == "field":
                print(text)
            else:
                print("text='%s' hint='%s' focused=%s" % (text, node.get("hint", ""), node.get("focused", "")))
            sys.exit(0)
    print("<нет поля>")
elif mode == "texts":
    out = []
    for node in nodes:
        out += labels(node)
    print(" | ".join(out)[:1500])
