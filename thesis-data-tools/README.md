# Thesis data tools

Tools I wrote with Cosmin Haja to prepare the DNA metabarcoding datasets of my MSc thesis in Marine Biology (University of Bologna): tables of ASVs (amplicon sequence variants) with their read counts in each sample and their taxonomic classification, for two markers (18S and COI). They automate steps that would otherwise take hours of manual work on tables with tens of thousands of rows.

The thesis is under embargo, so this folder contains **only the code**. The example files contain invented values.

| Folder | What it contains |
|---|---|
| [vba](vba/) | Excel macros: preparing and formatting the taxonomy, removing contaminants, counting ASVs per taxon and sample |
| [python](python/) | Python scripts: checking the taxonomy against the World Register of Marine Species (WoRMS) |
| [example-data](example-data/) | Small invented input files to try the Python scripts |

## What the tools do

| Task | Tool |
|---|---|
| Put the classifier output in a tidy table, one column per rank | VBA: `SplitAndReverseLineage` (18S), `FormatTaxonomy` (COI) |
| Remove ASVs found in the negative controls and contaminant taxa (human, domestic animals) | VBA: `FilterNegativeControls`, `RemoveContaminants` |
| Replace outdated names and synonyms with the accepted WoRMS classification | Python: `worms_18s.py`, `worms_coi.py` |
| Count how many ASVs of each kingdom, phylum and class are found in each sample | VBA: `CountAsvsByTaxon` |
