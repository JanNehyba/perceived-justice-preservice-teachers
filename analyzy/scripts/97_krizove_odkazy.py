"""Brána a nástroj pro vnitřní odkazy v kapitoly/cs (revize S5, 8. 10. 2026).

1. Každý číslovaný nadpis dostane kotvu: `# 5. …` → {#sec-kap-5}, `## 5.7 …` → {#sec-5-7},
   `# Příloha B: …` → {#sec-priloha-b}, `## B.2 …` → {#sec-b-2}.
2. Textové odkazy v próze („v oddílu 5.7", „příloha B", „kapitola 8", „kap. 7.3") se převedou
   na interní hypertextové odkazy `[v oddílu 5.7](#sec-5-7)`; v PDF jsou klikací.
3. Existující kotva u nadpisu zůstává i po přečíslování; čísla v textu odkazů se odvozují
   z cílového nadpisu, takže po přečíslování stačí skript spustit znovu (`--apply`).
4. Bez `--apply` jen kontroluje: hlásí odkazy na neexistující kotvy a textové odkazy bez
   hypertextu (návratový kód 1 při visícím odkazu).

Nemění nadpisy, HTML komentáře, metadata (řádky začínající „>"), pracovní seznamy literatury
ani text uvnitř existujících odkazů. Zachovává konce řádků souboru (CRLF/LF).

Užití: python analyzy/scripts/97_krizove_odkazy.py [--apply] [--chapters kapitoly/cs]
"""
import argparse
import pathlib
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
ap = argparse.ArgumentParser()
ap.add_argument("--chapters", default=str(pathlib.Path(__file__).resolve().parents[2] / "kapitoly" / "cs"))
ap.add_argument("--apply", action="store_true")
args = ap.parse_args()
root = pathlib.Path(args.chapters)
files = [p for p in sorted(root.glob("*.md")) if p.name not in ("99-references.md",)]

H_CHAP = re.compile(r"^(# )(\d+)\. (.+?)(\s*\{#[^}]+\})?\s*$")
H_SEC = re.compile(r"^(#{2,4} )(\d+(?:\.\d+)+) (.+?)(\s*\{#[^}]+\})?\s*$")
H_APP = re.compile(r"^(# )Příloha ([A-E]): (.+?)(\s*\{#[^}]+\})?\s*$")
H_APPSEC = re.compile(r"^(#{2,4} )([A-E](?:\.\d+)+) (.+?)(\s*\{#[^}]+\})?\s*$")


def sec_id(num):
    if re.fullmatch(r"[A-E](\.\d+)+", num):
        return "sec-" + num.lower().replace(".", "-")
    return "sec-" + num.replace(".", "-")


def keep(m):
    """Existující kotva zůstává (stabilní id i po přečíslování oddílu)."""
    g = m.group(4)
    return g.strip()[2:-1] if g else None


# --- 1. kotvy nadpisů + mapa id -> číslo (id se přidělí jen nadpisům bez kotvy)
targets = {}
texts = {}
for p in files:
    raw = p.read_bytes().decode("utf-8")
    nl = "\r\n" if "\r\n" in raw else "\n"
    out = []
    for line in raw.split(nl):
        m = H_CHAP.match(line)
        if m:
            i = keep(m) or f"sec-kap-{m.group(2)}"
            targets[i] = m.group(2)
            line = f"{m.group(1)}{m.group(2)}. {m.group(3)} {{#{i}}}"
        else:
            m = H_APP.match(line)
            if m:
                i = keep(m) or f"sec-priloha-{m.group(2).lower()}"
                targets[i] = m.group(2)
                line = f"{m.group(1)}Příloha {m.group(2)}: {m.group(3)} {{#{i}}}"
            else:
                for rx in (H_SEC, H_APPSEC):
                    m = rx.match(line)
                    if m:
                        i = keep(m) or sec_id(m.group(2))
                        targets[i] = m.group(2)
                        line = f"{m.group(1)}{m.group(2)} {m.group(3)} {{#{i}}}"
                        break
        out.append(line)
    texts[p] = (raw, nl, out)

# --- 2. textové odkazy -> hypertext
WORD_APP = r"(?:[Pp]říloh(?:a|y|e|u|ou|ách|ám))"
WORD_SEC = r"(?:oddíl(?:u|e|ech|ům|y|ů)?|pododdíl(?:u|e)?)"
WORD_KAP = r"(?:[Kk]apitol(?:a|y|e|u|ou|ách|ám)|kap\.)"
NUM = r"\d+(?:\.\d+)*"
RX_APP = re.compile(rf"\b({WORD_APP}) ([A-E])\b(?![.\d])")
RX_APP_SEC = re.compile(rf"\b({WORD_APP}|{WORD_SEC}) ([A-E](?:\.\d+)+)\b")
RX_SEC = re.compile(rf"\b({WORD_SEC}|{WORD_KAP}) ({NUM})(?:–(\d+(?:\.\d+)*))?\b")
LINK = re.compile(r"\[[^\]]*\]\([^)]*\)")
missing, plain = [], []


def protect(line):
    """Return spans that must not be touched (existing links, inline code)."""
    return [m.span() for m in LINK.finditer(line)] + [m.span() for m in re.finditer(r"`[^`]*`", line)]


def inside(pos, spans):
    return any(a <= pos < b for a, b in spans)


def link_line(line, fname, lineno):
    for rx, kind in ((RX_APP_SEC, "appsec"), (RX_APP, "app"), (RX_SEC, "sec")):
        spans = protect(line)
        res, last = [], 0
        for m in rx.finditer(line):
            if inside(m.start(), spans):
                continue
            word, num = m.group(1), m.group(2)
            if kind == "app":
                tid = f"sec-priloha-{num.lower()}"
            elif kind == "appsec":
                tid = sec_id(num)
            else:
                tid = f"sec-kap-{num}" if "." not in num and word.lower().startswith("kap") else sec_id(num)
                if "." not in num and not word.lower().startswith("kap"):
                    tid = sec_id(num)
            if tid not in targets:
                missing.append(f"{fname}:{lineno}: „{m.group(0)}“ → {tid} neexistuje")
                continue
            label = m.group(0)
            res.append(line[last:m.start()] + f"[{label}](#{tid})")
            last = m.end()
        if res:
            line = "".join(res) + line[last:]
    return line


in_lit = False
for p, (raw, nl, out) in texts.items():
    new = []
    in_comment = False
    for n, line in enumerate(out, 1):
        s = line.lstrip()
        if s.startswith("<!--"):
            in_comment = "-->" not in s
            new.append(line)
            continue
        if in_comment:
            in_comment = "-->" not in line
            new.append(line)
            continue
        if re.match(r"^#{1,4} ", line):
            in_lit = bool(re.match(r"^#{2,4} Literatura", line))
            new.append(line)
            continue
        if in_lit or s.startswith(">"):
            new.append(line)
            continue
        new.append(link_line(line, p.name, n))
    # 3. srovnat čísla v textech existujících odkazů s cílem
    fixed = []
    for line in new:
        def relabel(m):
            label, tid = m.group(1), m.group(2)
            if tid not in targets:
                missing.append(f"{p.name}: odkaz na neexistující #{tid} („{label}“)")
                return m.group(0)
            num = targets[tid]
            label2 = re.sub(r"(\s)([A-E](?:\.\d+)*|\d+(?:\.\d+)*)(–\d+(?:\.\d+)*)?$",
                            lambda k: k.group(1) + num + (k.group(3) or ""), label)
            return f"[{label2}](#{tid})"
        fixed.append(re.sub(r"\[([^\]]+)\]\(#(sec-[\w-]+)\)", relabel, line))
    new_raw = nl.join(fixed)
    in_c = False
    for n, line in enumerate(fixed, 1):
        if in_c or line.lstrip().startswith("<!--"):
            in_c = "-->" not in line
            continue
        if line.lstrip().startswith(">") or re.match(r"^#{1,4} ", line):
            continue
        spans = protect(line)
        for rx in (RX_APP, RX_SEC):
            for m in rx.finditer(line):
                if not inside(m.start(), spans):
                    plain.append(f"{p.name}:{n}: {m.group(0)}")
    if args.apply and new_raw != raw:
        p.write_bytes(new_raw.encode("utf-8"))
        print(f"zapsáno: {p.name}")

print(f"kotev: {len(targets)}; visících odkazů: {len(missing)}; textových odkazů bez hypertextu: {len(plain)}")
for x in missing:
    print("  VISÍ:", x)
for x in plain[:40]:
    print("  bez odkazu:", x)
sys.exit(1 if missing else 0)
