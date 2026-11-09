"""Kontrola, že stylistická úprava kapitoly nezměnila fakta (úprava čitelnosti, 14. 10. 2026).

Porovná kapitolu v pracovní kopii s její verzí v gitu (výchozí HEAD) a hlásí rozdíly v tom,
co se při úpravě čitelnosti měnit nesmí:
  - čísla v próze (multimnožina, včetně desetinných čárek, intervalů a p-hodnot),
  - citace v textu (příjmení + rok, např. „Marsh et al., 2014“, „Hennig (2007)“),
  - vnitřní odkazy (#sec-…) a webové odkazy,
  - řádky tabulek (začínají „|“), citované bloky („>“), HTML komentáře, nadpisy a kotvy,
  - pracovní seznam literatury kapitoly.
Pořadí v textu se smí změnit (věty se přeskupují), proto se porovnávají multimnožiny.

Užití (z habilitace-1): python analyzy/scripts/94_srovnani_faktu.py kapitoly/cs/07-study3-structure.md [--ref HEAD]
Návratový kód 1 = některá kategorie se liší.
"""
from __future__ import annotations

import argparse
import collections
import re
import subprocess
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

NUM = re.compile(r"(?<![\w#-])[−-]?\d+(?:[  ]\d{3})*(?:,\d+)?(?:\s?%)?")
CIT = re.compile(
    r"([A-ZÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ][\w'’\-]+(?:\s(?:&|a)\s[A-ZÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ][\w'’\-]+)?(?:\set al\.)?)"
    r"(?:,\s|\s\()(\d{4}[a-z]?)")
SEC = re.compile(r"\(#sec-[^)]+\)")
URL = re.compile(r"https?://[^\s)>\]]+")
QUOTE = re.compile(r"„([^“„]{3,}?)“")
SENT = re.compile(r"(?<=[.!?])\s+(?=[A-ZÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ„(*])")


def sentence_stats(text: str) -> tuple[int, float, int, int]:
    """Počet vět, průměrná délka, nejdelší věta a počet vět nad 40 slov (jen souvislá próza)."""
    text = re.sub(r"<!--.*?-->", " ", text.replace("\r\n", "\n"), flags=re.S)
    text = text.split("### Literatura (pracovní seznam")[0]
    skip = ("|", ">", "#", "!", "- ", "*Obr", "*Tab", "**Tabulka", "*Zdroj", "*Pozn")
    prose = " ".join(l for l in text.split("\n") if not l.lstrip().startswith(skip))
    prose = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", prose)
    lens = [len(s.split()) for s in SENT.split(prose) if len(s.split()) > 2]
    if not lens:
        return 0, 0.0, 0, 0
    return len(lens), sum(lens) / len(lens), max(lens), sum(l > 40 for l in lens)


def parts(text: str) -> dict[str, collections.Counter]:
    text = text.replace("\r\n", "\n")
    comments = re.findall(r"<!--.*?-->", text, flags=re.S)
    body = re.sub(r"<!--.*?-->", " ", text, flags=re.S)
    head, _, refs = body.partition("### Literatura (pracovní seznam")
    lines = head.split("\n")
    tables = [l.strip() for l in lines if l.lstrip().startswith("|")]
    quotes = [l.strip() for l in lines if l.lstrip().startswith(">")]
    headings = [l.strip() for l in lines if l.startswith("#")]
    prose = "\n".join(l for l in lines if not (l.lstrip().startswith("|") or l.lstrip().startswith(">") or l.startswith("#")))
    prose_nolinks = SEC.sub("", URL.sub("", prose))
    return {
        "čísla v próze": collections.Counter(n.replace(" ", " ").strip() for n in NUM.findall(prose_nolinks)),
        "citace": collections.Counter(f"{a} {y}" for a, y in CIT.findall(prose)),
        "doslovné citace v uvozovkách": collections.Counter(q.strip() for q in QUOTE.findall(prose)),
        "vnitřní odkazy": collections.Counter(SEC.findall(head)),
        "webové odkazy": collections.Counter(URL.findall(head)),
        "řádky tabulek": collections.Counter(tables),
        "citované bloky": collections.Counter(quotes),
        "nadpisy a kotvy": collections.Counter(headings),
        "HTML komentáře": collections.Counter(c.strip() for c in comments),
        "pracovní seznam literatury": collections.Counter(l.strip() for l in refs.split("\n") if l.strip()),
    }


def merged(texts: list[str]) -> dict[str, collections.Counter]:
    out: dict[str, collections.Counter] = {}
    for t in texts:
        for k, v in parts(t).items():
            out.setdefault(k, collections.Counter()).update(v)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("soubor", type=Path, nargs="?")
    ap.add_argument("--ref", default="HEAD")
    ap.add_argument("--kniha", action="store_true",
                    help="porovnat celou knihu (kapitoly/cs bez 99-references.md); přesuny mezi soubory se vyrovnají")
    a = ap.parse_args()
    top = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()).resolve()
    if a.kniha:
        cap = Path(__file__).resolve().parents[2] / "kapitoly" / "cs"
        relcap = cap.relative_to(top).as_posix()
        names = subprocess.check_output(["git", "-C", str(top), "ls-tree", "--name-only", "--full-tree", a.ref,
                                         relcap + "/"], text=True).split()
        old_files = [n for n in names if n.endswith(".md") and not n.endswith("99-references.md")]
        if not old_files:
            print(f"❌ v {a.ref} nejsou žádné kapitoly ({relcap}); nic k porovnání.")
            return 1
        olds = [subprocess.check_output(["git", "-C", str(top), "show", f"{a.ref}:{n}"]).decode("utf-8")
                for n in old_files]
        news = [p.read_bytes().decode("utf-8") for p in sorted(cap.glob("*.md")) if p.name != "99-references.md"]
        po, pn = merged(olds), merged(news)
        old, new = "\n".join(olds), "\n".join(news)
        print(f"celá kniha: {len(old_files)} souborů v {a.ref}, {len(news)} v pracovní kopii")
    else:
        if a.soubor is None:
            ap.error("zadej soubor, nebo --kniha")
        rel = a.soubor.resolve().relative_to(top).as_posix()
        old = subprocess.check_output(["git", "show", f"{a.ref}:{rel}"]).decode("utf-8")
        new = a.soubor.read_bytes().decode("utf-8")
        po, pn = parts(old), parts(new)
    bad = 0
    for k in po:
        if po[k] != pn[k]:
            bad += 1
            ubylo = po[k] - pn[k]
            pribylo = pn[k] - po[k]
            print(f"❌ {k}: ubylo {sum(ubylo.values())}, přibylo {sum(pribylo.values())}")
            for x, n in list(ubylo.items())[:12]:
                print(f"   − {x!r} ×{n}")
            for x, n in list(pribylo.items())[:12]:
                print(f"   + {x!r} ×{n}")
        else:
            print(f"✅ {k}: beze změny ({sum(po[k].values())})")
    wo = len(re.sub(r"<!--.*?-->", "", old, flags=re.S).split())
    wn = len(re.sub(r"<!--.*?-->", "", new, flags=re.S).split())
    print(f"slova: {wo} → {wn}")
    if a.kniha:
        def agg(texts):
            st = [sentence_stats(t) for t in texts]
            n = sum(s[0] for s in st)
            return (n, sum(s[0] * s[1] for s in st) / n if n else 0.0,
                    max((s[2] for s in st), default=0), sum(s[3] for s in st))
        so, sn = agg(olds), agg(news)
    else:
        so, sn = sentence_stats(old), sentence_stats(new)
    print(f"věty: {so[0]} → {sn[0]}; průměrná délka {so[1]:.1f} → {sn[1]:.1f} slov; "
          f"nejdelší {so[2]} → {sn[2]}; nad 40 slov {so[3]} → {sn[3]}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
