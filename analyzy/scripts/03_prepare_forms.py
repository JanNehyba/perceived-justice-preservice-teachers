#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
03_prepare_forms.py — Zpracování Google Forms exportů 2020–2026 (proud #1).

Vstup: zdrojove-texty/Dotazník k 1. hodině Sebezkušenosti <ROK>[ FINAL].csv.zip
       (2020, 2021, 2022, 2023, 2024, 2026; soubor 2020komb je vyřazen — pokyn autora)

Kroky:
  1. ANONYMIZACE: drop `Uživatelské jméno` (e-mail) a `Jakákoliv poznámka` (volný text);
     timestamp zkrácen na datum; přidán `resp_id` (w<rok>_NNN) a `wave`.
     → data/raw/forms_<rok>_anonymized.csv  (anonymizované "raw" této pipeline)
  2. KŘÍŽOVÁ KONTROLA: justice položky forms_2023+2024 == známý justice_2324.csv
     (multiset shody 26-tic). Při neshodě skript SELŽE.
  3. FINÁLNÍ DATASET: data/processed/justice_final.csv — n=744 (2023+2024+2026),
     sloupce: resp_id, wave, datum, pohlavi, rok_narozeni, obor1, obor2, zkusenost,
     item_01..item_26 (finální instrument, spravedlnostní škála 1–7).
  4. BIDR: data/processed/bidr_2023_2026.csv (19 položek, bidr_01..bidr_19 + resp_id)
     + codebook_bidr.csv (znění). (2022 má 20položkovou variantu — zůstává jen ve forms_2022.)
  5. PER-VLNA soubory pro E4: justice_2020_clean.csv (23 normativních položek, b01..b23),
     justice_2021_pool36.csv (36 položek, pool_01..pool_36, n=433 raw),
     justice_2022_clean.csv (26 položek mapovaných na finální číslování dle znění;
     item_16 = PŮVODNÍ REVERZNÍ znění — NEREKÓDOVÁNO, jen zdokumentováno).
  6. item_map_full.csv — rozšířená mapa: finální znění × {2022, pool2021, 2020-normativní (B),
     2019-popisná (A)}; automatické párování dle normalizovaného znění / token-overlap
     s příznakem jistoty (exact / high / REVIEW).

Zásady: originální zipy se nemění; data/raw obsahuje už jen anonymizované verze;
žádné statistické analýzy.
"""

from pathlib import Path
import re
import unicodedata
import pandas as pd
import numpy as np

SCRIPT = Path(__file__).resolve()
H1 = SCRIPT.parents[2]
ZT = H1 / "zdrojove-texty"
RAW = H1 / "data" / "raw"
OUT = H1 / "data" / "processed"
OUT.mkdir(parents=True, exist_ok=True)

FILES = {
    2020: "Dotazník k 1. hodině Sebezkušenosti 2020.csv.zip",
    2021: "Dotazník k 1. hodině Sebezkušenosti 2021.csv.zip",
    2022: "Dotazník k 1. hodině Sebezkušenosti 2022 FINAL.csv.zip",
    2023: "Dotazník k 1. hodině Sebezkušenosti 2023 FINAL.csv.zip",
    2024: "Dotazník k 1. hodině Sebezkušenosti 2024 FINAL.csv.zip",
    2026: "Dotazník k 1. hodině Sebezkušenosti 2026.csv.zip",
}
# pozice justice bloků (ověřeno proti hlavičkám 10. 7. 2026)
JUSTICE_SLICE = {2020: (6, 29), 2021: (6, 42), 2022: (5, 31),
                 2023: (6, 32), 2024: (6, 32), 2026: (6, 32)}
BIDR_SLICE = {2022: (31, 51), 2023: (32, 51), 2024: (32, 51), 2026: (32, 51)}
FINAL_WAVES = [2023, 2024, 2026]

PII_COLS = ["Uživatelské jméno", "Jméno a příjmení", "Jakákoliv poznámka:"]
DEMOG = {
    "Jaký obor studujete - váš 1. obor?": "obor1",
    "Jaký obor studujete - váš 2. obor? (nepovinná otázka)": "obor2",
    "Pohlaví": "pohlavi",
    "Rok narození:": "rok_narozeni",
}


def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", str(s)).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


def token_sim(a: str, b: str) -> float:
    """Jaccard podobnost obsahových tokenů (bez krátkých stop-slov)."""
    stop = {"by", "mel", "mela", "nemel", "ucitel", "zaku", "zakum", "zakovi", "zak",
            "se", "si", "na", "v", "ve", "s", "z", "k", "o", "a", "i", "pro", "pri",
            "do", "je", "ma", "jak", "jsou", "aby", "tak", "ktery", "ktera", "kteri"}
    ta = {t for t in norm(a).split() if t not in stop and len(t) > 2}
    tb = {t for t in norm(b).split() if t not in stop and len(t) > 2}
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / len(ta | tb)


# ---------------------------------------------------------------- 1) načtení + anonymizace
def load_wave(year: int) -> pd.DataFrame:
    df = pd.read_csv(ZT / FILES[year], encoding="utf-8-sig")
    df = df.loc[:, ~df.columns.str.startswith("Unnamed")]          # trailing prázdný sloupec (2023)
    return df


anon = {}
for year in FILES:
    df = load_wave(year)
    n0 = len(df)
    dropped = [c for c in PII_COLS if c in df.columns]
    df = df.drop(columns=dropped)
    # timestamp -> jen datum
    ts = pd.to_datetime(df["Časová značka"].str.replace(" GMT+2", "", regex=False)
                        .str.replace("dop.", "AM", regex=False).str.replace("odp.", "PM", regex=False),
                        format="%Y/%m/%d %I:%M:%S %p", errors="coerce")
    df.insert(0, "datum", ts.dt.date.astype(str))
    df = df.drop(columns=["Časová značka"])
    df.insert(0, "wave", year)
    df.insert(0, "resp_id", [f"w{year}_{i+1:03d}" for i in range(len(df))])
    # experience checkbox -> binární
    exp_col = [c for c in df.columns if c.startswith("Zaškrtněte")]
    if exp_col:
        df = df.rename(columns={exp_col[0]: "zkusenost_raw"})
        df["zkusenost"] = df["zkusenost_raw"].notna() & (df["zkusenost_raw"].astype(str).str.strip() != "")
        df = df.drop(columns=["zkusenost_raw"])
    df = df.rename(columns=DEMOG)
    out = RAW / f"forms_{year}_anonymized.csv"
    df.to_csv(out, index=False, encoding="utf-8")
    anon[year] = df
    print(f"forms_{year}_anonymized.csv : n={len(df)} (načteno {n0}), odstraněno PII: {dropped}")

META = ["resp_id", "wave", "datum", "pohlavi", "rok_narozeni", "obor1", "obor2", "zkusenost"]


def justice_block(year: int) -> pd.DataFrame:
    """Vrátí justice položky vlny s PŮVODNÍMI zněními jako názvy sloupců."""
    df = load_wave(year)                      # z originálu kvůli stabilním pozicím
    df = df.loc[:, ~df.columns.str.startswith("Unnamed")]
    a, b = JUSTICE_SLICE[year]
    return df.iloc[:, a:b]


# ---------------------------------------------------------------- 2) křížová kontrola vs justice_2324
def multiset(df: pd.DataFrame):
    from collections import Counter
    return Counter(map(tuple, df.astype(float).round(3).values))

old = pd.read_csv(RAW / "justice_2324.csv", sep=";", encoding="utf-8-sig")
new_2324 = pd.concat([justice_block(2023), justice_block(2024)], ignore_index=True)
assert new_2324.shape == (580, 26), f"nečekaný tvar forms 2023+2024: {new_2324.shape}"
ms_old, ms_new = multiset(old), multiset(new_2324)
if ms_old != ms_new:
    only_old = sum((ms_old - ms_new).values())
    only_new = sum((ms_new - ms_old).values())
    raise SystemExit(f"KŘÍŽOVÁ KONTROLA SELHALA: {only_old} řádků jen ve starém, {only_new} jen v novém.")
print("Křížová kontrola OK: forms 2023+2024 == justice_2324 (580 řádků, multiset shoda).")

# ---------------------------------------------------------------- 3) finální dataset n=744
codebook = pd.read_csv(OUT / "codebook.csv")
final_wording = {norm(r.cz_wording): int(r.item_id) for r in codebook.itertuples()}

def to_final_items(year: int) -> pd.DataFrame:
    jb = justice_block(year)
    cols = {}
    for c in jb.columns:
        iid = final_wording.get(norm(c))
        assert iid is not None, f"{year}: nespárované znění: {c[:60]}"
        cols[c] = f"item_{iid:02d}"
    out = jb.rename(columns=cols)
    return out[[f"item_{i:02d}" for i in range(1, 27)]]

parts = []
for year in FINAL_WAVES:
    items = to_final_items(year).reset_index(drop=True)
    meta = anon[year][[c for c in META if c in anon[year].columns]].reset_index(drop=True)
    parts.append(pd.concat([meta, items], axis=1))
final = pd.concat(parts, ignore_index=True)
final.to_csv(OUT / "justice_final.csv", index=False, encoding="utf-8")

dup_mask = final[[f"item_{i:02d}" for i in range(1, 27)]].duplicated(keep=False)
print(f"justice_final.csv : {final.shape}, vlny: {final['wave'].value_counts().to_dict()}, "
      f"duplicitní vzorce odpovědí: {int(dup_mask.sum())} řádků "
      f"(řešení: ponechány, dohledatelné přes resp_id)")

# ---------------------------------------------------------------- 4) BIDR
bidr_parts, bidr_wordings = [], None
for year in FINAL_WAVES:
    df = load_wave(year)
    df = df.loc[:, ~df.columns.str.startswith("Unnamed")]
    a, b = BIDR_SLICE[year]
    blk = df.iloc[:, a:b]
    w = [c.strip() for c in blk.columns]
    if bidr_wordings is None:
        bidr_wordings = w
    assert w == bidr_wordings, f"BIDR znění se liší ve vlně {year}"
    blk.columns = [f"bidr_{i:02d}" for i in range(1, len(w) + 1)]
    blk.insert(0, "resp_id", anon[year]["resp_id"].values)
    blk.insert(1, "wave", year)
    bidr_parts.append(blk)
bidr = pd.concat(bidr_parts, ignore_index=True)
bidr.to_csv(OUT / "bidr_2023_2026.csv", index=False, encoding="utf-8")
pd.DataFrame({"var": [f"bidr_{i:02d}" for i in range(1, len(bidr_wordings) + 1)],
              "cz_wording": bidr_wordings}).to_csv(OUT / "codebook_bidr.csv", index=False, encoding="utf-8")
print(f"bidr_2023_2026.csv : {bidr.shape} ({len(bidr_wordings)} položek; 2022 varianta s 20 pol. jen ve forms_2022)")

# ---------------------------------------------------------------- 5) per-vlna soubory pro E4
# 2022 → finální číslování dle znění; 2 položky mapovány přes staré znění (item_map)
imap = pd.read_csv(OUT / "item_map.csv")
old_wording_to_final = {norm(r.cz_wording_2021pool): int(r.item_id_2324)
                        for r in imap.itertuples() if isinstance(r.cz_wording_2021pool, str)}
jb22 = justice_block(2022)
cols22, flags22 = {}, []
for c in jb22.columns:
    iid = final_wording.get(norm(c)) or old_wording_to_final.get(norm(c))
    assert iid is not None, f"2022: nespárované znění: {c[:60]}"
    cols22[c] = f"item_{iid:02d}"
    if final_wording.get(norm(c)) is None:
        flags22.append((iid, c))
j22 = jb22.rename(columns=cols22)[[f"item_{i:02d}" for i in range(1, 27)]]
j22.insert(0, "resp_id", anon[2022]["resp_id"].values)
j22.to_csv(OUT / "justice_2022_clean.csv", index=False, encoding="utf-8")
print(f"justice_2022_clean.csv : {j22.shape}; položky se STARÝM zněním (nerekódováno!): "
      f"{[(i, w[:45]) for i, w in flags22]}")

# 2021 pool36 (raw 433)
jb21 = justice_block(2021)
j21 = jb21.copy()
j21.columns = [f"pool_{i:02d}" for i in range(1, 37)]
j21.insert(0, "resp_id", anon[2021]["resp_id"].values)
j21.to_csv(OUT / "justice_2021_pool36.csv", index=False, encoding="utf-8")
print(f"justice_2021_pool36.csv : {j21.shape} (raw Forms; publikovaná očištěná verze = justice_2021_clean.csv, n=346)")

# 2020 normativní (styl B)
jb20 = justice_block(2020)
w2020 = [c.strip() for c in jb20.columns]
j20 = jb20.copy()
j20.columns = [f"b{i:02d}" for i in range(1, 24)]
j20.insert(0, "resp_id", anon[2020]["resp_id"].values)
j20.to_csv(OUT / "justice_2020_clean.csv", index=False, encoding="utf-8")
print(f"justice_2020_clean.csv : {j20.shape} (normativní 3. os., vlastní kódy b01–b23)")

# ---------------------------------------------------------------- 6) item_map_full
# 2019 znění (styl A) z master XLSX
import openpyxl
wb = openpyxl.load_workbook(RAW / "Spravedlnost_2019-2023.xlsx", read_only=True, data_only=True)
ws = wb["Spravedlnost 2019"]
w2019 = []
for row in ws.iter_rows(values_only=True):
    if len(row) < 4:
        continue
    try:
        iid = int(float(row[0]))
    except (TypeError, ValueError):
        continue
    if 1 <= iid <= 30 and row[3]:
        w2019.append((iid, str(row[1]).strip(), str(row[3]).strip()))
wb.close()
w2019 = w2019[:21]

def best_match(wording, threshold_hi=0.5, threshold_lo=0.3):
    """Najde nejlepší finální položku dle token-similarity; vrací (id, sim, flag)."""
    sims = [(int(r.item_id), token_sim(wording, r.cz_wording)) for r in codebook.itertuples()]
    iid, s = max(sims, key=lambda x: x[1])
    if s >= threshold_hi:
        return iid, s, "high"
    if s >= threshold_lo:
        return iid, s, "REVIEW"
    return None, s, "none"

rows = []
for r in codebook.itertuples():
    rows.append({
        "item_id_final": int(r.item_id), "principle": r.principle_cz,
        "cz_wording_final_2023_2026": r.cz_wording,
        "cz_wording_2022": None, "match_2022": None,
        "pool2021_id": r.pool2021_code,
        "id_2020B": None, "cz_wording_2020B": None, "match_2020B": None,
        "id_2019A": None, "cz_wording_2019A": None, "match_2019A": None,
    })
bymap = {row["item_id_final"]: row for row in rows}

# 2022 sloupec
for c in jb22.columns:
    iid = final_wording.get(norm(c)) or old_wording_to_final.get(norm(c))
    bymap[iid]["cz_wording_2022"] = c.strip()
    bymap[iid]["match_2022"] = "exact" if final_wording.get(norm(c)) else "old-wording"

# 2020 (styl B) — automatické párování s příznaky
unmatched_2020 = []
for i, w in enumerate(w2020, start=1):
    iid, s, flag = best_match(w)
    if iid is not None and (bymap[iid]["id_2020B"] is None or flag == "high"):
        bymap[iid].update({"id_2020B": i, "cz_wording_2020B": w, "match_2020B": f"{flag}({s:.2f})"})
    else:
        unmatched_2020.append((i, w))

# 2019 (styl A)
unmatched_2019 = []
for iid19, prin19, w in w2019:
    iid, s, flag = best_match(w)
    if iid is not None and (bymap[iid]["id_2019A"] is None or flag == "high"):
        bymap[iid].update({"id_2019A": iid19, "cz_wording_2019A": w, "match_2019A": f"{flag}({s:.2f})"})
    else:
        unmatched_2019.append((iid19, w))

imf = pd.DataFrame(rows)
imf.to_csv(OUT / "item_map_full.csv", index=False, encoding="utf-8")
n_rev = int(imf["match_2020B"].astype(str).str.contains("REVIEW").sum()
            + imf["match_2019A"].astype(str).str.contains("REVIEW").sum())
print(f"item_map_full.csv : {len(imf)} finálních položek; REVIEW párování: {n_rev}; "
      f"2020 bez páru ve finálním setu: {len(unmatched_2020)}; 2019 bez páru: {len(unmatched_2019)}")
for i, w in unmatched_2020:
    print(f"   2020-B b{i:02d} bez finálního protějšku: {w[:80]}")
for i, w in unmatched_2019:
    print(f"   2019-A #{i:02d} bez finálního protějšku: {w[:80]}")

# ---------------------------------------------------------------- souhrn
print("\n=== 03_prepare_forms.py — hotovo ===")
for year in FILES:
    print(f"  vlna {year}: n={len(anon[year])}, datum {anon[year]['datum'].min()} – {anon[year]['datum'].max()}")
vals = final[[f"item_{i:02d}" for i in range(1, 27)]]
print(f"  justice_final: n={len(final)}, hodnoty {int(np.nanmin(vals.values))}-{int(np.nanmax(vals.values))}, "
      f"chybějící: {int(vals.isna().sum().sum())}")
