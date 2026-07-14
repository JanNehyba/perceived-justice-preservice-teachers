#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
01_prepare_data.py — Příprava dat proudu #1 (sebehodnotící dotazník spravedlnosti).

Cíl: z read-only originálů v data/raw/ vytvořit dohledatelné, dokumentované
výstupy v data/processed/. NEPROVÁDÍ statistické analýzy — jen mapuje položky
napříč lety a připravuje čistý finální dataset.

Vstupy (data/raw/):
  - justice_2324.csv         580×26, 2023+2024, sep=';', UTF-8-SIG   [FINÁLNÍ instrument]
  - justice_2023.csv         247×26, 2023,      sep=';', cp1250       (podmnožina 2324)
  - justice_2021.csv         346×26, 2021,      sep=',', cp1250, +index col (GitHub, jiné číslování)
  - Spravedlnost_2019-2023.xlsx   slovník položek po letech + PCA/EFA výstupy

Výstupy (data/processed/):
  - codebook.csv / codebook.md    kodex 26 položek FINÁLNÍHO instrumentu (CZ + EN draft)
  - item_map.csv                  mapa položek napříč vlnami (drift)
  - justice_final.csv             vyčištěný finální dataset (580×26, item_01..item_26)
  - justice_2021_clean.csv        vyčištěná vlna 2021 (ponechává vlastní číslování)
  - justice_2023_clean.csv        vyčištěná vlna 2023 (číslování shodné s 2324)

Zásada: každé číslo v textu musí být dohledatelné z tohoto skriptu + verze dat.
"""

from pathlib import Path
import re
import pandas as pd
import numpy as np

# ---------------------------------------------------------------- cesty
SCRIPT = Path(__file__).resolve()
H1 = SCRIPT.parents[2]                     # .../habilitace-1
RAW = H1 / "data" / "raw"
OUT = H1 / "data" / "processed"
OUT.mkdir(parents=True, exist_ok=True)
XLSX = RAW / "Spravedlnost_2019-2023.xlsx"

PRINCIPLE_EN = {
    "Procedurální": "Procedural",
    "Rovnost": "Equality",
    "Potřeby": "Need",
    "Zásluhy": "Merit",
    "Rovnost_r": "Equality (reverse)",
}

# EN DRAFT překlady 26 položek finálního (2023/2324) instrumentu.
# !!! DRAFT — nutná revize (workflow Fable/Opus). Nejde o oficiální překlad nástroje.
EN_DRAFT = {
    1:  "At the start of the year, it is important to me to clearly establish the rules of how the class works.",
    2:  "I clearly explain to pupils what I emphasize during oral examination.",
    3:  "I devote the same amount of time to every pupil during oral examination.",
    4:  "If a pupil is going through a difficult life situation (e.g. parents' divorce), I take it into account when grading.",
    5:  "I give more care to the pupil who, in my view, needs it most.",
    6:  "I inform my pupils in advance how I handle any conflicts in the class.",
    7:  "I tell pupils they can consult discrepancies in the marking of a test at any time.",
    8:  "I announce to pupils in advance the criteria for grading their written work.",
    9:  "When grading, I take into account whether the subject is difficult for a particular pupil.",
    10: "I devote the same degree of attention to every pupil's problems.",
    11: "To a pupil with a long-term problem understanding the material, I assign different homework than to others.",
    12: "I reward pupils who finish their classwork ahead of the deadline (e.g. they may work on their own things).",
    13: "If a pupil completes an extra task during the lesson, I duly appreciate their effort.",
    14: "I give the same degree of attention to all pupils.",
    15: "When assessing every pupil's behaviour, I always use the same criteria.",
    16: "I try to treat all pupils the same.",
    17: "To a pupil who was ill, I give extra time so they can catch up on the material.",
    18: "I would initially adjust the assessment of a pupil who transferred from another school.",
    19: "I appreciate a pupil's exceptional effort in the lesson in a corresponding way.",
    20: "I praise a pupil who successfully represents the school in a knowledge competition.",
    21: "I give recognition to a pupil who showed effort beyond the assigned task.",
    22: "During examination, I try to call on all pupils with the same regularity.",
    23: "I explain to pupils how to give peer feedback, e.g. when assessing each other's work.",
    24: "I give pupils room to co-create the rules of behaviour in the class.",
    25: "I appreciate a pupil who can carry out various class activities.",
    26: "It is important to me to have clear criteria by which I assess pupils.",
}


# ---------------------------------------------------------------- helpers
def clean_header(cols):
    """Sjednotí kódy položek na 'NNPrincip' (odstraní BOM, X prefix, mezery)."""
    out = []
    for c in cols:
        s = str(c).replace("﻿", "").strip()
        s = re.sub(r"^X", "", s)           # GitHub používá X1..X26
        out.append(s)
    return out


def parse_code(code):
    """'16Rovnost' -> (16, 'Rovnost'); '18Rovnost_r' -> (18, 'Rovnost_r')."""
    m = re.match(r"^(\d+)\s*([A-Za-zÁ-Žá-ž_]+)$", str(code))
    if not m:
        return (None, str(code))
    return (int(m.group(1)), m.group(2))


# ---------------------------------------------------------------- 1) slovník položek z XLSX
def read_defs(sheet, ncols, id_col=0, prin_col=1, code_col=2, word_col=3,
              start=0, stop_blank_id=True, extra_cols=None):
    """Načte řádky položek z definičního listu; vrátí list dictů."""
    df = pd.read_excel(XLSX, sheet_name=sheet, header=None, engine="openpyxl")
    recs = []
    for i in range(start, len(df)):
        row = df.iloc[i]
        idv = row[id_col] if id_col is not None else None
        wording = row[word_col]
        if pd.isna(wording) or str(wording).strip() == "":
            continue
        try:
            iid = int(float(idv)) if idv is not None and not pd.isna(idv) else None
        except (ValueError, TypeError):
            iid = None
        rec = {
            "id": iid,
            "principle": (str(row[prin_col]).strip() if prin_col is not None and not pd.isna(row[prin_col]) else None),
            "code": (str(row[code_col]).strip() if code_col is not None and not pd.isna(row[code_col]) else None),
            "wording": str(wording).strip(),
        }
        if extra_cols:
            for name, ci in extra_cols.items():
                rec[name] = (None if pd.isna(row[ci]) else (str(row[ci]).strip() if isinstance(row[ci], str) else row[ci]))
        recs.append(rec)
    return recs


# 2023 = finální instrument (řádky 1..26). Sloupce: A id, B princip, C kód,
# D znění 2023, E znění 2022, F staré kódování z 2021 poolu.
defs_2023 = read_defs("Spravedlnost 2023", ncols=6, start=1,
                      extra_cols={"wording_2022": 4, "pool2021_code": 5})
defs_2023 = [d for d in defs_2023 if d["id"] is not None and 1 <= d["id"] <= 26]

# kontextové štítky (druhý blok téhož listu, řádky ~30+): B id, C princip, D znění, F kontext
ctx = read_defs("Spravedlnost 2023", ncols=6, start=29,
                id_col=1, prin_col=2, code_col=None, word_col=3,
                extra_cols={"context": 5})
ctx_by_id = {d["id"]: d.get("context") for d in ctx if d["id"] is not None}

# 2021 pool (36 položek): A id, B princip, C kód, D znění
defs_2021pool = read_defs("Nová Spravedlnost2021", ncols=5, start=0)
pool_by_id = {d["id"]: d for d in defs_2021pool if d["id"] is not None}

# 2019 (21 položek, 3. osoba "Učitel..."): A id, B princip, C kód, D znění
defs_2019 = read_defs("Spravedlnost 2019", ncols=4, start=1)
defs_2019 = [d for d in defs_2019 if d["id"] is not None and 1 <= d["id"] <= 30]


# ---------------------------------------------------------------- 2) codebook (finální 26)
cb_rows = []
for d in defs_2023:
    iid = d["id"]
    _, prin_short = parse_code(d["code"]) if d["code"] else (None, d["principle"])
    reverse = bool(d["code"] and d["code"].endswith("_r"))
    pool_code = d.get("pool2021_code")
    try:
        pool_code = int(float(pool_code)) if pool_code is not None else None
    except (ValueError, TypeError):
        pool_code = None
    reworded = (d.get("wording_2022") is not None
                and str(d.get("wording_2022")).strip() != d["wording"].strip())
    cb_rows.append({
        "item_id": iid,
        "var": f"item_{iid:02d}",
        "code_2324": d["code"],
        "principle_cz": d["principle"],
        "principle_en": PRINCIPLE_EN.get(d["principle"], d["principle"]),
        "cz_wording": d["wording"],
        "en_wording_draft": EN_DRAFT.get(iid, ""),
        "context_cz": ctx_by_id.get(iid),
        "reverse_coded": reverse,
        "scale": "1-7 (Zcela NEspravedlivé — Zcela spravedlivé)",
        "present_in_waves": "2023;2324",
        "pool2021_code": pool_code,
        "reworded_2022_to_2023": reworded,
    })
codebook = pd.DataFrame(cb_rows).sort_values("item_id").reset_index(drop=True)
codebook.to_csv(OUT / "codebook.csv", index=False, encoding="utf-8")

# čitelná markdown verze codebooku
with open(OUT / "codebook.md", "w", encoding="utf-8") as f:
    f.write("# Codebook — finální dotazník spravedlnosti (2023/2324, 26 položek)\n\n")
    f.write("Škála: 1–7 (Zcela NEspravedlivé — Zcela spravedlivé). Reverzní položky: žádné "
            "(historicky reverzní položka byla v 2023 přeformulována na pozitivní, viz item 16).\n\n")
    f.write("> EN znění jsou **DRAFT** překlady k revizi (workflow Fable/Opus), ne oficiální překlad nástroje.\n\n")
    f.write("| # | var | Princip (CZ/EN) | Znění CZ | Znění EN (draft) | Kontext | 2021 pool |\n")
    f.write("|---|-----|-----------------|----------|------------------|---------|-----------|\n")
    for r in codebook.itertuples():
        f.write(f"| {r.item_id} | {r.var} | {r.principle_cz} / {r.principle_en} | "
                f"{r.cz_wording} | {r.en_wording_draft} | {r.context_cz or ''} | "
                f"{'' if pd.isna(r.pool2021_code) else int(r.pool2021_code)} |\n")


# ---------------------------------------------------------------- 3) item_map (drift napříč vlnami)
im_rows = []
for r in cb_rows:
    pool = pool_by_id.get(r["pool2021_code"]) if r["pool2021_code"] else None
    pool_word = pool["wording"] if pool else None
    pool_prin = pool["principle"] if pool else None
    word_changed = (pool_word is not None and pool_word.strip() != r["cz_wording"].strip())
    note = []
    if r["reworded_2022_to_2023"]:
        note.append("přeformulováno mezi 2022 a 2023")
    if pool_prin and pool_prin != r["principle_cz"]:
        note.append(f"princip 2021 poolu = {pool_prin}")
    if pool and str(pool.get("code", "")).endswith("_r"):
        note.append("v 2021 poolu REVERZNÍ (Rovnost_r) → v 2023 přeformulováno na pozitivní")
    im_rows.append({
        "item_id_2324": r["item_id"],
        "principle_2324": r["principle_cz"],
        "cz_wording_2324": r["cz_wording"],
        "pool2021_id": r["pool2021_code"],
        "principle_2021pool": pool_prin,
        "cz_wording_2021pool": pool_word,
        "wording_changed_2021_to_2023": word_changed,
        "note": "; ".join(note),
    })
item_map = pd.DataFrame(im_rows).sort_values("item_id_2324").reset_index(drop=True)
item_map.to_csv(OUT / "item_map.csv", index=False, encoding="utf-8")


# ---------------------------------------------------------------- 4) čisté datasety
def load_matrix(name, sep, enc, drop_index=False):
    df = pd.read_csv(RAW / name, sep=sep, encoding=enc)
    if drop_index:
        df = df.drop(columns=df.columns[0])
    df.columns = clean_header(df.columns)
    return df

# POZN.: justice_final.csv už tento skript NEVYTVÁŘÍ — finální dataset (n=744,
# 2023+2024+2026, s demografií) staví 03_prepare_forms.py z Google Forms exportů.
# Zde jen ověříme konzistenci historického souboru justice_2324.csv.
d2324 = load_matrix("justice_2324.csv", sep=";", enc="utf-8-sig")
order = [parse_code(c)[0] for c in d2324.columns]
assert order == list(range(1, 27)), f"nečekané pořadí položek 2324: {order}"
final = d2324.copy()
final.columns = [f"item_{i:02d}" for i in order]

# 2023 (stejné číslování jako 2324) — ponecháme čitelné kódy
d2023 = load_matrix("justice_2023.csv", sep=";", enc="cp1250")
d2023.to_csv(OUT / "justice_2023_clean.csv", index=False, encoding="utf-8")

# 2021 (GitHub) — VLASTNÍ číslování, ponecháme původní kódy (NEpřečíslovávat na 2324!)
d2021 = load_matrix("justice_2021.csv", sep=",", enc="cp1250", drop_index=True)
d2021.to_csv(OUT / "justice_2021_clean.csv", index=False, encoding="utf-8")


# ---------------------------------------------------------------- 5) shrnutí do stdout
def rng(df):
    v = df.select_dtypes(include=[np.number]).values
    return f"{int(np.nanmin(v))}-{int(np.nanmax(v))}, NaN={int(pd.isna(v).sum())}"

n_reworded = int(codebook["reworded_2022_to_2023"].sum())
n_reverse = int(codebook["reverse_coded"].sum())
print("=== 01_prepare_data.py — hotovo ===")
print(f"codebook.csv        : {len(codebook)} položek | reverzních={n_reverse} | přeformulovaných 2022→2023={n_reworded}")
print(f"item_map.csv        : {len(item_map)} položek | znění změněno 2021→2023 u {int(item_map['wording_changed_2021_to_2023'].sum())}")
print(f"justice_2324 (kontrola, final staví 03): {final.shape} | hodnoty {rng(final)}")
print(f"justice_2023_clean  : {d2023.shape} | hodnoty {rng(d2023)}")
print(f"justice_2021_clean  : {d2021.shape} | hodnoty {rng(d2021)}")
print(f"2019 slovník (jen definice, 3. osoba): {len(defs_2019)} položek")
print(f"2021 pool (superset, jen očíslované) : {len(pool_by_id)} položek")
