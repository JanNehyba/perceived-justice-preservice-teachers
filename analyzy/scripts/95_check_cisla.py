#!/usr/bin/env python3
"""Brána čísel: próza ↔ manifesty (machine-checkable; poučení č. 5 z hab-1).

Kontroluje v `kapitoly/cs/*.md`:
1. KOTVY `<!-- manifest <soubor>: <klic>=<hodnota> -->`:
   - manifest `vystupy/tabulky/<soubor>.csv` existuje,
   - klíč v něm existuje,
   - hodnota kotvy odpovídá manifestu (porovnání po zaokrouhlení na přesnost kotvy;
     desetinná čárka i tečka).
2. NEKOTVENÁ TVRDÁ ČÍSLA v próze: řádek bez kotvy nesmí obsahovat tvrdé číslo.
   Tvrdé číslo = desetinné (0,64 / 0.64), procento (72 %), N s mezerou (1 319),
   celé číslo ≥ 20. Výjimky: roky 1900–2099, čísla v hlavičkách/citacích/odkazech
   na Tabulku/Obrázek/kapitolu/RQ/přílohu/§, rozsahy škál (1–4, −2..+2), řádek
   s markerem `<!-- necislo -->` (výslovná výjimka), metadata blockquote, kód,
   HTML komentáře.

Užití: ./.venv/bin/python habilitace-2/analyzy/scripts/95_check_cisla.py [--chapters DIR] [--tabulky DIR] [--warn] [soubor.md …]
Exit 1 = mismatch kotvy NEBO nekotvené tvrdé číslo (HARD; --warn jen varuje).
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
DEFAULT_CHAPTERS = HERE.parents[2] / "kapitoly" / "cs"
DEFAULT_TABULKY = HERE.parents[2] / "vystupy" / "tabulky"

# klíč smí obsahovat dvojtečku, lomítko, mezery i diakritiku (názvy kategorií);
# hodnota je token bez mezery před koncem kotvy.
ANCHOR = re.compile(r"<!--\s*manifest\s+([\w\-\.]+?)(?:\.csv)?\s*:\s*(.+?)\s*=\s*([^\s>]+)\s*-->")
# necislo smí nést zdůvodnění za dvojtečkou: <!-- necislo: proč -->
SUPPRESS = re.compile(r"<!--\s*necislo\b[^>]*-->")

# tvrdá čísla (v pořadí priorit)
NUM_PATTERNS = [
    re.compile(r"[−\-]?\d+[.,]\d+"),          # desetinné (0,64 / -0.85)
    re.compile(r"\d{1,3}(?: \d{3})+"),        # 1 319 (mezera jako oddělovač tisíců)
    re.compile(r"\d+\s?%"),                   # 72 % / 72%
    re.compile(r"\b\d{2,}\b"),                # celá čísla ≥ 10 (filtr níže: ≥20, ne rok)
]
YEAR_RE = re.compile(r"\b(?:19|20)\d{2}[a-z]?\b")
# kontexty, kde číslo NENÍ tvrdý údaj
SOFT_CONTEXT = re.compile(
    r"(?:Tabulk[aáue]\w*|Obrázk?[uůey]?\w*|Obrázek|kapitol\w*|Kapitol\w*|RQ|přílo[hz]\w*|Přílo[hz]\w*|"
    r"§|Studi[eií]\w*|verz\w*|List|škál[aey]?\s*\d|krok\w*|oddíl\w*|www|http|doi|ISBN|"
    r"K[123]\b|S[1-7]\b|A\d{1,2}\b|F[0-9]\b|J[0-9]\b|P[0-9]\b|E[0-9]\b|D[0-9]\b)",
)
RANGE_RE = re.compile(r"[−\-]?\d+\s*[–\-\.]{1,2}\s*[−\-+]?\d+")  # 1–4, −2..+2
CI_BOILER = re.compile(r"95\s?%\s?(?:CI|interval)")  # „95% CI" = statistická vata, ne údaj


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


def num_equal(anchor_val: str, manifest_val: str) -> bool:
    is_pct = anchor_val.strip().endswith("%")

    def norm(x: str) -> str:
        return (x.replace(" ", "").replace(" ", "")  # mezera/NBSP v tisících
                .replace(",", ".").replace("−", "-").rstrip("%"))
    a, m = norm(anchor_val), norm(manifest_val)
    try:
        fa, fm = float(a), float(m)
    except ValueError:
        return anchor_val.strip() == manifest_val.strip()
    if is_pct and abs(fm) <= 1:  # „72 %“ v próze vs podíl v manifestu
        fm = fm * 100
    # zaokrouhlení manifestu na přesnost kotvy
    dec = len(a.split(".")[1]) if "." in a else 0
    return abs(round(fm, dec) - fa) < 10 ** (-dec) / 2 + 1e-12


def hard_numbers(line: str) -> list[str]:
    """Vrátí tvrdá čísla na řádku (po odstranění soft kontextů)."""
    s = re.sub(r"<!--.*?-->", " ", line)
    s = re.sub(r"`[^`]*`", " ", s)  # inline kód (`99-references.md` apod.)
    s = re.sub(r"!\[[^\]]*\]\([^)]*\)|\[[^\]]*\]\([^)]*\)", " ", s)  # odkazy/obrázky
    s = CI_BOILER.sub(" ", s)
    s = YEAR_RE.sub(" ", s)
    s = RANGE_RE.sub(" ", s)
    # odstranit čísla přilepená k soft kontextu (Tabulka 6.1, RQ2, kap. 5…)
    for m in list(SOFT_CONTEXT.finditer(s)):
        s = s[: m.start()] + " " * (m.end() - m.start()) + re.sub(r"^[\s\.]*[\d\.,]+", lambda x: " " * len(x.group(0)), s[m.end():], count=1)
    found: list[str] = []
    taken: list[tuple[int, int]] = []
    for pat in NUM_PATTERNS:
        for m in pat.finditer(s):
            if any(a < m.end() and m.start() < b for a, b in taken):
                continue
            tok = m.group(0)
            if pat is NUM_PATTERNS[3]:  # celá čísla
                if int(tok) < 20:
                    continue
            taken.append((m.start(), m.end()))
            found.append(tok)
    return found


def paragraphs(path: Path):
    """Vrátí (číslo_prvního_řádku, spojený text odstavce) — próza po odstavcích;
    přeskočí kód, blockquoty, nadpisy a checklist sekci. Odstavce se spojují
    mezerou, protože čeština láme věty přes řádky (číslo a kotva mohou být
    na různých řádcích)."""
    in_code = in_checklist = False
    buf: list[str] = []
    start = None
    for ln, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if re.match(r"#{2,}\s*Kontrolní seznam", stripped):
            in_checklist = True
        elif line.startswith("#"):
            in_checklist = False
        if stripped.startswith("```"):
            in_code = not in_code
            continue
        skip = in_code or in_checklist or line.lstrip().startswith((">", "#"))
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


def check_file(path: Path, manifests: dict[str, dict[str, str]]) -> list[str]:
    """Po odstavcích: každá kotva (nebo <!-- necislo -->) se páruje s POSLEDNÍM
    tvrdým číslem v úseku od předchozí kotvy; zbylá čísla = nekotvená."""
    errors: list[str] = []
    marker = re.compile(ANCHOR.pattern + "|" + SUPPRESS.pattern)
    for ln, text in paragraphs(path):
        pos = 0
        for am in marker.finditer(text):
            span = text[pos:am.start()]
            pos = am.end()
            nums = hard_numbers(span)
            if am.group(1) is None:  # <!-- necislo --> kryje celý úsek před sebou
                continue
            mf, key, val = am.group(1), am.group(2), am.group(3)
            man = manifests.get(mf) or manifests.get(mf + "_cisla")
            if man is None:
                errors.append(f"{path.name}:{ln}: kotva na neexistující manifest „{mf}“")
                continue
            if key not in man:
                errors.append(f"{path.name}:{ln}: klíč „{key}“ není v manifestu {mf}")
                continue
            if not num_equal(val, man[key]):
                errors.append(
                    f"{path.name}:{ln}: NESHODA {mf}:{key} — kotva {val} vs manifest {man[key]}")
            elif nums and not num_equal(nums[-1], man[key]):
                errors.append(
                    f"{path.name}:{ln}: PRÓZA {nums[-1]} ≠ manifest {mf}:{key}={man[key]}")
            # čísla PŘED posledním v úseku zůstávají nekotvená → nahlásit
            for tok in nums[:-1]:
                errors.append(
                    f"{path.name}:{ln}: nekotvené tvrdé číslo „{tok}“ (v úseku před kotvou "
                    f"{key}) — každé číslo potřebuje vlastní kotvu nebo <!-- necislo -->")
        # ocas odstavce za poslední kotvou
        for tok in hard_numbers(text[pos:]):
            errors.append(
                f"{path.name}:{ln}: nekotvené tvrdé číslo „{tok}“ — doplň "
                f"<!-- manifest soubor: klic=hodnota --> nebo <!-- necislo -->")
    return errors


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*", type=Path)
    ap.add_argument("--chapters", type=Path, default=DEFAULT_CHAPTERS)
    ap.add_argument("--tabulky", type=Path, default=DEFAULT_TABULKY)
    ap.add_argument("--warn", action="store_true")
    args = ap.parse_args()

    manifests = load_manifests(args.tabulky)
    # 99-references.md je bibliografie (čísla svazků/stran/DOI) — mimo záběr
    # pravidla o analytických číslech; vynechat i při explicitních argumentech
    files = args.files or sorted(args.chapters.glob("*.md"))
    files = [f for f in files if f.name != "99-references.md"]
    all_errors: list[str] = []
    n_anchors = 0
    for f in files:
        text = f.read_text(encoding="utf-8")
        n_anchors += len(ANCHOR.findall(text))
        all_errors += check_file(f, manifests)

    print(f"95_check_cisla: {len(files)} souborů, {n_anchors} kotev, "
          f"{len(manifests)} manifestů ({', '.join(sorted(manifests))}).")
    if all_errors:
        print(f"\n❌ PROBLÉMY ({len(all_errors)}):")
        for e in all_errors:
            print("   " + e)
    else:
        print("✅ všechna čísla kotvená a shodná s manifesty.")
    return 0 if (not all_errors or args.warn) else 1


if __name__ == "__main__":
    sys.exit(main())
