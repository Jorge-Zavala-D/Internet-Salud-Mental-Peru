# ENDES preparation and working dataset

Mental Health and Internet Access Peru project

## Dataset structure

`ENDES_coded.dta` is long across survey waves and has one row per selected health respondent per wave. In the pinned releases `wave hhid` uniquely identifies each row and `QSNUMERO` retains the selected household member’s line. INEI draws a selected-person health sample each round, using a design that reuses some primary sampling units. A person-level wide file would require repeated measurements of the same identified people. The long file preserves each interview on its actual calendar date or month, its nine symptom items, the survey weight and its locality. A later analysis can use it directly as repeated cross-sections or derive a purpose-specific locality-period aggregate when the design calls for one. The nine items remain nine columns on the same respondent row. A later exposure merge can assign the relevant locality rollout cohort and compare supported calendar periods while retaining survey weights, the declared sampling frame and any documented reuse of a PSU. Reshaping by respondent, averaging a locality before deciding the weighting target, or treating a survey wave as the actual visit year would change the intended comparison. [INEI sample design and questionnaires](https://encuestas.inei.gob.pe/endes/documentos.asp) · [Callaway and Sant’Anna on repeated cross-sections and staggered adoption](https://doi.org/10.1016/j.jeconom.2020.12.001)

The canonical working run uses `endes_with_2015`. `main_wave` identifies 2016–2025. All 2015 records are present to reconcile the released survey spine. `sensitivity_strict` identifies the approved geographically linkable 2015 subset. `sensitivity_corroborated` and `sensitivity_later_review` make the two follow-up checks separately reproducible. `eligible_rural_youth` encodes the pre-link outcome and weight rule. `geography_hold` and `service_site_review` describe different sources of uncertainty. These are preparation fields. The coauthors select the estimation sample and decide how to use 2020 and the site flags once service data are ready.

## Source and variable crosswalk

The pinned Dropbox inventories are `3 Data/0 Support docs/ENDES-all-project-datasets-2026-11-20-v1.csv` and `ENDES-covariate-inputs-2026-11-21.csv` in the same folder. They record table units, keys, archive members, source editions and SHA-256 checksums. The annual documentation registers name the original instruments and dictionaries, including documents in publisher archives. The staging script verifies each input and records the pinned evidence hashes. The preparation log names the physical source and SHA-256 for each import. `endes_source_fields.csv` records the source storage types and labels for every field entering the health spine.

| Source fields | Harmonization and unit |
| --- | --- |
| `HHID`, `QSNUMERO` and `HVIDX` | Retain leading zeros in the household key. Join `RECH0` and `RECH23` on household `HHID` within wave. Join the selected health line `QSNUMERO` to roster line `HVIDX` within the same household and wave in `RECH1`. `roster_checked` records an exact household and line match. Use roster sex `HV104` and age `HV105` to check the selected member. |
| `QS23`, `QSSEXO`, `QSRESULT`, `HV025` | Actual person age in completed years, sex, final health visit result and household rural or urban classification. Appropriate working flags are separate from the observed values. The health completion code is retained independently of the original PHQ eligibility rule. |
| `QS700A`–`QS700I` | INEI question 700, nine symptoms over the previous 14 days. The native item sequence places concentration under F, psychomotor symptoms under G, thoughts of death or self-harm under H and low self-worth under I. Codes 0–3 correspond to none, 1–6, 7–11, and 12 or more days. The sum requires nine valid responses. The per-item status distinguishes a valid zero, missing with no recorded item reason, missing on an absent or postponed interview, missing on a refused interview and codes outside 0–3. The last three categories are based on observed result or code, without inferring the cause of an unexplained item blank. The 2020 regular questionnaire still shows all nine items. The telephone instrument and respondent interview mode are unverified, so the file carries a 2020 review flag. |
| `PESO15_AJUS` (2015), `PESO15_AMAS` (2016–2025) | Selected-person health weight. `health_weight` copies the native value without rescaling and `weight_source` records its native name. Missing and nonpositive values are counted. The tail summary reports within-wave quantiles and extrema for review. |
| `HV001`, `HV022`, `HV023`, `QHCLUSTER` | Household PSU, household stratum, household domain and health PSU. The two PSU fields are compared when present. Wave-qualified PSU and stratum tags support diagnostics. INEI documents PSU panel overlap for 2022–2023 and 2024–2025. The final survey specification and assignment-level clustering belong to the analysis design. |
| `QSINTD`, `QSINTM`, `QSINTY` | Final health visit dates, with literal day present in the 2015–2018 releases and unavailable in the pinned 2019–2025 releases. An invalid day can retain a valid month. The raw values, date precision, out-of-window and next-calendar-year flags are all retained. INEI describes regular fieldwork in March–December through 2017, February–December in 2018 and January–December from 2019, and documents 2025-wave recovery in January–February 2026. Other cross-year dates remain visible with the calendar anomaly flags. |
| `SH61Q` and `HV015` | INEI released 0/1 home internet access and original household visit result. The annual form has a separate household internet item with yes/no answers. The released recode is the authority for 0/1. Blank responses are counted by the available household outcome, and any unrecognized nonblank code is flagged. This field measures reported household access. |
| `HV024`, `SHPROVIN`, `SHDISTRI`, `UBIGEO`, `CODCCPP` and `NOMCCPP` | Construct department, province and district with two digits each when the first releases lack a native UBIGEO. Use the released six-digit field from 2018, compare against available components and hold inconsistencies. Retain the native four-digit suffix, raw names, components and the validated ten-digit key. District 99 does not identify a locality. |
| `LONGITUDX` and `LATITUDY`, or `LONG_CCPP` and `LAT_CCPP` in 2017 | Retain original axes as decimal degrees and separate interpreted fields. Only adopt a 2025 swap if the published orientation is implausible and the swapped point agrees with an independent INEI same-code reference within one metre. The locality code remains unchanged. |
| Approved settlement evidence | Join the survey code and literal name to the reviewed name and code-switch cases. For the separate district review, use the exact wave, literal name, released or housing-derived code fields, and both raw point coordinates on the audited interviews. Keep unresolved identities and possible switches under a geography hold. For 2015 only, exact district and coordinates rounded to six decimal places identify the approved two-round lookup. The broad match is diagnostic. The locality code enters the output only for the strict no-conflict rule. |

### Education and household covariates

The `RECH1` household roster provides schooling for both sexes in 2016–2025 and for the 2015 sensitivity wave. `RECH0` and `RECH23` supply household composition and dwelling characteristics. All are measured in the survey wave. The selected-person health interview supplies age and sex for the existing eligibility rules. `roster_age_gap` records the difference when both ages are below the top-coded range. Hold the new person characteristics if the roster line is absent, recorded sexes disagree, or reported ages differ by more than one year. Keep the respondent, health outcomes, and household characteristics on the same row.

| Measure | Official inputs and harmonization |
| --- | --- |
| Education years and attainment | `RECH1 HV108` records 0–20 years through 2018 and 0–21 thereafter. `HV109` records no schooling, incomplete or complete primary, incomplete or complete secondary, and higher education. Unknown codes become missing. |
| School attendance, household membership and union | `RECH1 HV121` records attendance at any point in the current school year, including early code 2. The 2015–2025 questionnaires route the item to roster ages 3–24. Released zeros outside that range are coded missing in `school_attended`. `HV102` indicates usual residence. `HV116` distinguishes current, former and never in a union. |
| Household composition and household head | `RECH0 HV012` counts usual household members. `RECH23 HV216`, `HV219` and `HV220` record sleeping rooms, head sex and head age. A head age of 97 means 97 or older. Take head attainment from `RECH1 HV109` when `HV101` identifies exactly one head. |
| Dwelling and assets | `RECH23 HV201`, `HV205`, `HV206` and `HV213` record public piped drinking water inside the dwelling, public sewer inside the dwelling, electricity, and earth or sand flooring. `HV207`–`HV209` record radio, television, and refrigerator or freezer. Preserve native codes alongside the derived indicators. |
| Relative wealth | `RECH23 HV270` is the published INEI wealth quintile for that survey wave. It measures relative position within the wave. The proposal discusses income as a determinant of take-up, and these modules provide an asset-based rank for describing material conditions. |

The household variables can support descriptive profiles. Reserve pre-treatment adjustment for variables with substantiated timing and a role in the design. Interview-time schooling, attendance, household composition, wealth, and home internet can reflect changes after broadband arrives. Consider age and sex for composition and precision. For locality adjustment, the literature review prioritizes pre-rollout electricity, schools and clinics, settlement size, travel access, and prior connectivity. Date each source before the relevant assignment or anticipation window. Peru's concession evidence motivates checking baseline infrastructure and sample stability. The Uruguay broadband study uses pre-rollout neighborhood income and sanitation in its specifications and reports current household characteristics in a separate composition check. [INEI annual questionnaires](https://encuestas.inei.gob.pe/endes/documentos.asp) · [INEI 2019 household dictionary](https://www.inei.gob.pe/media/DATOS_ABIERTOS/ENDES/DICCIONARIO/2019/DiccionarioHogar.pdf) · [Bonifaz and Aguirre, Tables 4–5](https://doi.org/10.1016/j.telpol.2025.103149) · [Colombo, Failache and Querejeta, Sections 4–5](https://doi.org/10.1007/s00148-025-01082-7) · [Caetano et al. on time-varying covariates in difference-in-differences](https://arxiv.org/abs/2202.02903)

`RECH1` covers the proposal's education and household-composition additions. `CSALUD01` childhood language and ethnic self-identification have support for both sexes from 2019 onward and are candidates for a later composition or heterogeneity analysis. The employment recode `RE516171` follows the women's questionnaire, with further telephone-instrument limitations in 2020. Home internet remains available as a possible uptake measure. The 2020 mixed-mode review flag still applies. [INEI annual questionnaires](https://encuestas.inei.gob.pe/endes/documentos.asp) · [2020 ficha técnica, Cuadro 2](https://www.inei.gob.pe/descargar/encuestas/documentos/ficha-tecnica-endes-2020.pdf/)

### District-code decisions adopted for 2016–2025

The approved 21 November 2026 district ledger covers 107 eligible rural interviews at 35 distinct wave-and-geography records. It corroborates seven released codes where the housing components disagree, supports 65 assignments through settlement-specific crosswalks, and holds 35 interviews for unresolved historical geography. The staging script verifies the ledger hash and supplies only its Stata join fields and approved decisions. The join uses both code fields and the released coordinates as recorded in the ledger. It changes no INEI source field.

`district_link_status` identifies interviews outside this audit (0), corroborated released codes (1), approved statistical crosswalks (2), and unresolved district cases (3). `district_review_id` points to the adjudication ledger. `native_key_valid` continues to record the original component consistency check. `locality10` contains the approved derived assignment where available. Always use `locality_usable` when forming a geographically usable sample. A possible code switch or unresolved identity from the earlier review can carry a native key under a hold. A project-site review is a separate flag and the ENDES block assigns no broadband operation or treatment status.

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

Use [the master instructions](../README.md#run-the-stata-workflow). The staged inventory covers 94 project files for 2016–2025. The 2015 sensitivity wave adds `RECH1` from the project Dropbox and the three pinned 2015 files. The full 2016–2017 intakes include 54 contextual tables alongside eight preparation inputs. The workflow imports and checks each table against its own source grain. It records nonunique candidate keys as requiring review before a later join. The linked survey file uses `CSALUD01`, `RECH0`, `RECH23` and `RECH1` in each wave. The two `CSALUD08` releases have a separate, unique household-and-child-index key using `QHCLUSTER QHNUMBER QHHOME QS801`. The household member line `QS800` is largely unreleased in those two tables. The reviewed 2017 child-discipline key has an incomplete component. These independent tables stay at their native grain until an approved analysis needs a defined linkage or aggregation.

The master replaces `3 Data/2 Working/ENDES_coded.dta` on each project run. The file opens directly in Stata. The preparation records below refresh in `3 Data/0 Support docs`. All assembled wave files and per-module extracts use Stata temporary files.

| Output | Purpose |
| --- | --- |
| `ENDES_coded.dta` | One row per selected respondent-wave, sorted by `wave hhid` |
| `endes_inputs.csv` and `endes_evidence.csv` | Source catalogue, units, paths, SHA-256, dictionary and audit fingerprints |
| `endes_import_counts.csv` and `endes_merge_counts.csv` | Actual dimensions, candidate-grain status and distinct counts for all sides of each documented join |
| `endes_source_fields.csv` and `endes_codebook.csv` | Native types and labels for fields entering the spine, and final schema |
| `endes_wave_checks.csv` | Ordered flow from the health spine through age, weight, PHQ completeness, rural residence and usable locality, with independent quality flags and the three district-review counts |
| `endes_visit_calendar.csv`, `endes_phq_completeness.csv` and `endes_phq_item_routing.csv` | Calendar day/month precision, visit status, age/area/mode coverage and item response quality |
| `endes_weight_check.csv`, `endes_preparation.log` and `endes_signature.txt` | Weight tails, execution record and stable contents signature |

`endes_covariate_availability.csv` in Support docs records the 21 November 2026 verification by wave and recorded sex among `eligible_rural_youth`, with counts of observed covariates, roster holds, and the school-attendance universe. The harmonized attendance denominator uses roster ages 3–24.

The two-wave audit targets 3,558 and 3,534 eligible rural respondents in 2016 and 2017, with 3,549 and 3,528 usable native keys before applying the case holds. The full build has 34,630 eligible rural respondents in 2016–2025. `pilot_geographic_shape` preserves the original form-of-code check, while `native_key_valid` also checks district components. With the approved district decisions, 34,548 have usable geography and 82 remain held. The holds comprise 35 unresolved district cases, 15 earlier incomplete keys, 14 unresolved locality identities and 18 possible code switches.

The 2015 audit has 3,926 eligible rural respondents, 3,145 broad geographic matches, 2,157 strict matches and 581 strict matches with further geographic corroboration. Ten strictly linked 2015 interviews use codes that overlap an open later-wave case. Comparing the 2025 axes does not modify the locality field.

The current build’s contents signature is in `3 Data/0 Support docs/endes_signature.txt`.
