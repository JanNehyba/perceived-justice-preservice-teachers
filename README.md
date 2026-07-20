# perceived-justice-preservice-teachers

Companion repository — data, analysis code, and reproducible outputs for the habilitation monograph *Perceived Justice and Its Measurement Among Czech Pre-Service Teachers* (Jan Nehyba, Faculty of Education, Masaryk University, 2026).

Repository: <https://github.com/JanNehyba/perceived-justice-preservice-teachers>

[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/JanNehyba/perceived-justice-preservice-teachers/HEAD?urlpath=rstudio)

> **Work in progress.** This repository and the included monograph PDFs are being updated while the monograph is finalized. They are not a formal archival release.

## What is here
- `data/processed/` — **anonymized** analytic datasets (no direct identifiers), codebooks, and the item/version crosswalk. Data-boundary notes in `data/processed/DATA_README.md`.
- `analyzy/scripts/` — Python data-preparation scripts (01–03) and helper scripts.
- `analyzy/notebooks/` — R (Quarto) analysis notebooks, one per empirical chapter.
- `analyzy/figures/` — figure sources (Graphviz).
- `vystupy/tabulky/` — frozen number manifests (`<chapter>_cisla.csv`); every number in the book traces here.
- `vystupy/obrazky/` — figures as used in the book.
- `vystupy/export/habilitace-CZ.pdf` — the rendered monograph (**Czech, primary edition**); its figure/table captions link directly back to the notebooks, scripts and datasets in this repository. `habilitace-EN.pdf` — English edition (may lag the Czech).
- `kniha/` — Quarto book build configuration.
- `docs/` — a plain-language landing page (GitHub Pages) for non-technical readers.

## What is deliberately NOT here
Raw data (contains or derives from identifiers), source questionnaire exports, third-party materials (other theses, MU brand assets and fonts), and all personal/administrative documents. Only anonymized, redistributable, reproducibility-relevant material is published.

## Verify the book's numbers (three ways)
Every hard number in the book is anchored to a **number manifest** (`vystupy/tabulky/<chapter>_cisla.csv`) produced by an analysis notebook. A plain-language Czech guide is in [`JAK-OVERIT-CISLA.md`](JAK-OVERIT-CISLA.md).
1. **No install (2 min).** Open the manifest CSV for a chapter and match its keys to the `<!-- manifest chapter: key=value -->` comments in the book's source text.
2. **In the browser (Binder, ~15 min first run).** Click the Binder badge above; RStudio opens in your browser with nothing installed locally. Render a notebook in `analyzy/notebooks/` and compare with the book.
3. **Locally.** `./reproduce.sh` restores the R environment (`renv`), renders the notebooks, regenerates figures, and runs the gates.

## Reproduce
- Analyses: render the Quarto notebooks in `analyzy/notebooks/` (R 4.5.3; packages pinned in `renv.lock`). Each notebook writes its manifest to `vystupy/tabulky/`.
- Data prep: `python3 analyzy/scripts/03_prepare_forms.py` (Python 3.11; see `requirements.txt`).
- Gates: `python3 analyzy/scripts/95_check_cisla.py` (prose numbers ↔ manifests) and `analyzy/scripts/check_references.py` (citations ↔ references).
- Book: `cd kniha && ./build.sh` (Quarto; default is the **Czech primary** edition, `./build.sh en` for the English mirror; MUNI fonts not included — substitute or install locally).

## Ethics
Participation was voluntary and anonymous; informed consent covered anonymous academic and research use of the data (see the monograph's ethics appendix). No direct identifiers are present in this repository.

## Cite
See `CITATION.cff`. Please cite the monograph and the GitHub repository URL shown there.

## License
Code: MIT (see `LICENSE`). Data, text, and figures: CC BY 4.0 (see `DATA-LICENSE.md`).
