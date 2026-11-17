# Python tools: WoRMS taxonomy check

Two command-line scripts for metabarcoding tables in Excel. Written together with Cosmin Haja.

| Script | What it does |
|---|---|
| [`worms_18s.py`](worms_18s.py) | Cleans the free-text lineages of 18S results and replaces them with the accepted classification from WoRMS |
| [`worms_coi.py`](worms_coi.py) | Checks the COI taxonomy (one column and one confidence score per rank) against WoRMS, for all rows or only for reliable assignments |
| [`worms.py`](worms.py) | Shared WoRMS client used by the two taxonomy scripts |

## Why check the taxonomy against WoRMS

Reference databases for metabarcoding often contain outdated names, synonyms and inconsistent ranks. The [World Register of Marine Species](https://www.marinespecies.org) (WoRMS) is the authoritative list of marine taxa. For every ASV the scripts:

1. take the names assigned by the classifier, from the most specific (species) to the most general;
2. search them on the WoRMS REST API: exact match first, then a fuzzy match as a fallback, choosing among the results with a score (accepted names, exact or similar spelling, more specific rank);
3. follow synonyms to the accepted name and download its full classification;
4. write the WoRMS classification in the table, with `ND` where a rank is missing, plus the name actually used (`value_found`) so that every assignment can be checked.

Each distinct name is searched only once, and the classifications are cached, so tables with tens of thousands of ASVs need far fewer calls to the server.

For COI, the threshold mode keeps only reliable assignments: rows with a genus score ≥ 0.80 go to `results_genus.xlsx` (updated up to genus), rows with a species score ≥ 0.80 to `results_species.xlsx`.

## How to use

Requires Python 3.9 or later and an internet connection for WoRMS.

```
pip install -r requirements.txt

python worms_18s.py input.xlsx output.xlsx
python worms_coi.py input.xlsx --mode threshold --min-score 0.80 --outdir results
python worms_coi.py input.xlsx --mode total --outdir results
```

Each script prints its options with `--help`. Small example inputs with invented values are in [`../example-data`](../example-data) (created by [`make_example_data.py`](make_example_data.py)).

## Tests

The tests run offline: WoRMS is replaced by a small fake server with a few invented records ([`tests/fake_worms.py`](tests/fake_worms.py)).

```
pip install pytest
python -m pytest tests
```
