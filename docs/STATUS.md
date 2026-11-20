# Project status

Record shareable summaries here at each handoff. Keep personal paths, unpublished decisions, and restricted evidence in the authorized private locations.

## 20 November 2026 — Foundational Dropbox delivery

- Use the existing project Dropbox for project data and run artifacts and the shared checkout for code and project documentation. The project Dropbox link is intentionally public. See [project storage rules](../AGENTS.md#writing-presentations-and-release).
- Project Dropbox `3 Data` contains 47 files in `1 Raw` and 36 in `0 Support docs`. The source receipt lists 24 PRONATEL files and 15 ENDES documentation files. The 27 core ENDES modules for 2017–2025 remain in the frozen Stage 02 archive at their original paths. The project link opens the project folder. The archive currently shows Jorge-only access. The Data chat recorded destinations and dependencies for consolidation.
- Keep effect estimation on hold. Obtain Junín’s signed access act, exceptions and named milestone lists, dated service and pending-service histories for candidate comparison sites, and historical locality-level mobile coverage. Resolve historical locality and facility linkage. For any design using 2020, resolve the ENDES telephone instrument and interview mode or document the coauthors’ decision about how to handle that wave.

## 19 November 2026 — Current coordination checkpoint

**Research direction** — The academic research project will be a causal impact evaluation. The coauthors will choose the treatment contrast, target population, comparison, and estimand after auditing service delivery and ENDES support. Frame the contribution around the effect the chosen design identifies. The facility chronology and descriptive checks supply evidence for design selection. If the current contrast lacks credible identifying variation or adequate precision, revisit exposure, comparison, or data before estimating an effect.

- The shared physical checkout uses `main` at `e14afbcf3db37be867bc132508889e5109274eef`. The setup branch already had a commit at `cc37054` before the switch. The scaffold and specialist edits are local, unstaged work on `main`. The entries below retain the branch and input state at the time of each check.
- **02 Data and econometrics in Stata.** The seven-wave rebuild matched 105 saved diagnostics and 12 historical source hashes. The separate nine-wave run added 2019 and 2023. Replay signatures matched for the original seven waves. The private Stage 02 packet contains manifests, logs, and support checks. Ten regional anchors cover 3,650 of 9,013 eligible rural roster matches, with 101 localities observed on both sides of a regional start under the pilot timing rule. Facility service, geographic concordance, and comparison support remain open.
- **03 Literature, bibliography and evidence.** The reviewed bibliography has 42 entries and covers all 17 proposal references. The private evidence matrix documents version links, the 32 absent citation records across the combined source lists, and the closest Peru study's corrigendum and specification audit.
- **04 Working paper and presentations.** The paper and Zavala v3 deck are local drafts. The citation and exhibit test used a private synthetic fixture. The reviewed bibliography and descriptive data products are now available for coordinated integration. Review of production exhibits and owner-side Overleaf verification remain pending.
- **Next decision.** The coauthors will review the first facility chronology target, timing and comparison checks for feasibility, and release scope. Keep the historical pilot, Stata rebuild, and successor runs identifiable by vintage.

Follow the [coordination and handoff rules](../AGENTS.md#coordination-and-handoffs). Every task handoff includes the proposed commit title and description for `main`, alongside the changes, checks, and open decisions.

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

## 19 November 2026 — Literature and evidence

The evidence matrix, positioning memo and record-level reconciliation are in the project’s private Dropbox folder `2 Design`. The review matched 17 proposal references, 51 RIS records and 41 recommendations against the local Zotero Desktop group. The three lists yield 74 distinct citation records across 71 work families, including 54 empirical research families under the documented version links.

After review the Zotero group contains all 17 proposal references and 42 of the 74 distinct citations. It has 43 parent items, including one retained Geraci duplicate. The review cataloged the missing proposal entries, two Peruvian school studies and the Peru broadband corrigendum. It corrected the Montesinos Vidal creator field and linked the corrigendum to the journal article.

Better BibTeX in Jorge’s Zotero workspace produced the reviewed [project bibliography](../3%20Paper/references.bib). Both root TeX files compiled. A separate local `plainnat` build exercised all 42 keys. Its build logs and the before and after snapshots are in the Git-ignored literature evidence record.

The complete Bonifaz and Aguirre corrigendum appears on PDF p. 15 of the combined journal attachment. Its sole instruction adds an acknowledgments and PROINVERSIÓN funding footnote to the original article’s cover (p. 1). The evidence matrix cites the original estimates in Tables 2–5 (pp. 7–8) and the remaining checks in Tables 6–11 (pp. 9–12). [Corrigendum text](https://faculty.up.edu.pe/en/publications/corrigendum-to-impact-assessment-of-broadband-transport-and-inter/)

The Tables 4–5 audit traces both sign changes to column 3, where three household controls enter and the outcome-specific samples shrink. INEI’s codebooks and the earlier ProInversión report identify the survey inputs for main-job hours and appointment scheduling. The memo records the journal’s unresolved aggregation and denominators. The published columns leave the role of added controls and sample composition unresolved. [Journal article](https://doi.org/10.1016/j.telpol.2025.103149)

The matrix distinguishes the published school appendix from the subscription-only article text. Zotero confirmed local attachments directly. NotebookLM authentication remained unavailable in the MCP session. Effect sizes remain on their respective outcome scales. The design decision still depends on verified service dates, ENDES routing and geographic support.

## 19 November 2026 — Data and econometrics

The Stata/MP 19 workflow rebuilt the 17 November pilot against all twelve pinned historical sources and reproduced all 105 saved counts and diagnostics. A separate run added the native INEI modules for 2019 and 2023. The original seven rounds retained identical working and coded Stata data signatures in the replay. The master dispatches both stages using explicit private input and run paths.

The private Stage 02 Dropbox packet contains the source and coded-data manifests, questionnaires, merge counts, missingness checks, calendar and geographic support, design-based descriptive precision and verification logs. Roster designation, regional operation and final health visit timing remain distinct. Facility service history, comparison support and the causal precision target remain open. Aggregate manuscript promotion awaits coauthor review.


## 19 November 2026 — Standing Stata coding standard

Jorge adopted the [Stata coding standard](STATA_CODING_STANDARD.txt) for all project Stata programming, review, refactoring, and reproducibility-package work. The file preserves the full supplied text. The [root project instructions](../AGENTS.md#stata-workflow) require it throughout development and milestone reviews.

## Handoffs

- **Data and econometrics — Jorge.** The initial nine-wave Stata review is complete. Review the private Stage 02 handoff and use the dated calendar and overlap exports to adjudicate service timing and comparison support with Aurelia. Follow the [Stata workflow](../AGENTS.md#stata-workflow) for a separately labeled successor.
- **Literature and evidence — Aurelia, with Jorge reviewing.** Trace the proposed Junín facility case from designation through dated service evidence. Record source title and page, locality and institution, service type, event and date precision, and unresolved conflicts. Keep regional operations and local service separate. The literature matrix records the remaining source checks and citation decisions.
- **Writing and presentations — both coauthors.** Follow the [writing and release rules](../AGENTS.md#writing-presentations-and-release). Use the root paper and Beamer entries, the imported personal theme, and one reviewed bibliography. Link each quantitative claim to its reviewed Stata export and input vintage. The coauthors will select the bibliography exporter and approve any circulation.
