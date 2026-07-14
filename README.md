# perceived-justice-preservice-teachers

Companion repository — data, analysis code, and reproducible outputs for the habilitation monograph *Perceived Justice and Its Measurement Among Czech Pre-Service Teachers* (Jan Nehyba, Faculty of Education, Masaryk University, 2026).

Repository: <https://github.com/JanNehyba/perceived-justice-preservice-teachers>

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

## Reproduce
- Data prep: `python3 analyzy/scripts/03_prepare_forms.py` (Python 3.11; see `requirements.txt`).
- Analyses: render the Quarto notebooks in `analyzy/notebooks/` (R 4.5.3; packages pinned in `renv.lock`). Each notebook writes its manifest to `vystupy/tabulky/`.
- Book: `cd kniha && ./build.sh en pdf` (Quarto; MUNI fonts not included — substitute or install locally).

## Ethics
Participation was voluntary and anonymous; informed consent covered anonymous academic and research use of the data (see the monograph's ethics appendix). No direct identifiers are present in this repository.

## Cite
See `CITATION.cff`. Please cite the monograph and this repository's archival DOI (see the release/OSF record).

## License
Code: MIT. Data, text, and figures: CC BY 4.0. See `LICENSE`.
