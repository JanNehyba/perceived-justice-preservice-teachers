#!/usr/bin/env bash
# Regenerace VŠECH figur knihy (kniha/GRAFICKY-MANUAL.md je závazný styl).
# Koncepční diagramy: graphviz .dot -> PNG (200dpi) + PDF.
# Datové figury: R skripty (theme_book.R) — timeline 4.1, viněty 5.x, sítě 7.x, stromy E5/2.2.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/../../vystupy/obrazky"
SCR="$HERE/../scripts"
mkdir -p "$OUT"

for base in 02_typologie 04_tri_stupne 06_evoluce_nastroje; do
  dot -Tpng -Gdpi=200 "$HERE/$base.dot" -o "$OUT/$base.png"
  dot -Tpdf            "$HERE/$base.dot" -o "$OUT/$base.pdf"
  echo "rendered $base -> $OUT/$base.{png,pdf}"
  # česká varianta (_cs.dot -> *-cs.png/pdf) pro CZ knihu
  if [ -f "$HERE/${base}_cs.dot" ]; then
    dot -Tpng -Gdpi=200 "$HERE/${base}_cs.dot" -o "$OUT/$base-cs.png"
    dot -Tpdf            "$HERE/${base}_cs.dot" -o "$OUT/$base-cs.pdf"
    echo "rendered ${base}_cs -> $OUT/$base-cs.{png,pdf}"
  fi
done

# Rscript se spouští z analyzy/ (kořen renv, kde leží .Rprofile) — z scripts/ by se
# renv knihovna neaktivovala (bootnet/dendextend by chyběly).
for rs in fig_04_timeline.R fig_05_vinety.R fig_07_networks.R fig_E5_trees.R; do
  if [ -f "$SCR/$rs" ]; then
    (cd "$SCR/.." && Rscript "scripts/$rs") && echo "rendered $rs"
    # česká varianta figur (skripty berou volitelný argument jazyka)
    case "$rs" in fig_05_vinety.R|fig_07_networks.R|fig_E5_trees.R)
      (cd "$SCR/.." && Rscript "scripts/$rs" cs) && echo "rendered $rs (cs)" ;;
    esac
  fi
done
