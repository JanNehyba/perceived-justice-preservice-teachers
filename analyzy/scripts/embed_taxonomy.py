#!/usr/bin/env python3
"""
E5.1 — complementary wording-based representation: embed the 24 concept NAMES plus
working definitions and write a cosine-distance matrix. This representation uses none of
the 16 feature scores. Its partial agreement with the feature-score tree is a sensitivity
check on representation choice, not independent validation. Keys are read from ENV VARS
ONLY and never printed or stored.

Usage (key already exported in your shell, e.g. from the edustories env):
    python embed_taxonomy.py                      # OpenAI text-embedding-3-large
Env:
    OPENAI_API_KEY   [OPENAI_BASE_URL=https://api.openai.com/v1]  [EMBED_MODEL=text-embedding-3-large]
    (for an e-INFRA/other OpenAI-compatible embeddings endpoint, set OPENAI_BASE_URL + EMBED_MODEL)

Writes: data/processed/typology_embed_dist.csv  (24x24 cosine-distance matrix, taxa as row/col names)
"""
import os, sys, csv, json, math, pathlib, urllib.request, urllib.error

PROC = pathlib.Path(__file__).resolve().parents[1].parent / "data" / "processed"
TAXA = PROC / "typology_taxa.csv"

def embed():
    key = os.environ.get("OPENAI_API_KEY") or sys.exit("ENV OPENAI_API_KEY not set (keys stay in your shell).")
    base = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    model = os.environ.get("EMBED_MODEL", "text-embedding-3-large")
    timeout = float(os.environ.get("LLM_TIMEOUT", "180"))
    taxa = list(csv.DictReader(open(TAXA, encoding="utf-8")))
    inputs = [f'{r["taxon"]}: {r["definition"]}' for r in taxa]     # name + definition
    body = json.dumps({"model": model, "input": inputs}).encode()
    req = urllib.request.Request(base + "/embeddings", data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    print(f"[embed] model={model} endpoint={base}  n={len(inputs)}  (key hidden)")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        sys.exit(f"[embed] HTTP {e.code}: {e.read().decode('utf-8','replace')[:500]}")
    vecs = [d["embedding"] for d in sorted(data["data"], key=lambda d: d["index"])]
    return [r["taxon"] for r in taxa], vecs

def cosine_dist(a, b):
    dot = sum(x*y for x, y in zip(a, b))
    na = math.sqrt(sum(x*x for x in a)); nb = math.sqrt(sum(y*y for y in b))
    return 1.0 - dot/(na*nb) if na and nb else 1.0

def main():
    names, vecs = embed()
    n = len(names)
    out = PROC / "typology_embed_dist.csv"
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow([""] + names)
        for i in range(n):
            w.writerow([names[i]] + [round(cosine_dist(vecs[i], vecs[j]), 6) for j in range(n)])
    print(f"[embed] wrote {out.name}: {n}x{n} cosine-distance matrix")

if __name__ == "__main__":
    main()
