#!/usr/bin/env python3
"""Brána čísel: každé tvrdé číslo v próze se automaticky hledá ve výstupech analýz.

Rozhodnutí D30 (revize 9. 10. 2026): místo ručních kotev se každé tvrdé číslo
v `kapitoly/cs/*.md` vyhledá ve VŠECH výstupech analýz a hlásí se jen ta čísla,
která se nikde nenašla. Prohledává se:
  - každá buňka všech `vystupy/tabulky/*.csv` (manifesty *_cisla.csv i datové tabulky),
  - čísla v dokumentaci zpracovaných dat `data/processed/*.md` (DATA_README, codebooky).

Shoda: číslo z prózy se porovná po zaokrouhlení hodnoty z výstupu na přesnost prózy
(0,812 ~ 0.8123); u procent se zkouší i podíl ×100 (44,2 % ~ 0.442); celá čísla
se porovnávají přesně; záporné hodnoty i v absolutní hodnotě (korelace se znaménkem).

Tvrdé číslo = desetinné (0,64), procento (72 %), N s mezerou (1 319), celé číslo ≥ 20.
Mimo záběr: roky 1900–2099, rozsahy škál (1–7), čísla u odkazů na tabulku/obrázek/
kapitolu/přílohu/stranu, HTML komentáře, inline kód, odkazy, nadpisy, blockquoty, kód,
bibliografie (99-references.md, pracovní seznamy „Literatura“ v kapitolách). Výslovná
výjimka: `<!-- necislo: důvod -->` hned za číslem kryje jen toto jedno číslo (nastavení
analýzy, kombinatorika návrhu, rozdíl vykázaných hodnot, citovaný údaj z literatury).

Volitelné ruční kotvy `<!-- manifest soubor: klíč=hodnota -->` se dál kontrolují přesně.

Užití: python analyzy/scripts/95_check_cisla.py [--warn] [--verbose] [soubor.md …]
Exit 1 = číslo nenalezené ve výstupech nebo neshoda kotvy (HARD; --warn jen varuje).
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
ROOT = HERE.parents[2]
DEFAULT_CHAPTERS = ROOT / "kapitoly" / "cs"
DEFAULT_TABULKY = ROOT / "vystupy" / "tabulky"
DEFAULT_DOCS = ROOT / "data" / "processed"

ANCHOR = re.compile(r"<!--\s*manifest\s+([\w\-\.]+?)(?:\.csv)?\s*:\s*(.+?)\s*=\s*([^\s>]+)\s*-->")
SUPPRESS = re.compile(r"<!--\s*necislo\b[^>]*-->")

SP = "[   ]"  # mezera, NBSP, úzká NBSP (oddělovač tisíců)
NUM_PATTERNS = [
    re.compile(r"\d{1,3}(?:" + SP + r"\d{3})+(?:[.,]\d+)?"),  # 1 319 / 2 991,1
    re.compile(r"[−\-]?\d+[.,]\d+"),          # desetinné (0,64 / -0.85)
    re.compile(r"\d+\s?%"),                   # 72 % / 72%
    re.compile(r"\b\d{2,}\b"),                # celá čísla (filtr níže: ≥ 20)
]
YEAR_RE = re.compile(r"\b(?:19|20)\d{2}[a-z]?\b")
SOFT_CONTEXT = re.compile(
    r"(?:Tabulk[aáue]\w*|tabulk[aáue]\w*|Obrázk?[uůey]?\w*|Obrázek|obr\.|tab\.|kapitol\w*|Kapitol\w*|"
    r"kap\.|RQ|přílo[hz]\w*|Přílo[hz]\w*|§|Studi[eií]\w*|verz\w*|List|škál[aey]?\s*\d|krok\w*|"
    r"oddíl\w*|www|http|doi|ISBN|\bs\.|\bpp?\.|\bstr\.|\bč\.|No\.|Article|"
    r"K[123]\b|S[1-7]\b|A\d{1,2}\b|F[0-9]\b|J[0-9]\b|P[0-9]\b|E[0-9]\b|D[0-9]\b)",
)
RANGE_RE = re.compile(r"[−\-]?\d+\s*[–\-\.]{1,2}\s*[−\-+]?\d+(?![.,]\d)")
CI_BOILER = re.compile(r"95\s?%\s?(?:CI|interval)")
ITEM_RE = re.compile(r"\b(?:item|položk\w*|b)_?\d+\b")


def to_float(tok: str) -> float | None:
    s = re.sub(SP, "", tok).replace(",", ".").replace("−", "-").rstrip("%").strip()
    try:
        return float(s)
    except ValueError:
        return None


def build_index(tabulky: Path, docs: Path) -> tuple[list[float], int]:
    vals: set[float] = set()
    nfiles = 0
    for f in sorted(tabulky.glob("*.csv")):
        nfiles += 1
        with f.open(encoding="utf-8", newline="") as fh:
            for row in csv.reader(fh):
                for cell in row:
                    v = to_float(cell)
                    if v is not None:
                        vals.add(v)
                        if "e" in cell.lower():  # 6.69e-16 -> próza „6,7 × 10⁻¹⁶“
                            vals.add(float(cell.lower().split("e")[0]))
                    else:  # buňky typu „0.81 [0.78, 0.84]“ nebo „44.2%“
                        for m in re.finditer(r"[−\-]?\d+(?:[.,]\d+)?", cell):
                            w = to_float(m.group(0))
                            if w is not None:
                                vals.add(w)
    for f in sorted(docs.glob("*.md")):
        nfiles += 1
        for m in re.finditer(r"[−\-]?\d{1,3}(?:[  ]\d{3})+|[−\-]?\d+(?:[.,]\d+)?", f.read_text(encoding="utf-8")):
            w = to_float(m.group(0))
            if w is not None:
                vals.add(w)
    return sorted(vals), nfiles


def found(tok: str, index: list[float]) -> bool:
    x = to_float(tok)
    if x is None:
        return True
    norm = tok.replace(",", ".").replace("−", "-").rstrip("%").strip()
    dec = len(norm.split(".")[1]) if "." in norm else 0
    is_pct = tok.strip().endswith("%")
    tol = 10 ** (-dec) / 2 + 1e-9
    cands = [x, abs(x)]
    for v in index:
        tests = [v, abs(v)]
        if is_pct and abs(v) <= 1:
            tests += [v * 100, abs(v) * 100]
        for t in tests:
            if dec == 0 and not is_pct:
                if float(t).is_integer() and t in cands:
                    return True
            elif any(abs(round(t, dec) - c) < tol for c in cands):
                return True
    return False


def hard_numbers(text: str) -> list[str]:
    s = re.sub(r"<!--.*?-->", " ", text)
    s = re.sub(r"https?://\S+", " ", s)
    s = re.sub(r"`[^`]*`", " ", s)
    s = re.sub(r"!\[[^\]]*\]\([^)]*\)|\]\([^)]*\)", " ", s)
    s = re.sub(r"\{[#.][^}]*\}", " ", s)
    s = re.sub(r"\[@[^\]]*\]", " ", s)
    s = CI_BOILER.sub(" ", s)
    s = ITEM_RE.sub(" ", s)
    s = YEAR_RE.sub(" ", s)
    s = RANGE_RE.sub(" ", s)
    for m in list(SOFT_CONTEXT.finditer(s)):
        s = s[: m.start()] + " " * (m.end() - m.start()) + re.sub(
            r"^[\s\.]*[A-Z]?[\d\.,]+", lambda x: " " * len(x.group(0)), s[m.end():], count=1)
    out: list[tuple[int, str]] = []
    taken: list[tuple[int, int]] = []
    for pat in NUM_PATTERNS:
        for m in pat.finditer(s):
            if any(a < m.end() and m.start() < b for a, b in taken):
                continue
            tok = m.group(0)
            if pat is NUM_PATTERNS[3] and int(tok) < 20:
                continue
            taken.append((m.start(), m.end()))
            out.append((m.start(), tok))
    return [t for _, t in sorted(out)]  # v pořadí výskytu


def paragraphs(path: Path):
    in_code = in_lit = False
    buf: list[str] = []
    start = None
    for ln, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#"):  # pracovní seznam literatury kapitoly = bibliografie
            in_lit = bool(re.match(r"#+\s*Literatura\b", stripped))
        if stripped.startswith("```"):
            in_code = not in_code
            continue
        skip = in_code or in_lit or line.lstrip().startswith((">", "#"))
        if not stripped or skip:
            if buf:
                yield start, " ".join(buf)
                buf, start = [], None
            continue
        if start is None:
            start = ln
        buf.append(line)
    if buf:
        yield start, " ".join(buf)


def load_manifests(tabulky: Path) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for f in tabulky.glob("*_cisla.csv"):
        d: dict[str, str] = {}
        with f.open(encoding="utf-8") as fh:
            rd = csv.DictReader(fh)
            cols = rd.fieldnames or []
            kcol = "nazev" if "nazev" in cols else ("metric" if "metric" in cols else cols[0])
            vcol = "hodnota" if "hodnota" in cols else ("value" if "value" in cols else cols[1])
            for r in rd:
                d[str(r[kcol]).strip()] = str(r[vcol]).strip()
        out[f.stem] = d
    return out


def check_file(path: Path, index: list[float], manifests: dict[str, dict[str, str]]) -> tuple[list[str], int]:
    errors: list[str] = []
    n_checked = 0
    marker = re.compile(ANCHOR.pattern + "|" + SUPPRESS.pattern)
    for ln, text in paragraphs(path):
        pos = 0
        segments: list[tuple[str, bool]] = []
        for am in marker.finditer(text):
            segments.append((text[pos:am.start()], am.group(1) is None))
            pos = am.end()
            if am.group(1) is not None:
                mf, key, val = am.group(1), am.group(2), am.group(3)
                man = manifests.get(mf) or manifests.get(mf + "_cisla")
                if man is None or key not in man:
                    errors.append(f"{path.name}:{ln}: kotva {mf}:{key} nemá záznam v manifestu")
                elif to_float(val) is not None and not found(val, [to_float(man[key]) or 0.0]):
                    errors.append(f"{path.name}:{ln}: NESHODA kotvy {mf}:{key} {val} vs {man[key]}")
        segments.append((text[pos:], False))
        for seg, suppressed in segments:
            nums = hard_numbers(seg)
            if suppressed:  # výjimka kryje jen číslo bezprostředně před sebou
                nums = nums[:-1]
            for tok in nums:
                n_checked += 1
                if not found(tok, index):
                    i = seg.find(tok)
                    ctx = re.sub(r"\s+", " ", seg[max(0, i - 50): i + len(tok) + 30]).strip()
                    errors.append(f"{path.name}:{ln}: „{tok}“ není ve výstupech analýz | …{ctx}…")
    return errors, n_checked


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*", type=Path)
    ap.add_argument("--chapters", type=Path, default=DEFAULT_CHAPTERS)
    ap.add_argument("--tabulky", type=Path, default=DEFAULT_TABULKY)
    ap.add_argument("--docs", type=Path, default=DEFAULT_DOCS)
    ap.add_argument("--warn", action="store_true")
    args = ap.parse_args()
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except AttributeError:
        pass

    index, nfiles = build_index(args.tabulky, args.docs)
    manifests = load_manifests(args.tabulky)
    files = args.files or sorted(args.chapters.glob("*.md"))
    files = [f for f in files if f.name != "99-references.md"]
    all_errors: list[str] = []
    n_checked = 0
    for f in files:
        errs, n = check_file(f, index, manifests)
        all_errors += errs
        n_checked += n

    print(f"95_check_cisla: {len(files)} kapitol, {n_checked} tvrdých čísel, "
          f"hledáno v {nfiles} výstupech ({len(index)} různých hodnot).")
    if all_errors:
        print(f"\n❌ NENALEZENO ({len(all_errors)}):")
        for e in all_errors:
            print("   " + e)
    else:
        print("✅ každé tvrdé číslo v textu se našlo ve výstupech analýz.")
    return 0 if (not all_errors or args.warn) else 1


if __name__ == "__main__":
    sys.exit(main())
