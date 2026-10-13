# perceived-justice-preservice-teachers

> ⚠️ **Draft, not an official submission.** This is a working draft of a habilitation monograph. It is **not** an officially submitted, filed, or defended habilitation thesis.

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
- `vystupy/export/habilitace-CZ.pdf` — the rendered monograph (in Czech, with an English abstract); its figure/table captions link directly back to the notebooks, scripts and datasets in this repository.
- `kniha/` — Quarto book build configuration.
- `docs/` — a plain-language landing page (GitHub Pages) for non-technical readers.

## What is deliberately NOT here
Raw data (contains or derives from identifiers), source questionnaire exports, third-party materials (other theses, MU brand assets and fonts), and all personal/administrative documents. Only anonymized, redistributable, reproducibility-relevant material is published.

## Verify the book's numbers (three ways)
Every hard number in the book is anchored to a **number manifest** (`vystupy/tabulky/<chapter>_cisla.csv`) produced by an analysis notebook. A plain-language Czech guide is in [`JAK-OVERIT-CISLA.md`](JAK-OVERIT-CISLA.md).
1. **No install (2 min).** Open the manifest CSV for a chapter and look up the number from the book. When the book is built, every hard number in its text is automatically searched for in the output tables in `vystupy/tabulky/`; the build fails if a number is missing.
2. **In the browser (Binder, ~15 min first run).** Click the Binder badge above; RStudio opens in your browser with nothing installed locally. Render a notebook in `analyzy/notebooks/` and compare with the book. The environment uses R 4.5 with a CRAN snapshot of 10 July 2026, i.e. the package versions recorded in `renv.lock`; on 9 October 2026 all five notebooks rendered in it (the network notebook 30 takes about 40 minutes), and the frozen outputs of notebooks 20, 40 and 50 were last computed in it on 13 October 2026. Parallel analysis runs serially so that the fixed seed gives the same result on every run.
3. **Locally.** `./reproduce.sh` restores the R environment (`renv`), renders the notebooks, regenerates figures, and runs the gates.

## Reproduce
- Analyses: render the Quarto notebooks in `analyzy/notebooks/` (R 4.5.3; packages pinned in `renv.lock`, completed on 10 October 2026 with the packages used only by the notebooks). Each notebook writes its manifest to `vystupy/tabulky/`.
- Data prep: `python3 analyzy/scripts/03_prepare_forms.py` (Python 3.11; see `requirements.txt`).
- Gates: `python3 analyzy/scripts/95_check_cisla.py` (every hard number in the prose is searched for in the output tables) and `analyzy/scripts/96_check_references.py` (citations ↔ references). Both need the chapter sources (`kapitoly/cs/`), which are not part of this repository; here the number gate stops with "nic k ověření" (nothing to check) instead of reporting success.
- Book: `cd kniha && ./build.sh cs pdf` (Quarto; the book is in Czech; MUNI fonts not included — substitute or install locally).

## Ethics
Participation was voluntary; the consent statement described anonymous academic and research use of the data (see the monograph's ethics appendix). In some cohorts the forms recorded an e-mail address; addresses and other direct identifiers were removed before analysis and are not present in this repository. The data keep gender, year of birth, fields of study and prior teaching experience; in combination these can be unique within a cohort.

## Cite
See `CITATION.cff`. Please cite the monograph and the GitHub repository URL shown there.

## License
The whole repository (code, data, text, and figures) is licensed under **CC BY-NC 4.0** (non-commercial, with attribution). See `LICENSE`.
