# PLAN-analyz — závazný analytický plán monografie (pre-registrace metod)

> Sepsáno PŘED spuštěním analýz (10. 7. 2026). Odchylky od tohoto plánu se
> dokumentují a zdůvodňují. Vazba na kapitoly viz `kapitoly/OSNOVA.md`; datové
> hranice viz `data/processed/DATA_README.md`.

> **Dodatek o provedení (12. 7. 2026):** E1–E5.1 byly provedeny a zmrazeny; P7 je dokončeno.
> Původní plán níže zůstává zachován, ale odchylky a skutečný stav jsou vyznačeny přímo u kroků.

## Nástroje a reprodukovatelnost
- **R** = inferenční statistika (lavaan, semTools, psych, EGAnet, qgraph, bootnet,
  NetworkComparisonTest, tidyLPA, rstatix, effectsize, ordinal, networktools, mgm).
  **Python** (.venv) = příprava dat (skripty 01–03, hotové). Rozhodnutí autora 10. 7. 2026.
- `renv` v `analyzy/` (`renv.lock` existuje, ale k 12. 7. 2026 není synchronizován se skutečnou
  projektovou knihovnou); **Quarto** notebooky, 1 na empirickou
  kapitolu: `10_vinety.qmd`, `20_psychometrie.qmd`, `30_network.qmd`, `40_crosswave.qmd`;
  render → `analyzy/vystupy/`. `set.seed()` u každého stochastického kroku; těžké
  bootstrapy (≥1000 iterací) cachovat do `.rds`.
- **Manifest čísel:** každý notebook na konci zapíše `vystupy/tabulky/<kap>_cisla.csv`
  (statistika, odhad, CI, p, n, hash dat, seed). Próza smí citovat jen čísla z manifestu.
- **Analysis freeze** = notebook rendruje end-to-end z `data/processed/` + zamčený
  manifest. Teprve pak se píší výsledkové pasáže (chapter freeze → CZ překlad).

## E1 — Viněty (kap. 5; `10_vinety.qmd`; plánováno n=146 → provedeno n=315, rozšíření 13. 7. 2026)
1. Deskriptiva per vesnice (`psych::describe`), četnosti, divergentní Likert figura;
   Spearman + polychorické korelace 6 hodnocení.
2. **Primární inference:** Friedman (`rstatix::friedman_test`, Kendallovo W) →
   post-hoc párové Wilcoxony (Holm; 15 párů) + matched-pairs rank-biserial r
   (`effectsize::rank_biserial(paired=TRUE)`).
3. Robustnost (příloha): `ordinal::clmm(rating ~ vesnice + (1|resp_id))`; shoda tří
   přístupů = argument robustnosti.
4. Profily: spaghetti + within-subject CI; volitelně MDS geometrie principů.
5. **Person-centered (exploratorní, tak označeno):** primárně hierarchické klastrování
   (Ward.D2) + PAM; k dle siluety + NbClust; stabilita `fpc::clusterboot` (Jaccard ≥ .75).
   **LPA (`tidyLPA`) jen jako triangulace** — parsimonní modely, BIC/saBIC/BLRT/entropie
   ≥ .8/velikost tříd; **demotion pravidlo:** při nestabilitě zůstává klastrová typologie
   deskriptivní a LPA jde do poznámky. (n=315 — citovat Spurk 2020; Tein 2013.)
6. Demografie (204/315 pohlaví, 206/315 věk; chybění dle verze formuláře = ne náhodné): POUZE popis
   podvzorku, žádná inference.

## E2 — Psychometrie (kap. 7.3 + dokončení kap. 6; `20_psychometrie.qmd`; n=744)
0. **Replikace publikované EFA 2021 (dokončení kap. 6).** `justice_2021_clean.csv`
   (n=346, vlastní číslování 16↔17): replikovat publikovanou EFA co nejblíže archivnímu
   notebooku (psych::fa, 4 faktory; KMO, Bartlett, % rozptylu, α subškál) → čísla pro
   markery `<!-- verify against manifest -->` v kap. 6.4 do manifestu **`06_cisla.csv`**
   (+ z `sessionInfo()` doložit verzi `psych` pro VERIFY-REF citaci Revelle). Případné
   odchylky od publikovaných hodnot (KMO=.80, ~40 %, standardizovaná α .70–.80) reportovat,
   nepřepisovat. **Oprava provedení:** starší plánovací hodnota α byla chybná; replikovaná raw α=.69–.76.
1. **Temporální split:** explorace **2023** (n=247) → konfirmace **2024** (n=333) →
   **holdout replikace 2026** (n=164). Podmíněné pravidlo (předem): drží-li
   konfigurální+metrická invariance (gate E2.7), finální parametry se reportují
   z pooled n=744.
2. Explorace 2023: KMO, Bartlett (na polychorikách), paralelní analýza
   (`fa.parallel(cor="poly")`), + `EGAnet::EGA` jako druhý hlas o dimenzionalitě;
   EFA `psych::fa(fm="minres", rotate="oblimin", cor="poly")`, řezy 3/4/5 faktorů,
   loading ≥ .40 (pásmo .30–.40 reportovat v závorce), cross-loadingy reportovat,
   žádné tiché mazání položek. **Rozhodovací pravidlo o k (předem):** primární hlas =
   paralelní analýza; EGA = druhý hlas; **4F je fokální kandidát vždy** (teorie);
   navrhnou-li PA/EGA k≠4, jde navržené řešení do konfirmace jako soupeř (E2.3e) —
   explorace o vítězi nerozhoduje.
3. Konfirmace 2024 (ordinální CFA, `lavaan::cfa(ordered=TRUE, estimator="WLSMV")`):
   srovnání modelů — (a) 1F; (b) **4F korelované (fokální)**; (c) higher-order;
   (d) bifaktor — verdikt dle tandem indexů `BifactorIndicesCalculator` (ωH, ECV, PUC),
   ne jen fitu; (e) EFA/EGA-navržená alternativa; (f) **ESEM** (lavaan `efa()` blok,
   rotace geomin; + srovnání faktorových korelací CFA vs ESEM — inflační check) —
   vzhledem k historii krátkých heterogenních subškál pravděpodobný highlight. Nested: scaled Δχ²
   (`lavTestLRT`); non-nested: robustní CFI/RMSEA/BIC.
   **Fit kritéria (předem, jako heuristiky, ne zákon):** robustní CFI/TLI ≥ .95
   (přijatelné ≥ .90), RMSEA ≤ .06 (přijatelné ≤ .08; 90% CI reportovat), SRMR ≤ .08;
   s explicitní výhradou, že cutoffs jsou kalibrované na ML a WLSMV je může nadhodnocovat
   (citovat Hu & Bentler 1999 + Xia & Yang 2019) — verdikt vždy z více indexů + parametrů.
   **Rozhodovací strom při selhání konfirmace (předem):** selže-li fokální model na 2024 →
   modifikace POUZE dle teorie + MI na 2024 (max. malý počet, typicky korelované reziduály
   uvnitř téhož principu), každá zdokumentovaná → modifikovaný model se povinně re-validuje
   na netknutém 2026. **Holdout 2026 je čistě konfirmační: žádné modifikace na něm;**
   posuzuje se replikace fitu + kongruence parametrů s 2024 (korelace loadingů), s výhradou
   n=164 (větší SE; nesoudit jen podle striktních cutoffs).
4. Reliabilita: **kategoriální ω** (`semTools::compRelSEM(ord.scale=TRUE)`) + ω_h/ω_t;
   α jen jako legacy. Per subškálu a per vlnu + pooled (podmíněně dle gate E2.7).
   Zůstane-li ω v .6: sumační skóry se NEdoporučují pro individuální
   diagnostiku — říct dřív, než to řekne oponent.
5. Plná invariance 2023/2024/2026 (vč. skalární + latentní průměry) zůstává v E4 (tier 1).
   Senzitivita: klíčové modely bez 2 duplicitních řádků (n=742) do přílohy.
6. Deskriptiva: rozdělení položek (ceiling očekáván), tabulka četností kategorií
   zdůvodňující ordinální zacházení.
7. **Gate konfigurální+metrická invariance (v P3, minimální verze).** Pooled n=744
   reporting (E2.1) závisí na invarianci, ale plná E4 mašinerie běží až v P5 → do
   `20_psychometrie.qmd` patří jen **minimální gate**: configural → thresholds →
   +loadings (`semTools::measEq.syntax`, Wu–Estabrook, theta; ΔCFI ≤ .01). Projde →
   pooled reporting povolen; neprojde → kap. 7 reportuje per-vlnu a pooled se ruší.
   Žádné skalární kroky, žádné latentní průměry, žádný partial-hunting — to vše až E4/P5
   (kap. 8). Toto rozdělení je záměrné a zapsané předem (žádné dvojí testování téhož).
8. **Reprodukovatelnost P3:** `set.seed()` u PA/EGA/bootstrapů; těžké kroky cache `.rds`;
   manifesty: **`07_cisla.csv`** (kap. 7.3) + **`06_cisla.csv`** (E2.0); próza cituje jen
   z manifestů. Vstup: `justice_final.csv` (item_01..item_26, vše pozitivně kódované,
   0 chybějících) + `justice_2021_clean.csv` pro E2.0.

## E3 — Síť (kap. 7.4–7.6; `30_network.qmd`; n=744)
1. `EGAnet::UVA` — redundance položek předem (wTO); nalezené páry diskutovat, nemazat tiše.
2. Estimace: `bootnet::estimateNetwork(default="EBICglasso", corMethod="cor_auto")`;
   senzitivita γ ∈ {0, 0.25, 0.5}; sidebar: konvergence s `psychonetrics` prune→stepup.
3. **Stabilita povinně:** nonparametrický bootstrap hran + case-drop pro centrality
   (1000 iterací); CS-koeficient ≥ .25 (min) / .50 (preferováno), Epskamp et al. 2018.
4. Centralita: **jen strength + expected influence** (bez betweenness/closeness — citovat
   kritiku Bringmann 2019; Hallquist); + **node predictability** (`mgm`).
5. **EGA blok (odpověď na „síťové klastry"):** `EGA(model="glasso", algorithm="walktrap")`
   (+ louvain senzitivita) → `bootEGA` (1000; structural consistency, `itemStability`
   ≥ .70–.75) → `hierEGA` (hierarchie: 4 principy pod obecným faktorem?) →
   `net.loads` (síťové náboje).
6. Trojcestné srovnání partic: EGA komunity × apriorní 4 principy × EFA faktory —
   ARI (`mclust::adjustedRandIndex`) / NMI (`igraph::compare`), + křížová tabulka;
   volitelně `EGAnet::LCT`.
7. **NCT párově 2023/2024/2026** (`NCT(it=1000, test.edges=TRUE, p.adjust="holm",
   test.centrality=TRUE)`) — legitimní jen uvnitř tieru 1; layout `averageLayout`;
   **identické nastavení estimace ve všech vlnách** (cor_auto, γ=0.5, stejný default),
   aby rozdíly sítí nebyly artefakt rozdílné estimace.
8. Vizualizace: dvoupanel (A: barvy = apriorní principy, B: barvy = EGA komunity,
   týž layout); `networktools::MDSnet` (interpretovatelné vzdálenosti); bridge
   strength/EI mezi komunitami; publikační verze `ggraph`; jednotná paleta knihy.
9. **BIDR (kap. 7.6):** skór BIDR (self-deception; kódování dle Paulhuse) →
   korelace s faktorovými skóry/latentními faktory a se sílou uzlů/komunitami;
   interpretace jako diskriminační validita. Rozsah rozšíření (BIDR jako kovariát,
   moderovaná síť) rozhodnout po prvních výsledcích — zapsat rozhodnutí sem.
   **ROZHODNUTO (11. 7. 2026, po prvních výsledcích):** max |r| BIDR×faktor = .161
   (rovnost; ostatní ≤ .07); centralita nesouvisí se SD-sytostí (ρ=.095) → **žádné
   rozšíření** (kovariát/moderovaná síť) se neprovádí, diskriminační validita doložena
   korelacemi. Klíčování BIDR (reverzní {02,04,06,08,10,12,14,16,19}; SDE škála bez
   původní položky 18) — **POTVRZENO Janem 11. 7. 2026** proti zdrojové verzi BIDR-CZ
   (položky 1–17, 19, 20; č. 18 vypuštěna). Shoduje se s klíčováním použitým v analýze
   → žádný přepočet. Doplnit citaci české adaptace (VERIFY-REF v kap. 7.6).
   **Odchylky P4 (dokumentovaně):** (a) `MDSnet` figura vypuštěna (chyba funkce i po
   opravě; vizualizaci pokrývá dvoupanel + bridge tabulka); (b) bootEGA `type="resampling"`
   (neparametrický, konzistentně s bootnet), plán typ nespecifikoval.

## E4 — Sedm kohort (kap. 8; `40_crosswave.qmd`)
**Rámec: „evoluce nástroje + replikace napříč nezávislými kohortami" — NE longitudinální
změna.** Třístupňová srovnatelnost (závazná, DATA_README):
- **Tier 1 {2023, 2024, 2026}:** ordinální měřicí invariance
  (`semTools::measEq.syntax`, ID.cat="Wu.Estabrook.2016", theta;
  configural → thresholds → +loadings → +scalar; ΔCFI ≤ .01 / ΔRMSEA dle
  Rutkowski & Svetina; partial fallback dokumentovaně). Drží-li skalární:
  **latentní průměry** — jediné legitimní „mean" srovnání v knize. + párové NCT (E3.7).
- **Tier 2 {2021, 2022}:** per-kohorta EFA (polychorická, minres, oblimin; target
  rotace na apriorní vzor) + EGA na zarovnaných položkách (`item_map_full.csv`;
  2022: item_16 staré REVERZNÍ znění → pro strukturní srovnání rekódovat 8−x
  a označit; senzitivita bez položek 16 a 22) → **Tuckerova kongruence**
  (`psych::factor.congruence`; benchmarky ≥ .95 / .85–.94, Lorenzo-Seva & ten Berge)
  → ARI/NMI komunit → deskriptivní srovnání sítí (Spearman korelace odpovídajících
  hran, bez p-hodnot). Žádné srovnání průměrů/prahů přes hranici škály.
- **Tier 3 {2020}:** normativní frame („by měl") — jen konfigurační EFA/EGA popis
  a role ve vývojovém narativu; párování položek dle `item_map_full` (REVIEW
  položky nejdřív ručně potvrdit s autorem).
- **Provedení E4:** šest Tier-3 párování autor potvrdil; n=375, 12 položek, kongruence
  .94/.93/.90/.82, EGA 3 komunity, ARI .658. V Tier 1 nebyl úplný ordinální prahový žebřík
  odhadnutelný (18/26 položek mělo v některé vlně prázdnou dolní kategorii); provedena byla
  nejúplnější možná kontinuální MLR řada až po striktní invarianci a per-wave ordinální CFA.
- Navíc: drift tabulka verzí (generovaná z `item_map_full.csv`); ω trajektorie
  2020–2026 (tabulka, bez testů); 2019 = jen znění (bez dat) — výhradně narativ.

**NEPŘÍPUSTNÉ (a kapitola 8.1 to explicitně zdůvodní):** pooling raw skórů přes
hranici škály; latentní průměry 2022↔2023 (prahy nejsou definované na společném
kontinuu); NCT přes různé škály; IRT linking bez kotev na společné metrice;
růstový jazyk (jiní respondenti, non-probability vzorky, změněný nástroj).

## E5 — Typologie spravedlnosti (koncepční mapa; původně volitelná, nyní dokončená)
**Účel:** dát čtenáři explicitní mapu druhů spravedlnosti a vymezit rozsah studie —
co měříme (4 principy) vs co vědomě NEměříme (retributivní, restorativní, korektivní,
interakční). Volitelně mapu empiricky podložit stromem podobnosti konceptů.
**Pravidlo:** E5 NESMÍ zdržet empirické jádro (E1–E4 / kap. 5–8). E5.0 je levné a doporučené;
E5.1 byla plánována jako „nice-to-have" s tvrdým kill-switchem; kill-switch prošel a E5.1 byla
dokončena. E5.2 se v této monografii NEDĚLÁ.

### E5.0 — Taxonomický diagram (Level 0; obrázek do kap. 2, teaser do kap. 1)
Deliverable: `vystupy/obrazky/02_typologie.{svg,pdf,png}` + odkaz v próze kap. 2. Bez dat, bez LLM.
- **Struktura (schváleno Janem 11. 7. 2026):** kořen SPRAVEDLNOST → 4 větve: distributivní
  {Equality/rovnost, Need/potřeby, Merit-desert/zásluhy}, procedurální, interakční
  {interpersonální, informativní}, rectifikační {retributivní, restorativní, korektivní}.
  Kontextové **pásy (ne větve):** organizační spravedlnost (tradice → procedurální+interakční),
  classroom justice (= kde stojí kniha).
- **Vrstva „data / bez dat":** 4 měřené principy zvýrazněné, zbytek vyšedlý (plní záměr:
  restorativní ap. jsou v mapě, ale viditelně mimo rozsah).
- **Volitelné osy:** outcome↔process; backward↔forward-looking.
- **Terminologie (oprava Janova nákresu):** vypustit „equity"; `Equality (rovnost)`,
  `Merit/desert (zásluhy)`. Uspořádání rectifikační větve = „jedno z možných", spornost
  (Weinrib) explicitně přiznat v popisku/textu.
- **Zdroje:** Aristoteles, Deutsch 1975, Leventhal 1980, Thibaut & Walker 1975, Bies & Moag 1986,
  Greenberg 1987/1993, Colquitt 2001, Chory-Assad — vše už ověřené v ref. kap. 2 (0 nových citací).
- **Nástroj:** Graphviz/DOT (reprodukovatelné, verzovatelné, čisté do print PDF); popisky EN
  autoritativní, CZ v zrcadle (P7). Alternativa `DiagrammeR`/`ggraph`.
- **Časování:** doporučeno v **P6** (produkce obrázků); lze rychlé intermezzo po P5. Náklad malý.

### E5.1 — Fenetický dendrogram konceptů (Level 1; IN-BOOK, rozhodnuto 11. 7. 2026)
**Integrace do knihy (PRŮŘEZOVĚ — P6b sahá do více kapitol):**
- **kap. 2.7** (nová podkapitola, dnešní „Pre-Service Teachers" → 2.8): *výsledek* — NeighborNet
  figura + ~1–1,5 s. interpretace (shodují se datové shluky s taxonomií z 2.1–2.6?). Result-focused,
  žánr kap. 2 zůstává teoretický.
- **kap. 4.5** (metodologie): *dokumentace metody* — LLM-as-judge kódování jako postup knihy
  (odkaz na Přílohu E); patří sem, protože ch4 dokumentuje VŠECHNY metody.
- **Příloha E**: *plný protokol* — `kapitoly/en/appendix-E-typology-method.md`.
- **kap. 9.6**: přeznačit z „future companion" → „uděláno v 2.7; budoucí jen Level 2 (descent-based)".
- **kap. 1.5**: řádek do „structure of the book".
- **OSNOVA / glosář / tento PLAN**: přečíslování 2.7→2.8, Příloha E aktivní.
**Rámování (závazné):** vždy **„fenetický / konceptuální dendrogram"** (strom podobnosti konceptů) —
žádné tvrzení o descentu/dědičnosti/evoluci. **Evolučně-biologický termín pro strom původu se
v knize ani v pracovních dokumentech NEPOUŽÍVÁ** (jednak je nepřesný — koncepty se nedědí jako
geny; jednak spouští bio-bezpečnostní filtry). Retikulaci ukázat **sítí (NeighborNet)**, ne jen stromem.
1. **Taxony:** ~20–30 konceptů (NE článků); seznam předregistrovat (distributivní principy vč.
   Rawlsova difference principle; Leventhalova procedurální pravidla; interpersonal/informational;
   retributive/restorative/corrective; širší: capabilities, luck egalitarianism, desert…).
   1 kanonická definice/taxon, verzovaná.
2. **Znaky:** ~12–20 pojmových os s definovanými stavy (outcome/process; backward/forward-looking;
   comparative/non-comparative; individual/collective; punishment-/repair-oriented; desert-based;
   need-sensitive; role of voice; interpersonal-treatment focus…). Předregistrovat kodovací manuál.
3. **Kódování (LLM-as-judge, více kodérů):** N≥3 nezávislých LLM kodérů (různé modely/seedy) →
   matice taxon×znak z definice + manuálu. **Reliabilita: Krippendorffovo α** per znak i celkově,
   práh ≥ .667 (jinak znak revidovat/vypustit — předem). **Provedeno:** buněčný konsensus většinou;
   při třech různých kódech dokumentovaný Opus tie-break (nikoli medián).
   **Lidská validace POVINNÁ:** pilot ~5 taxonů dvojkódovaný 2 lidmi (Jan + 1) → LLM–human α.
4. **Strom/síť:** Gowerova distance → **NeighborNet** (`phangorn`/SplitsTree) + Ward dendrogram.
   **Odchylka v provedení:** plánovaný bootstrap znaků ≥1000 nebyl realizován; místo něj byla
   provedena plná 16znaková analýza a dvě transparentní senzitivity — 9 spolehlivých znaků a
   α-vážené znaky (ARI .257/.354/.359).
5. **Konvergence dvou metod (podpis knihy):** nezávisle **embeddingový** strom (embed definice →
   kosinová distance → NeighborNet) vs znakový; shoda přes kofenetickou korelaci / normalized
   Robinson–Foulds / tanglegram. Shoda = validita; neshoda = lokalizace sporných konceptů.
   (Přímý analog kap. 7: dva nezávislé pohledy konvergují.)
6. **Výstup:** Příloha E (metoda, matice, α, validace) + 1 NeighborNet obrázek + box v kap. 2/9;
   manifest `vystupy/tabulky/E5_typologie_cisla.csv` (α, kofenetická r, RF, senzitivity
   podle reliability znaků).
7. **Infra:** R (`phangorn`,`ape`,`cluster`,`dendextend`) + LLM API. ~25×20×3 ≈ 1500 volání →
   **e-INFRA/HPC NENÍ nutná** (běží přes API); e-INFRA až pro Level 2.
8. **KILL-SWITCH (předem):** E5.1 se realizuje jen když (a) E1–E4 zmražené a kap. 5–8 hotové;
   (b) zbývá kapacita; (c) pilotní LLM–human α ≥ .6. Jinak → zůstává jen E5.0; E5.1 se odkáže
   jako „future direction". Nikdy neblokuje hlavní text. **Provedení: PASS** — člověk–člověk
   α=.777, Jan–LLM konsensus .772, kolega–LLM konsensus .758, všech pět kodérů .776.

### E5.2 — Plný strom původu (descent-based; Level 2) — V TÉTO MONOGRAFII NEDĚLAT
Korpus článků + parsimonie/Bayes + časová kalibrace z let vydání = samostatný budoucí článek.
Slabina = předpoklad descentu (koncepty se šíří retikulárně, ne dědičně). Zapsáno jen jako directions.

## Registr rizik (oponentní výtky → předjednané obrany)
| # | Výtka | Obrana v plánu |
|---|---|---|
| 1 | „Krátké subškály mají jen střední reliabilitu" | správná publikovaná standardizovaná α .70–.80 a replikovaná raw α .69–.76; kategoriální ω na finálních datech; modelování latentně/ESEM/síťově; ω trajektorie transparentně (8.5) |
| 2 | „Změnili jste škálu a stejně srovnáváte" | třístupňový rámec (8.1) PŘED výsledky; přes hranici jen struktura, nikdy skóry |
| 3 | „Convenience vzorky" | claims jen o struktuře a within-sample vztazích; interní replikace 2023→2024→2026; limity čelně (9.4) |
| 4 | „LPA na n=315" | LPA jen triangulace klastrů; parsimonní prostor; plná diagnostika; demotion pravidlo předem |
| 5 | „Duplicitní řádky" | audit našel jeden duplicitní vzorec; skutečná senzitivita odstranila druhý výskyt (n=743), nikoli plánované n=742; odchylka dokumentována v Příloze C |
| 6 | „Přeinterpretovaná centralita" | jen strength/EI + CS koeficienty; predictability; kritika citována |
| 7 | „Bifaktor vyhrál na fit — no a?" | tandem indexy (ωH/ECV/PUC) rozhodují, zapsáno předem |
| 8 | „Kde jsou data 2019? / dvě 2019 věci" | 6.2: znění bez dat, přiznáno; viněty 2019 = jiná studie (kap. 5); bez ID žádné propojování |
| 9 | „Ceiling / ordinalita ignorována" | WLSMV/polychoriky všude; viněty rank-based/CLMM; tabulky četností |
| 10 | „Explorace = konfirmace na týchž datech" | temporální split 2023→2024→2026 + podmíněné pooled pravidlo zapsané předem |
| 11 | „PII v datech" | anonymizační protokol (03); grep kontrola; Příloha D; originály mimo repo doporučeno |
| 12 | „2026 sběr neuzavřen" | okno 11. 2.–22. 4. 2026 dokumentováno z dat; zařazení rozhodnuto 10. 7. 2026; případný dosběr = nová kohorta, ne přílepek |
| 13 | „2020 měří něco jiného (normativní)" | přiznáno jako jiný konstrukt-frame; jen tier 3; interpretačně využito (normy vs sebepopis) v 6.3/9.3 |
| 14 | „Automatické párování položek 2019/2020" | šest REVIEW párování ručně potvrzeno autorem; Tier 3 následně dokončen |
| 15 | „Holdout n=164 je malý pro WLSMV CFA s 26 položkami" | holdout je čistě konfirmační (žádné modifikace); posuzuje se replikace fitu + kongruence parametrů s 2024, ne jen striktní cutoffs; výhrada zapsána předem (E2.3) |
| 16 | „Pooled n=744 použit dřív, než byla prokázána invariance" | minimální gate configural+metrická přímo v P3 (E2.7); neprojde-li, pooled reporting se ruší a kap. 7 jede per-vlnu; plná invariance vč. skalární až E4 |
| 17 | „LLM okódovalo typologii — to není věda" (E5.1) | 3 nezávislí LLM kodéři + Krippendorff α=.841; povinná lidská validace PASS (člověk–člověk .777; LLM konsensus vůči lidem .772/.758) |
| 18 | „Strom původu konceptů je metafora / koncepty se nedědí" (E5.1) | vždy „fenetický / konceptuální dendrogram" (strom podobnosti), NE strom původu; retikulace zobrazena sítí (NeighborNet); descentní model (Level 2) odmítnut a odložen (E5.2) |
| 19 | „Typologie je jen autorská" (E5.0/E5.1) | E5.0 vázán na kanonické zdroje (Deutsch/Colquitt…); E5.1 dodá nezávislé empirické podložení dvěma metodami (znaky + embeddingy) s testem konvergence |

## Fáze a quality gates
P0 ✅ (data, anonymizace, n=744, item_map_full, dokumentace) →
**P1** teorie kap. 2+3, narativ 6.1–6.6, skeleton kap. 4 (žádná závislost na analýzách) →
**P2** `10_vinety.qmd` → freeze → kap. 5 →
**P3** `20_psychometrie.qmd` (E2.0 replikace EFA 2021 → manifest `06_cisla.csv`;
E2.1–2.6 split+modely; E2.7 gate invariance → manifest `07_cisla.csv`) → freeze →
kap. 7.3 + dokončení kap. 6 (TODO marker 6.4 + VERIFY-REF psych verze) →
**P4** `30_network.qmd` (+BIDR) → freeze → kap. 7.4–7.7 →
**P5** `40_crosswave.qmd` → freeze → kap. 8 →
**P6** kap. 9, 1, 10; **E5.0 typologický diagram do kap. 2** (produkce obrázků); zamknout glosář →
**P6b ✅** E5.1 fenetický dendrogram + Příloha E + validace + konvergence dokončeny →
**P7 ✅** 17/17 EN↔CZ párů přeloženo, opraveno a ověřeno →
**P8 ✅** Quarto/Tectonic sazba, EN/CZ DOCX+PDF, přílohy a konsolidovaná literatura dokončeny;
veřejný companion repo publikován 14. 7. 2026 jako průběžná pracovní verze bez release a DOI.
Gate: žádná výsledková próza před freezem; žádný CZ překlad před EN freezem.
Poznámka: E5.0 lze pull-forward jako rychlé intermezzo mezi P5 a P6; E5.1/E5.2 NIKDY neblokují
hlavní empirický text (kap. 5–8) ani závěr.

## P8 — Sazba, publikace, reprodukovatelnost (finiš)
**Text — jeden zdroj (Markdown) → více formátů přes Quarto.** Quarto „book"
projekt spojuje `kapitoly/en/*` a `cs/*`; skutečné provedení používá konsolidované
`99-references.md` (nikoli dosud nevytvořený `references.bib`) a
MU titulní stranu a prohlášení dle „Vzor úpravy" (`pozadavky/`). Render:
- **.docx** — pro recenzenty / jazykovou korekturu / nakladatele (MUNIPRESS bere Word k sazbě),
- **print .pdf** (LaTeX) — pro tiskárnu a 4 povinné vázané výtisky (A4, řádkování 1,5–2, prohlášení),
- **.html** — web verze.
Pracovní kapitolové seznamy jsou při sestavení odstraněny a nahrazeny jedinou konsolidovanou
bibliografií (89 unikátních záznamů). Migrace do `.bib` zůstává pouze volitelnou budoucí změnou.
Word ani LaTeX needitovat ručně.

**Data + kód — veřejný companion repo (ZVLÁŠŤ od tohoto pracovního stromu).** Obsah:
skripty, R/Quarto notebooky, **anonymizovaná** processed data, codebooky, `DATA_README`,
`renv.lock`, a **renderované HTML reporty** (ne-IT recenzent čte čísla/grafy bez spouštění).
NIKDY: originály s PII, `.venv`, `renv/library`, `rizeni/`, `pozadavky/` ani cizí materiály.
Companion je na `github.com/JanNehyba/perceived-justice-preservice-teachers`; anonymizaci a PII
bránu zajišťuje `companion/make_companion.sh`. Jde o průběžnou pracovní verzi, nikoli archivní release.

**Tři repozitáře — NEMÍCHAT.** V programu jsou tři různé entity:
1. **`github.com/JanNehyba/Justice`** — existující **2021 repo** (EFA notebook + veřejná
   data 2021, n=346). Je **citovaný v kap. 6** jako historický artefakt pilotu → nemazat.
2. **Tento `habilitace/` pracovní repo** — obsahuje PII-historii → **NIKDY nezveřejnit**.
3. **Companion repo habilitace 1** — nový samostatný veřejný repozitář s anonymizovanými daty,
   kódem a výstupy celé knihy.

**Rozhodnutí Jana 14. 7. 2026:**
- Companion habilitace 1 je samostatný nový repozitář; habilitace 2 případně dostane vlastní.
  Žádný společný umbrella repo a žádné sdílení neveřejných dat mezi habilitacemi.
- Kniha ještě není oficiální a budou úpravy: **nyní bez GitHub release, Zenodo/OSF a DOI**.
  Archivní krok lze řešit jen na nový explicitní pokyn po finalizaci.
- **`JanNehyba/Justice` zůstává beze změny.** Nemazat, nearchivovat ani nepřejmenovávat;
  je to původní repo z roku 2021 a companion do něj nic nepushuje.

**Odkazy — jeden zdroj pravdy + kontrola.** Rétorika Markdownu je
formátově neutrální, ale externí odkazy se musí správně přenést do všech výstupů
(.docx/.pdf/.html) a nesmí se rozejít. Pravidla:
- URL companionu držet jako jediný zdroj pravdy v `_variables.yml` (`repo.url`, `repo.blob`).
- Ve veřejných výstupech nemají být žádné DOI placeholdery ani tvrzení o archivním vydání.
- **Link-check před freeze.** Automatický kontrolní pass odkazů při každém renderu;
  tvrdá brána před tiskem (žádné 404 / žádné placeholdery v print .pdf).
- **Print .pdf = URL viditelné.** Ve vázaném výtisku se neklikne, proto je URL vypsaná
  a současně klikací; odkazy na zdroje jsou v popiscích obrázků a tabulek.
  HTML: klikací + `link-citations: true`.
- GitHub companion se cituje jako datová sada/kód s živou URL; žádný DOI zatím nemá.

## Blockery
- [x] R runtime funguje a reprodukční běhy E4/E5 prošly.
- [ ] Synchronizovat `renv.lock` s projektovou knihovnou (`renv::status()` stále hlásí rozdíly).
- [x] Ruční revize 6 REVIEW párování v `item_map_full.csv` — potvrzeno autorem 11. 7. 2026 (všech 6 = stejná položka) → E4 tier 3 odblokován
- [x] Rozhodnutí o rozsahu BIDR analýz po prvních výsledcích (E3.9) — uzavřeno
  11. 7. 2026: diskriminační validita + dichotomizovaná senzitivita, bez rozšíření
