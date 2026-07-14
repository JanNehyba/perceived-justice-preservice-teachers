#!/usr/bin/env python3
"""V0 gate: ověření provenience a integrity ROZŠÍŘENÝCH vinětových dat před přepočtem
Studie 1. Porovná nový export (vinety_vesnice_2019_v2.xlsx) se starým n=146 souborem.
JEN ČTENÍ. Nic nemění. Cíl: potvrdit, že jde o reálné rozšíření, ne syntetickou imitaci
(viz paměť hab1-vinety-146-realna-vs-synteticke).

Užití:  python3 analyzy/scripts/check_vinety_v2.py
"""
from __future__ import annotations
import sys
from pathlib import Path

try:
    import pandas as pd
except ImportError:
    sys.exit("pandas není dostupné — spusť ve .venv projektu.")

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "data" / "raw"
OLD = RAW / "vinety_vesnice_2019.xlsx"          # původní n=146 (referenční)
NEW = RAW / "vinety_vesnice_2019_v2.xlsx"       # rozšířený export od Jana

PRINC_COLS = ["Modrá-rovnost", "Bílá-náhoda", "Zelená-potřeby",
              "Oranžová-zásluhy", "Červená-rovné příležitosti",
              "Žlutá-kasty,sociální skupiny"]
SUMMARY = {"Medián", "Průměr", "Median", "Prumer"}


def load(path: Path):
    raw = pd.read_excel(path, sheet_name=0, header=0, engine="openpyxl")
    label = raw.columns[0]
    resp = raw[~raw[label].astype(str).str.strip().isin(SUMMARY)].copy()
    # zahodit úplně prázdné řádky přes principy (pokud sloupce existují)
    cols = [c for c in PRINC_COLS if c in resp.columns]
    if cols:
        resp = resp.dropna(how="all", subset=cols)
    return raw, resp, cols


def main() -> int:
    if not NEW.exists():
        print(f"⏳ Rozšířený soubor zatím není: {NEW}")
        print("   → Jan: v Numbers Soubor → Exportovat → Excel → ulož SEM pod tímto názvem.")
        return 2
    old_raw, old, ocols = load(OLD)
    new_raw, new, ncols = load(NEW)

    print("=== ROZSAH ===")
    print(f"starý n = {len(old)} | nový n = {len(new)}  (Δ = {len(new) - len(old):+d})")
    print(f"sloupce nové: {list(new_raw.columns)}")
    miss = [c for c in PRINC_COLS if c not in new_raw.columns]
    if miss:
        print(f"⚠️  chybí očekávané principové sloupce: {miss} — export má jiné hlavičky, uprav mapování v 02_prepare_vignettes.py")

    print("\n=== HODNOTY 1–7 / CHYBĚJÍCÍ ===")
    ok_range = True
    for c in ncols:
        v = pd.to_numeric(new[c], errors="coerce")
        nmiss = int(v.isna().sum())
        lo, hi = v.min(), v.max()
        flag = "" if (lo >= 1 and hi <= 7 and nmiss == 0) else "  ⚠️"
        if flag:
            ok_range = False
        print(f"  {c:32s} min={lo} max={hi} chybí={nmiss}{flag}")

    print("\n=== PRŮMĚRY per princip (nový vs starý) ===")
    for c in ncols:
        nm = pd.to_numeric(new[c], errors="coerce").mean()
        om = pd.to_numeric(old[c], errors="coerce").mean() if c in ocols else float("nan")
        print(f"  {c:32s} nový={nm:.4f}  starý={om:.4f}  Δ={nm - om:+.4f}")

    print("\n=== SHODA PRVNÍCH 146 ŘÁDKŮ (rozšíření vs přepis) ===")
    if len(new) >= len(old) and ocols == ncols:
        a = old[ocols].reset_index(drop=True)
        b = new[ncols].iloc[:len(old)].reset_index(drop=True)
        same = a.equals(b)
        if same:
            print(f"  ✅ prvních {len(old)} řádků IDENTICKÝCH → jde o rozšíření (přidané řádky).")
        else:
            ndiff = int((a.ne(b)).any(axis=1).sum())
            print(f"  ⚠️  prvních {len(old)} řádků SE LIŠÍ v {ndiff} řádcích → NENÍ prosté přidání;")
            print("      ověř s Janem (mohl přeuspořádat/přepsat, nebo jde o jiný soubor).")
    else:
        print("  (nelze srovnat po řádcích — jiný počet sloupců nebo menší n)")

    print("\n=== ARTEFAKTY (podezření na imputaci/syntetiku) ===")
    # a) duplicitní kompletní řádky přes principy
    dup = int(new[ncols].duplicated().sum())
    print(f"  duplicitní vzorce odpovědí (přes 6 principů): {dup}"
          + ("  ⚠️ hodně duplicit může značit generovaná data" if dup > len(new) * 0.15 else ""))
    # b) neceločíselné hodnoty (papírová viněta = celá čísla 1–7)
    nonint = 0
    for c in ncols:
        v = pd.to_numeric(new[c], errors="coerce").dropna()
        nonint += int((v != v.round()).sum())
    print(f"  neceločíselné hodnoty: {nonint}"
          + ("  ⚠️ papírový sběr má být celočíselný" if nonint else "  (ok, celočíselné)"))

    print("\n=== VERDIKT ===")
    if not ok_range or miss:
        print("  ❌ data mají problém (rozsah/sloupce) — NEPŘEPOČÍTÁVAT, viz výše.")
        return 1
    print("  ✅ rozsah i sloupce OK. Zkontroluj Δn, shodu prvních řádků a artefakty výše,")
    print("     potvrď s Janem 'reálně sebraní' → teprve pak V1 (přepočet).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
