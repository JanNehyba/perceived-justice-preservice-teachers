#!/usr/bin/env python3
"""Trvalé uložení výsledků agentních workflow do repa (vystupy/agenti/).

Žurnály workflow žijí v session adresáři Claude Code (~/.claude/projects/…),
který nepřežije úklid sessions. Tento skript přečte journal.jsonl daného běhu
a uloží výsledky agentů do `vystupy/agenti/<datum>_<label>.json` (stroj)
+ `.md` (člověk). Výstupy jsou PROCESNÍ artefakty — kniha z nich NIKDY
necituje čísla (pravda = manifesty, brána 95).

Použití:
  98_uloz_vysledky_agentu.py <journal.jsonl> <label> [--datum YYYY-MM-DD]
"""
from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "vystupy" / "agenti"


def md_blok(i: int, agent_id: str, res: object) -> str:
    lines = [f"## Agent {i} (`{agent_id}`)", ""]
    if isinstance(res, dict) and "nalezy" in res:
        lines.append(f"**Typ: oponent** — nálezů: {len(res['nalezy'])}")
        lines.append("")
        for n in res["nalezy"]:
            lines.append(f"### [{n.get('zavaznost', '?')}] {n.get('soubor', '?')}")
            lines.append(f"- **Věta:** {n.get('citace_vety', '')}")
            lines.append(f"- **Problém:** {n.get('problem', '')}")
            lines.append(f"- **Oprava:** {n.get('oprava', '')}")
            lines.append("")
        if res.get("ok_kategorie"):
            lines.append(f"**Ověřeno OK:** {res['ok_kategorie']}")
    elif isinstance(res, dict) and "obsah" in res:
        lines.append("**Typ: průzkumník podkladů**")
        lines.append("")
        for s in res.get("soubory", []):
            lines.append(f"- `{s.get('cesta', '?')}` — {s.get('popis', '')}")
        lines.append("")
        lines.append("### Vytěžený obsah")
        lines.append(res["obsah"])
        if res.get("mezery"):
            lines.append("")
            lines.append("### Mezery (❓ pro Jana)")
            for m in res["mezery"]:
                lines.append(f"- {m}")
        if res.get("doporuceni_struktura"):
            lines.append("")
            lines.append(f"### Doporučená struktura\n{res['doporuceni_struktura']}")
    else:
        lines.append("```json")
        lines.append(json.dumps(res, ensure_ascii=False, indent=2))
        lines.append("```")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("journal", type=Path)
    ap.add_argument("label")
    ap.add_argument("--datum", default=date.today().isoformat())
    args = ap.parse_args()

    results = []
    for line in args.journal.read_text(encoding="utf-8").splitlines():
        rec = json.loads(line)
        if rec.get("type") != "result":
            continue
        res = rec.get("result")
        if isinstance(res, str):
            try:
                res = json.loads(res)
            except json.JSONDecodeError:
                pass
        results.append({"agentId": rec.get("agentId"), "result": res})

    if not results:
        raise SystemExit(f"Žurnál {args.journal} neobsahuje žádné výsledky.")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    base = OUT_DIR / f"{args.datum}_{args.label}"
    base.with_suffix(".json").write_text(
        json.dumps(
            {"zdroj_journal": str(args.journal), "datum": args.datum,
             "label": args.label, "vysledky": results},
            ensure_ascii=False, indent=2,
        ),
        encoding="utf-8",
    )
    md = [f"# Výsledky agentů: {args.label} ({args.datum})", "",
          f"> Zdroj: `{args.journal}`", "> PROCESNÍ artefakt — kniha z něj "
          "necituje čísla (pravda = manifesty, brána 95).", ""]
    for i, r in enumerate(results, 1):
        md.append(md_blok(i, r["agentId"], r["result"]))
    base.with_suffix(".md").write_text("\n".join(md), encoding="utf-8")
    print(f"{len(results)} výsledků → {base}.json + .md")


if __name__ == "__main__":
    main()
