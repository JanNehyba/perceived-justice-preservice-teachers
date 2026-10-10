"""Tabulka D.4 (příloha D): zastoupení studovaných oborů po kohortách.

Rozhodnutí autora 10. 10. 2026 (připomínky B5-170 a B5-171): popis vzorků v oddílu 4.2
(„převážně studentů předmětových (aprobačních) oborů“) doložit tabulkou zastoupení
studovaných oborů po kohortách; obory sloučit do širších skupin a málo početné skupiny
do „jiné“.

Vstupy (jen čtení; nic se nepřepisuje):
  - dotazník 2023, 2024, 2026: data/processed/justice_final.csv (sloupce obor1, obor2;
    ověřeno, že se shodují s anonymizovanými exporty formulářů téže vlny);
  - dotazník 2020, 2021, 2022: data/raw/forms_{2020,2021,2022}_anonymized.csv
    (anonymizované exporty formulářů ze skriptu 03; jediný zdroj oborů těchto vln, protože
    soubory justice_20xx_clean.csv nesou jen položky). Vlna 2021 v plném počtu 433 odpovědí
    (stejně jako v oddílu 4.2), ne v publikované očištěné podmnožině 346, ke které obory nejsou.
    Soubory data/raw nejsou součástí doprovodného repozitáře; tam lze ze vstupů znovu spočítat
    jen vlny 2023–2026 a viněty, vlny 2020–2022 jsou doloženy výstupní tabulkou;
  - dotazník 2019: odpovědi se nedochovaly (DATA_README), obory proto nejsou;
  - viněty 2019: data/processed/vinety_final.csv (obor1, obor2; demografická sekce byla
    dobrovolná a v části administrací nebyla distribuována, údaj proto u části vzorku chybí;
    hodnoty „nevím“ a „Nevytištěno“ převádí skript 02 na chybějící).

Postup:
  1. Každý respondent se zařadí podle PRVNÍHO oboru (obor1) do jedné z širších skupin.
     Mapování je níže ve slovníku SKUPINY (klíč = název oboru bez přípony
     „se zaměřením na vzdělávání“). Hodnoty, které ve slovníku nejsou, jdou do „jiné“
     a skript je vypíše (nic se neodhaduje).
  2. Skupina, která má ve vlně 1–9 respondentů, se v této vlně sloučí do „jiné“ (anonymita
     a čitelnost: žádná zobrazená buňka kromě „jiné“ a řádku „obor neuveden“ nemá 1–9 osob).
  3. Druhý obor: respondent uvádí platný druhý obor, je-li obor2 vyplněn, není zástupnou
     hodnotou („-“ ve vinětách = bez druhého oboru; „Option 1“ = výchozí text volby
     formuláře) a liší se od obor1. Respondenti vinět, kteří vyplnili jen druhý obor, jsou
     v řádku „obor neuveden“ (skupina se určuje jen podle prvního oboru).
  4. Procenta se počítají z respondentů s uvedeným prvním oborem (u dotazníku všichni,
     u vinět jen ti, u nichž údaj je); podíl s druhým oborem ze stejného jmenovatele.

Mapování oborů na skupiny (slovník SKUPINY; v datech se vyskytují všechny uvedené
hodnoty kromě tělesné výchovy):
  Jazyky: Anglický jazyk; Český jazyk a literatura; Český jazyk (viněty); Německý jazyk;
    Ruský jazyk; Francouzský jazyk; Lektorství cizího jazyka - německý jazyk;
    Pedagogické asistentství českého jazyka a literatury pro základní školy.
  Společenské a humanitní předměty: Dějepis; Občanská výchova a základy společenských věd
    (i „Občanská výchova a ZSV“); Základy společenských věd; Pedagogické asistentství
    občanské výchovy pro základní školy.
  Matematika, přírodní vědy a technika: Matematika; Přírodopis; Chemie; Fyzika; Zeměpis
    (řazen k přírodním vědám jako ve vzdělávací oblasti Člověk a příroda RVP ZV);
    Technická a informační výchova; Pedagogické asistentství přírodopisu / matematiky /
    zeměpisu / technické a informační výchovy pro základní školy.
  Výchovy: Výtvarná výchova; Výtvarná výchova a vizuální tvorba; Vizuální tvorba;
    Hudební výchova; Výchova ke zdraví; Tělesná výchova; Pedagogické asistentství výchovy
    ke zdraví pro základní školy.
  Speciální pedagogika: Speciální pedagogika (s příponou i bez ní); Pedagogické
    asistentství speciální pedagogiky pro základní školy.
  Jiné: Jiný obor; Učitelství praktického vyučování (viněty).
  Bakalářské obory „Pedagogické asistentství X pro základní školy“ se řadí podle předmětu X.
  Mimo slovník (jde do „jiné“ a skript ji vypíše): zkratka „ÚPV“ ve vinětách, jejíž význam
  data nedokládají.

Výstupy:
  vystupy/tabulky/D4_obory.csv        – dlouhá tabulka (vlna × řádek): n, %, příznak sloučení
  vystupy/tabulky/D4_obory_cisla.csv  – manifest (metric,value) čísel, která uvádí příloha D
Na konci skript vypíše řádky Markdown tabulky D.4 (pro kontrolu proti příloze D).

Užití (z habilitace-1): python analyzy/scripts/obory_prehled.py
"""
from __future__ import annotations

import csv
import pathlib
import sys

import pandas as pd

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
PROC = ROOT / "data" / "processed"
RAW = ROOT / "data" / "raw"
OUT = ROOT / "vystupy" / "tabulky"

SUFFIX = " se zaměřením na vzdělávání"
PRAH = 10  # skupina s 1–9 respondenty ve vlně jde do „jiné“

JAZ = "Jazyky"
SPH = "Společenské a humanitní předměty"
MPT = "Matematika, přírodní vědy a technika"
VYC = "Výchovy"
SPP = "Speciální pedagogika"
JINE = "Jiné"
SKUPINY_PORADI = [JAZ, SPH, MPT, VYC, SPP, JINE]
PREDMETOVE = [JAZ, SPH, MPT, VYC]  # první obor odpovídá vyučovacímu předmětu
SLUG = {JAZ: "jazyky", SPH: "spol_hum", MPT: "mat_prir_tech", VYC: "vychovy", SPP: "spec_ped", JINE: "jine"}
R_CELKEM = "Celkem s uvedeným prvním oborem"
R_CHYBI = "Obor neuveden"
R_DRUHY = "Uvádí i druhý obor"

SKUPINY: dict[str, str] = {
    # jazyky
    "Anglický jazyk": JAZ,
    "Český jazyk a literatura": JAZ,
    "Český jazyk": JAZ,
    "Německý jazyk": JAZ,
    "Ruský jazyk": JAZ,
    "Francouzský jazyk": JAZ,
    "Lektorství cizího jazyka - německý jazyk": JAZ,
    "Pedagogické asistentství českého jazyka a literatury pro základní školy": JAZ,
    # společenské a humanitní předměty
    "Dějepis": SPH,
    "Občanská výchova a základy společenských věd": SPH,
    "Občanská výchova a ZSV": SPH,
    "Základy společenských věd": SPH,
    "Pedagogické asistentství občanské výchovy pro základní školy": SPH,
    # matematika, přírodní vědy a technika
    "Matematika": MPT,
    "Přírodopis": MPT,
    "Chemie": MPT,
    "Fyzika": MPT,
    "Zeměpis": MPT,
    "Technická a informační výchova": MPT,
    "Pedagogické asistentství přírodopisu pro základní školy": MPT,
    "Pedagogické asistentství matematiky pro základní školy": MPT,
    "Pedagogické asistentství zeměpisu pro základní školy": MPT,
    "Pedagogické asistentství technické a informační výchovy pro základní školy": MPT,
    # výchovy
    "Výtvarná výchova": VYC,
    "Výtvarná výchova a vizuální tvorba": VYC,
    "Vizuální tvorba": VYC,
    "Hudební výchova": VYC,
    "Výchova ke zdraví": VYC,
    "Tělesná výchova": VYC,
    "Pedagogické asistentství výchovy ke zdraví pro základní školy": VYC,
    # speciální pedagogika
    "Speciální pedagogika": SPP,
    "Pedagogické asistentství speciální pedagogiky pro základní školy": SPP,
    # jiné (známé hodnoty)
    "Jiný obor": JINE,
    "Učitelství praktického vyučování": JINE,
}
ZASTUPNE = {"-", "Option 1"}  # zástupné hodnoty v obor2 (nejde o druhý obor)

VLNY = ["2019v", "2020", "2021", "2022", "2023", "2024", "2026"]
POPISKY = {"2019v": "Viněty 2019", **{w: f"Dotazník {w}" for w in VLNY[1:]}}


def zakladni_nazev(x) -> str | None:
    if pd.isna(x) or str(x).strip() == "":
        return None
    s = str(x).strip()
    return s[: -len(SUFFIX)].strip() if s.endswith(SUFFIX) else s


def nacti() -> dict[str, pd.DataFrame]:
    data: dict[str, pd.DataFrame] = {}
    data["2019v"] = pd.read_csv(PROC / "vinety_final.csv", usecols=["resp_id", "obor1", "obor2"])
    for w in (2020, 2021, 2022):
        f = RAW / f"forms_{w}_anonymized.csv"
        if not f.exists():
            raise SystemExit(f"Chybí {f.relative_to(ROOT)} (neveřejný vstup; vlny 2020–2022 jsou "
                             "v doprovodném repozitáři doloženy jen výstupní tabulkou D4_obory.csv).")
        data[str(w)] = pd.read_csv(f, usecols=["resp_id", "obor1", "obor2"])
    j = pd.read_csv(PROC / "justice_final.csv", usecols=["resp_id", "wave", "obor1", "obor2"])
    for w in (2023, 2024, 2026):
        data[str(w)] = j.loc[j["wave"] == w, ["resp_id", "obor1", "obor2"]].reset_index(drop=True)
    return data


def pct(n: int, d: int) -> float:
    return round(100 * n / d, 1)


def main() -> None:
    data = nacti()
    radky: list[dict] = []
    manifest: list[tuple[str, object]] = []
    nezname: dict[str, int] = {}
    zastupne: dict[str, int] = {}
    shodne: dict[str, int] = {}
    pct_predmetove: dict[str, float] = {}
    pct_druhy: dict[str, float] = {}

    for w in VLNY:
        d = data[w].copy()
        d["o1"] = d["obor1"].map(zakladni_nazev)
        d["o2"] = d["obor2"].map(zakladni_nazev)
        for val in d["o1"].dropna():
            if val not in SKUPINY:
                key = f"{POPISKY[w]}: {val}"
                nezname[key] = nezname.get(key, 0) + 1
        d["skupina"] = d["o1"].map(lambda x: None if pd.isna(x) else SKUPINY.get(x, JINE))
        n_celkem = len(d)
        uv = d[d["skupina"].notna()]
        n_uv = len(uv)
        n_chybi = n_celkem - n_uv
        zastupne[w] = int(d["o2"].isin(ZASTUPNE).sum())
        shodne[w] = int((d["o2"].notna() & (d["o2"] == d["o1"])).sum())
        n_druhy = int((uv["o2"].notna() & ~uv["o2"].isin(ZASTUPNE) & (uv["o2"] != uv["o1"])).sum())
        jen_druhy = int((d["skupina"].isna() & d["o2"].notna() & ~d["o2"].isin(ZASTUPNE)).sum())

        surove = uv["skupina"].value_counts().reindex(SKUPINY_PORADI, fill_value=0).astype(int)
        konecne = surove.copy()
        slouceno = {g: bool(0 < surove[g] < PRAH) for g in SKUPINY_PORADI[:-1]}
        for g, ano in slouceno.items():
            if ano:
                konecne[JINE] += surove[g]
                konecne[g] = 0

        for g in SKUPINY_PORADI:
            sl = slouceno.get(g, False)
            radky.append({"vlna": POPISKY[w], "radek": g,
                          "n": "" if sl else int(konecne[g]),
                          "pct": "" if sl else pct(int(konecne[g]), n_uv),
                          "slouceno_do_jine": "ano" if sl else "",
                          "n_vlna": n_celkem, "n_s_prvnim_oborem": n_uv})
            if not sl:
                manifest += [(f"n_{SLUG[g]}_{w}", int(konecne[g])),
                             (f"pct_{SLUG[g]}_{w}", pct(int(konecne[g]), n_uv))]
        pct_druhy[w] = pct(n_druhy, n_uv)
        radky += [
            {"vlna": POPISKY[w], "radek": R_CELKEM, "n": n_uv, "pct": 100.0, "slouceno_do_jine": "",
             "n_vlna": n_celkem, "n_s_prvnim_oborem": n_uv},
            {"vlna": POPISKY[w], "radek": R_CHYBI, "n": n_chybi, "pct": "", "slouceno_do_jine": "",
             "n_vlna": n_celkem, "n_s_prvnim_oborem": n_uv},
            {"vlna": POPISKY[w], "radek": R_DRUHY, "n": n_druhy, "pct": pct_druhy[w], "slouceno_do_jine": "",
             "n_vlna": n_celkem, "n_s_prvnim_oborem": n_uv},
        ]
        n_pred = int(sum(konecne[g] for g in PREDMETOVE))
        pct_predmetove[w] = pct(n_pred, n_uv)
        manifest += [
            (f"n_celkem_{w}", n_celkem),
            (f"n_s_prvnim_oborem_{w}", n_uv),
            (f"n_obor_neuveden_{w}", n_chybi),
            (f"n_druhy_obor_{w}", n_druhy),
            (f"pct_druhy_obor_{w}", pct_druhy[w]),
            (f"n_predmetove_{w}", n_pred),
            (f"pct_predmetove_{w}", pct_predmetove[w]),
        ]
        if w == "2019v":
            manifest.append(("n_jen_druhy_obor_2019v", jen_druhy))

    # souhrny pro text přílohy D (dotazník 2020–2026 zvlášť od vinět)
    dot = VLNY[1:]
    manifest += [
        ("n_dotaznik_2020_2026", sum(len(data[w]) for w in dot)),
        ("pct_druhy_obor_dotaznik_min", min(pct_druhy[w] for w in dot)),
        ("pct_druhy_obor_dotaznik_max", max(pct_druhy[w] for w in dot)),
        ("pct_predmetove_dotaznik_min", min(pct_predmetove[w] for w in dot)),
        ("pct_predmetove_dotaznik_max", max(pct_predmetove[w] for w in dot)),
    ]

    OUT.mkdir(parents=True, exist_ok=True)
    with (OUT / "D4_obory.csv").open("w", encoding="utf-8", newline="") as fh:
        wr = csv.DictWriter(fh, fieldnames=list(radky[0].keys()))
        wr.writeheader()
        wr.writerows(radky)
    with (OUT / "D4_obory_cisla.csv").open("w", encoding="utf-8", newline="") as fh:
        wr = csv.writer(fh)
        wr.writerow(["metric", "value"])
        wr.writerows(manifest)

    # ---- kontrolní výpis
    print("Hodnoty obor1 mimo slovník (zařazeny do „jiné“):", nezname or "žádné")
    print("Zástupné hodnoty v obor2 („-“, „Option 1“; nejsou druhým oborem):", zastupne)
    print("obor2 shodný s obor1 (není druhým oborem):", shodne)
    tab = pd.DataFrame(radky)

    def bunka(r) -> str:
        if r["slouceno_do_jine"]:
            return "–"
        if r["pct"] == "" or r["radek"] == R_CELKEM:  # součtový řádek jen počtem (100 %)
            return str(r["n"])
        return f"{r['n']} ({r['pct']:.1f})".replace(".", ",")

    tab["bunka"] = tab.apply(bunka, axis=1)
    wide = tab.pivot(index="radek", columns="vlna", values="bunka").reindex(
        index=SKUPINY_PORADI + [R_CELKEM, R_CHYBI, R_DRUHY], columns=[POPISKY[w] for w in VLNY])
    print(wide.to_string())
    print("\nMarkdown (Tabulka D.4):")
    print("| Skupina oborů (první obor) | Viněty 2019 | " + " | ".join(dot) + " |")
    print("|" + "-" * 23 + "|" + "|".join(["-" * 10 + ":"] * len(VLNY)) + "|")
    for idx, row in wide.iterrows():
        print(f"| {idx} | " + " | ".join(row.tolist()) + " |")
    print("\nManifest D4_obory_cisla.csv:")
    for k, v in manifest:
        print(f"  {k} = {v}")


if __name__ == "__main__":
    main()
