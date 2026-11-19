# Project status

Record shareable summaries here at each handoff. Keep personal paths, unpublished decisions, and restricted evidence in the authorized private locations.

## 19 November 2026 — Local setup

| Field | Entry |
| --- | --- |
| Date and scope | Local Windows scaffold in the existing checkout. Both original READMEs were preserved. |
| Branch and owners | `codex/econthaki-local-setup` at base `e14afbcf3db37be867bc132508889e5109274eef`. Jorge Zavala and Aurelia Olivas Arrieta own the empirical and release decisions. |
| Source and dataset state | The 17 November historical pilot is available as saved code, aggregates, and a 12-file checksum manifest. The project’s four Dropbox data subfolders are present and empty. Exact input vintages still need recovery. |
| Stata and checks | The named-session MCP probe returned `42` and Stata/MP 19 with four configured processors. `stata_run_file` ran the supplied `03_test_in_Stata.do` in a fresh session. Both checkout and Dropbox paths resolved, the proposal bytes were readable, and `ECONTHAKI_SYNTHETIC_SMOKE_OK` appeared on its own line. The `prep`, `analysis`, and `all` guards returned the expected `r(601)` for missing production do-files. |
| Local builds | TeX Live 2026 built `paper.tex` (one page) and `slides-template.tex` (four slides). The deck uses the Zavala v3 style dated 12 November 2026. Its theme and document inputs resolve inside the checkout. PDFs and logs are in the ignored `.local/tex/` tree. |
| Git and privacy | The index contains the two original README files. Git ignores the machine override, build artifacts, and private setup evidence. The private handoff and project data storage are external to the checkout. |
| Outstanding access | Live Zotero membership and the shared BibTeX export, Overleaf linkage and builds, and PRONATEL operating dates remain unverified. NotebookLM’s last MCP health check reported no authenticated session. |
| Next empirical deliverables | One documented service chronology and one newly labeled seven-wave Stata reconciliation against the saved pilot. Setup checks establish execution readiness. Empirical decisions remain open. |

Git, PowerShell, Python 3.12, PDF extraction, and local TeX are available. GitHub file reads were exercised during the inventory. Dropbox, Zotero, and literature-search operations are exposed. Recheck actual access and compute at each new stage under the [capability rules](../AGENTS.md#capabilities-and-evidence). The ignored `.local/setup-checks.md` holds the detailed commands, results, and private theme provenance.

## Handoffs

- **Data and econometrics — Jorge.** Follow the [Stata workflow](../AGENTS.md#stata-workflow). Recover and hash the exact inputs for 2017, 2018, 2020, 2021, 2022, 2024, and 2025. Preparation owns source validation, the three-module link, and harmonization. Analysis owns the reconciliation, support checks, and reviewed exports. Compare eligible youth, rural youth, rural roster matches, and matched localities with the saved counts. Explain each difference by input vintage, wave, filter, or join. Track survey round and interview month separately.
- **Literature and evidence — Aurelia, with Jorge reviewing.** Trace the proposed Junín facility case from designation through dated service evidence. Record source title and page, locality and institution, service type, event and date precision, and unresolved conflicts. Keep regional operations and local service separate. Reconcile the 17 proposal references against the saved RIS and the live collection when available.
- **Writing and presentations — both coauthors.** Follow the [writing and release rules](../AGENTS.md#writing-presentations-and-release). Use the root paper and Beamer entries, the imported personal theme, and one reviewed bibliography. Link each quantitative claim to its reviewed Stata export and input vintage. The coauthors will select the bibliography exporter and approve any circulation.
