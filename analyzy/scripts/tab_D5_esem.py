"""Tabulka D.5 (příloha D): úplné standardizované náboje ESEM, vlna 2024 a ověřovací kohorta 2026.

Generuje se z vystupy/tabulky/07_esem_loadings_2024.csv a 07_esem_loadings_2026.csv (notebook
20_psychometrie.qmd, chunk esem-loadings) a z přiřazení faktorů k principům v 07_cisla.csv
(klíče esem24_factor_map, esem26_factor_map). Vkládá se do kapitoly/cs/appendix-D-supplementary-tables.md
mezi značky <!-- tab-D5 start --> a <!-- tab-D5 end -->. Ručně se nepřepisuje (audit A08, 13. 10. 2026).

Užití (z habilitace-1): python analyzy/scripts/tab_D5_esem.py
"""
import csv
import pathlib
import sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
TAB = ROOT / "vystupy" / "tabulky"
DST = ROOT / "kapitoly" / "cs" / "appendix-D-supplementary-tables.md"
START, END = "<!-- tab-D5 start -->", "<!-- tab-D5 end -->"
ORDER = ["procedural", "equality", "needs", "merit"]
SHORT = {"procedural": "Proc.", "equality": "Rovn.", "needs": "Potř.", "merit": "Zásl."}
GROUP = {"procedural": "Procedurální", "equality": "Rovnost", "needs": "Potřeby", "merit": "Zásluhy"}


def manifest(name):
    with (TAB / name).open(encoding="utf-8") as f:
        return {r["metric"]: r["value"] for r in csv.DictReader(f)}


def factor_map(spec):
    # "F1=needs; F2=procedural; ..." -> {"needs": "F1", ...}
    out = {}
    for part in spec.split(";"):
        f, p = part.strip().split("=")
        out[p.strip()] = f.strip()
    return out


def fmt(v, primary):
    s = f"{float(v):.2f}".replace(".", ",")
    if s == "-0,00":
        s = "0,00"
    return f"**{s}**" if primary else s


m = manifest("07_cisla.csv")
waves = {}
for w, key in (("2024", "esem24_factor_map"), ("2026", "esem26_factor_map")):
    fm = factor_map(m[key])
    with (TAB / f"07_esem_loadings_{w}.csv").open(encoding="utf-8") as f:
        waves[w] = ({r["item"]: r for r in csv.DictReader(f)}, fm)

items = sorted(waves["2024"][0], key=lambda k: (ORDER.index(waves["2024"][0][k]["principle"]), k))
head = "| Položka | " + " | ".join(
    f"{SHORT[p]} {w}" for w in ("2024", "2026") for p in ORDER) + " |"
# relativní šířky sloupců v sazbě: první sloupec širší (položka, mezititulky principů)
sep = "|" + "-" * 14 + "|" + ("-" * 7 + ":|") * 8
lines = [
    "**Tabulka D.5.** Standardizované náboje ESEM (WLSMV, rotace geomin): konfirmační vlna 2024 "
    "(n = 333) a ověřovací kohorta 2026 (n = 164)",
    "",
    head,
    sep,
]
current = None
for it in items:
    pr = waves["2024"][0][it]["principle"]
    if pr != current:
        # mezititulek skupiny položek apriorního principu (samostatný sloupec se v sazbě nevešel)
        lines.append(f"| *{GROUP[pr]}* |" + " |" * 8)
        current = pr
    cells = []
    for w in ("2024", "2026"):
        rows, fm = waves[w]
        for p in ORDER:
            cells.append(fmt(rows[it][fm[p]], p == pr))
    lines.append(f"| {it} | " + " | ".join(cells) + " |")
lines += [
    "",
    "*Poznámka.* Faktory jsou přiřazeny k principům podle Tuckerovy kongruence sloupce nábojů "
    "s apriorním vzorem; položky jsou seskupeny podle apriorního principu a tučně je náboj na faktoru "
    "tohoto principu. "
    "Proc. = procedurální spravedlnost, Rovn. = rovnost, Potř. = potřeby, Zásl. = zásluhy.",
]

raw = DST.read_bytes().decode("utf-8")
nl = "\r\n" if "\r\n" in raw else "\n"
t = raw.replace("\r\n", "\n")
if START not in t or END not in t:
    sys.exit(f"Značky {START} / {END} v {DST.name} chybí.")
a = t.index(START) + len(START)
b = t.index(END)
t = t[:a] + "\n" + "\n".join(lines) + "\n" + t[b:]
DST.write_bytes(t.replace("\n", nl).encode("utf-8"))
print(f"Tabulka D.5: {len(items)} položek zapsáno do {DST.name}")
