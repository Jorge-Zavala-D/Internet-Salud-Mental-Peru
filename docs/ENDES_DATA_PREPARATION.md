# ENDES preparation and working dataset

Mental Health and Internet Access Peru project

## Dataset structure

`ENDES_coded.dta` is long across survey waves and has one row per selected health respondent per wave. In the pinned releases `wave hhid` uniquely identifies each row and `QSNUMERO` retains the selected household member’s line. INEI draws a selected-person health sample each round, using a design that reuses some primary sampling units. A person-level wide file would require repeated measurements of the same identified people. The long file preserves each interview on its actual calendar date or month, its nine symptom items, the survey weight and its locality. A later analysis can use it directly as repeated cross-sections or derive a purpose-specific locality-period aggregate when the design calls for one. The nine items remain nine columns on the same respondent row. A later exposure merge can assign the relevant locality rollout cohort and compare supported calendar periods while retaining survey weights, the declared sampling frame and any documented reuse of a PSU. Reshaping by respondent, averaging a locality before deciding the weighting target, or treating a survey wave as the actual visit year would change the intended comparison. [INEI sample design and questionnaires](https://encuestas.inei.gob.pe/endes/documentos.asp) · [Callaway and Sant’Anna on repeated cross-sections and staggered adoption](https://doi.org/10.1016/j.jeconom.2020.12.001)

The canonical working run uses `endes_with_2015`. `main_wave` identifies 2016–2025. All 2015 records are present to reconcile the released survey spine. `sensitivity_strict` identifies the approved geographically linkable 2015 subset. `sensitivity_corroborated` and `sensitivity_later_review` make the two follow-up checks separately reproducible. `eligible_rural_youth` encodes the pre-link outcome and weight rule. `geography_hold` and `service_site_review` describe different sources of uncertainty. These are preparation fields. The coauthors select the estimation sample and decide how to use 2020 and the site flags once service data are ready.

## Source and variable crosswalk

The pinned Dropbox inventory is `3 Data/0 Support docs/ENDES-all-project-datasets-2026-11-20-v1.csv`. The 2016–2017 inventory gives table units, candidate keys, member paths, source editions and checksum evidence. The annual documentation registers name each original instrument and dictionary, including documents in publisher archives. The staging script verifies each input and records the pinned evidence hashes. The preparation log names the physical source and SHA-256 for each import. `endes_source_fields.csv` records source storage types and labels for every field entering the health spine.

| Source fields | Harmonization and unit |
| --- | --- |
| `HHID`, `QSNUMERO` and `HVIDX` | Retain leading zeros in the household key. Verify unique household joins in every wave. Pair selected health line `QSNUMERO` with household line `HVIDX` in 2016 and 2017, and use `HV104` and `HV105` to check sex and age. `RECH1` is only present in the two full annual intakes. |
| `QS23`, `QSSEXO`, `QSRESULT`, `HV025` | Actual person age in completed years, sex, final health visit result and household rural or urban classification. Appropriate working flags are separate from the observed values. The health completion code is retained independently of the original PHQ eligibility rule. |
| `QS700A`–`QS700I` | INEI question 700, nine symptoms over the previous 14 days. The native item sequence places concentration under F, psychomotor symptoms under G, thoughts of death or self-harm under H and low self-worth under I. Codes 0–3 correspond to none, 1–6, 7–11, and 12 or more days. The sum requires nine valid responses. The per-item status distinguishes a valid zero, missing with no recorded item reason, missing on an absent or postponed interview, missing on a refused interview and codes outside 0–3. The last three categories are based on observed result or code, without inferring the cause of an unexplained item blank. The 2020 regular questionnaire still shows all nine items. The telephone instrument and respondent interview mode are unverified, so the file carries a 2020 review flag. |
| `PESO15_AJUS` (2015), `PESO15_AMAS` (2016–2025) | Selected-person health weight. `health_weight` copies the native value without rescaling and `weight_source` records its native name. Missing and nonpositive values are counted. The tail summary reports within-wave quantiles and extrema for review. |
| `HV001`, `HV022`, `HV023`, `QHCLUSTER` | Household PSU, household stratum, household domain and health PSU. The two PSU fields are compared when present. Wave-qualified PSU and stratum tags support diagnostics. INEI documents PSU panel overlap for 2022–2023 and 2024–2025. The final survey specification and assignment-level clustering belong to the analysis design. |
| `QSINTD`, `QSINTM`, `QSINTY` | Final health visit dates, with literal day present in the 2015–2018 releases and unavailable in the pinned 2019–2025 releases. An invalid day can retain a valid month. The raw values, date precision, out-of-window and next-calendar-year flags are all retained. INEI describes regular fieldwork in March–December through 2017, February–December in 2018 and January–December from 2019, and documents 2025-wave recovery in January–February 2026. Other cross-year dates remain visible with the calendar anomaly flags. |
| `SH61Q` and `HV015` | INEI released 0/1 home internet access and original household visit result. The annual form has a separate household internet item with yes/no answers. The released recode is the authority for 0/1. Blank responses are counted by the available household outcome, and any unrecognized nonblank code is flagged. This field measures reported household access. |
| `HV024`, `SHPROVIN`, `SHDISTRI`, `UBIGEO`, `CODCCPP` and `NOMCCPP` | Construct department, province and district with two digits each when the first releases lack a native UBIGEO. Use the released six-digit field from 2018, compare against available components and hold inconsistencies. Retain the native four-digit suffix, raw names, components and the validated ten-digit key. District 99 does not identify a locality. |
| `LONGITUDX` and `LATITUDY`, or `LONG_CCPP` and `LAT_CCPP` in 2017 | Retain original axes as decimal degrees and separate interpreted fields. Only adopt a 2025 swap if the published orientation is implausible and the swapped point agrees with an independent INEI same-code reference within one metre. The locality code remains unchanged. |
| Approved settlement evidence | Join the 2016–2025 survey code and literal name to the reviewed cases. Preserve unresolved identities and possible switches as holds and distinguish site follow-up. For 2015 only, exact district and coordinates rounded to six decimal places identify the approved two-round lookup. The broad match is diagnostic. The locality code enters the output only for the strict no-conflict rule. |

### Primary documentation pages

PDF pages are counted from the first PDF page. The health dictionary pages report the selected-person module’s Q700 variables and final visit status. The household form page shows the original internet question. Consult each annual dictionary listed in the Dropbox register for source labels and values.

| Wave | Health form, Q700 | CSALUD01 dictionary, Q700 / visit result | Household form, internet |
| --- | ---: | ---: | ---: |
| 2015 | 17 | 19 / 3 | 9 |
| 2016 | 15 | 19 / 3 | 8 |
| 2017 | 15 | 49 / 32 | 9 |
| 2018 | 15 | 15 / 2 | 8 |
| 2019 | 15 | 9 / 1 | 8 |
| 2020 | 15 | 8 / 1 | 8 |
| 2021 | 15 | 7 / 1 | 8 |
| 2022 | 15 | 7 / 1 | 12 |
| 2023 | 14 | 7 / 1 | 8 |
| 2024 | 14 | 8 / 1 | 8 |
| 2025 | 14 | 9 / 2 | 8 |

The annual INEI files and the 2020 October manual were inspected alongside the raw schemas. The 2020 ficha discusses the move to telephone collection and reduced instruments. The 2025 publisher companion includes a ficha headed “2026” that documents the 2025 recovery period retrospectively on PDF page 4. The 2023 ficha notes rotation and PSU overlap on PDF page 3. [INEI ENDES methodology](https://encuestas.inei.gob.pe/endes/documentos.asp) · [2020 ficha técnica](https://www.inei.gob.pe/descargar/encuestas/documentos/ficha-tecnica-endes-2020.pdf/) · [2023 ficha técnica](https://proyectos.inei.gob.pe/endes/2023/DOCUMENTOS/FICHA_TECNICA_ENDES_2023.pdf) · [2025 official companion material](https://www.inei.gob.pe/media/MenuRecursivo/publicaciones_digitales/Est/Lib2089/informacion_complementaria.zip)


## Run and outputs

Use [the master instructions](../README.md#run-the-stata-workflow). The staged inventory covers 86 project files plus three pinned 2015 files in the sensitivity run. The two-wave full intakes include 54 contextual tables in addition to the eight preparation inputs. The workflow imports and checks each table against its own source grain. It records nonunique candidate keys as requiring review before a later join. These independent universes stay in their published files until an approved analysis needs an explicit linkage or aggregation. The linked survey file uses only `CSALUD01`, `RECH0`, `RECH23` and the available `RECH1` person-line validation. The two `CSALUD08` releases have a separate, unique household-and-child-index key using `QHCLUSTER QHNUMBER QHHOME QS801`. The household member line `QS800` is largely unreleased in those two tables. The reviewed 2017 child-discipline key has an incomplete component. These are separate instruments, so retaining their grain and flags avoids a false link to the selected adult health sample.

The protected run contains one permanent Stata dataset. All assembled wave files and per-module extracts use Stata temporary files.

| Protected artifact | Purpose |
| --- | --- |
| `ENDES_coded.dta` | One row per selected respondent-wave, sorted by `wave hhid` |
| `endes_inputs.csv` and `endes_evidence.csv` | Source catalogue, units, paths, SHA-256, dictionary and audit fingerprints |
| `endes_import_counts.csv` and `endes_merge_counts.csv` | Actual dimensions, candidate-grain status and distinct counts for all sides of each documented join |
| `endes_source_fields.csv` and `endes_codebook.csv` | Native types and labels for fields entering the spine, and final schema |
| `endes_wave_checks.csv` | Ordered flow from the health spine through age, weight, PHQ completeness, rural residence and usable locality, with independent quality flags |
| `endes_visit_calendar.csv`, `endes_phq_completeness.csv` and `endes_phq_item_routing.csv` | Calendar day/month precision, visit status, age/area/mode coverage and item response quality |
| `endes_weight_check.csv`, `endes_preparation.log` and `endes_signature.txt` | Weight tails, execution record and stable contents signature |

The two-wave audit targets 3,558 and 3,534 eligible rural respondents in 2016 and 2017, with 3,549 and 3,528 usable native keys before applying the case holds. The full audit targets 34,630 eligible rural respondents in 2016–2025. For comparison with the prior review, `pilot_geographic_shape` reproduces the older form-of-code checks. The stricter `native_key_valid` also applies district component checks. Beyond the 15 earlier failures, it flags 100 eligible rows with district code 99 in the released UBIGEO in 2018–2020 and seven with disagreement between released district and housing components in 2021–2023. Keep those rows and their reported geography in the spine and hold their locality key for assignment review. The 2015 audit has 3,926 eligible rural respondents, 3,145 broad geographic matches, 2,157 strict matches and 581 strict matches with further geographic corroboration. Ten strictly linked 2015 interviews use codes that overlap an open later-wave case. Comparing the 2025 axes does not modify the locality field.

Keep the Stata run, detailed diagnostics and raw key joins in a controlled location. The project Dropbox working folder can be reached through the shared project link. Place the validated `ENDES_coded.dta.gpg` there and keep the passphrase in the approved private channel. After obtaining access, decrypt into a controlled local directory before opening with Stata. Verify against the version’s contents signature. [GnuPG symmetric encryption and decryption](https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html)
