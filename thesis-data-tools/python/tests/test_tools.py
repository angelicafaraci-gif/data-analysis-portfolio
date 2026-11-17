"""Offline tests: WoRMS is replaced by tests/fake_worms.py.

Run from the python/ folder:  python -m pytest tests
"""
import os
import sys

import pytest
from openpyxl import load_workbook

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
EXAMPLES = os.path.join(HERE, "..", "..", "example-data")

import worms         # noqa: E402
import worms_18s     # noqa: E402
import worms_coi     # noqa: E402
from fake_worms import fake_http_get_json   # noqa: E402


@pytest.fixture(autouse=True)
def offline(monkeypatch):
    monkeypatch.setattr(worms, "http_get_json", fake_http_get_json)


# --- 18S lineage cleaning -----------------------------------------------------
def test_clean_lineage_rebuilds_binomial_and_drops_placeholders():
    raw = ["Metazoa", "Bryozoa", "Unknown", "Bugula (genus)", "X", "neritina (species)", None]
    assert worms_18s.clean_lineage(raw) == ["Metazoa", "Bryozoa", "Bugula (genus)", "Bugula neritina"]


def test_fill_nd_only_between_first_and_last_rank():
    out = {"kingdom": "Animalia", "phylum": None, "class": "Bivalvia", "order": None}
    filled = worms_18s.fill_nd_between(out)
    assert filled["phylum"] == "ND" and filled["order"] is None


# --- WoRMS record choice ------------------------------------------------------
def test_choose_record_prefers_most_specific_exact_match():
    session = worms.new_session()
    names = {worms.norm_low(q): q for q in ["Mollusca", "Mytilus galloprovincialis"]}
    exact, fuzzy = worms.prefetch(session, names)
    q, rec, used_fuzzy = worms.choose_record(["Mollusca", "Mytilus galloprovincialis"], exact, fuzzy)
    assert q == "Mytilus galloprovincialis" and rec["rank"] == "Species" and not used_fuzzy


def test_synonym_resolves_to_accepted_classification():
    session = worms.new_session()
    rec = worms.search_name(session, "Mytilus edulis galloprovincialis", like=False)
    ranks = worms.ranks_from_chain(worms.classification_chain(session, rec, {}))
    assert ranks["species"] == "Mytilus galloprovincialis" and ranks["family"] == "Mytilidae"


def test_fuzzy_match_used_when_exact_fails():
    session = worms.new_session()
    names = {"mytilus galloprovincialiss": "Mytilus galloprovincialiss"}
    exact, fuzzy = worms.prefetch(session, names)
    q, rec, used_fuzzy = worms.choose_record(list(names.values()), exact, fuzzy)
    assert used_fuzzy and rec["scientificname"] in ("Mytilus", "Mytilus galloprovincialis")


# --- whole scripts on the example files ----------------------------------------
def test_worms_18s_on_example(tmp_path):
    out = tmp_path / "out.xlsx"
    worms_18s.process_file(os.path.join(EXAMPLES, "example_18s.xlsx"), str(out))
    ws = load_workbook(out)["dati"]
    header = [c.value for c in ws[1]]
    row = {h: c.value for h, c in zip(header, ws[2])}
    assert row["scientificname"] == "Bugula neritina" and row["phylum"] == "Bryozoa"
    assert {h: c.value for h, c in zip(header, ws[3])}["class"] == "Bivalvia"
    assert ws.cell(row=4, column=1).fill.start_color.rgb.endswith("FFC7CE")   # Otu3 not found: red


def test_worms_coi_threshold_mode(tmp_path, monkeypatch):
    monkeypatch.setattr(sys, "argv", ["worms_coi.py", os.path.join(EXAMPLES, "example_coi.xlsx"),
                                      "--outdir", str(tmp_path)])
    worms_coi.main()
    species = load_workbook(tmp_path / "results_species.xlsx")["site_1"]
    genus = load_workbook(tmp_path / "results_genus.xlsx")["site_1"]
    assert species.max_row == 2      # only ASV1 has species_score >= 0.80
    assert genus.max_row == 3        # ASV1 and ASV2 have genus_score >= 0.80
    header = [c.value for c in genus[1]]
    asv2 = {h: c.value for h, c in zip(header, genus[3])}
    assert asv2["genus"] == "Bugula" and asv2["superkingdom"] == "Animalia"
    assert asv2["species"] == "Bugula neritina"   # species column untouched in genus mode, '_' removed


def test_worms_coi_total_mode(tmp_path, monkeypatch):
    monkeypatch.setattr(sys, "argv", ["worms_coi.py", os.path.join(EXAMPLES, "example_coi.xlsx"),
                                      "--mode", "total", "--outdir", str(tmp_path)])
    worms_coi.main()
    ws = load_workbook(tmp_path / "results_total.xlsx")["site_1"]
    header = [c.value for c in ws[1]]
    asv3 = {h: c.value for h, c in zip(header, ws[4])}
    assert ws.max_row == 4 and asv3["class"] == "Bivalvia" and asv3["species"] == "ND"
