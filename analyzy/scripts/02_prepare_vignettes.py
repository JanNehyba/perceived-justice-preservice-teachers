#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
02_prepare_vignettes.py — Příprava dat proudu #2 (vinětová úloha „vesnice", jaro 2019).

POZOR: samostatný nástroj, NEsměšovat s dotazníkem (proud #1). Jiná jednotka
(respondent × 6 vesnic), jiná škála-použití a ŠIRŠÍ taxonomie: 6 principů
spravedlnosti (dotazník má 4).

Vstup:  data/raw/vinety_vesnice_2019.xlsx  (Sheet1: r0 hlavička, r1 Medián, r2 Průměr, r3.. respondenti)
Výstupy (data/processed/):
  - vinety_final.csv        wide: respondent × 6 vesnic + demografie (146 řádků)
  - vinety_long.csv         long: respondent × princip (876 řádků)
  - codebook_vinety.csv/md  6 vesnic → barva, princip (CZ/EN), krátké znění viněty, škála

Integritní kontrola: přepočtené průměry musí odpovídat řádku 'Průměr' v originálu.
"""

from pathlib import Path
import pandas as pd
import numpy as np

SCRIPT = Path(__file__).resolve()
H1 = SCRIPT.parents[2]
RAW = H1 / "data" / "raw"
OUT = H1 / "data" / "processed"
OUT.mkdir(parents=True, exist_ok=True)
# Rozšířený vzorek (13. 7. 2026): 315 respondentů z .numbers exportu.
# Původní vinety_vesnice_2019.xlsx (n=146) zachován pro audit; prvních 146 řádků v2 je identických.
SRC = RAW / "vinety_vesnice_2019_v2.xlsx"

# pořadí vesnic dle SLOUPCŮ v xlsx (r0): Modrá, Bílá, Zelená, Oranžová, Červená, Žlutá
VILLAGES = [
    # (var,               barva,     princip_cz,             principle_en,        gloss_cz)
    ("v_rovnost",          "Modrá",   "rovnost",              "equality",          "Každý občan dostane stejný díl bez ohledu na cokoli."),
    ("v_nahoda",           "Bílá",    "náhoda",               "chance/lottery",    "Losování — každý má stejnou šanci, ceny rozděluje náhoda."),
    ("v_potreby",          "Zelená",  "potřeby",              "need",              "Rozděleno podle potřeb jednotlivých občanů."),
    ("v_zasluhy",          "Oranžová","zásluhy",              "merit/desert",      "Více dostanou ti, kdo pracovali, přispěli nebo dlouho sloužili."),
    ("v_rovne_prilezitosti","Červená","rovné příležitosti",   "equal opportunity", "Stejná startovní čára, každý si urve, co stihne."),
    ("v_kasty",            "Žlutá",   "kasty/sociální skupiny","caste/social groups","Rozděleno mezi tři kasty; rovnost jen uvnitř kasty."),
]
SCALE = "1-7 (1 = Naprosto NEspravedlivě — 7 = Naprosto spravedlivě)"
NA_TOKENS = {"Nevytištěno", "nevím", "Nevím", "nevim", ""}


def to_na(x):
    if pd.isna(x):
        return np.nan
    return np.nan if str(x).strip() in NA_TOKENS else x


# ---- načtení ----
raw = pd.read_excel(SRC, sheet_name="Sheet1", header=0, engine="openpyxl")
raw.columns = ["label", "pohlavi", "vek", "obor1", "obor2"] + [v[0] for v in VILLAGES]

# odděl souhrnné řádky (Medián / Průměr) od respondentů
summary = raw[raw["label"].isin(["Medián", "Průměr"])].set_index("label")
resp = raw[~raw["label"].isin(["Medián", "Průměr"])].copy()
resp = resp.dropna(how="all", subset=[v[0] for v in VILLAGES]).reset_index(drop=True)

# ---- čištění ----
resp["resp_id"] = [f"v2019_{i+1:03d}" for i in range(len(resp))]
for c in ["pohlavi", "vek", "obor1", "obor2"]:
    resp[c] = resp[c].map(to_na)
resp["vek"] = pd.to_numeric(resp["vek"], errors="coerce")
# sjednocení pohlaví
resp["pohlavi"] = resp["pohlavi"].replace({"Žena": "Z", "žena": "Z", "Muž": "M", "muž": "M"})
for v in VILLAGES:
    resp[v[0]] = pd.to_numeric(resp[v[0]], errors="coerce")

village_vars = [v[0] for v in VILLAGES]
final = resp[["resp_id", "pohlavi", "vek", "obor1", "obor2"] + village_vars]
final.to_csv(OUT / "vinety_final.csv", index=False, encoding="utf-8")

# ---- long ----
long = final.melt(id_vars=["resp_id", "pohlavi", "vek", "obor1", "obor2"],
                  value_vars=village_vars, var_name="var", value_name="rating")
meta = {v[0]: (v[1], v[2], v[3]) for v in VILLAGES}
long["barva"] = long["var"].map(lambda x: meta[x][0])
long["princip_cz"] = long["var"].map(lambda x: meta[x][1])
long["principle_en"] = long["var"].map(lambda x: meta[x][2])
long.to_csv(OUT / "vinety_long.csv", index=False, encoding="utf-8")

# ---- codebook vinět ----
cb = pd.DataFrame([{
    "var": v[0], "barva": v[1], "princip_cz": v[2], "principle_en": v[3],
    "gloss_cz": v[4], "scale": SCALE,
} for v in VILLAGES])
cb.to_csv(OUT / "codebook_vinety.csv", index=False, encoding="utf-8")
with open(OUT / "codebook_vinety.md", "w", encoding="utf-8") as f:
    f.write("# Codebook — vinetova uloha 'vesnice' (jaro 2019, proud #2)\n\n")
    f.write(f"Jednotka: respondent (n={len(final)}). Škála: {SCALE}. "
            "Šest principů spravedlnosti (širší taxonomie než 4 principy dotazníku).\n\n")
    f.write("| var | Barva | Princip (CZ) | Principle (EN) | Viněta (stručně) |\n")
    f.write("|-----|-------|--------------|----------------|------------------|\n")
    for v in VILLAGES:
        f.write(f"| {v[0]} | {v[1]} | {v[2]} | {v[3]} | {v[4]} |\n")

# ---- integritní kontrola ----
# POZN. (13. 7. 2026): souhrnný řádek 'Průměr' v tabulce je STATICKÝ a po rozšíření
# vzorku na n=315 už NEODPOVÍDÁ (drží staré 146-průměry). Proto integritu NEvážeme na něj,
# ale na tvrdá kritéria dat: rozsah 1–7, žádné chybějící u principů, celočíselné hodnoty.
print("=== 02_prepare_vignettes.py — hotovo ===")
print(f"vinety_final.csv : {final.shape} (respondentů={len(final)})")
print(f"vinety_long.csv  : {long.shape}")
print(f"demografie chybí : pohlaví={int(final.pohlavi.isna().sum())}, věk={int(final.vek.isna().sum())} z {len(final)}")
pvars = [v[0] for v in VILLAGES]
vals = final[pvars]
in_range = bool(((vals >= 1) & (vals <= 7)).all().all())
no_missing = bool(vals.notna().all().all())
integer = bool((vals == vals.round()).all().all())
print("integrita dat (nezávislá na souhrnném řádku):")
print(f"  rozsah 1–7: {in_range} | bez chybějících: {no_missing} | celočíselné: {integer}")
print("recomputed průměry (n=315):")
for v in VILLAGES:
    print(f"  {v[1]:9s} {v[2]:22s} mean={final[v[0]].mean():.4f}")
print("INTEGRITA:", "OK" if (in_range and no_missing and integer) else "SELHALA")
