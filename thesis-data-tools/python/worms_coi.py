"""Checks and updates the taxonomy of COI metabarcoding results with WoRMS.

Input: an Excel file with one ASV table per sheet. Each sheet must have the
columns superkingdom, superkingdom_score, phylum, phylum_score, ...,
species, species_score, as written by the classifier (scores from 0 to 1).
Other columns (ASV id, read counts per sample) are copied unchanged.

For every selected row the script searches the names on WoRMS, from the most
specific to the most general (exact match first, fuzzy match as a fallback),
and overwrites the taxonomy columns with the accepted WoRMS classification
("ND" where a rank is missing). Three columns are added on the right:
value_found (the name used for the search), taxon_name and taxon_rank.

Two modes:
  --mode total      all rows, all ranks -> results_total.xlsx
  --mode threshold  (default) only reliable assignments:
                    rows with genus_score >= MIN_SCORE, ranks up to genus   -> results_genus.xlsx
                    rows with species_score >= MIN_SCORE, ranks up to species -> results_species.xlsx

Usage:
    python worms_coi.py input.xlsx [--mode threshold] [--min-score 0.80] [--outdir .]
"""
import argparse
import os

from openpyxl import Workbook, load_workbook

import worms

TAXA = ["superkingdom", "phylum", "class", "order", "family", "genus", "species"]
REQUIRED_HEADERS = [h for t in TAXA for h in (t, t + "_score")]
DEBUG_HEADERS = ["value_found", "taxon_name", "taxon_rank"]
ND = "ND"


def normalize_name(v) -> str:
    """Classifier names use '_' instead of spaces: 'Mytilus_edulis' -> 'Mytilus edulis'."""
    return worms.norm(worms.sanitize_excel_text(v).replace("_", " ")) if v is not None else ""


def to_float(v):
    if isinstance(v, (int, float)):
        return float(v)
    try:
        return float(str(v).strip().replace(",", "."))
    except (TypeError, ValueError):
        return None


def read_sheets(path):
    """Reads every sheet that has all the required columns.

    Returns {sheet: {"header": [...], "cols": {header: index}, "rows": [[...], ...]}}
    and the list of skipped sheets.
    """
    wb = load_workbook(path, read_only=True, data_only=True)
    sheets, skipped = {}, []
    for ws in wb.worksheets:
        rows = ws.iter_rows(values_only=True)
        header = list(next(rows, None) or [])
        while header and (header[-1] is None or str(header[-1]).strip() == ""):
            header.pop()
        cols = {}
        for i, h in enumerate(header):
            key = str(h).strip().lower() if h is not None else ""
            if key in REQUIRED_HEADERS and key not in cols:
                cols[key] = i
        if any(h not in cols for h in REQUIRED_HEADERS):
            skipped.append(ws.title)
            continue
        n = len(header)
        data = []
        for row in rows:
            row = list(row[:n]) + [None] * max(0, n - len(row))
            if all(v is None for v in row):
                continue
            for t in TAXA:   # '_' -> ' ' in the taxonomy columns
                if isinstance(row[cols[t]], str):
                    row[cols[t]] = normalize_name(row[cols[t]])
            data.append(row)
        sheets[ws.title] = {"header": header, "cols": cols, "rows": data}
    wb.close()
    return sheets, skipped


def candidates(row, cols, ranks):
    """Names of the row for the given ranks, from the most general to the most specific."""
    out = []
    for t in ranks:
        q = normalize_name(row[cols[t]])
        if q and q.lower() != "nd":
            out.append(q)
    return out


def select_rows(sheets, mode, min_score):
    """Returns {output name: (ranks to update, {sheet: [row indices]})}."""
    if mode == "total":
        return {"results_total.xlsx": (TAXA, {s: list(range(len(m["rows"]))) for s, m in sheets.items()})}
    def reliable(row, score_col):
        score = to_float(row[score_col])
        return score is not None and score >= min_score

    selection = {"results_genus.xlsx": (TAXA[:-1], {}), "results_species.xlsx": (TAXA, {})}
    for s, m in sheets.items():
        c = m["cols"]
        selection["results_genus.xlsx"][1][s] = [
            i for i, row in enumerate(m["rows"]) if reliable(row, c["genus_score"])]
        selection["results_species.xlsx"][1][s] = [
            i for i, row in enumerate(m["rows"]) if reliable(row, c["species_score"])]
    return selection


def worms_taxa(session, rec, value_found, cache):
    """Taxonomy columns and debug columns from the WoRMS record chosen for a row."""
    taxa = {t: None for t in TAXA}
    debug = {"value_found": value_found, "taxon_name": None, "taxon_rank": None}
    chain = worms.classification_chain(session, rec, cache) if rec else []
    if chain:
        ranks = worms.ranks_from_chain(chain)
        taxa.update({t: ranks.get(t) for t in TAXA[1:]})
        taxa["superkingdom"] = ranks["kingdom"]   # the WoRMS kingdom goes in the superkingdom column
        debug.update(taxon_name=ranks["taxon_name"], taxon_rank=ranks["taxon_rank"])
    return taxa, debug


def write_results(path, sheets, skipped, ranks, rows_by_sheet, exact, fuzzy, session, cache):
    wb = Workbook()
    wb.remove(wb.active)
    for name in skipped:
        wb.create_sheet(name).append(["(sheet skipped: taxonomy columns missing)"])
    for name, meta in sheets.items():
        ws = wb.create_sheet(name)
        ws.append([worms.safe_cell_value(h) for h in meta["header"]] + DEBUG_HEADERS)
        cols = meta["cols"]
        for i in rows_by_sheet.get(name, []):
            row = list(meta["rows"][i])
            value_found, rec, _ = worms.choose_record(candidates(row, cols, ranks), exact, fuzzy)
            taxa, debug = worms_taxa(session, rec, value_found, cache)
            for t in ranks:
                row[cols[t]] = taxa[t] or ND
            row += [debug[h] for h in DEBUG_HEADERS]
            ws.append([worms.safe_cell_value(v) for v in row])
        print(f"  {name}: {len(rows_by_sheet.get(name, []))} rows")
    wb.save(path)
    print(f"Saved {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("input", nargs="?", default="dati.xlsx", help="input Excel file (default: dati.xlsx)")
    parser.add_argument("--mode", choices=["threshold", "total"], default="threshold")
    parser.add_argument("--min-score", type=float, default=0.80,
                        help="minimum classifier score for genus/species (threshold mode, default 0.80)")
    parser.add_argument("--outdir", default=".", help="folder for the output files")
    args = parser.parse_args()

    sheets, skipped = read_sheets(args.input)
    for name in skipped:
        print(f"Skipped sheet '{name}': taxonomy columns missing")
    selection = select_rows(sheets, args.mode, args.min_score)

    # Search each distinct name once, for all outputs together
    queries = {}
    for ranks, rows_by_sheet in selection.values():
        for s, idx in rows_by_sheet.items():
            for i in idx:
                for q in candidates(sheets[s]["rows"][i], sheets[s]["cols"], ranks):
                    key = worms.norm_low(q)
                    if len(q) > len(queries.get(key, "")):
                        queries[key] = q
    if not queries:
        print("No rows selected: nothing to search.")
        return

    session = worms.new_session()
    exact, fuzzy = worms.prefetch(session, queries)
    cache = {}
    os.makedirs(args.outdir, exist_ok=True)
    for out_name, (ranks, rows_by_sheet) in selection.items():
        if any(rows_by_sheet.values()):
            write_results(os.path.join(args.outdir, out_name), sheets, skipped, ranks,
                          rows_by_sheet, exact, fuzzy, session, cache)


if __name__ == "__main__":
    main()
