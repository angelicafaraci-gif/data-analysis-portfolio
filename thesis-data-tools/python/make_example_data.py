"""Creates the small example files in ../example-data (invented values).

Run once: python make_example_data.py
"""
import os

from openpyxl import Workbook

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "example-data")


def save(wb, name):
    os.makedirs(OUT, exist_ok=True)
    wb.save(os.path.join(OUT, name))
    print("written", name)


# 18S: free-text lineage to the right of "Classification"
wb = Workbook()
ws = wb.active
ws.title = "dati"
ws.append(["OTU", "sample_A", "sample_B", "blank_1", "Classification", "col1", "col2",
           "col3", "col4", "col5", "col6", "col7"])
ws.append(["Otu1", 12, 4, 0, "Main genome", "Eukaryota", "Opisthokonta", "Metazoa", "Bryozoa",
           "Gymnolaemata", "Bugula (genus)", "neritina"])
ws.append(["Otu2", 30, 0, 0, "Main genome", "Eukaryota", "Opisthokonta", "Metazoa", "Mollusca",
           "Bivalvia", "Unknown", "XX"])
ws.append(["Otu3", 0, 7, 0, "Main genome", "Eukaryota", "Unknown", "X", None, None, None, None])
save(wb, "example_18s.xlsx")

# COI: one column per rank and one score column per rank
wb = Workbook()
ws = wb.active
ws.title = "site_1"
ws.append(["ASV", "ARMS_1A", "ARMS_1B", "superkingdom", "superkingdom_score", "phylum", "phylum_score",
           "class", "class_score", "order", "order_score", "family", "family_score",
           "genus", "genus_score", "species", "species_score"])
ws.append(["ASV1", 120, 85, "Eukaryota", 1, "Mollusca", 1, "Bivalvia", 0.99, "Mytilida", 0.97,
           "Mytilidae", 0.95, "Mytilus", 0.92, "Mytilus_galloprovincialis", 0.88])
ws.append(["ASV2", 40, 22, "Eukaryota", 1, "Bryozoa", 0.95, "Gymnolaemata", 0.9, "Cheilostomatida", 0.85,
           "Bugulidae", 0.83, "Bugula", 0.81, "Bugula_neritina", 0.42])
ws.append(["ASV3", 5, 0, "Eukaryota", 1, "Mollusca", 0.7, "Bivalvia", 0.5, "ND", 0.3,
           "ND", 0.2, "ND", 0.1, "ND", 0.05])
save(wb, "example_coi.xlsx")
