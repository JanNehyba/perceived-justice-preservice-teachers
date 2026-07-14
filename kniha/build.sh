#!/usr/bin/env bash
# P8 build: synchronize the authoritative chapter sources into this staging
# directory, remove editorial-only metadata/checklists and duplicate working
# reference lists, then render a clean English and/or Czech book.
#
# Usage:
#   ./build.sh                    # EN, DOCX (CZ je ZMRAZENA — jen na explicitní ./build.sh cs)
#   ./build.sh en all             # EN, DOCX + PDF
#   ./build.sh cs pdf             # CZ only, PDF (až po finálním rozhodnutí o překladu)
#   ./build.sh both all           # EN + CZ, DOCX + PDF
set -euo pipefail
cd "$(dirname "$0")"

language="${1:-en}"
format="${2:-docx}"

# Also accept the former one-argument format form (for example ./build.sh pdf).
case "$language" in
  docx|pdf|all)
    format="$language"
    language="en"
    ;;
esac

case "$language" in en|cs|both) ;; *)
  echo "Unknown language '$language' (use en, cs, or both)." >&2
  exit 2
esac
case "$format" in docx|pdf|all) ;; *)
  echo "Unknown format '$format' (use docx, pdf, or all)." >&2
  exit 2
esac

sync_language() {
  local lang="$1"
  python3 - "$lang" <<'PY'
import os
import re
import sys

lang = sys.argv[1]
src = os.path.join("..", "kapitoly", lang)
# Přílohy mají od P9 (14. 7. 2026) v CZ jiné pořadí písmen (dle toku textu);
# EN zůstává u původního řazení, dokud neproběhne backport.
appendices = {
    "en": [
        "appendix-A-instrument.md",
        "appendix-B-vignettes.md",
        "appendix-C-supplementary-tables.md",
        "appendix-D-ethics.md",
        "appendix-E-typology-method.md",
    ],
    "cs": [
        "appendix-A-typology-method.md",
        "appendix-B-vignettes.md",
        "appendix-C-instrument.md",
        "appendix-D-supplementary-tables.md",
        "appendix-E-ethics.md",
    ],
}[lang]
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

    # Paths are authored relative to kapitoly/{en,cs}; staged files sit in kniha/.
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

  # Povinná brána: každá citace v textu musí mít záznam v 99-references.md
  # (a naopak se hlásí osiřelé záznamy). Build spadne při chybějící citaci.
  if [ "$lang" = "en" ] && [ -f ../analyzy/scripts/check_references.py ]; then
    python3 ../analyzy/scripts/check_references.py || {
      echo "check_references.py FAILED — oprav literaturu před renderem." >&2
      return 1
    }
  fi
  # CZ: brána literatury jen informativně (warn) — česká in-text citace může znít
  # „Colquitt a Rodell" místo „&"; nechceme kvůli tomu shodit build.
  if [ "$lang" = "cs" ] && [ -f ../analyzy/scripts/check_references.py ]; then
    python3 ../analyzy/scripts/check_references.py \
      --chapters ../kapitoly/cs --refs ../kapitoly/cs/99-references.md \
      || echo "check_references.py (CZ) hlásí neshody — zkontroluj, ale build pokračuje." >&2
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
    # Obálku (síť) předřadíme jako 1. stranu PDF (EN i CZ). Cover PDF je v A4; pypdf.
    if printf '%s\n' "${formats[@]}" | grep -qx pdf; then
      coverpdf="cover/cover_final.pdf"
      bookpdf="../vystupy/export/habilitace-EN.pdf"
      if [ "$lang" = "cs" ]; then
        coverpdf="cover/cover_final-cs.pdf"
        bookpdf="../vystupy/export/habilitace-CZ.pdf"
      fi
      if [ -f "$coverpdf" ]; then
        python3 - "$coverpdf" "$bookpdf" <<'PY'
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
    local title="Six Villages, Four Principles"
    local output="../vystupy/export/habilitace-EN.docx"
    if [ "$lang" = "cs" ]; then
      title="Šest vesnic, čtyři principy"
      output="../vystupy/export/habilitace-CZ.docx"
    fi
    mkdir -p ../vystupy/export
    pandoc --from gfm --toc --toc-depth=2 \
      --metadata title="$title" --metadata author="Jan Nehyba" \
      --resource-path=..:../vystupy/obrazky -o "$output" \
      index.md 0[1-9]-*.md 10-*.md 99-references.md \
      appendix-A-*.md appendix-B-*.md appendix-C-*.md appendix-D-*.md appendix-E-*.md
  fi
}

# Keep the staging directory in its documented EN state, even after a CZ build.
restore_english_staging() {
  local status=$?
  trap - EXIT
  set +e
  sync_language en >/dev/null 2>&1
  exit "$status"
}
trap restore_english_staging EXIT

case "$language" in
  en) render_language en ;;
  cs) render_language cs ;;
  both)
    render_language en
    render_language cs
    ;;
esac

echo "OK: ../vystupy/export/"
