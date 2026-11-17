# Excel VBA macros for metabarcoding tables

Five VBA modules that take the output of a taxonomic classifier and turn it into clean tables ready for analysis. They work on whole sheets in memory (arrays and dictionaries instead of cell-by-cell loops), so tables with tens of thousands of ASVs are processed in seconds.

Written together with Cosmin Haja. The examples below use invented values.

## Pipeline

| Step | Module | Macro | What it does |
|---|---|---|---|
| 0 | [`00_SplitAndReverseLineage.bas`](00_SplitAndReverseLineage.bas) | `SplitAndReverseLineage` | 18S only: splits the comma-separated lineage exported by the pipeline and puts it in order from the most general to the most specific name, ready for [`worms_18s.py`](../python/worms_18s.py) |
| 1 | [`01_FormatTaxonomy.bas`](01_FormatTaxonomy.bas) | `AlignTaxonomyTriplets`, then `CleanTaxonomyTable` | Aligns the classifier output so each taxonomic rank is in its own column, then writes a tidy table |
| 2a | [`02_FilterNegativeControls.bas`](02_FilterNegativeControls.bas) | `FilterNegativeControls` | Simple version: copies to a new sheet only the ASVs with zero reads in the negative controls |
| 2b | [`03_RemoveContaminants.bas`](03_RemoveContaminants.bas) | `RemoveContaminantsAllSheets` | Complete version, on every sheet: removes ASVs found in the controls and ASVs of contaminant taxa (human, domestic animals) |
| 3 | [`04_CountAsvsByTaxon.bas`](04_CountAsvsByTaxon.bas) | `CountAsvsByTaxon` | Counts how many ASVs of each kingdom, phylum and class are present in each sample, merging all sheets |

### Step 1: format the taxonomy

The classifier returns, for each ASV, a sequence of *(taxon, rank, confidence)* triplets. When a rank is missing, the following triplets shift to the left, so the same column can hold phyla in one row and classes in another:

| ASV | | | | | | |
|---|---|---|---|---|---|---|
| OTU_1 | Eukaryota | superkingdom | 1.00 | Mollusca | phylum | 0.98 |
| OTU_2 | Eukaryota | superkingdom | 1.00 | *Bivalvia* | *class* | *0.71* |

`AlignTaxonomyTriplets` moves each triplet under the column of its rank. `CleanTaxonomyTable` renames the identifiers (OTU → ASV), drops the repeated rank labels and writes:

| ASV | superkingdom | superkingdom_score | phylum | phylum_score | class | class_score | … | species | species_score |
|---|---|---|---|---|---|---|---|---|---|
| ASV_1 | Eukaryota | 1.00 | Mollusca | 0.98 | Bivalvia | 0.95 | … | Mytilus galloprovincialis | 0.90 |

### Step 2: remove contaminants

Input: ASV tables with one column per sample, one or more negative-control columns and the taxonomy columns.

| ASV | ARMS_site1_A | ARMS_site1_B | CEB_1 | … | genus | species |
|---|---|---|---|---|---|---|
| ASV_1 | 120 | 85 | 0 | … | Mytilus | Mytilus galloprovincialis |
| ASV_2 | 15 | 0 | 0 | … | Homo | Homo sapiens |
| ASV_3 | 40 | 22 | 9 | … | Balanus | Balanus trigonus |

ASV_2 is removed because it is human DNA, ASV_3 because it also appears in the negative control `CEB_1`. Control columns are recognised by their header (containing "control", "blank" or "ceb"); the lists of contaminant genera and species are at the top of the module and can be edited.

### Step 3: count ASVs per taxon

For each rank (kingdom, phylum, class) the macro writes a sheet with taxa in rows and samples in columns: each cell is the number of ASVs of that taxon with at least one read in that sample.

| phylum | ARMS_site1_A | ARMS_site1_B | … |
|---|---|---|---|
| Annelida | 12 | 9 | … |
| Mollusca | 25 | 31 | … |

## How to use

1. Open the Excel workbook with the data and save a copy as `.xlsm` (the macros of step 2b delete rows).
2. Open the VBA editor (**Alt + F11**) → **File → Import File...** and choose the `.bas` file.
3. Run the macro with **Alt + F8**.

Sheet names, column prefixes (`ARMS`, `CEB_`) and the contaminant lists are constants at the top of each module.
