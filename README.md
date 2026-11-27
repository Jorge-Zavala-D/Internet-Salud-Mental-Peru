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

### PRONATEL roster and service chronology

Use `events.csv`, `sources.csv`, `roster_geoperu_20240416.csv` and
`workbook_source.csv` from `3 Data/0 Support docs/PRONATEL/Chronology inputs`
in project Dropbox. The workbook register names the original XLSX received on
24 November 2026 and records its SHA-256. Stata reads the original `Export`
sheet from the raw path documented in the register. From the checkout root,
run the master in a fresh named Stata MCP session.

```stata
do "1 Code/0 Master.do" "<full path to Chronology inputs>" "" pronatel
```

This replaces `3 Data/2 Working/PRONATEL_coded.dta` and refreshes the
preparation log and event counts in `3 Data/0 Support docs/PRONATEL`.
Pass an existing scratch directory as the second argument for verification.
Use `event_id` as the row key. Each locality in either roster has one
`roster_snapshot` row. `roster_in_geoperu` and `roster_in_workbook` record
membership in each dated source file. The `workbook_*` fields keep the native
names, reported counts, regional project date and Excel row. A workbook-only
row has the workbook as its source and has no site event date. The chronology
can have several separately sourced events for a locality and service venue.
Read each with its intended users. The support documents record the source
scopes and the ENDES interview-window checks.

### ENDES–PRONATEL descriptive workflow

After both source stages have produced their working files, run the master
from the checkout root in Stata MCP.

```stata
do "1 Code/0 Master.do" "" "" modern
```

This reads the two existing source files from `3 Data/2 Working`, saves
`3 Data/3 Coded/Data Analysis.dta` in project Dropbox and runs the descriptive
exhibits. The integrated file retains one record per ENDES wave and household
case, including 2015 and geography or site holds. The merge joins an approved
ten-digit locality to the two PRONATEL roster snapshots. The reference clock
uses the sourced exact regional dates in the prepared PRONATEL chronology.
Workbook dates enter a separate sensitivity. Timing uses the possible 14-day
recall envelope before the final health visit. The visit is the proxy for
questionnaire administration, and the exhibits describe calendar support for
formal milestones. Local service and interruptions enter the named-venue table
through the prepared chronology and the 27 November public-record audit.

The PDF and underlying count CSV go to `2 Output/Figures` and
`2 Output/Numbers`. The survey support tables and named-venue table go to
`2 Output/Tables`. Logs go to `3 Data/0 Support docs/PRONATEL`.
For a scratch run, pass an explicit working input directory and an existing
scratch output directory. Both stages write into that scratch directory.

```stata
do "1 Code/0 Master.do" "<directory with both source .dta files>" "<scratch output directory>" modern
```

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
