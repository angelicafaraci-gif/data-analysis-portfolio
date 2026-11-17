"""A tiny fake WoRMS used by the tests, so they run offline.

It knows a handful of invented records and answers the two API calls used by
worms.py (AphiaRecordsByName and AphiaClassificationByAphiaID).
"""
from urllib.parse import unquote

# AphiaID -> (rank, name, parent AphiaID)
TAXA = {
    2: ("Kingdom", "Animalia", None),
    51: ("Phylum", "Mollusca", 2),
    105: ("Class", "Bivalvia", 51),
    210: ("Order", "Mytilida", 105),
    211: ("Family", "Mytilidae", 210),
    1000: ("Genus", "Mytilus", 211),
    1001: ("Species", "Mytilus galloprovincialis", 1000),
    146142: ("Phylum", "Bryozoa", 2),
    1100: ("Class", "Gymnolaemata", 146142),
    1101: ("Order", "Cheilostomatida", 1100),
    1102: ("Family", "Bugulidae", 1101),
    1103: ("Genus", "Bugula", 1102),
    1104: ("Species", "Bugula neritina", 1103),
}
BY_NAME = {name.lower(): aid for aid, (_, name, _) in TAXA.items()}
UNACCEPTED = {"mytilus edulis galloprovincialis": 1001}   # synonym -> valid AphiaID


def record(aid, status="accepted", name=None, valid=None):
    rank, sci, _ = TAXA[aid]
    return {"AphiaID": aid if status == "accepted" else 99999, "scientificname": name or sci,
            "rank": rank, "status": status, "valid_AphiaID": valid or aid, "valid_name": sci}


def classification(aid):
    chain = []
    while aid is not None:
        rank, name, parent = TAXA[aid]
        chain.append((rank, name))
        aid = parent
    node = {}
    for rank, name in chain:   # build the nested structure from the leaf upwards
        node = {"rank": rank, "scientificname": name, "child": node or None}
    return {"rank": "Superdomain", "scientificname": "Biota", "child": node}


def fake_http_get_json(session, url, params=None, tries=2):
    if "AphiaRecordsByName/" in url:
        name = unquote(url.rsplit("/", 1)[1]).lower()
        if name in BY_NAME:
            return [record(BY_NAME[name])]
        if name in UNACCEPTED:
            return [record(UNACCEPTED[name], status="unaccepted", name=name)]
        if params and params.get("like") == "true":   # fuzzy search: prefix match
            hits = [aid for n, aid in BY_NAME.items() if n.startswith(name[:5])]
            return [record(a) for a in hits]
        return []
    if "AphiaClassificationByAphiaID/" in url:
        aid = int(url.rsplit("/", 1)[1])
        return classification(aid) if aid in TAXA else []
    return None
