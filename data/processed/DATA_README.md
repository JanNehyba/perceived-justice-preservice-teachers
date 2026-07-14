# DATA_README — habilitace-1 (spravedlnost u studentů učitelství) · v2

Dokumentace připravených dat. Generováno skripty v `analyzy/scripts/` z originálů
v `zdrojove-texty/` a `data/raw/`. **Každé číslo v textu monografie musí být
dohledatelné ze skriptu + verze dat** (pravidlo CLAUDE.md).

> ⚠️ Dva oddělené empirické proudy — nesměšovat: **#1 dotazník** (26 položek,
> 4 principy) a **#2 viněty „vesnice"** (6 vesnic, 6 principů).

---

## Proud #1 — Sebehodnotící dotazník spravedlnosti (7 kohort 2019–2026)

### Inventář kohort
| Vlna | n | Položek | Styl znění | Škála 1–7 | Extra | Sběr (z dat) |
|---|---|---|---|---|---|---|
| 2019 | — (jen slovník) | 21 | 3. os. popisná („Učitel…") | — | — | — |
| 2020 | 375 | 23 | 3. os. **normativní** („Učitel by měl…") | souhlas | — | 02–08/2020 |
| 2021 | 433 raw / 346 publikovaná | 36 (pool) | 1. os. | souhlas | 6 lži-položek | 02/2021–03/2022 |
| 2022 | 263 | 26 (2 stará znění) | 1. os. | souhlas | BIDR 20 | 02–05/2022 |
| 2023 | 247 | 26 finální | 1. os. | **spravedlnost** | BIDR 19 | 02–04/2023 |
| 2024 | 333 | 26 finální | 1. os. | spravedlnost | BIDR 19 | 02–04/2024 |
| 2026 | 164 | 26 finální | 1. os. | spravedlnost | BIDR 19 | 02–04/2026 |

Škály (potvrzeno autorem 10. 7. 2026): 2020–2022 souhlasová („Silně NEsouhlasím … Silně
souhlasím"), 2023+ spravedlnostní („Zcela NEspravedlivé … Zcela spravedlivé").
**Hranice srovnatelnosti škál = mezi 2022 a 2023.** Vlna 2025 neexistuje (sběr nebyl).
Soubor „2020komb" (kombinovaní studenti, n=46, jiná populace, obsahoval plná jména)
byl na pokyn autora vyřazen a smazán (10. 7. 2026).

### FINÁLNÍ analytický dataset
**`justice_final.csv` — n = 744 = 247 (2023) + 333 (2024) + 164 (2026).**
Sloupce: `resp_id, wave, datum, pohlavi, rok_narozeni, obor1, obor2, zkusenost,
item_01..item_26`. Hodnoty 1–7, **0 chybějících**. Identický nástroj i škála ve všech
třech vlnách → jediný soubor, kde je legitimní plná invariance/NCT napříč vlnami.
**2 řádky s duplicitním vzorcem odpovědí** (dohledatelné přes `resp_id`; senzitivita
analýz bez nich = pravidlo v PLAN-analyz.md). Zdůvodnění výběru: nejnovější a finální
verze nástroje, největší n, položková úplnost.

Křížová kontrola provenience: justice položky forms 2023+2024 == historický
`data/raw/justice_2324.csv` (580 řádků, multiset shoda) — ověřeno skriptem 03.

### Ostatní soubory proudu #1 (data/processed)
| Soubor | Obsah | Role |
|---|---|---|
| `bidr_2023_2026.csv` (744×21) + `codebook_bidr.csv` | BIDR sebeklamu, 19 položek, vlny 2023–2026 | validizace (kap. 7); 2022 má 20položkovou variantu jen ve `forms_2022` |
| `justice_2022_clean.csv` (263×27) | 26 položek mapováno na finální číslování **podle znění** | replikace E4; **item_16 a item_22 mají STARÁ znění** — item_16 je REVERZNÍ („S některými žáky zacházím jinak…"), NEREKÓDOVÁNO |
| `justice_2021_pool36.csv` (433×37) | surový 36položkový pool z Forms | vývoj nástroje (kap. 6) |
| `justice_2021_clean.csv` (346×26) | publikovaná očištěná verze (GitHub) | replikace EFA 2021; vlastní číslování (16↔17 prohozeno vs finální!) |
| `justice_2020_clean.csv` (375×24) | 23 normativních položek, kódy b01–b23 | jen konfigurační srovnání (jiný konstrukt-frame) |
| `justice_2023_clean.csv` (247×26) | historická items-only verze vlny 2023 | superseded `justice_final`em (wave==2023) |
| `item_map.csv` | crosswalk finální ↔ 2021 pool | z 01_prepare_data.py |
| `item_map_full.csv` | crosswalk finální ↔ 2022 ↔ pool2021 ↔ 2020-B ↔ 2019-A | 6 dřívějších REVIEW párování (fin. 3, 6, 13, 15, 17, 19) **potvrzeno autorem 11. 7. 2026** jako táž položka (příznak `confirmed-author`; fin. 15 = vědomá změna domény výkon→chování/operacionalizace, fin. 17 = realističtější přeformulace téhož); položky bez finálního protějšku vypisuje skript 03 |
| `codebook.csv/.md` | 26 finálních položek CZ + EN draft + princip + kontext | EN = draft k revizi |

### Anonymizační protokol (skript 03)
Z Forms exportů odstraněno: `Uživatelské jméno` (e-mail), `Jakákoliv poznámka:`
(volný text); timestamp zkrácen na datum; přidán syntetický `resp_id`.
Ponecháno: pohlaví, rok narození, obory (kvaziidentifikátory), zkušenost (binární).
Kontrola: rekurzivní grep zavináče přes `data/` nenajde nic (kromě této věty).
> ✅ **Originální Forms zipy (s e-maily) byly z repozitáře SMAZÁNY 10. 7. 2026** — Jan je má
> bezpečně zálohované mimo repo. V celém `habilitace-1/` už není žádný přímý identifikátor.
> **Důsledek pro reprodukci:** `03_prepare_forms.py` nelze spustit od nuly bez těch originálů
> (jsou offline). Pracovní vstup pipeline jsou nyní anonymizované `data/raw/forms_*_anonymized.csv`;
> ty stačí ke všem analýzám. Tento (pracovní) repo NENÍ určen ke zveřejnění — veřejný prezentační
> repo vznikne zvlášť a jen s anonymizovanými daty.

### Třístupňová srovnatelnost napříč kohortami (závazné pro analýzy)
1. **{2023, 2024, 2026}** — identický nástroj i škála → plná měřicí invariance,
   NCT, latentní průměry (podmíněno skalární invariancí).
2. **{2021, 2022}** — stejné/téměř stejné položky, **jiná škála (souhlas)** →
   jen strukturní replikace: EFA/EGA per kohorta, Tuckerova kongruence, ARI/NMI
   komunit, deskriptivní srovnání sítí. Žádné srovnání průměrů/prahů.
3. **{2020}** — normativní 3. os. („by měl") = jiný konstrukt-frame → jen
   konfigurační/kvalitativní srovnání + role ve vývojovém narativu.
NEPŘÍPUSTNÉ: pooling skórů přes hranici škály; latentní průměry 2022↔2023;
NCT přes různé škály; růstový/trendový jazyk (kohorty = jiní respondenti).

### Drift položek (shrnutí; plné detaily `item_map_full.csv`)
- 2019 → 2020: popisná → normativní 3. os., 21 → 23 položek.
- 2020 → 2021: normativní 3. os. → 1. os., pool rozšířen na 36.
- 2021: z poolu 36 vybráno 26 (publikovaná EFA verze, GitHub).
- 2022: týchž 26 položek a pořadí jako publikovaná 2021 (souhlasová škála).
- 2022 → 2023: přeformulace item 16 (reverzní → pozitivní „Se všemi žáky se snažím
  zacházet stejně.") a item 22; přečíslování (16↔17); **změna škály souhlas → spravedlnost**.
- 2023 = 2024 = 2026: identické.

---

## Proud #2 — Vinětová úloha „vesnice" (jaro 2019) — otvírák

**ROZŠÍŘENO 13. 7. 2026 na n=315** (dřív 146). Zdroj: `vinety_vesnice_2019_v2.xlsx`
(vygenerováno z `vinety_vesnice_2019.numbers`, master v repu); původní 146-soubor
`vinety_vesnice_2019.xlsx` zachován pro audit — **prvních 146 řádků v2 je identických**
(čistá expanze, ne přepis; jen reálně sebraní respondenti). `vinety_final.csv` —
**315 respondentů** × 6 vesnic (rovnost 5,50 · náhoda 4,50 · potřeby 4,22 · zásluhy 3,93 ·
rovné příležitosti 2,36 · kasty 2,00; škála 1–7), + `vinety_long.csv` (1890),
+ `codebook_vinety.csv/.md`. Demografie u 204 (pohlaví) / 206 (věk) z 315. Bez
individuálního propojení s dotazníkem. Integrita: rozsah 1–7, bez chybějících, celočíselné.

---

## Reprodukce
```bash
cd <repo-root>
./.venv/bin/python habilitace-1/analyzy/scripts/01_prepare_data.py   # codebook, item_map, legacy soubory
./.venv/bin/python habilitace-1/analyzy/scripts/02_prepare_vignettes.py  # proud #2
./.venv/bin/python habilitace-1/analyzy/scripts/03_prepare_forms.py  # anonymizace + justice_final n=744 + BIDR + per-vlna + item_map_full
```
Skripty čtou `zdrojove-texty/` a `data/raw/` (originály se nemění) a zapisují jen
`data/raw/forms_*` a `data/processed/`. Notebooky (EFA 2021, GGM 2324) čtou `data/raw/`.
