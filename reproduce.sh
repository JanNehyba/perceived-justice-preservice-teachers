#!/usr/bin/env bash
# Reprodukce analýz knihy od anonymizovaných dat po manifesty čísel a figury.
# Předpoklady: R + renv (renv.lock), Quarto, Python 3.11 (pro brány).
# Datové vstupy: anonymizovaná podmnožina v data/processed/ (surová data
# s přímými identifikátory nejsou součástí companionu).
# Spouštět z kořene publikovaného repozitáře (tam, kde leží analyzy/ a vystupy/).
set -euo pipefail
cd "$(dirname "$0")"

echo "── R prostředí (renv)"
Rscript -e 'if (!requireNamespace("renv", quietly=TRUE)) install.packages("renv"); renv::restore(prompt=FALSE)' || true

echo "── notebooky (render → manifesty čísel + reporty)"
for nb in analyzy/notebooks/10_vinety.qmd analyzy/notebooks/20_psychometrie.qmd \
          analyzy/notebooks/30_network.qmd analyzy/notebooks/40_crosswave.qmd \
          analyzy/notebooks/50_typology.qmd; do
  [ -f "$nb" ] && quarto render "$nb" || \
    echo "   (přeskočeno: $nb vyžaduje data mimo companion)"
done

echo "── figury knihy (z manifestů)"
[ -x analyzy/figures/render_figures.sh ] && analyzy/figures/render_figures.sh || true

echo "── kontrolní brány (čísla ↔ manifesty, reference)"
python3 analyzy/scripts/95_check_cisla.py || true
python3 analyzy/scripts/check_references.py || true

echo "HOTOVO. Manifesty: vystupy/tabulky/ | figury: vystupy/obrazky/"
