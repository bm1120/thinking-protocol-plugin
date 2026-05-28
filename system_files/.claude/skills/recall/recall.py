#!/usr/bin/env python3
# managed-by: thinking-protocol-plugin
# Structure-aware recall engine. Stdlib only. Searches a vault's document
# layers by purpose, degrading gracefully when optional layers are absent.
import os, re, glob, argparse

# (layer_key, glob_pattern_relative_to_root, base_priority)
# Higher base_priority = more authoritative for "what do I already know" queries.
LAYERS = [
    ("insights_moc", "insights/_MOC.md",            10),
    ("insights",     "insights/**/*.md",             9),
    ("decision",     "04_Archives/decisions/**/*.md", 8),
    ("kb",           "03_Knowledge_Base/**/*.md",     6),
    ("analyses",     "analyses/**/*.md",              5),
    ("inbox",        "00_Idea_Inbox/**/*.md",         2),
]

# Query-intent heuristics → which layer family to boost. First match wins.
INTENTS = [
    ("analyses", r"\banalyz|\banalysis\b|분석"),
    ("decided",  r"\bdecid|\bchose|결정|골랐"),
    ("basis",    r"\bbasis\b|\bsource\b|\bevidence\b|근거|출처"),
    ("know",     r"\bknow\b|\baware\b|conclu|결론|아는|알고"),
]
INTENT_BOOST = {
    "analyses": {"analyses": 6},
    "decided":  {"decision": 4},
    "basis":    {"kb": 5},
    "know":     {"insights": 4, "insights_moc": 4, "decision": 2},
}

def classify_intent(query):
    q = query.lower()
    for name, pat in INTENTS:
        if re.search(pat, q):
            return name
    return "know"  # default: treat as a "what do I know" recall

# CJK (Korean/Chinese/Japanese) content words are commonly 2 chars, so keep len>=2.
# Pure-ASCII tokens keep the len>2 cutoff to drop English stopwords (is, of, to, an).
def _is_cjk(c):
    o = ord(c)
    return (0xAC00 <= o <= 0xD7A3 or 0x4E00 <= o <= 0x9FFF      # Hangul syllables, CJK
            or 0x3040 <= o <= 0x30FF or 0x3130 <= o <= 0x318F)  # kana, Hangul jamo

def keep_term(w):
    return len(w) >= 2 if any(_is_cjk(c) for c in w) else len(w) > 2

def detect_layers(root):
    """Return list of (layer_key, [files]) for layers that exist (non-empty)."""
    present = []
    for key, pattern, _ in LAYERS:
        files = [f for f in glob.glob(os.path.join(root, pattern), recursive=True)
                 if os.path.isfile(f)]
        if files:
            present.append((key, files))
    return present

FM_RE = re.compile(r"^---\n(.*?)\n---", re.S)

def parse_frontmatter(text):
    """Return (tags:set, date:str) from YAML-ish frontmatter; tolerant."""
    m = FM_RE.match(text)
    tags, date = set(), ""
    if m:
        block = m.group(1)
        tline = re.search(r"tags:\s*\[([^\]]*)\]", block) or re.search(r"tags:\s*(.+)", block)
        if tline:
            tags = {t.strip().strip('"\'').lstrip("- ").lower()
                    for t in re.split(r"[,\n]", tline.group(1)) if t.strip()}
        dline = re.search(r"date:\s*(\S+)", block)
        if dline:
            date = dline.group(1)
    return tags, date

def score_file(path, terms, query_tags, base_priority, boost):
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    low = text.lower()
    name = os.path.basename(path).lower()
    match = sum(low.count(t) for t in terms)
    name_hit = sum(2 for t in terms if t in name)
    if match == 0 and name_hit == 0:
        return None
    tags, date = parse_frontmatter(text)
    tag_overlap = len(query_tags & tags) * 3
    recency = 1 if date >= "2026-01-01" else 0  # crude freshness nudge
    why = []
    if name_hit: why.append("filename match")
    if match: why.append(f"{match} body hit(s)")
    if tag_overlap: why.append("tag overlap")
    score = base_priority + boost + min(match, 5) + name_hit + tag_overlap + recency
    conf = "strong" if score >= base_priority + 6 else ("weak" if score <= base_priority + 1 else "medium")
    return (score, conf, ", ".join(why))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("query")
    ap.add_argument("--root", default=os.getcwd())
    ap.add_argument("--debug-intent", action="store_true")
    args = ap.parse_args()
    root = os.path.abspath(args.root)

    intent = classify_intent(args.query)
    if args.debug_intent:
        print(f"intent={intent}")
        return

    layers = detect_layers(root)
    present_keys = {k for k, _ in layers}
    all_keys = {k for k, _, _ in LAYERS}
    skipped = sorted(all_keys - present_keys)

    terms = [w for w in re.split(r"\W+", args.query.lower()) if keep_term(w)]
    query_tags = set(terms)
    boost = INTENT_BOOST.get(intent, {})

    print(f'Recall: "{args.query}"')
    print(f'searched: {", ".join(sorted(present_keys)) or "(none)"} | skipped (absent): {", ".join(skipped) or "(none)"}\n')

    results = []
    base = {k: b for k, _, b in LAYERS}
    for key, files in layers:
        for path in files:
            scored = score_file(path, terms, query_tags, base[key], boost.get(key, 0))
            if scored:
                rel = os.path.relpath(path, root)
                results.append((scored[0], key, rel, scored[1], scored[2]))

    results.sort(reverse=True)
    for score, key, rel, conf, why in results[:8]:
        print(f"- [{key}] {rel} — {why} — {conf}")

    if len(results) < 3:
        print("\nLow connection density — may be a genuinely new topic.")

if __name__ == "__main__":
    main()
