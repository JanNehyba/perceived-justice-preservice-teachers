#!/usr/bin/env python3
"""Trvalá kontrola literatury: každá in-textová citace (Autor, rok) v kapitolách
musí mít záznam v konsolidovaném seznamu 99-references.md — a osiřelé záznamy
(bez jediné citace v textu) se hlásí jako varování.

Užití:  python3 analyzy/scripts/check_references.py  [--chapters DIR] [--refs FILE]
Exit 1 = existuje citace bez záznamu (blokuje build); orphany jsou jen warning.
Klíč = (příjmení PRVNÍHO autora bez diakritiky/částic, rok). Stdlib only.
Volá se z kniha/build.sh před každým EN renderem.
"""
from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path

HERE = Path(__file__).resolve()
DEFAULT_CHAPTERS = HERE.parents[2] / "kapitoly" / "en"
DEFAULT_REFS = DEFAULT_CHAPTERS / "99-references.md"

YEAR = r"(?:1[89]|20)\d{2}[a-z]?"
NAMEWORD = r"[A-ZŠČŘŽÝÁÍÉÚŮĎŤŇÓ][\w'’\-]*"

MONTHS = {
    "january", "february", "march", "april", "may", "june", "july", "august",
    "september", "october", "november", "december",
    "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "sept", "oct",
    "nov", "dec",
}
# Kapitalizovaná běžná slova, která nejsou příjmení (nadpisy, popisky, zkraty vět).
STOPWORDS = {
    "chapter", "table", "figure", "section", "appendix", "study", "version",
    "wave", "tier", "volume", "vol", "loadings", "pooled", "data", "sample",
    "invariance", "network", "model", "scale", "items", "item", "justice",
    "cohort", "cohorts", "since", "until", "spring", "autumn", "fall",
    "winter", "summer", "part", "panel", "note", "source", "results",
}
PARTICLES = {"van", "von", "de", "der", "den", "ten", "te", "la", "le", "du"}
CORPORATE = {"r core team", "czech republic", "msmt"}


def normalize(surname: str) -> str:
    s = unicodedata.normalize("NFKD", surname)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return s.lower().strip()


def lead_surname(author_segment: str) -> str | None:
    """Z '(van) Borkulo, C. D., van Bork, R.' / 'Chory-Assad & Paulsel' /
    'McCollough, Berry, & Yadav' / \"Adams's\" vydá normalizované příjmení
    PRVNÍHO autora (bez částic a přivlastňovacího 's)."""
    seg = author_segment.strip()
    seg = re.sub(r"^(?:e\.g\.|i\.e\.|see also|see|cf\.|viz|after|following|in|from)[,\s]+",
                 "", seg, flags=re.I)
    seg = re.split(r"\s+(?:&|and)\s+", seg)[0]          # jen před & / and
    seg = re.sub(r"\bet al\.?", "", seg)
    # první čárkový blok, který vypadá jako jméno — deskriptory typu
    # "Czech version BIDR-CZ, Preiss" přeskočit (obsahují malé slovo / číslici)
    chunks = [c.strip() for c in seg.split(",") if c.strip()]
    seg = ""
    for c in chunks:
        words = c.split()
        lowers = [w for w in words if w[0].islower() and w.lower() not in PARTICLES]
        if lowers or any(ch.isdigit() for ch in c):
            continue
        seg = c
        break
    seg = re.sub(r"[''’]s$", "", seg).strip(" .;:")      # Adams's → Adams
    if not seg:
        return None
    if normalize(seg) in CORPORATE:
        return normalize(seg)
    words = seg.split()
    # zahodit vedoucí částice (van Borkulo → Borkulo); poslední slovo = příjmení
    while words and words[0].lower() in PARTICLES:
        words = words[1:]
    if not words:
        return None
    surname = words[-1]
    key = normalize(surname)
    if key in MONTHS or key in STOPWORDS or len(key) < 2:
        return None
    if not re.match(r"^[a-z][\w'\-]*$", key):
        return None
    return key


def strip_noncited(text: str) -> str:
    """Odstraní HTML komentáře, code bloky, metadata blockquoty a kapitolové
    pracovní seznamy literatury — nic z toho není citace v textu."""
    text = re.sub(r"<!--.*?-->", " ", text, flags=re.S)
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    text = re.sub(r"^>[^\n]*$", " ", text, flags=re.M)
    m = re.search(r"\n#{2,4}\s+(?:References?|Literature|Literatura)\b", text, re.I)
    if m:
        tail = text[m.end():]
        cut = [i for i in (tail.find("\n---"), tail.find("\n#")) if i >= 0]
        text = text[: m.start()] + (tail[min(cut):] if cut else "")
    return text


def extract_citations(text: str) -> set[tuple[str, str]]:
    found: set[tuple[str, str]] = set()

    # 1) Závorkové skupiny (…; …) — každou část parsujeme zvlášť.
    for group in re.finditer(r"\(([^()]*?" + YEAR + r"[^()]*)\)", text):
        for part in group.group(1).split(";"):
            part = part.strip()
            ym = re.search(r"\b(" + YEAR + r")\b", part)
            if not ym:
                continue
            # segment autorů = text před rokem (bez závěrečné čárky)
            seg = part[: ym.start()].rstrip(" ,")
            if not seg or not re.search(NAMEWORD, seg):
                continue
            # "12 July" / "spring 2019" apod. — segment končící ne-jménem
            key = lead_surname(seg)
            if key:
                found.add((key, ym.group(1)))

    # 2) Narativní: Autor (2021) / A & B (2010) / A, B, and C (2019) / A et al. (…)
    for m in re.finditer(
        r"\b(" + NAMEWORD + r"(?:[\s\-]" + NAMEWORD + r")*"
        r"(?:\s*,\s*" + NAMEWORD + r"(?:[\s\-]" + NAMEWORD + r")*)*"
        r"(?:\s*,?\s+(?:&|and)\s+" + NAMEWORD + r"(?:[\s\-]" + NAMEWORD + r")*)?"
        r"(?:[''’]s)?(?:\s+et al\.?)?)\s*\((" + YEAR + r")\)",
        text,
    ):
        key = lead_surname(m.group(1))
        if key:
            found.add((key, m.group(2)))

    return found


def extract_refs(refs_text: str) -> dict[tuple[str, str], str]:
    entries: dict[tuple[str, str], str] = {}
    for para in refs_text.split("\n\n"):
        para = para.strip()
        if not para or para.startswith(("#", ">", "<!--", "This consolidated")):
            continue
        y = re.search(r"\((" + YEAR + r")(?:,|\))", para)
        m = re.match(r"^(?:- )?([^,(]+?)(?:,| \()", para)
        if not m or not y:
            continue
        key = lead_surname(m.group(1))
        if key is None:
            key = normalize(m.group(1).strip().rstrip("."))
        entries[(key, y.group(1))] = para.splitlines()[0][:90]
    return entries


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--chapters", type=Path, default=DEFAULT_CHAPTERS)
    ap.add_argument("--refs", type=Path, default=DEFAULT_REFS)
    args = ap.parse_args()

    refs = extract_refs(args.refs.read_text(encoding="utf-8"))

    cited: dict[tuple[str, str], set[str]] = {}
    for f in sorted(args.chapters.glob("*.md")):
        if f.name == "99-references.md":
            continue
        text = strip_noncited(f.read_text(encoding="utf-8"))
        for key in extract_citations(text):
            cited.setdefault(key, set()).add(f.name)

    def in_refs(s: str, y: str) -> bool:
        if (s, y) in refs:
            return True
        base = y.rstrip("abc")
        return any((s, base + suf) in refs for suf in ("", "a", "b", "c"))

    missing = [((s, y), fs) for (s, y), fs in sorted(cited.items())
               if not in_refs(s, y)]

    used = set()
    for (s, y) in cited:
        base = y.rstrip("abc")
        for key in refs:
            if key[0] == s and key[1].rstrip("abc") == base:
                used.add(key)
    orphans = [(k, v) for k, v in sorted(refs.items()) if k not in used]

    print(f"check_references: {len(cited)} unikátních citací v textu, "
          f"{len(refs)} záznamů v seznamu.")
    if missing:
        print(f"\n❌ CITACE BEZ ZÁZNAMU ({len(missing)}):")
        for (s, y), files in missing:
            print(f"   ({s}, {y})  ←  {', '.join(sorted(files))}")
    if orphans:
        print(f"\n⚠️  záznamy bez citace v textu ({len(orphans)}) — jen varování:")
        for (s, y), head in orphans:
            print(f"   {head}")
    if not missing and not orphans:
        print("✅ literatura konzistentní (0 chybějících, 0 osiřelých).")
    elif not missing:
        print("\n✅ žádná citace bez záznamu (osiřelé záznamy nejsou blokující).")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
