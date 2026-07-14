#!/usr/bin/env python3
"""
E5.1 — one LLM coder for the justice-concept dendrogram.
Provider-agnostic: works with any OpenAI-compatible /chat/completions endpoint
(OpenAI, GLM/Zhipu via e-INFRA, etc.). Keys are read from ENV VARS ONLY and are
never printed or written anywhere. Output = a long-format coded matrix CSV.

Usage (keys already exported in your shell, e.g. from the edustories env):
    python code_taxonomy.py openai
    python code_taxonomy.py glm

Env vars per provider:
  openai : OPENAI_API_KEY   [OPENAI_BASE_URL=https://api.openai.com/v1] [OPENAI_MODEL=gpt-5.5]
  glm    : GLM_API_KEY       GLM_BASE_URL (e-INFRA: https://llm.ai.e-infra.cz/v1)  [GLM_MODEL=glm-5.2]
Notes: reasoning models (gpt-5.x) reject a non-default temperature -> auto-retried without it.
       slow "thinking" models (glm-5.2): raise the timeout via env LLM_TIMEOUT (e.g. 600).

Writes: data/processed/typology_matrix_<provider>.csv  (taxon_id,taxon,char_id,character,code)
"""
import os, sys, csv, json, re, pathlib, urllib.request, urllib.error

HERE = pathlib.Path(__file__).resolve().parents[1]          # analyzy/
PROC = HERE.parent / "data" / "processed"                   # habilitace-1/data/processed
TAXA = PROC / "typology_taxa.csv"
CODEBOOK = PROC / "typology_codebook.md"

# 16 characters, fixed order, allowed tokens (must match typology_codebook.md)
CHARS = [
 ("focus", ["outcome","process","relationship"]),
 ("comparative", ["comparative","noncomparative"]),
 ("temporal", ["backward","forward","atemporal"]),
 ("structure", ["endstate","patterned","historical"]),
 ("currency", ["resources","welfare","capability","opportunity","na"]),
 ("need_sensitive", ["yes","partial","no"]),
 ("desert_sensitive", ["yes","partial","no"]),
 ("equal_shares_default", ["yes","no"]),
 ("remedial", ["remedial","nonremedial"]),
 ("punishment", ["yes","no"]),
 ("repair", ["yes","no"]),
 ("voice", ["central","peripheral","absent"]),
 ("interpersonal_treatment", ["yes","no"]),
 ("transparency_info", ["yes","no"]),
 ("level", ["micro","macro","both"]),
 ("scope", ["domaingeneral","spherespecific"]),
]

PROVIDERS = {
 "openai": dict(key="OPENAI_API_KEY", base="OPENAI_BASE_URL", base_default="https://api.openai.com/v1",
                model="OPENAI_MODEL", model_default="gpt-5.5"),
 "glm":    dict(key="GLM_API_KEY", base="GLM_BASE_URL", base_default=None,
                model="GLM_MODEL", model_default="glm-5.2"),
}

def build_prompt():
    taxa = list(csv.DictReader(open(TAXA, encoding="utf-8")))
    manual = "\n".join(f'{i+1}. {name}: {"/".join(toks)}' for i,(name,toks) in enumerate(CHARS))
    concept_lines = "\n".join(f'- {r["taxon"]}: {r["definition"]}' for r in taxa)
    sys_p = ("You are an expert coder in political philosophy and justice theory doing a "
             "content-analysis coding task. Judge each concept ONLY from its definition. "
             "Use ONLY the allowed tokens. Return STRICT JSON, no prose.")
    user_p = (f"Concepts (24):\n{concept_lines}\n\n"
              f"Characters (16), in order, with allowed tokens:\n{manual}\n\n"
              'Return JSON exactly: {"rows":[{"taxon":"<exact name>","codes":["t1",...,"t16"]}, ...]} '
              "with one object per concept (24 total) and the 16 tokens in the order above.")
    return [r["taxon"] for r in taxa], sys_p, user_p

def call(provider):
    cfg = PROVIDERS[provider]
    key = os.environ.get(cfg["key"])
    base = os.environ.get(cfg["base"], cfg["base_default"])
    model = os.environ.get(cfg["model"], cfg["model_default"])
    if not key:  sys.exit(f"ENV {cfg['key']} not set — export it (keys stay in your shell).")
    if not base: sys.exit(f"ENV {cfg['base']} not set — GLM needs its endpoint URL.")
    taxa_names, sys_p, user_p = build_prompt()
    timeout = float(os.environ.get("LLM_TIMEOUT", "180"))
    payload = dict(model=model, temperature=0,
        messages=[{"role":"system","content":sys_p},{"role":"user","content":user_p}])
    def post(d):
        req = urllib.request.Request(base.rstrip("/")+"/chat/completions",
            data=json.dumps(d).encode(),
            headers={"Authorization":f"Bearer {key}","Content-Type":"application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read())
    print(f"[{provider}] model={model} endpoint={base}  (key hidden)")
    try:
        data = post(payload)
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", "replace")
        # reasoning models (gpt-5.x, o3…) reject non-default temperature
        if e.code == 400 and "temperature" in err:
            payload.pop("temperature", None)
            data = post(payload)
        else:
            sys.exit(f"[{provider}] HTTP {e.code}: {err[:500]}")
    content = data["choices"][0]["message"]["content"]
    blob = re.search(r"\{.*\}", content, re.S).group(0)
    rows = json.loads(blob)["rows"]
    return taxa_names, rows

def validate_write(provider, taxa_names, rows):
    taxa = list(csv.DictReader(open(TAXA, encoding="utf-8")))
    id_by_name = {r["taxon"]: r["id"] for r in taxa}
    out = PROC / f"typology_matrix_{provider}.csv"
    n_bad = 0
    with open(out,"w",newline="",encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(["taxon_id","taxon","char_id","character","code"])
        for row in rows:
            tname = row["taxon"]; codes = row["codes"]
            tid = id_by_name.get(tname, "?")
            for i,(cname,toks) in enumerate(CHARS):
                code = codes[i] if i < len(codes) else ""
                if code not in toks:
                    n_bad += 1; code = f"INVALID:{code}"
                w.writerow([tid, tname, i+1, cname, code])
    print(f"[{provider}] wrote {out.name}: {len(rows)} concepts x 16 chars"
          + (f"  ⚠ {n_bad} invalid tokens" if n_bad else "  (all tokens valid)"))

if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in PROVIDERS:
        sys.exit("usage: python code_taxonomy.py [openai|glm]")
    p = sys.argv[1]
    names, rows = call(p)
    validate_write(p, names, rows)
