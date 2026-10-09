#!/usr/bin/env bash
# P8 build: synchronize the authoritative chapter sources into this staging
# directory, remove editorial-only metadata/checklists and duplicate working
# reference lists, then render a clean Czech book.
#
# Kniha je POUZE ČESKÁ (rozhodnutí Jana 8. 10. 2026; Směrnice MU 7/2017 čl. 5:
# anglicky je povinný jen abstrakt, ten je v kapitoly/cs/00-front-matter.md).
# Anglická verze kapitol do 8. 10. 2026: git tag hab1-pred-revizi.
#
# Usage:
#   ./build.sh                    # CZ, DOCX
#   ./build.sh cs pdf             # CZ, PDF
#   ./build.sh cs all             # CZ, DOCX + PDF
set -euo pipefail
export PYTHONIOENCODING=utf-8
cd "$(dirname "$0")"

PY="../../.venv/bin/python"                       # macOS/Linux
[ -x "$PY" ] || PY="../../.venv/Scripts/python.exe"  # Windows (Git Bash)
[ -x "$PY" ] || PY="python3"
command -v "$PY" >/dev/null 2>&1 || PY="python"

language="${1:-cs}"
format="${2:-docx}"

# Also accept the former one-argument format form (for example ./build.sh pdf).
case "$language" in
  docx|pdf|all)
    format="$language"
    language="cs"
    ;;
esac

case "$language" in cs) ;; *)
  echo "Unknown language '$language' (kniha je jen česká: cs)." >&2
  exit 2
esac
case "$format" in docx|pdf|all) ;; *)
  echo "Unknown format '$format' (use docx, pdf, or all)." >&2
  exit 2
esac

sync_language() {
  local lang="$1"
  "$PY" - "$lang" <<'PY'
import os
import re
import sys

lang = sys.argv[1]
src = os.path.join("..", "kapitoly", lang)
# Přílohy (pořadí písmen podle toku textu, P9 14. 7. 2026).
appendices = [
    "appendix-A-typology-method.md",
    "appendix-B-vignettes.md",
    "appendix-C-instrument.md",
    "appendix-D-supplementary-tables.md",
    "appendix-E-ethics.md",
]
files = [
    "00-front-matter.md",
    "01-introduction.md",
    "02-theoretical-foundations.md",
    "03-czech-context.md",
    "04-methodology.md",
    "05-study1-six-villages.md",
    "06-study2-instrument.md",
    "07-study3-structure.md",
    "08-study4-stability.md",
    "09-discussion.md",
    "10-conclusion.md",
    "99-references.md",
    "98-abbreviations.md",
] + appendices

metadata_labels = (
    "Language of this file", "Chapter type", "Research question covered",
    "Underlying data", "Underlying analysis", "Drafting model", "Sync status",
    "Type", "Source policy", "Status",
    "Jazyk tohoto souboru", "Jazyk souboru", "Typ kapitoly",
    "Pokrytá výzkumná otázka", "Podkladová data", "Podkladová analýza",
    "Model pro draft", "Model draftu", "Model draftování", "Model konceptu",
    "Stav synchronizace", "Typ", "Pravidlo zdrojů", "Stav",
)
metadata_re = re.compile(
    r"^>\s*(?:\*\*)?(?:" + "|".join(re.escape(x) for x in metadata_labels)
    + r")[^\n]*\n?",
    re.I | re.M,
)
reference_heading_re = re.compile(
    r"\n#{2,4}\s+(?:References?|Literature|Literatura|Seznam (?:použité )?literatury|"
    r"Použitá literatura|Použité zdroje|Odkazy)\b[^\n]*\n",
    re.I,
)
visible_checklist_re = re.compile(
    r"\n---+\s*\n#{2,4}\s*(?:Pre-finalization checklist|"
    r"Kontrolní seznam před finalizací|Checklist před finalizací)[^\n]*\n.*\Z",
    re.I | re.S,
)
comment_checklist_re = re.compile(
    r"<!--(?:(?!-->).)*(?:Pre-finalization checklist|"
    r"Kontrolní seznam před finalizací|Checklist před finalizací)"
    r"(?:(?!-->).)*-->",
    re.I | re.S,
)

for filename in files:
    path = os.path.join(src, filename)
    with open(path, encoding="utf-8") as handle:
        text = handle.read()

    # A single consolidated bibliography is rendered from 99-references.md.
    if filename != "99-references.md":
        match = reference_heading_re.search(text)
        if match:
            tail = text[match.end():]
            boundaries = [i for i in (tail.find("\n---"), tail.find("\n<!--")) if i >= 0]
            end = min(boundaries) if boundaries else len(tail)
            text = text[:match.start()] + tail[end:]

    text = visible_checklist_re.sub("\n", text)
    text = comment_checklist_re.sub("", text)
    text = metadata_re.sub("", text)
    # Nikdy nepustit český titul na titulku (řeší ji partials/before-body.tex).
    text = re.sub(r"^\*\(Czech title for the record[^\n]*\n?", "", text, flags=re.M)
    text = re.sub(r"\n{3,}", "\n\n", text)

    # Paths are authored relative to kapitoly/cs; staged files sit in kniha/.
    text = text.replace("](" + "../../vystupy/", "](" + "../vystupy/")
    text = text.replace("](" + "vystupy/", "](" + "../vystupy/")

    output = "index.md" if filename == "00-front-matter.md" else filename
    with open(output, "w", encoding="utf-8") as handle:
        handle.write(text.rstrip() + "\n")

print(f"Synced {len(files)} {lang.upper()} source files.")
PY
}

render_language() {
  local lang="$1"
  local formats=()

  # Povinná brána: každá citace v textu musí mít záznam v 99-references.md.
  # Čeština je primární verze → build spadne při chybějící citaci v CZ.
  # Používá česky uvědomělý 96_check_references.py (spojka „a", „a kol.",
  # přivlastňovací a deklinační tvary příjmení), který zvládá českou morfologii.
  if [ "$lang" = "cs" ] && [ -f ../analyzy/scripts/96_check_references.py ]; then
    "$PY" ../analyzy/scripts/96_check_references.py \
      --chapters ../kapitoly/cs --refs ../kapitoly/cs/99-references.md || {
      echo "96_check_references.py (CZ) FAILED — oprav literaturu před renderem." >&2
      return 1
    }
  fi
  # TVRDÁ brána em-dash (pravidlo: 0 dlouhých pomlček v celé knize;
  # en-dash '–' v rozsazích OK) + INFORMATIVNÍ brána čísel 95 (próza ↔ manifesty).
  # Plné ukotvení všech čísel v knize je zatím backlog (tier C), proto 95 jen varuje.
  if [ "$lang" = "cs" ]; then
    if grep -l "—" ../kapitoly/cs/*.md >/dev/null 2>&1; then
      echo "em-dash '—' nalezen v kapitoly/cs (pravidlo: 0 v celé knize) — nahraď en-dash '–':" >&2
      grep -n "—" ../kapitoly/cs/*.md >&2
      return 1
    fi
    # TVRDÁ brána vnitřních odkazů (revize S5): žádný odkaz na neexistující kotvu {#sec-…}.
    if [ -f ../analyzy/scripts/97_krizove_odkazy.py ]; then
      "$PY" ../analyzy/scripts/97_krizove_odkazy.py --chapters ../kapitoly/cs || {
        echo "97_krizove_odkazy FAILED — visící vnitřní odkaz (oprav, nebo spusť s --apply)." >&2
        return 1
      }
    fi
    # TVRDÁ brána čísel (rozhodnutí D30, 9. 10. 2026): každé tvrdé číslo v próze se
    # automaticky hledá ve výstupech analýz (vystupy/tabulky/*.csv + data/processed/*.md).
    if [ -f ../analyzy/scripts/95_check_cisla.py ]; then
      "$PY" ../analyzy/scripts/95_check_cisla.py || {
        echo "95_check_cisla FAILED — číslo v textu se nenašlo ve výstupech analýz." >&2
        return 1
      }
    fi
  fi

  sync_language "$lang"
  if [ "$format" = "all" ]; then
    formats=(docx pdf)
  else
    formats=("$format")
  fi

  if command -v quarto >/dev/null; then
    for target in "${formats[@]}"; do
      quarto render --profile "$lang" --to "$target" --no-clean
    done
    # Obálku (síť) předřadíme jako 1. stranu PDF. Cover PDF je v A4; pypdf.
    if printf '%s\n' "${formats[@]}" | grep -qx pdf; then
      coverpdf="cover/cover_final-cs.pdf"
      bookpdf="../vystupy/export/habilitace-CZ.pdf"
      if [ -f "$coverpdf" ]; then
        "$PY" - "$coverpdf" "$bookpdf" <<'PY'
import sys
from pypdf import PdfWriter, PdfReader
coverpdf, book = sys.argv[1], sys.argv[2]
w = PdfWriter()
w.append(PdfReader(coverpdf))   # 1. strana = obálka
w.append(PdfReader(book))       # pak celá kniha
with open(book, "wb") as f:
    w.write(f)
print(f"cover prepended -> {book}")
PY
      fi
    fi
  else
    if [ "$format" != "docx" ]; then
      echo "Quarto is required for PDF rendering." >&2
      return 1
    fi
    local title="Subjektivně vnímaná spravedlnost a její měření u studentů učitelství"
    local output="../vystupy/export/habilitace-CZ.docx"
    mkdir -p ../vystupy/export
    pandoc --from gfm --toc --toc-depth=2 \
      --metadata title="$title" --metadata author="Jan Nehyba" \
      --resource-path=..:../vystupy/obrazky -o "$output" \
      index.md 0[1-9]-*.md 10-*.md 99-references.md 98-abbreviations.md \
      appendix-A-*.md appendix-B-*.md appendix-C-*.md appendix-D-*.md appendix-E-*.md
  fi
}

# Keep the staging directory in its documented CZ state after any build.
restore_primary_staging() {
  local status=$?
  trap - EXIT
  set +e
  sync_language cs >/dev/null 2>&1
  exit "$status"
}
trap restore_primary_staging EXIT

render_language cs

echo "OK: ../vystupy/export/"
