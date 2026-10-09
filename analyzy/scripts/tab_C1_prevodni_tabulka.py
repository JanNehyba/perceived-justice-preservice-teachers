"""Tabulka C.1 (příloha C): převodní tabulka položek finálního nástroje a dřívějších verzí.

Generuje se z data/processed/item_map_full.csv a vkládá do kapitoly/cs/appendix-C-instrument.md
mezi značky <!-- tab-C1 start --> a <!-- tab-C1 end -->. Ručně se nepřepisuje (B6-224, revize
8. 10. 2026). Čísla položek dřívějších verzí jsou čísla v daném dotazníku; znění všech verzí je
v souboru item_map_full.csv v doprovodném repozitáři.

Užití (z habilitace-1): python analyzy/scripts/tab_C1_prevodni_tabulka.py
"""
import csv
import pathlib
import sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "data" / "processed" / "item_map_full.csv"
DST = ROOT / "kapitoly" / "cs" / "appendix-C-instrument.md"
START, END = "<!-- tab-C1 start -->", "<!-- tab-C1 end -->"


def num(v):
    v = (v or "").strip()
    if not v or v.lower() == "nan":
        return "–"
    try:
        return str(int(float(v)))
    except ValueError:
        return v


def mark(idv, match):
    n = num(idv)
    if n == "–":
        return n
    return n + ("*" if (match or "").startswith("confirmed-author") else "")


rows = list(csv.DictReader(SRC.open(encoding="utf-8")))
lines = [
    "**Tabulka C.1.** Převodní tabulka položek finálního nástroje (verze 5, 2023–2026) a dřívějších verzí.",
    "",
    "| Č. | Princip | Verze 4 (2022) | Verze 3 (2021) | Pilotní 2 (2020) | Pilotní 1 (2019) |",
    "|----:|------------------|--------------|----------|----------|----------|",
]
for r in rows:
    v22 = {"exact": "shodná", "old-wording": "jiné znění"}.get(r["match_2022"].strip(), r["match_2022"].strip() or "–")
    lines.append(f"| {num(r['item_id_final'])} | {r['principle'].strip()} | {v22} | {num(r['pool2021_id'])} | "
                 f"{mark(r['id_2020B'], r['match_2020B'])} | {mark(r['id_2019A'], r['match_2019A'])} |")
lines += [
    "",
    "*Poznámka.* Č. = číslo finální položky. Verze 4: „shodná“ = stejné znění jako ve finální verzi. Verze 3 a pilotní verze: číslo položky v daném dotazníku (u verze 3 v zásobníku 36 položek). „–“ = položka nemá v dané verzi protějšek. Hvězdička = párování, které bylo podle textové "
    "podobnosti nejisté a autor je posoudil jako tutéž položku v odlišném rámci (dvě z nich se obsahově "
    "posunuly, viz [oddíl 8.4](#sec-8-4)). Ostatní párování mají vysokou textovou podobnost. "
    "*Zdroj:* vlastní zpracování; znění všech verzí v doprovodném repozitáři (Nehyba, 2026b; "
    "[převodní tabulka položek](https://github.com/JanNehyba/perceived-justice-preservice-teachers/blob/main/data/processed/item_map_full.csv)).",
]
block = START + "\n" + "\n".join(lines) + "\n" + END

raw = DST.read_bytes().decode("utf-8")
nl = "\r\n" if "\r\n" in raw else "\n"
t = raw.replace("\r\n", "\n")
if START in t:
    s, e = t.index(START), t.index(END) + len(END)
    t = t[:s] + block + t[e:]
else:
    raise SystemExit(f"V {DST.name} chybí značka {START}")
DST.write_bytes(t.replace("\n", nl).encode("utf-8"))
print(f"Tabulka C.1: {len(rows)} položek zapsáno do {DST.name}")
