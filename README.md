# Mental Health and Internet Access Peru

## Run the Stata workflow

Copy [the path example](config/paths.example.do) to `.local/paths.local.do`
and set the full local path to the project Dropbox folder. Start a fresh
named Stata MCP session with the Git checkout as its working directory.
The do-files use Stata 16 syntax and built-in commands, including
`import spss` and `svy`. The frozen reference runs used Stata/MP 19.

### ENDES survey preparation

Stage the current source inventory before starting the named Stata MCP session.
The staging script uses Python 3.11 or later and its standard library. It hashes
the raw files in place and writes the input manifest and geographic evidence
tables. Stata installs no packages for this block.

```powershell
python "1 Code/extract/endes_inputs.py" "<project Dropbox>" "<approved locality audit>" "<new staged input directory>" --district-review "<district case ledger>" --earlier "<2015 INEI source audit>" --crosswalk "<2015 locality evidence audit>"
```

From the checkout root, run the master with the staged inputs.

```stata
do "1 Code/0 Master.do" "<staged input directory>"
```

The default series is `endes_with_2015`. It covers 2016–2025 and includes the
separately flagged 2015 sensitivity wave. Each successful run replaces
`3 Data/2 Working/ENDES_coded.dta` in project Dropbox and refreshes the
preparation records in `3 Data/0 Support docs`. Open the working file directly
in Stata. Use one working dataset per source in this folder.

For a verification run, pass a scratch output directory and `endes_pilot`
(2016–2017), `endes` (2016–2025), or `endes_with_2015` as the next two
arguments. The 2016–2025 builds use the district ledger. Only the build with
2015 needs the two 2015 staging options. [Dataset variables, geography and outputs](docs/ENDES_DATA_PREPARATION.md)

### Frozen Stage 02 replay

Use the frozen Stage 02 input directory (`inputs-v1`), with `core/modules.csv`,
`muestra.csv`, the roster and `regional_dates.csv`. The `extended` series also
reads `extension/modules.csv`. The module registers identify the exact files and
formats. Use a fresh, existing run directory for each replay.

```stata
do "1 Code/0 Master.do" "<full frozen input path>" "<run folder relative to project Dropbox>" historical
```

Choose `historical` for 2017, 2018, 2020–2022, 2024 and 2025. Choose `extended`
for all nine 2017–2025 rounds and give it a separate run folder. Preparation
writes `prep.log`, `working.dta`, `coded.dta` and the merge counts. Analysis
reads `coded.dta` in the same run folder and writes `analysis.log` and the
reconciliation, overlap, timing, missingness and descriptive precision CSVs.

To run a stage on its own from the checkout root, supply full input and run
paths. Analysis requires the matching prepared `coded.dta` in the run folder.

```stata
set more off
do "1 Code/1 Data Preparation.do" "<full frozen input path>" "<full run path>" historical
do "1 Code/2 Data Analysis.do" "<full frozen input path>" "<full run path>" historical
```

For a synthetic installation check, run `do "1 Code/setup_smoke.do"` on its own.
The dated Stage 02 wrappers record the commands used with the historical master.
