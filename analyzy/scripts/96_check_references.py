#!/usr/bin/env python3
"""Brána literatury pro CZ-primární knihu (habilitace-2) — TVRDÁ.

Každá in-textová citace (Autor, rok) v kapitolách musí mít záznam
v kapitoly/cs/99-references.md. Adaptace hab-1 check_references.py s CZ podporou:
- „Novák a Svoboda (2020)" i „(Novák a Svoboda, 2020)" — spojka „a" jako &/and,
- „a kol." jako et al.,
- česká kapitalizovaná ne-příjmení ve stopwords.

Užití: ./.venv/bin/python habilitace-2/analyzy/scripts/96_check_references.py [--chapters DIR] [--refs FILE] [--warn]
Exit 1 = citace bez záznamu (HARD; --warn jen varuje — pouze pro zaváděcí fázi).
"""
from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path

HERE = Path(__file__).resolve()
DEFAULT_CHAPTERS = HERE.parents[2] / "kapitoly" / "cs"
DEFAULT_REFS = DEFAULT_CHAPTERS / "99-references.md"

YEAR = r"(?:1[89]|20)\d{2}[a-z]?"
NAMEWORD = r"[A-ZŠČŘŽÝÁÍÉÚŮĎŤŇÓ][\w'’\-]*"

MONTHS = {
    "january", "february", "march", "april", "may", "june", "july", "august",
    "september", "october", "november", "december", "jan", "feb", "mar", "apr",
    "jun", "jul", "aug", "sep", "sept", "oct", "nov", "dec",
    "ledna", "unora", "brezna", "dubna", "kvetna", "cervna", "cervence",
    "srpna", "zari", "rijna", "listopadu", "prosince",
}
STOPWORDS = {
    # EN (převzato z hab-1)
    "chapter", "table", "figure", "section", "appendix", "study", "version",
    "wave", "tier", "volume", "vol", "data", "sample", "model", "scale",
    "items", "item", "part", "panel", "note", "source", "results",
    # CZ
    "tabulka", "obrazek", "kapitola", "kapitole", "studie", "priloha", "graf",
    "verze", "vlna", "cast", "zdroj", "poznamka", "skala", "polozka", "polozky",
    "oddil", "obr", "tab", "rovnice", "krok", "faze", "kampan", "rez", "studii",
    "anotovani", "reseni", "vysledek", "dopad", "vhodnost", "kvalita",
}
PARTICLES = {"van", "von", "de", "der", "den", "ten", "te", "la", "le", "du"}
CORPORATE = {
    "r core team", "czech republic", "msmt", "masarykova univerzita",
    "ceska republika", "openai", "anthropic",
    "narodni pedagogicky institut cr", "ceska skolni inspekce",
}


def normalize(surname: str) -> str:
    s = unicodedata.normalize("NFKD", surname)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return s.lower().strip()


def lead_surname(author_segment: str) -> str | None:
    seg = author_segment.strip()
    seg = re.sub(
        r"^(?:e\.g\.|i\.e\.|see also|see|cf\.|viz|srov\.|napr\.|např\.|dle|podle|after|following|in|from|z|ze)[,\s]+",
        "", seg, flags=re.I)
    # spojka mezi autory: & / and / české „a"
    seg = re.split(r"\s+(?:&|and|a)\s+", seg)[0]
    seg = re.sub(r"\bet al\.?|\ba kol\.?", "", seg)
    chunks = [c.strip() for c in seg.split(",") if c.strip()]
    seg = ""
    for c in chunks:
        # korporátní autor (může obsahovat malá slova: „Národní pedagogický institut ČR")
        if normalize(c.strip(" .;:")) in CORPORATE:
            return normalize(c.strip(" .;:"))
        words = c.split()
        lowers = [w for w in words if w[0].islower() and w.lower() not in PARTICLES]
        if lowers or any(ch.isdigit() for ch in c):
            continue
        seg = c
        break
    seg = re.sub(r"[''’]s$", "", seg).strip(" .;:")
    if not seg:
        return None
    if normalize(seg) in CORPORATE:
        return normalize(seg)
    words = seg.split()
    while words and words[0].lower() in PARTICLES:
        words = words[1:]
    if not words:
        return None
    key = normalize(words[-1])
    if key in MONTHS or key in STOPWORDS or len(key) < 2:
        return None
    if not re.match(r"^[a-z][\w'\-]*$", key):
        return None
    return key


def strip_noncited(text: str) -> str:
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
    for group in re.finditer(r"\(([^()]*?" + YEAR + r"[^()]*)\)", text):
        for part in group.group(1).split(";"):
            part = part.strip()
            ym = re.search(r"\b(" + YEAR + r")\b", part)
            if not ym:
                continue
            seg = part[: ym.start()].rstrip(" ,")
            if not seg or not re.search(NAMEWORD, seg):
                continue
            key = lead_surname(seg)
            if key:
                found.add((key, ym.group(1)))
    # narativní: Novák (2020) / Novák a Svoboda (2020) / Novák a kol. (2020) / A & B (2010)
    for m in re.finditer(
        r"\b(" + NAMEWORD + r"(?:[\s\-]" + NAMEWORD + r")*"
        r"(?:\s*,\s*" + NAMEWORD + r"(?:[\s\-]" + NAMEWORD + r")*)*"
        r"(?:\s*,?\s+(?:&|and|a)\s+" + NAMEWORD + r"(?:[\s\-]" + NAMEWORD + r")*)?"
        r"(?:[''’]s)?(?:\s+(?:et al\.?|a kol\.?))?)\s*\((" + YEAR + r")\)",
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
        if not para or para.startswith(("#", ">", "<!--", "Konsolidovaný", "This consolidated")):
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
    ap.add_argument("--warn", action="store_true",
                    help="jen varovat (zaváděcí fáze prvních 2 kapitol)")
    args = ap.parse_args()

    refs = extract_refs(args.refs.read_text(encoding="utf-8"))
    cited: dict[tuple[str, str], set[str]] = {}
    for f in sorted(args.chapters.glob("*.md")):
        if f.name == "99-references.md":
            continue
        text = strip_noncited(f.read_text(encoding="utf-8"))
        for key in extract_citations(text):
            cited.setdefault(key, set()).add(f.name)

    def surname_variants(s: str) -> set[str]:
        """Česká deklinace a přivlastňovací tvary cizích příjmení.
        „podle Nováka" → novak; „dle Svobody/Nehyby" → svoboda/nehyba;
        „Novákovi/Novákem" → novak. Přivlastňovací adjektivum Xův/Xova/Xovo… se
        shoduje s rodem NÁSLEDUJÍCÍHO jména, ne s pohlavím autora: „Holmovou
        korekcí" → holm, „Rawlsově teorii" → rawls, „Adamsovo pojetí" → adams,
        „Elsterových" → elster, „Hennigovým" → hennig. Funkce jen PŘIDÁVÁ
        kandidáty (nemaže), takže ženská příjmení „Karasové → karasova" platí dál."""
        v = {s}
        # přivlastňovací adjektivum (delší koncovky nejdřív)
        for suf in ("ovych", "ovymi", "ovym", "ovou", "ove", "ova", "ovo",
                    "ovi", "ovem", "ovu", "uv", "ov"):
            if s.endswith(suf) and len(s) - len(suf) >= 3:
                v.add(s[: -len(suf)])
        for suf in ("ovi", "em", "ou"):
            if s.endswith(suf) and len(s) - len(suf) >= 3:
                v.add(s[: -len(suf)])
        if s.endswith(("a", "e", "u")) and len(s) >= 4:
            v.add(s[:-1])            # Nováka → novak
        if s.endswith(("y", "e")) and len(s) >= 4:
            v.add(s[:-1] + "a")      # Svobody → svoboda; Karasové → karasova
        return v

    def in_refs(s: str, y: str) -> bool:
        base = y.rstrip("abc")
        for cand in surname_variants(s):
            for suf in ("", "a", "b", "c"):
                if (cand, base + suf) in refs or (cand, y) in refs:
                    return True
        return False

    missing = [((s, y), fs) for (s, y), fs in sorted(cited.items()) if not in_refs(s, y)]
    used = set()
    for (s, y) in cited:
        base = y.rstrip("abc")
        for key in refs:
            if key[0] == s and key[1].rstrip("abc") == base:
                used.add(key)
    orphans = [(k, v) for k, v in sorted(refs.items()) if k not in used]

    print(f"96_check_references (CZ-HARD): {len(cited)} citací v textu, {len(refs)} záznamů.")
    if missing:
        print(f"\n❌ CITACE BEZ ZÁZNAMU ({len(missing)}):")
        for (s, y), files in missing:
            print(f"   ({s}, {y})  ←  {', '.join(sorted(files))}")
    if orphans:
        print(f"\n⚠️  záznamy bez citace ({len(orphans)}) — varování:")
        for (s, y), head in orphans:
            print(f"   {head}")
    if not missing:
        print("✅ žádná citace bez záznamu.")
    return 0 if (not missing or args.warn) else 1


if __name__ == "__main__":
    sys.exit(main())
