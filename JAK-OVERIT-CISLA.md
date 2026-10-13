# Jak si ověřit čísla knihy (návod pro netechnické čtenáře)

Každé číslo v knize pochází ze **zdrojové tabulky čísel**: tabulky dvojic
„název metriky, hodnota" (soubory `*_cisla.csv`), kterou vygeneroval analytický
notebook nad verzovaným řezem anonymizovaných dat. Tento repozitář obsahuje vše,
co potřebujete k ověření, že čísla v knize odpovídají výstupům analýz. Nabízíme
tři cesty podle toho, kolik techniky chcete.

## Cesta 1: bez instalace čehokoli (2 minuty)

1. Otevřete složku `vystupy/tabulky/` a v ní zdrojovou tabulku čísel kapitoly,
   která vás zajímá: `05_cisla.csv` (viněty, kap. 5), `06_cisla.csv` (vývoj nástroje,
   kap. 6), `07_cisla.csv`, `07_network_cisla.csv` a `07_reliabilita_kompozit_cisla.csv`
   (struktura, sítě a reliabilita skórů subškál, kap. 7),
   `08_cisla.csv` (mezikohortní stabilita, kap. 8), `E5_typologie_cisla.csv`
   (typologie). Je to obyčejná tabulka „název metriky, hodnota"; otevře ji
   jakýkoli tabulkový editor nebo prohlížeč.
2. Najděte v tabulce číslo, které vás v knize zajímá, a ověřte shodu. Při
   sestavení knihy kontrola automaticky vyhledá každé tvrdé číslo z textu ve
   všech výstupních tabulkách složky `vystupy/tabulky/`; kniha se nesestaví,
   pokud některé číslo ve výstupech analýz chybí.

## Cesta 2: spustit analýzu v prohlížeči (Binder, ~15 minut poprvé)

1. Klikněte na odznak „launch binder" v README tohoto repozitáře. Poprvé se
   prostředí sestaví (~15 minut), pak se otevře RStudio ve vašem prohlížeči;
   nic se neinstaluje k vám do počítače. Prostředí má R 4.5 a balíčky ze snímku
   CRAN k 10. 7. 2026, tedy ve stejných verzích, jaké zaznamenává `renv.lock`.
   Dne 9. 10. 2026 se v něm všech pět notebooků vyrenderovalo (síťový notebook 30
   počítá asi 40 minut); výstupy notebooků 20, 40 a 50 byly v tomto prostředí
   naposledy spočteny 13. 10. 2026. Paralelní analýza běží sériově, aby pevné
   počáteční semínko dávalo pokaždé stejný výsledek.
2. **Analýzy běží rovnou** z anonymizovaných dat repozitáře. Otevřete notebook
   ve složce `analyzy/notebooks/` a klikněte na **Render**, pak porovnejte
   hodnoty s knihou:
   - `10_vinety.qmd` (Studie 1, kap. 5): vinětové hodnocení šesti principů;
   - `20_psychometrie.qmd` (Studie 2–3, kap. 6–7): reliabilita, faktorová analýza;
   - `30_network.qmd` (Studie 3, kap. 7): síťové modely a jejich stabilita;
   - `40_crosswave.qmd` (Studie 4, kap. 8): třístupňové srovnání kohort;
   - `50_typology.qmd` (příloha o typologii): typologie a validační pilot.

Poznámka: v logu RStudia se mohou objevit hlášky „checkSpelling / iconv" nad
českými slovy. Jsou neškodné (kontrola pravopisu neumí diakritiku) a na výpočty
ani render nemají vliv.

## Cesta 3: lokálně (pro technické čtenáře)

```bash
./reproduce.sh          # ověří prostředí (renv), přepočítá notebooky a spustí brány
```

Skript `analyzy/scripts/95_check_cisla.py` vyhledá každé tvrdé číslo z prózy
knihy ve výstupních tabulkách `vystupy/tabulky/`; čísla s ruční kotvou
`<!-- manifest … -->` porovná přímo s uvedeným klíčem. Próza knihy (zdrojové
kapitoly `kapitoly/cs/`) není součástí tohoto repozitáře, proto zde skript skončí
hlášením „nic k ověření“; zkouška čísel se tu dělá podle cesty 1 nebo 2.
`analyzy/scripts/96_check_references.py` zkontroluje citace proti seznamu
literatury a potřebuje tytéž zdrojové kapitoly.

## Co znamená, když se čísla neshodují

Neshoda mezi prózou a zdrojovou tabulkou čísel je chyba a budeme rádi, když ji nahlásíte
(kontakt v README). Brány běží před každým sestavením knihy, takže publikovaná
verze by měla být vždy konzistentní.
