# Mental Health and Internet Access Peru

## Run the Stata workflow

Copy [the path example](config/paths.example.do) to `.local/paths.local.do`
and set the full local path to the project Dropbox folder. Start a fresh
named Stata MCP session with the Git checkout as its working directory.
The do-files use Stata 16 syntax and built-in commands, including
`import spss` and `svy`. The frozen reference runs used Stata/MP 19.

### ENDES survey preparation

Use a fresh, empty run directory outside the shared Dropbox and checkout. Verify
the raw-file and geographic-audit vintages before starting the named Stata MCP
session. The staging script uses Python 3.11 or later and its standard library.
It hashes the raw files in place and writes only the verification manifest
and GIS evidence extracts. Stata installs no packages for this block.

```powershell
python "1 Code/extract/endes_inputs.py" "<project Dropbox>" "<approved locality audit>" "<new protected input directory>" --district-review "<private 09_case_adjudication.csv>" --earlier "<2015 INEI source audit>" --crosswalk "<2015 locality evidence audit>"
```

From the checkout root, use one of these commands with its own fresh protected run directory.

```stata
do "1 Code/0 Master.do" "<protected input directory>" "<protected pilot path>" endes_pilot
do "1 Code/0 Master.do" "<protected input directory>" "<protected main path>" endes
do "1 Code/0 Master.do" "<protected input directory>" "<protected full path>" endes_with_2015
```

`endes_pilot` checks 2016–2017, `endes` covers 2016–2025, and
`endes_with_2015` adds the predesignated 2015 sensitivity wave to the same long
file. Supply the approved district ledger for `endes` and `endes_with_2015`.
Only the last series needs the two 2015 staging options. All three
write a single `ENDES_coded.dta` plus protected diagnostics. The working folder
in the existing project Dropbox holds the encrypted copy of the validated
canonical run. When evolving or testing only the preparation stage, load
`.local/paths.local.do` in a fresh session and call `1 Code/1 Data Preparation.do`
with the same three arguments. [Dataset variables, geography and outputs](docs/ENDES_DATA_PREPARATION.md)

### Frozen Stage 02 replay

Use the frozen Stage 02 input directory (`inputs-v1`), with `core/modules.csv`,
`muestra.csv`, the roster and `regional_dates.csv`. The `extended` series also
reads `extension/modules.csv`. The module registers identify the exact files and
formats. Use a fresh, existing run directory and keep working data, linked rows
and unreviewed diagnostics out of public sync.

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
