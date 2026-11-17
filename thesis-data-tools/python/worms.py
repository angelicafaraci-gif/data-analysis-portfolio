"""Small client for the WoRMS REST API (World Register of Marine Species).

Shared by worms_18s.py and worms_coi.py. For each taxon name it finds the
best matching WoRMS record (exact search first, fuzzy search as a fallback)
and downloads its full classification.

API documentation: https://www.marinespecies.org/rest/
"""
import difflib
import re
import time

import requests

BASE_URL = "https://www.marinespecies.org/rest/"
USER_AGENT = "thesis-data-tools/1.0 (WoRMS taxonomy check)"

REQUEST_SLEEP_SEC = 0.05   # pause between calls, to be polite with the server
HTTP_TRIES = 2
HTTP_TIMEOUT = 12

# Fuzzy search (like=true) is skipped for very short names, and short names
# are penalised when choosing among fuzzy results.
IGNORE_LIKE_TRUE_MAXLEN = 2
SHORT_QUERY_PENALTY_THRESHOLD = 3
SHORT_QUERY_PENALTY = 500
LENGTH_BONUS_CAP = 30

# Bonus for more specific ranks when scoring candidate records
RANK_SCORE = {
    "subspecies": 100, "species": 90, "genus": 60, "family": 40,
    "order": 30, "class": 20, "phylum": 10, "division": 10, "kingdom": 5,
}

# Control characters that make an .xlsx file invalid
ILLEGAL_XML_RE = re.compile(r"[\x00-\x08\x0B\x0C\x0E-\x1F]")


# ---------------------------------------------------------------- text helpers
def sanitize_excel_text(x) -> str:
    if x is None:
        return ""
    return ILLEGAL_XML_RE.sub("", str(x))


def safe_cell_value(v):
    """Keeps real blanks (None) and cleans strings before writing them to Excel."""
    if v is None:
        return None
    if isinstance(v, str):
        s = sanitize_excel_text(v)
        return s if s.strip() else None
    return v


def norm(s) -> str:
    """Collapses repeated whitespace, keeping the case."""
    return " ".join(sanitize_excel_text(s).strip().split())


def norm_low(s) -> str:
    return norm(s).lower()


def normalize_rank(rank: str):
    """Returns (base_rank, is_division). 'Phylum (Division)' and 'Division' count as phylum."""
    if not rank:
        return "", False
    rlow = str(rank).strip().lower()
    is_div = re.search(r"\bdivision\b", rlow) is not None   # not 'subdivision'
    base = re.sub(r"\s*\(.*?\)\s*", "", rlow).strip()
    if base == "division":
        base, is_div = "phylum", True
    return base, is_div


# ------------------------------------------------------------------ HTTP layer
def strict_quote_path(s: str) -> str:
    """Percent-encodes everything except letters and digits (names go in the URL path)."""
    out = []
    for byte in str(s).encode("utf-8"):
        ch = chr(byte)
        out.append(ch if ch.isascii() and ch.isalnum() else f"%{byte:02X}")
    return "".join(out)


def http_get_json(session: requests.Session, url: str, params=None, tries: int = HTTP_TRIES):
    """GET with retries. 204/404 -> [] (no match); repeated failure or non-JSON body -> None."""
    for attempt in range(1, tries + 1):
        try:
            r = session.get(url, params=params, timeout=HTTP_TIMEOUT, allow_redirects=True)
            time.sleep(REQUEST_SLEEP_SEC)
            if r.status_code in (204, 404):
                return []
            if r.status_code == 429:   # too many requests: wait and retry
                try:
                    wait = float(r.headers.get("Retry-After"))
                except (TypeError, ValueError):
                    wait = 0.6 * attempt
                time.sleep(wait)
                continue
            if 500 <= r.status_code <= 599:
                time.sleep(0.6 * attempt)
                continue
            r.raise_for_status()
            txt = (r.text or "").strip()
            if not txt:
                return []
            if not txt.startswith(("{", "[")):
                return None
            return r.json()
        except (requests.RequestException, ValueError):
            if attempt == tries:
                return None
            time.sleep(0.6 * attempt)
    return None


def new_session() -> requests.Session:
    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT, "Accept": "application/json"})
    return session


# ----------------------------------------------------------- record selection
def similarity(a: str, b: str) -> float:
    a_n, b_n = norm_low(a), norm_low(b)
    if not a_n or not b_n:
        return 0.0
    return difflib.SequenceMatcher(None, a_n, b_n).ratio()


def score_record(rec: dict, query: str) -> int:
    """Higher is better: accepted names, exact matches, similar names and specific ranks."""
    q = norm_low(query)
    status = norm_low(rec.get("status", ""))
    sci = rec.get("scientificname") or ""
    valid = rec.get("valid_name") or ""
    s = 0
    if status == "accepted":
        s += 1000
    if norm_low(sci) == q:
        s += 600
    if norm_low(valid) == q:
        s += 550
    s += int(max(similarity(query, sci), similarity(query, valid)) * 300)
    s += RANK_SCORE.get(norm_low(rec.get("rank", "")), 0)
    if status != "accepted" and rec.get("valid_AphiaID"):
        s += 80   # unaccepted name that points to a valid one
    return s


def best_record(records, query: str):
    if not isinstance(records, list):
        return None
    candidates = [rec for rec in records if isinstance(rec, dict)]
    if not candidates:
        return None
    return max(candidates, key=lambda rec: score_record(rec, query))


def search_name(session, query: str, like: bool):
    """Best WoRMS record for a name (like=True for the fuzzy search), or None."""
    url = f"{BASE_URL}AphiaRecordsByName/{strict_quote_path(query)}"
    params = {"like": "true" if like else "false", "marine_only": "false"}
    data = http_get_json(session, url, params=params)
    return best_record(data, query) if data else None


def prefetch(session, queries):
    """Searches every distinct name once.

    queries: dict normalised key -> name as written.
    Returns two dicts key -> record (or None): exact search, and fuzzy search
    for the names that the exact search did not find.
    """
    items = sorted(queries.items(), key=lambda kv: (-len(kv[0]), kv[0]))
    print(f"Distinct names to search: {len(items)}")

    exact = {}
    for i, (key, name) in enumerate(items, start=1):
        exact[key] = search_name(session, name, like=False) if len(key) > 1 else None
        if i % 200 == 0 or i == len(items):
            print(f"  exact search {i}/{len(items)}")

    to_fuzzy = [(k, n) for k, n in items if exact.get(k) is None and len(k) > IGNORE_LIKE_TRUE_MAXLEN]
    fuzzy = {}
    for i, (key, name) in enumerate(to_fuzzy, start=1):
        fuzzy[key] = search_name(session, name, like=True)
        if i % 200 == 0 or i == len(to_fuzzy):
            print(f"  fuzzy search {i}/{len(to_fuzzy)}")
    return exact, fuzzy


def choose_record(candidates, exact, fuzzy):
    """Picks the WoRMS record for one row.

    candidates: names from the most general to the most specific rank.
    1. exact matches, starting from the most specific name;
    2. otherwise the best fuzzy match, favouring longer (more specific) names.
    Returns (name_used, record, used_fuzzy) or (None, None, None).
    """
    for q in reversed(candidates):
        rec = exact.get(norm_low(q))
        if rec:
            return q, rec, False

    best = None   # (overall score, name, record)
    for q in reversed(candidates):
        q_len = len(norm_low(q))
        if q_len <= IGNORE_LIKE_TRUE_MAXLEN:
            continue
        rec = fuzzy.get(norm_low(q))
        if not rec:
            continue
        overall = (score_record(rec, q) + min(q_len, LENGTH_BONUS_CAP) * 5
                   - (SHORT_QUERY_PENALTY if q_len <= SHORT_QUERY_PENALTY_THRESHOLD else 0))
        if best is None or overall > best[0]:
            best = (overall, q, rec)
    if best is None:
        return None, None, None
    return best[1], best[2], True


# ------------------------------------------------------------- classification
def classification_chain(session, record: dict, cache: dict):
    """Full classification of the accepted name of a record, as a list of (rank, name)."""
    aphia_id = record.get("valid_AphiaID") or record.get("AphiaID")
    if not aphia_id:
        return []
    aphia_id = int(aphia_id)
    if aphia_id not in cache:
        cache[aphia_id] = http_get_json(session, f"{BASE_URL}AphiaClassificationByAphiaID/{aphia_id}")
    chain, node = [], cache[aphia_id]
    while isinstance(node, dict) and node:
        if node.get("rank") and node.get("scientificname"):
            chain.append((str(node["rank"]), str(node["scientificname"])))
        node = node.get("child")
    return chain


def ranks_from_chain(chain):
    """Dict with kingdom, phylum, class, order, family, genus, species (+ leaf rank and name)."""
    out = {k: None for k in ("kingdom", "phylum", "class", "order", "family", "genus")}
    for rank, name in chain:
        base, is_div = normalize_rank(rank)
        if base == "phylum" and is_div:
            out["phylum"] = out["phylum"] or name   # 'Division' is written in phylum
        elif base in out:
            out[base] = name
    leaf_rank, leaf_name = chain[-1] if chain else (None, None)
    is_species = str(leaf_rank or "").strip().lower() in ("species", "subspecies")
    out["species"] = leaf_name if is_species else None
    out["taxon_rank"] = leaf_rank
    out["taxon_name"] = leaf_name
    return out
