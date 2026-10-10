#!/usr/bin/env python3
"""Spočítá vyplněné volné poznámky („Jakákoliv poznámka:") v PŮVODNÍCH exportech formulářů.

Připomínka B6-245 (rozhodnutí Jana 10. 10. 2026): pole s poznámkou bylo při anonymizaci odstraněno,
v datech repozitáře proto není. Skript je určen ke spuštění jen u autora nad offline zálohou původních
exportů (CSV nebo XLSX z Google Forms). Vypíše pouze počty a délky, nikdy text poznámek ani jiné údaje.

Užití:  python analyzy/scripts/pocet_poznamek.py <soubor.csv|soubor.xlsx> [další soubory …]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import pandas as pd

VZOR = re.compile(r"jakákoliv\s+poznámka|poznámk|komentář", re.IGNORECASE)
PRAZDNE = re.compile(r"[-–.\s0]*")


def nacti(cesta: Path) -> pd.DataFrame:
    if cesta.suffix.lower() in (".xlsx", ".xls"):
        return pd.read_excel(cesta, dtype=str)
    return pd.read_csv(cesta, dtype=str)


def main(argv: list[str]) -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except AttributeError:
        pass
    if not argv:
        print(__doc__)
        return 1
    for arg in argv:
        cesta = Path(arg)
        d = nacti(cesta)
        sloupce = [c for c in d.columns if VZOR.search(str(c))]
        if not sloupce:
            print(f"{cesta.name} (n = {len(d)}): pole poznámky nenalezeno")
            continue
        for c in sloupce:
            s = d[c].fillna("").astype(str).str.strip()
            s = s[(s != "") & (~s.apply(lambda x: bool(PRAZDNE.fullmatch(x))))]
            delky = s.str.len()
            median = int(delky.median()) if len(s) else 0
            nad100 = int((delky > 100).sum())
            print(f"{cesta.name} (n = {len(d)}): {len(s)} vyplněných poznámek, medián délky {median} znaků, "
                  f"{nad100} delších než 100 znaků")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
