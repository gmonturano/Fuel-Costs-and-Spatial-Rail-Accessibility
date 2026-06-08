# Fuel Costs and Spatial Rail Accessibility — Replication Package

This repository contains estimation code for the paper:

**Fuel Costs and Spatial Rail Accessibility: Econometric Evidence from an Empirically-Weighted Network-Based 3SFCA Model**

Published article: <https://www.sciencedirect.com/science/article/pii/S2210539526000994>

## What the replication package does

The replication package reproduces the estimation stage, not the full private data construction workflow.

It is organised around one processed panel and one metadata workbook:

```text
data/processed/DB_finale_3SFCA_panel.RData
data/metadata/Meta_fusco_dm.xlsx
```

The processed panel must contain the object:

```r
Access_norm
```

The metadata workbook contains three sheets:

```text
GENERAL   # TWFE specifications
IV        # IV / 2SLS specifications
DBML      # Double / Debiased Machine Learning specifications
```

Each sheet uses the same logic:

```text
dependent_var      outcome variable
independent_vars   treatment/endogenous variable
control_vars       controls
instrument_vars    excluded instruments, only for IV
interaction        interactions, if used
```

## Repository structure

```text
R/
  00_functions.R
  01_twfe_metadata.R
  02_iv_metadata.R
  03_dml_metadata.R
  99_run_all.R

data/
  processed/
    DB_finale_3SFCA_panel.RData
  metadata/
    Meta_fusco_dm.xlsx

results/
  tables/
```

## How to run

Run all models:

```r
source("R/99_run_all.R")
```

Or run one block at a time:

```r
source("R/01_twfe_metadata.R")
source("R/02_iv_metadata.R")
source("R/03_dml_metadata.R")
```

## Outputs

The scripts generate new output files in:

```text
results/tables/
```

The repository does not need to include the final published tables. The paper is the official reference for the reported results; the code regenerates machine-readable outputs from the processed panel and metadata.
