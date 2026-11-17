"""Checks and completes the taxonomy of 18S metabarcoding results with WoRMS.

The classifier output for 18S gives, for each OTU/ASV, a free-text lineage
spread over many columns to the right of a column called "Classification"
(e.g. Eukaryota | Opisthokonta | Metazoa | Bryozoa | ... ). Some cells hold
placeholders ("Unknown", "X", "XX") and some hold names like
"Bugula (genus)" followed by an epithet in the next cell.

For every row the script:
  1. cleans the lineage (removes placeholders, rebuilds "Genus epithet" names);
  2. searches the names on WoRMS, from the most specific to the most general,
     exact match first and fuzzy match as a fallback;
  3. writes the accepted WoRMS classification (kingdom ... species) next to
     the "Classification" column, with "ND" for ranks missing in between.

Rows are coloured in column A: green = found, red = not found. The taxon_name
cell is green for an exact match and yellow for a fuzzy match, to be checked.

Usage:
    python worms_18s.py input.xlsx output.xlsx [--sheet dati]
"""
import argparse
import re

from openpyxl import Workbook, load_workbook
from openpyxl.styles import PatternFill

import worms

OUTPUT_FIELDS = ["kingdom", "phylum", "class", "order", "family", "genus",
                 "species", "value_found", "taxon_rank", "taxon_name"]
HEADER_LABELS = {"species": "scientificname"}   # column title used in the original results
RANK_FIELDS = ["kingdom", "phylum", "class", "order", "family", "genus", "species"]
ND = "ND"

CLEAN_SHEET = "cleaned_values"   # second output sheet with the cleaned lineage
CLEAN_START_COL = 8              # column H

GREEN = PatternFill(start_color="C6EFCE", end_color="C6EFCE", fill_type="solid")
RED = PatternFill(start_color="FFC7CE", end_color="FFC7CE", fill_type="solid")
YELLOW = PatternFill(start_color="FFEB9C", end_color="FFEB9C", fill_type="solid")

# Reading the lineage: stop after this many empty cells in a row (or this many columns)
READ_MAX_COLS = 160
READ_EMPTY_RUN_STOP = 15

# "Name (strain)", "Name (species)" or "Name (genus)"
FIRST_PART_RE = re.compile(r"^\s*(?P<base>.*?)\s*\(\s*(strain|species|genus)\s*\)\s*$", re.IGNORECASE)
# Placeholders X, XX, XXX as a separate word
X_TOKEN_RE = re.compile(r"\bX+\b", re.IGNORECASE)


def strip_parentheses(s) -> str:
    return worms.norm(re.sub(r"\([^)]*\)", "", worms.sanitize_excel_text(s)))


def first_token(s) -> str:
    parts = worms.norm(s).split()
    return parts[0] if parts else ""


def is_placeholder(value) -> bool:
    """Empty cells, 'Unknown' and X/XX/XXX are not taxon names."""
    txt = worms.norm(value)
    return not txt or "unknown" in txt.lower() or X_TOKEN_RE.search(txt) is not None


def clean_lineage(values):
    """Cleans the lineage of one row and returns the list of taxon names.

    If a cell is "Base (genus|species|strain)", the next valid cell provides
    the epithet: "Bugula (genus)", "neritina" -> "Bugula neritina".
    """
    vals = [worms.norm(v) for v in values if v is not None and worms.norm(v)]

    base_i = None
    for i, s in enumerate(vals):
        m = FIRST_PART_RE.match(s)
        if m:
            base = worms.norm(m.group("base"))
            base_i = i if base else None
            break

    if base_i is not None:
        for k in range(base_i + 1, len(vals)):
            if is_placeholder(vals[k]):
                vals[k] = None
                continue
            token = first_token(strip_parentheses(vals[k])) or first_token(vals[k])
            if token:
                vals[k] = f"{base} {token}"
            break

    return [v for v in vals if v is not None and not is_placeholder(v)]


def fill_nd_between(out: dict) -> dict:
    """Writes ND only in the gaps between the most general and the most specific rank found."""
    filled = [i for i, f in enumerate(RANK_FIELDS) if out.get(f)]
    if len(filled) >= 2:
        for f in RANK_FIELDS[min(filled):max(filled) + 1]:
            if not out.get(f):
                out[f] = ND
    return out


def find_classification_start(ws) -> int:
    """First output column: two columns after the header containing 'Classification'."""
    for col in range(1, ws.max_column + 1):
        v = ws.cell(row=1, column=col).value
        if isinstance(v, str) and "classification" in v.lower():
            return col + 2
    raise ValueError("No header containing 'Classification' found in row 1.")


def read_lineage(ws, row: int, start_col: int):
    values, empty_run = [], 0
    for offset in range(READ_MAX_COLS):
        v = ws.cell(row=row, column=start_col + offset).value
        values.append(v)
        empty_run = empty_run + 1 if not worms.norm(v) else 0
        if empty_run >= READ_EMPTY_RUN_STOP:
            break
    return values


def process_file(input_xlsx: str, output_xlsx: str, sheet: str = "dati"):
    wb_in = load_workbook(input_xlsx, data_only=True)
    if sheet not in wb_in.sheetnames:
        raise ValueError(f"Sheet '{sheet}' not found in {input_xlsx}.")
    ws_in = wb_in[sheet]
    start_col = find_classification_start(ws_in)
    max_row = ws_in.max_row

    wb_out = Workbook()
    wb_out.remove(wb_out.active)
    ws_out = wb_out.create_sheet(sheet)
    ws_clean = wb_out.create_sheet(CLEAN_SHEET)
    ws_clean.cell(row=1, column=CLEAN_START_COL).value = "cleaned_values"

    for c in range(1, start_col):
        ws_out.cell(row=1, column=c).value = worms.safe_cell_value(ws_in.cell(row=1, column=c).value)
    for i, field in enumerate(OUTPUT_FIELDS):
        ws_out.cell(row=1, column=start_col + i).value = HEADER_LABELS.get(field, field)

    # 1. Clean the lineages and collect the distinct names to search
    print("Cleaning the lineages...")
    candidates_by_row = {}
    queries = {}
    for r in range(2, max_row + 1):
        for c in range(1, start_col):
            ws_out.cell(row=r, column=c).value = worms.safe_cell_value(ws_in.cell(row=r, column=c).value)
        cleaned = clean_lineage(read_lineage(ws_in, r, start_col))
        for i, v in enumerate(cleaned):
            ws_clean.cell(row=r, column=CLEAN_START_COL + i).value = worms.safe_cell_value(v)
        cands = [q for q in (strip_parentheses(v) for v in cleaned) if q]
        candidates_by_row[r] = cands
        for q in cands:
            queries.setdefault(worms.norm_low(q), q)

    # 2. Search each distinct name once on WoRMS
    session = worms.new_session()
    exact, fuzzy = worms.prefetch(session, queries)
    cache = {}

    # 3. Write the WoRMS classification row by row
    print("Writing the results...")
    found = 0
    taxon_name_col = start_col + OUTPUT_FIELDS.index("taxon_name")
    for r in range(2, max_row + 1):
        value_found, rec, used_fuzzy = worms.choose_record(candidates_by_row[r], exact, fuzzy)
        chain = worms.classification_chain(session, rec, cache) if rec else []
        if not chain:
            ws_out.cell(row=r, column=1).fill = RED
            continue
        out = fill_nd_between(worms.ranks_from_chain(chain))
        out["value_found"] = value_found
        for i, field in enumerate(OUTPUT_FIELDS):
            ws_out.cell(row=r, column=start_col + i).value = worms.safe_cell_value(out.get(field))
        ws_out.cell(row=r, column=1).fill = GREEN
        ws_out.cell(row=r, column=taxon_name_col).fill = YELLOW if used_fuzzy else GREEN
        found += 1

    wb_out.save(output_xlsx)
    print(f"Done: {found} of {max_row - 1} rows found on WoRMS. Saved {output_xlsx}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("input", nargs="?", default="dati.xlsx", help="input Excel file (default: dati.xlsx)")
    parser.add_argument("output", nargs="?", default="dati_worms.xlsx", help="output Excel file")
    parser.add_argument("--sheet", default="dati", help="sheet with the data (default: dati)")
    args = parser.parse_args()
    process_file(args.input, args.output, args.sheet)


if __name__ == "__main__":
    main()
