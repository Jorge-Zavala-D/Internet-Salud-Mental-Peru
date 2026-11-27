version 16.0
args inputs run series
if "`series'" == "" local series endes_with_2015

* Read a source using its recorded format and retain only the fields used in the survey file.
program define read_endes_module
    args year table inventory import_counts source_fields

    quietly use "`inventory'", clear
    quietly keep if wave == `year' & table == "`table'"
    local source = path[1]
    local format = format[1]
    local encoding = encoding[1]
    local separator = separator[1]
    local role = role[1]
    local grain = subinstr(keys[1],";","",.)
    local sha = sha256[1]
    display "Input `year' `table' `source' SHA-256 `sha'"

    if "`format'" == "sav" quietly import spss using "`source'", clear case(lower)
    if "`format'" == "dta" quietly use "`source'", clear
    if "`format'" == "csv" {
        local delimiter = cond("`separator'" == "semicolon",";",",")
        quietly import delimited using "`source'", clear case(lower) varnames(1) ///
            stringcols(_all) delimiters("`delimiter'") bindquote(strict) encoding("`encoding'")
    }

    local native_columns = c(k)
    if "`role'" == "context" {
        * These tables keep their published units and do not enter the adult health file.
        tempvar one_per_key
        quietly egen byte `one_per_key' = tag(`grain')
        quietly count if `one_per_key'
        local grain_check = cond(r(N) == _N,"candidate key unique","candidate key needs review before use")
        post `import_counts' (`year') ("`table'") ("context") (_N) (`native_columns') ("`grain_check'")
        exit
    }

    local text_fields hhid
    if "`table'" == "CSALUD01" {
        local weight peso15_amas
        if `year' == 2015 local weight peso15_ajus
        local numbers qs23 qssexo qsnumero qhcluster qsresult qsintm qsinty `weight' ///
            qs700a qs700b qs700c qs700d qs700e qs700f qs700g qs700h qs700i
        if `year' <= 2018 local numbers `numbers' qsintd
    }
    if "`table'" == "RECH0" {
        local lon longitudx
        local lat latitudy
        if `year' == 2017 {
            local lon long_ccpp
            local lat lat_ccpp
        }
        local numbers hv001 hv012 hv015 hv022 hv023 hv024 hv025 `lon' `lat'
        if `year' >= 2016 local text_fields hhid codccpp nomccpp
        if `year' >= 2018 local text_fields hhid codccpp nomccpp ubigeo
    }
    if "`table'" == "RECH23" local numbers sh61q shprovin shdistri hv201 hv205 hv206 ///
        hv207 hv208 hv209 hv213 hv216 hv219 hv220 hv270
    if "`table'" == "RECH1" local numbers hvidx hv101 hv102 hv104 hv105 hv108 hv109 hv116 hv121

    keep `text_fields' `numbers'
    preserve
        order `text_fields' `numbers'
        quietly describe, replace clear
        rename (name type varlab) (native_field native_type native_label)
        generate int wave = `year'
        generate str12 table = "`table'"
        keep wave table position native_field native_type native_label
        quietly append using "`source_fields'"
        quietly save "`source_fields'", replace
    restore

    * The semicolon CSVs use a decimal comma. Identifiers remain strings.
    if inlist(`year',2020,2022) quietly destring `numbers', replace dpcomma
    else quietly destring `numbers', replace
    quietly replace hhid = strtrim(hhid)
    post `import_counts' (`year') ("`table'") ("core") (_N) (`native_columns') ("verified unique")

    * Preserve native metadata above, then apply common labels after appending the waves.
    label drop _all
    if "`table'" == "CSALUD01" {
        generate double health_weight = `weight'
        generate str11 weight_source = upper("`weight'")
        if `year' >= 2019 generate byte qsintd = .
        generate byte visit_day_released = (`year' <= 2018)
    }
    if "`table'" == "RECH0" {
        rename (`lon' `lat') (longitude_raw latitude_raw)
        if `year' == 2015 {
            generate str4 codccpp = ""
            generate str1 nomccpp = ""
        }
        if `year' < 2018 generate str6 ubigeo = ""
    }
    if "`table'" == "RECH1" {
        * Take education from the one member identified as the household head.
        tempvar heads
        quietly bysort hhid: egen int `heads' = total(hv101==1)
        quietly by hhid: egen byte hh_head_education = ///
            max(cond(`heads'==1 & hv101==1 & inrange(hv109,0,5),hv109,.))
        drop `heads'
        rename (hvidx hv104 hv105) (qsnumero roster_sex roster_age)
    }
end

* Build one survey wave before adding it to the repeated cross-section.
program define append_endes_wave
    args year inventory appended import_counts merge_counts source_fields
    tempfile health household housing roster

    read_endes_module `year' CSALUD01 "`inventory'" `import_counts' "`source_fields'"
    local health_n = _N
    quietly save "`health'"

    read_endes_module `year' RECH0 "`inventory'" `import_counts' "`source_fields'"
    local household_n = _N
    quietly save "`household'"

    read_endes_module `year' RECH23 "`inventory'" `import_counts' "`source_fields'"
    local housing_n = _N
    quietly save "`housing'"

    read_endes_module `year' RECH1 "`inventory'" `import_counts' "`source_fields'"
    local roster_n = _N
    quietly save "`roster'"

    * Keep the selected health respondents after each household join.
    quietly use "`health'", clear
    quietly merge 1:1 hhid using "`household'", generate(household_merge) nolabel
    tabulate household_merge
    quietly count if household_merge == 1
    local health_only = r(N)
    quietly count if household_merge == 2
    post `merge_counts' (`year') ("household") ("1:1") (`health_n') (`household_n') ///
        (`health_only') (r(N)) (`health_n'-`health_only') (`health_n')
    quietly drop if household_merge == 2
    drop household_merge

    quietly merge 1:1 hhid using "`housing'", generate(housing_merge) nolabel
    tabulate housing_merge
    quietly count if housing_merge == 1
    local health_only = r(N)
    quietly count if housing_merge == 2
    post `merge_counts' (`year') ("housing") ("1:1") (`health_n') (`housing_n') ///
        (`health_only') (r(N)) (`health_n'-`health_only') (`health_n')
    quietly drop if housing_merge == 2
    drop housing_merge

    * Read personal covariates from the selected member's exact household line.
    quietly merge 1:1 hhid qsnumero using "`roster'", generate(roster_merge) nolabel
    tabulate roster_merge
    quietly count if roster_merge == 1
    local health_only = r(N)
    quietly count if roster_merge == 2
    post `merge_counts' (`year') ("person_roster") ("1:1") (`health_n') (`roster_n') ///
        (`health_only') (r(N)) (`health_n'-`health_only') (`health_n')
    quietly drop if roster_merge == 2
    generate byte roster_checked = roster_merge == 3
    drop roster_merge

    generate int wave = `year'
    quietly append using "`appended'"
    quietly save "`appended'", replace
end

* ENDES survey preparation. Each row represents one selected person in one survey wave.
if inlist("`series'", "endes_pilot", "endes", "endes_with_2015") {
    * The project run replaces one working dataset and refreshes the preparation records.
    local working "`run'"
    if "`run'" == "" {
        local working "${econ_dropbox}/3 Data/2 Working"
        local run "${econ_dropbox}/3 Data/0 Support docs"
    }

    log using "`run'/endes_preparation.log", text replace name(endes_prep)
    local edition = cond(c(MP), "MP", cond(c(SE), "SE", "BE"))
    display "Stata/`edition' " c(stata_version) " revision " c(born_date)
    display "ENDES input register: `inputs'/modules.csv. Series: `series'."
    local first = 2016
    local last = 2025
    if "`series'" == "endes_pilot" local last = 2017
    if "`series'" == "endes_with_2015" local first = 2015

    * The Stata input catalogue comes from the source-hash check.
    tempfile inventory appended reviews exceptions district_reviews lookup points
    tempfile import_counts merge_counts source_fields
    tempname imports joins

    quietly import delimited using "`inputs'/modules.csv", clear varnames(1) stringcols(_all) encoding("utf-8")
    quietly destring wave, replace
    keep if inrange(wave,`first',`last')
    quietly destring rows variables, replace
    export delimited using "`run'/endes_inputs.csv", replace
    copy "`inputs'/input_provenance.csv" "`run'/endes_evidence.csv", replace
    quietly save "`inventory'"

    clear
    quietly save "`appended'", emptyok
    quietly save "`source_fields'", emptyok
    postfile `imports' int wave str32 table str8 role long observations int fields ///
        str40 grain_check using "`import_counts'"
    postfile `joins' int wave str20 relation str5 cardinality long ///
        master_before using_before master_only using_only matched retained using "`merge_counts'"

    * Append the core files by survey year. Keep the 2015 sensitivity wave separate.
    if `first' == 2015 append_endes_wave 2015 "`inventory'" "`appended'" `imports' `joins' "`source_fields'"
    append_endes_wave 2016 "`inventory'" "`appended'" `imports' `joins' "`source_fields'"
    append_endes_wave 2017 "`inventory'" "`appended'" `imports' `joins' "`source_fields'"
    if `last' == 2025 {
        append_endes_wave 2018 "`inventory'" "`appended'" `imports' `joins' "`source_fields'"
        append_endes_wave 2019 "`inventory'" "`appended'" `imports' `joins' "`source_fields'"
        append_endes_wave 2020 "`inventory'" "`appended'" `imports' `joins' "`source_fields'"
        append_endes_wave 2021 "`inventory'" "`appended'" `imports' `joins' "`source_fields'"
        append_endes_wave 2022 "`inventory'" "`appended'" `imports' `joins' "`source_fields'"
        append_endes_wave 2023 "`inventory'" "`appended'" `imports' `joins' "`source_fields'"
        append_endes_wave 2024 "`inventory'" "`appended'" `imports' `joins' "`source_fields'"
        append_endes_wave 2025 "`inventory'" "`appended'" `imports' `joins' "`source_fields'"
    }

    * Inspect the other tables from the 2016 intake at their published grain.
    read_endes_module 2016 CSALUD08 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 PROGRAMAS_SOCIALES_X_HOGAR "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 PSBECA18 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 PSCOMEDOR "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 PSPENSION65 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 PSQALIWARMA "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 PSWAWAWASI "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 RE223132 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 RE516171 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 RE758081 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC0111 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC21 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC41 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC42 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC43 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC44 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC82 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC83 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC84DV "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC91 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC93DV_DISCIPLINA "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC94 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 REC95 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 RECH4 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 RECH5 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2016 RECH6 "`inventory'" `imports' "`source_fields'"

    * Inspect the other tables from the 2017 intake at their published grain.
    read_endes_module 2017 CSALUD08 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 PROGRAMAS_SOCIALES_X_HOGAR "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 PSBECA18 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 PSCOMEDOR "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 PSPENSION65 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 PSQALIWARMA "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 PSTRABAJA "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 PSVL "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 PSWAWAWASI "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 RE223132 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 RE516171 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 RE758081 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC0111 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC21 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC41 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC42 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC43 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC44 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC82 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC83 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC84DV "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC91 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC93DV_DISCIPLINA "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC94 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 REC95 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 RECH4 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 RECH5 "`inventory'" `imports' "`source_fields'"
    read_endes_module 2017 RECH6 "`inventory'" `imports' "`source_fields'"

    postclose `imports'
    postclose `joins'

    use "`import_counts'", clear
    sort wave table
    export delimited using "`run'/endes_import_counts.csv", replace

    use "`merge_counts'", clear
    export delimited using "`run'/endes_merge_counts.csv", replace

    use "`source_fields'", clear
    sort wave table position
    order wave table native_field native_type native_label
    drop position
    export delimited using "`run'/endes_source_fields.csv", replace

    * Read the approved locality decisions before matching them to the assembled survey.
    quietly import delimited using "`inputs'/locality_reviews.csv", clear stringcols(_all) encoding("utf-8")
    quietly destring wave, replace
    quietly save "`reviews'"

    quietly import delimited using "`inputs'/geography_exceptions.csv", clear stringcols(_all) encoding("utf-8")
    quietly destring wave code_switch_review, replace
    quietly save "`exceptions'"

    if `last' == 2025 {
        quietly import delimited using "`inputs'/district_reviews.csv", clear stringcols(_all) encoding("utf-8")
        quietly destring wave district_link_status, replace
        drop reviewed_interviews
        quietly save "`district_reviews'"
    }
    if `first' == 2015 {
        quietly import delimited using "`inputs'/2015_locality_lookup.csv", clear stringcols(_all) encoding("utf-8")
        quietly destring x y two_rounds external_agree external_conflict, replace
        rename locality10 candidate_2015
        quietly save "`lookup'"
    }

    * Keep all selected respondents. Age, rural residence and the native weight define separate flags.
    quietly use "`appended'", clear
    generate byte main_wave = inrange(wave,2016,2025)
    * The released 2020 records do not distinguish individual interview modes.
    * The retained service-support audit uses the original 2020-only marker.
    generate byte mode_review = wave == 2020
    generate byte fieldwork_mode_review = inlist(wave, 2020, 2021)
    generate byte youth = inrange(qs23,15,29) & qs23==floor(qs23)
    generate byte age_band = .
    replace age_band = 1 if inrange(qs23,0,14) & qs23==floor(qs23)
    replace age_band = 2 if inrange(qs23,15,19) & youth
    replace age_band = 3 if inrange(qs23,20,24) & youth
    replace age_band = 4 if inrange(qs23,25,29) & youth
    replace age_band = 5 if inrange(qs23,30,120) & qs23==floor(qs23)
    generate byte rural = (hv025==2) if inlist(hv025,1,2)
    generate byte weight_status = cond(missing(health_weight),2,cond(health_weight>0,0,1))
    generate byte positive_weight = weight_status == 0
    generate byte health_complete = (qsresult==1) if inlist(qsresult,1,2,3,4,5,6,9)
    generate byte home_internet = sh61q if inlist(sh61q,0,1)
    generate byte internet_status = 0 if !missing(home_internet)
    replace internet_status = 1 if missing(sh61q) & hv015==1
    replace internet_status = 2 if missing(sh61q) & inlist(hv015,2,3,4,5,6,7,8,9)
    replace internet_status = 3 if !missing(sh61q) & missing(home_internet)
    replace internet_status = 4 if missing(internet_status)

    * Use the health interview age. An adjacent roster age can reflect the interview dates.
    generate int roster_age_gap = qs23 - roster_age if inrange(qs23,0,96) & inrange(roster_age,0,96)
    generate byte person_covariates_held = roster_checked == 0
    replace person_covariates_held = 1 if !missing(roster_age_gap) & abs(roster_age_gap)>1
    replace person_covariates_held = 1 if inlist(qssexo,1,2) & inlist(roster_sex,1,2) & qssexo!=roster_sex
    drop roster_sex

    * The household roster covers both sexes. Schooling follows the published years and attainment.
    generate byte education_years = hv108 if !person_covariates_held & inrange(hv108,0,21)
    replace education_years = . if wave<=2018 & education_years==21
    generate byte education_attainment = hv109 if !person_covariates_held & inrange(hv109,0,5)
    * The attendance question covers ages 3 to 24. Released zeros outside that range are routed skips.
    generate byte school_attended = hv121 if !person_covariates_held & inrange(roster_age,3,24) & inlist(hv121,0,1)
    replace school_attended = 1 if !person_covariates_held & inrange(roster_age,3,24) & wave<=2018 & hv121==2
    generate byte usual_resident = hv102 if !person_covariates_held & inlist(hv102,0,1)
    generate byte union_status = hv116 if !person_covariates_held & inlist(hv116,0,1,2)

    * Household conditions refer to the household interview. Keep the published source codes.
    generate byte hh_usual_members = hv012 if inrange(hv012,0,cond(wave<=2018,90,25))
    generate byte hh_sleeping_rooms = hv216 if inrange(hv216,0,cond(wave<=2018,24,15))
    generate byte hh_head_age = hv220 if inrange(hv220,12,97)
    generate byte hh_head_female = (hv219==2) if inlist(hv219,1,2)
    generate byte hh_electricity = hv206 if inlist(hv206,0,1)
    generate byte hh_piped_drinking_water = (hv201==11) if inlist(hv201,11,12,13,21,22,41,43,51,61,71,96)
    generate byte hh_public_sewer_inside = (hv205==11) if inlist(hv205,11,12,21,22,23,24,31,32,96)
    generate byte hh_earthen_floor = (hv213==11) if inlist(hv213,11,21,31,32,33,34,96)
    generate byte hh_radio = hv207 if inlist(hv207,0,1)
    generate byte hh_television = hv208 if inlist(hv208,0,1)
    generate byte hh_refrigerator = hv209 if inlist(hv209,0,1)
    generate byte hh_wealth_quintile = hv270 if inrange(hv270,1,5)

    * Q700 records nine symptoms over the previous 14 days. The score requires nine valid responses.
    local phq_items qs700a qs700b qs700c qs700d qs700e qs700f qs700g qs700h qs700i
    generate byte blank_item_status = 1
    replace blank_item_status = 2 if inlist(qsresult,2,3)
    replace blank_item_status = 3 if qsresult == 4
    generate byte qs700a_status = cond(inlist(qs700a,0,1,2,3),0,cond(missing(qs700a),blank_item_status,4))
    generate byte qs700b_status = cond(inlist(qs700b,0,1,2,3),0,cond(missing(qs700b),blank_item_status,4))
    generate byte qs700c_status = cond(inlist(qs700c,0,1,2,3),0,cond(missing(qs700c),blank_item_status,4))
    generate byte qs700d_status = cond(inlist(qs700d,0,1,2,3),0,cond(missing(qs700d),blank_item_status,4))
    generate byte qs700e_status = cond(inlist(qs700e,0,1,2,3),0,cond(missing(qs700e),blank_item_status,4))
    generate byte qs700f_status = cond(inlist(qs700f,0,1,2,3),0,cond(missing(qs700f),blank_item_status,4))
    generate byte qs700g_status = cond(inlist(qs700g,0,1,2,3),0,cond(missing(qs700g),blank_item_status,4))
    generate byte qs700h_status = cond(inlist(qs700h,0,1,2,3),0,cond(missing(qs700h),blank_item_status,4))
    generate byte qs700i_status = cond(inlist(qs700i,0,1,2,3),0,cond(missing(qs700i),blank_item_status,4))
    drop blank_item_status

    egen byte nphq = anycount(`phq_items'), values(0 1 2 3)
    generate byte phq9 = qs700a+qs700b+qs700c+qs700d+qs700e+qs700f+qs700g+qs700h+qs700i if nphq == 9
    * Measure outcome eligibility before any locality or service decisions.
    generate byte eligible = youth & positive_weight & nphq==9
    generate byte eligible_rural_youth = eligible & rural==1

    * The survey wave and calendar period are separate. Month-only dates stay month-only.
    generate int visit_month = ym(qsinty,qsintm) if inlist(qsinty,wave,wave+1) & ///
        inrange(qsintm,1,12) & qsintm==floor(qsintm)
    generate int visit_date = mdy(qsintm,qsintd,qsinty) if !missing(visit_month) & visit_day_released & ///
        inrange(qsintd,1,31) & qsintd==floor(qsintd)
    replace visit_date = . if !missing(visit_date) & ///
        (day(visit_date)!=qsintd | month(visit_date)!=qsintm | year(visit_date)!=qsinty)
    generate byte date_precision = cond(!missing(visit_date),2,cond(!missing(visit_month),1,0))
    generate byte date_anomaly = !missing(qsintm,qsinty) & missing(visit_month)
    generate byte day_anomaly = !missing(visit_month,qsintd) & missing(visit_date) & visit_day_released
    generate byte next_calendar_year = (qsinty==wave+1) if !missing(visit_month)
    generate byte fieldwork_unexpected = 0 if !missing(visit_month)
    replace fieldwork_unexpected = 1 if !missing(visit_month) & ///
        (qsinty> wave | (wave<=2017 & qsintm<3) | (wave==2018 & qsintm<2))
    replace fieldwork_unexpected = 0 if wave==2025 & qsinty==2026 & inlist(qsintm,1,2)
    format visit_month %tm
    format visit_date %td

    * Retain both released design fields. Wave-qualified tags index descriptive diagnostics.
    generate byte psu_disagreement = (hv001!=qhcluster) if !missing(hv001,qhcluster)
    generate long wave_psu_id = 100000*wave+hv001 if inrange(hv001,1,99999) & hv001==floor(hv001)
    generate long wave_stratum_id = 100000*wave+hv022 if inrange(hv022,1,99999) & hv022==floor(hv022)
    generate byte survey_design_missing = missing(wave_psu_id,wave_stratum_id)

    * Retain the native codes and record why they fail before applying any reviewed assignment.
    generate str6 district_components = string(hv024,"%02.0f") + string(shprovin,"%02.0f") + ///
        string(shdistri,"%02.0f") if inrange(hv024,1,25) & inrange(shprovin,1,98) & ///
        inrange(shdistri,1,98) & hv024==floor(hv024) & shprovin==floor(shprovin) & shdistri==floor(shdistri)
    generate byte district_conflict = wave>=2018 & !missing(district_components,ubigeo) & ///
        district_components!=strtrim(ubigeo)
    generate str6 district6 = district_components if wave<=2017
    replace district6 = strtrim(ubigeo) if wave>=2018 & ustrregexm(strtrim(ubigeo),"^[0-9]{6}$") & ///
        inrange(real(substr(ubigeo,1,2)),1,25) & inrange(real(substr(ubigeo,3,2)),1,98) & ///
        inrange(real(substr(ubigeo,5,2)),1,98)
    generate str4 locality_suffix = strtrim(codccpp) if ustrregexm(strtrim(codccpp),"^[0-9]{4}$")
    generate byte pilot_geographic_shape = !missing(locality_suffix) & ///
        ((wave<=2017 & !missing(district_components)) | ///
         (wave>=2018 & ustrregexm(strtrim(ubigeo),"^[0-9]{6}$")))
    generate byte district_range_review = wave>=2018 & pilot_geographic_shape & missing(district6)
    generate byte native_key_valid = !missing(district6,locality_suffix) & !district_conflict
    generate str10 native_locality10 = district6 + locality_suffix if native_key_valid
    generate str10 locality10 = native_locality10
    * The name and code-switch ledgers cover all main waves, including waves outside the pilot.
    quietly merge m:1 wave native_locality10 nomccpp using "`reviews'", generate(name_merge) nolabel
    tabulate name_merge
    drop if name_merge == 2
    drop name_merge
    generate byte locality_review = 0
    replace locality_review = 1 if disposition=="verified"
    replace locality_review = 2 if disposition=="point_review"
    replace locality_review = 3 if disposition=="identity_unresolved"
    drop disposition
    quietly merge m:1 wave native_locality10 nomccpp using "`exceptions'", generate(switch_merge) nolabel
    tabulate switch_merge
    drop if switch_merge == 2
    drop switch_merge
    replace code_switch_review = 0 if missing(code_switch_review)
    generate byte service_site_review = locality_review==2

    * Resolve the separately reviewed district-code flags for the 2016–2025 series.
    if `last' == 2025 {
        * Use the exact released wave, name, codes and point from each reviewed survey record.
        * Limit the join to the audited rural youth. Nearby or similarly named records are outside its scope.
        generate byte district_queue = main_wave & eligible_rural_youth & pilot_geographic_shape & !native_key_valid
        generate str10 source_locality10 = ubigeo + codccpp if district_queue
        generate str10 housing_locality10 = district_components + codccpp if district_queue & !missing(district_components)
        generate str22 lon_key = strtrim(string(longitude_raw,"%22.13f")) if district_queue
        generate str22 lat_key = strtrim(string(latitude_raw,"%22.13f")) if district_queue
        quietly merge m:1 wave source_locality10 housing_locality10 nomccpp lon_key lat_key ///
            using "`district_reviews'", keep(master match) generate(district_merge) nolabel
        tabulate district_merge

        * Preserve every native field and use a derived key only for a supported locality.
        replace district_link_status = 0 if missing(district_link_status)
        replace locality10 = approved_locality10 if inlist(district_link_status,1,2)
        drop district_queue source_locality10 housing_locality10 lon_key lat_key ///
            district_merge approved_locality10
    }
    else {
        generate str4 district_review_id = ""
        generate byte district_link_status = 0
    }

    * The 2015 sensitivity sample requires the same locality point in two reference rounds.

    generate byte sensitivity_broad = 0
    generate byte sensitivity_strict = 0
    generate byte sensitivity_corroborated = 0
    generate byte sensitivity_later_review = 0
    if `first'==2015 {
        generate long x = round(longitude_raw*1000000) if wave==2015
        generate long y = round(latitude_raw*1000000) if wave==2015
        merge m:1 district6 x y using "`lookup'", keep(master match) generate(link2015)
        tabulate link2015 if wave==2015
        replace sensitivity_broad = 1 if wave==2015 & eligible_rural_youth & link2015==3
        replace sensitivity_strict = 1 if sensitivity_broad & two_rounds==1 & external_conflict==0
        replace sensitivity_corroborated = 1 if sensitivity_strict & external_agree==1
        replace locality10 = candidate_2015 if sensitivity_strict
        drop x y link2015 two_rounds external_conflict external_agree
        tempfile later_holds
        preserve
            quietly use "`reviews'", clear
            quietly keep if inlist(disposition,"point_review","identity_unresolved")
            keep native_locality10
            quietly duplicates drop
            rename native_locality10 candidate_2015
            quietly save "`later_holds'"
        restore
        merge m:1 candidate_2015 using "`later_holds'", keep(master match) generate(later_review)
        replace sensitivity_later_review = (later_review==3) if sensitivity_strict
        drop candidate_2015 later_review
    }
    * Hold unresolved identities and possible switches even when a native code is available.
    generate byte geography_hold = missing(locality10) | locality_review==3 | code_switch_review==1
    generate byte locality_usable = !geography_hold
    generate byte field_staff_removed = wave==2016

    * Use the prior bounds to detect transposition and require a same-code INEI point within one metre.
    generate byte raw_point_plausible = longitude_raw> -82 & longitude_raw< -68 & latitude_raw> -19 & latitude_raw<0
    generate byte swap_candidate = wave==2025 & native_key_valid & !raw_point_plausible & ///
        latitude_raw> -82 & latitude_raw< -68 & longitude_raw> -19 & longitude_raw<0
    generate byte coordinate_swapped = 0
    if `last'==2025 {
        preserve
            quietly import delimited using "`inputs'/inei_reference_points.csv", clear varnames(1) stringcols(1) asdouble
            quietly save "`points'"
        restore
        tempfile same_code
        preserve
            keep if swap_candidate
            keep native_locality10 longitude_raw latitude_raw
            quietly duplicates drop
            quietly joinby native_locality10 using "`points'"
            generate double distance_m = 111195*sqrt((longitude_raw-reference_lat)^2 + ///
                ((latitude_raw-reference_lon)*cos(_pi*(longitude_raw+reference_lat)/360))^2)
            quietly collapse (min) distance_m, by(native_locality10 longitude_raw latitude_raw)
            quietly save "`same_code'"
        restore
        quietly merge m:1 native_locality10 longitude_raw latitude_raw using "`same_code'", keep(master match) nogen
        replace coordinate_swapped = 1 if swap_candidate & distance_m<=1
        drop distance_m
    }
    generate double longitude = longitude_raw if raw_point_plausible
    generate double latitude = latitude_raw if raw_point_plausible
    replace longitude = latitude_raw if coordinate_swapped
    replace latitude = longitude_raw if coordinate_swapped
    generate byte coordinate_status = cond(coordinate_swapped,1,cond(raw_point_plausible,0, ///
        cond(swap_candidate,2,cond(missing(longitude_raw,latitude_raw),3,4))))


    * Labels document values and units alongside the retained raw fields.
    label define yes_no 0 "No" 1 "Yes"
    label define age_band 1 "0–14" 2 "15–19" 3 "20–24" 4 "25–29" 5 "30–120"
    label define area 1 "Urban" 2 "Rural"
    label define sex 1 "Male" 2 "Female"
    label define health_result 1 "Complete" 2 "Absent" 3 "Postponed" 4 "Refused" ///
        5 "Incomplete" 6 "Disability" 9 "Other"
    label define weight_status 0 "Positive" 1 "Zero or negative" 2 "Missing"
    label define phq_frequency 0 "None" 1 "1–6 days" 2 "7–11 days" 3 "12 or more days"
    label define item_status 0 "Valid response" 1 "Missing, no recorded item reason" ///
        2 "Missing, interview absent or postponed" 3 "Missing, interview refused" 4 "Code outside 0–3"
    label define internet_status 0 "Observed 0 or 1" 1 "Missing on complete household interview" ///
        2 "Missing with other household result" 3 "Code outside 0 or 1" 4 "Missing, household result unknown"
    label define date_precision 0 "No usable calendar month" 1 "Month only" 2 "Day observed"
    label define locality_review 0 "No matched case in review ledger" 1 "Identity supported" ///
        2 "Identity supported, project-site review" 3 "Locality identity unresolved"
    label define district_link_status 0 "Outside the district review" 1 "Released code corroborated" ///
        2 "Approved statistical locality crosswalk" 3 "Exact locality unresolved"
    label define coordinate_status 0 "Published axes plausible" 1 "Swapped, same-code INEI reference within 1 m" ///
        2 "Swap candidate without reference confirmation" 3 "Source coordinate missing" 4 "Outside geographic range"
    label define attainment 0 "No schooling" 1 "Primary incomplete" 2 "Primary complete" ///
        3 "Secondary incomplete" 4 "Secondary complete" 5 "Higher education"
    label define union_status 0 "Never in union" 1 "Currently in union" 2 "Formerly in union"
    label define wealth_rank 1 "Lowest" 2 "Second" 3 "Middle" 4 "Fourth" 5 "Highest"
    label values age_band age_band
    label values hv025 area
    label values qssexo sex
    label values qsresult health_result
    label values weight_status weight_status
    label values `phq_items' phq_frequency
    label values qs700?_status item_status
    label values internet_status internet_status
    label values date_precision date_precision
    label values locality_review locality_review
    label values district_link_status district_link_status
    label values coordinate_status coordinate_status
    label values education_attainment hh_head_education attainment
    label values union_status union_status
    label values hh_wealth_quintile wealth_rank
    label values main_wave mode_review fieldwork_mode_review youth rural positive_weight health_complete home_internet ///
        eligible eligible_rural_youth visit_day_released date_anomaly day_anomaly next_calendar_year ///
        fieldwork_unexpected psu_disagreement survey_design_missing district_conflict district_range_review ///
        pilot_geographic_shape native_key_valid ///
        service_site_review code_switch_review sensitivity_broad sensitivity_strict sensitivity_corroborated ///
        sensitivity_later_review geography_hold locality_usable coordinate_swapped roster_checked ///
        field_staff_removed raw_point_plausible swap_candidate ///
        person_covariates_held school_attended usual_resident hh_head_female hh_electricity ///
        hh_piped_drinking_water hh_public_sewer_inside hh_earthen_floor hh_radio hh_television hh_refrigerator yes_no

    label variable wave "ENDES sampling wave"
    label variable hhid "INEI household case code (unique within wave)"
    label variable qsnumero "Released selected-person line number"
    label variable qs23 "Age in completed years, selected person"
    label variable qssexo "Sex recorded for the selected person"
    label variable age_band "Age band for diagnostics; missing outside recorded plausible range"
    label variable qsresult "Final health interview result, released code"
    label variable hv015 "Household interview result, released code"
    label variable health_complete "Final health interview complete"
    label variable hv025 "INEI residence area, released code"
    label variable hv024 "INEI department, released code"
    label variable shprovin "INEI province component from housing file"
    label variable shdistri "INEI district component from housing file"
    label variable rural "Rural residence (HV025=2)"
    label variable youth "Selected person aged 15–29"
    label variable qs700a "Q700 A: little interest in activities"
    label variable qs700b "Q700 B: low mood or hopelessness"
    label variable qs700c "Q700 C: sleep difficulties or excess sleep"
    label variable qs700d "Q700 D: tiredness or low energy"
    label variable qs700e "Q700 E: poor appetite or overeating"
    label variable qs700f "Q700 F: trouble concentrating"
    label variable qs700g "Q700 G: slowed movement or restlessness"
    label variable qs700h "Q700 H: thoughts of death or self-harm"
    label variable qs700i "Q700 I: feeling bad about oneself"
    label variable qs700a_status "qs700a response status"
    label variable qs700b_status "qs700b response status"
    label variable qs700c_status "qs700c response status"
    label variable qs700d_status "qs700d response status"
    label variable qs700e_status "qs700e response status"
    label variable qs700f_status "qs700f response status"
    label variable qs700g_status "qs700g response status"
    label variable qs700h_status "qs700h response status"
    label variable qs700i_status "qs700i response status"
    label variable nphq "Number of valid Q700 responses (0–9)"
    label variable phq9 "Sum of nine valid Q700 responses, previous 14 days (0–27)"
    label variable health_weight "Native selected-person health weight, unscaled"
    label variable weight_source "Native INEI name of health weight"
    label variable positive_weight "Health weight is finite and positive"
    label variable eligible "Age 15–29, positive health weight and all nine Q700 items valid"
    label variable eligible_rural_youth "Outcome-eligible and rural, before linkage and mode decisions"
    label variable main_wave "In 2016–2025 survey series"
    label variable mode_review "2020 mixed-mode comparability review, individual mode unidentified"
    label variable fieldwork_mode_review "Wave flagged for mode review (2020 or 2021)"
    label variable qsintd "Day of final health visit if released"
    label variable qsintm "Month of final health visit, released code"
    label variable qsinty "Calendar year of final health visit, released code"
    label variable visit_day_released "Source release has a final health visit day field"
    label variable visit_date "Day of final health visit if a valid day is released (Stata %td)"
    label variable visit_month "Calendar month of final health visit as released (Stata %tm)"
    label variable date_precision "Finest supported health visit date precision"
    label variable date_anomaly "Recorded year/month outside usable calendar domain"
    label variable day_anomaly "Released visit day does not form a valid date"
    label variable next_calendar_year "Final visit recorded in calendar year after sampling wave"
    label variable fieldwork_unexpected "Outside regular fieldwork months or documented recovery"
    label variable weight_status "Native selected-person weight availability"
    label variable qhcluster "PSU number in selected-person file"
    label variable hv001 "PSU number in household file"
    label variable hv022 "Household sample stratum (native)"
    label variable hv023 "Household sample domain (native)"
    label variable psu_disagreement "Nonmissing household and health PSU codes differ"
    label variable wave_psu_id "Wave-qualified PSU code for descriptive tabulation"
    label variable wave_stratum_id "Wave-qualified stratum code for descriptive tabulation"
    label variable survey_design_missing "Missing valid household PSU or stratum"
    label variable sh61q "Household internet access, native INEI response"
    label variable home_internet "Household reports internet access (0/1)"
    label variable internet_status "Household internet response status"
    label variable ubigeo "Native district UBIGEO when released in RECH0"
    label variable district_components "District built from the three released numeric components"
    label variable district_conflict "Native UBIGEO and usable department/province/district components differ"
    label variable district6 "Six-digit survey district before adjudication, range checked"
    label variable codccpp "Original populated-centre suffix"
    label variable nomccpp "Original INEI populated-centre name"
    label variable locality_suffix "Validated four-digit populated-centre suffix"
    label variable pilot_geographic_shape "Native source meets the original pilot district and locality format"
    label variable district_range_review "Six-digit released UBIGEO has a component outside district code ranges"
    label variable native_key_valid "Released district and suffix form a consistent locality key"
    label variable native_locality10 "Ten-digit locality code from released survey fields"
    label variable locality10 "Survey locality for linkage, including approved adjudication"
    label variable locality_usable "Code available and survey identity is usable for later linkage"
    label variable case_id "Case in the approved survey name adjudication ledger"
    label variable locality_review "Survey locality identity adjudication status"
    label variable district_review_id "Case in the approved district-code audit"
    label variable district_link_status "Survey district-code adjudication outcome"
    label variable geography_hold "Missing key, unresolved survey locality identity or possible code switch"
    label variable service_site_review "Known locality identity with unresolved project-site question"
    label variable code_switch_review "Additional reviewed geographic code could change designation"
    label variable sensitivity_broad "2015 broad coordinate linkage, diagnostic only"
    label variable sensitivity_strict "2015 eligibility and strict two-round locality sensitivity rule"
    label variable sensitivity_corroborated "Strict 2015 link supported by an additional public reference"
    label variable sensitivity_later_review "Strict 2015 code also appears in an open later-wave case"
    label variable longitude_raw "Published survey longitude field, decimal degrees as delivered"
    label variable latitude_raw "Published survey latitude field, decimal degrees as delivered"
    label variable longitude "Interpreted longitude, decimal degrees"
    label variable latitude "Interpreted latitude, decimal degrees"
    label variable raw_point_plausible "Published coordinates in expected ranges"
    label variable swap_candidate "2025 coordinate axes plausible only when reversed"
    label variable coordinate_status "Survey coordinate interpretation"
    label variable coordinate_swapped "2025 swap confirmed by independent same-code INEI point"
    label variable roster_checked "Exact household and selected member line found in RECH1"
    label variable roster_age "Released age on the selected member's household roster line"
    label variable roster_age_gap "Health interview age minus roster age below the top-coded range"
    label variable person_covariates_held "Missing roster line, sex conflict or reported ages differ by over one year"
    label variable education_years "Years of education as recorded in the household roster"
    label variable education_attainment "Schooling attained according to the household roster"
    label variable school_attended "Attended in the current school year (roster ages 3 to 24)"
    label variable usual_resident "Usual member of this household in the household roster"
    label variable union_status "Current, former or never in a union at roster interview"
    label variable hh_usual_members "Number of usual household members"
    label variable hh_sleeping_rooms "Number of rooms used for sleeping"
    label variable hh_head_age "Age of household head (97 indicates 97 years or more)"
    label variable hh_head_female "Household head recorded as female"
    label variable hh_head_education "Schooling attained by the unique household head"
    label variable hh_electricity "Household has electricity"
    label variable hh_piped_drinking_water "Public piped drinking water inside the dwelling"
    label variable hh_public_sewer_inside "Toilet connected to public sewer inside the dwelling"
    label variable hh_earthen_floor "Main floor material is earth or sand"
    label variable hh_radio "Household owns a radio"
    label variable hh_television "Household owns a television"
    label variable hh_refrigerator "Household owns a refrigerator or freezer"
    label variable hh_wealth_quintile "INEI household wealth quintile for this wave"
    label variable field_staff_removed "Source is 2016 health copy with staff identifier fields omitted"

    order wave hhid qsnumero main_wave eligible eligible_rural_youth sensitivity_strict locality10 ///
        geography_hold district_link_status district_review_id visit_month visit_date date_precision phq9 nphq health_weight
    sort wave hhid
    compress
    label data "ENDES selected-person repeated cross-sections, survey preparation"
    char _dta[series] "`series'"
    char _dta[source_vintage] "endes-2016-2017-full-intake-2026-11-20-v1; frozen 2018–2025 and audited 2015"
    char _dta[covariates] "Official roster and household covariates, intake verified 2026-11-21"
    char _dta[wave_key] "wave hhid; qsnumero records selected household member"
    char _dta[interview_mode] "2020 mixed mode. Respondent-level administration unverified."
    char _dta[locality_audit] "endes-pronatel-locality-adjudication-2026-11-20-v1"
    if `last' == 2025 char _dta[district_code_audit] "endes-district-code-review-2026-11-21-v1"
    char _dta[design] "Native PSU, stratum and domain retained. No assumption of independence across waves."
    quietly datasignature
    local signature "`r(datasignature)'"
    local total = _N
    local columns = c(k)
    * Write the preparation diagnostics and save one respondent file.
    preserve
        generate byte Health = 1
        generate byte Age = youth
        generate byte Weight = youth & positive_weight
        generate byte PHQ = eligible
        generate byte Rural = eligible_rural_youth
        generate byte Geography = Rural & locality_usable
        generate byte Native = Rural & native_key_valid
        generate byte PilotKeyShape = Rural & pilot_geographic_shape
        generate byte UnknownAge = missing(age_band)
        generate byte UnknownArea = missing(rural)
        generate byte UnknownInternet = missing(home_internet)
        generate byte WeightMissing = missing(health_weight)
        generate byte WeightNonpositive = weight_status == 1
        generate byte IncompletePHQ = nphq != 9
        generate byte ModeReview = mode_review
        generate byte DateDay = date_precision == 2
        generate byte DateMonthOnly = date_precision == 1
        generate byte DateUnknown = date_precision == 0
        generate byte DateOutside = fieldwork_unexpected == 1
        generate byte InvalidDate = date_anomaly | day_anomaly
        generate byte NextYear = next_calendar_year == 1
        generate byte DesignMissing = survey_design_missing
        generate byte PSUDiffers = psu_disagreement==1
        generate byte DistrictConflict = Rural & district_conflict
        generate byte DistrictRangeReview = Rural & district_range_review
        generate byte DistrictNativeConfirmed = district_link_status == 1
        generate byte DistrictCrosswalk = district_link_status == 2
        generate byte DistrictLinkUnresolved = district_link_status == 3
        generate byte SiteReview = Rural & service_site_review
        generate byte CodeReview = Rural & code_switch_review
        generate byte VerifiedIdentity = Rural & locality_review==1
        generate byte UnresolvedIdentity = Rural & locality_review==3
        generate byte AxesSwapped = Rural & coordinate_swapped
        collapse (sum) Health Age Weight PHQ Rural Geography Native PilotKeyShape UnknownAge UnknownArea ///
            UnknownInternet WeightMissing WeightNonpositive IncompletePHQ ModeReview DateDay DateMonthOnly ///
            DateUnknown DateOutside InvalidDate NextYear DesignMissing PSUDiffers DistrictConflict DistrictRangeReview ///
            DistrictNativeConfirmed DistrictCrosswalk DistrictLinkUnresolved SiteReview ///
            CodeReview VerifiedIdentity UnresolvedIdentity AxesSwapped sensitivity_broad sensitivity_strict ///
            sensitivity_corroborated sensitivity_later_review, by(wave)
        export delimited using "`run'/endes_wave_checks.csv", replace
    restore
    preserve
        * Count every combination of native visit fields, including records without a usable date.
        contract wave qsinty qsintm qsintd date_precision health_complete mode_review, freq(interviews)
        export delimited using "`run'/endes_visit_calendar.csv", replace
    restore
    preserve
        contract wave age_band rural mode_review qsresult nphq, freq(interviews)
        export delimited using "`run'/endes_phq_completeness.csv", replace
    restore
    preserve
        * Count each response status separately for the nine items.
        keep wave age_band rural mode_review qs700?_status
        quietly recode qs700?_status (0=1) (else=0), generate( ///
            nqs700a_0 nqs700b_0 nqs700c_0 nqs700d_0 nqs700e_0 nqs700f_0 nqs700g_0 nqs700h_0 nqs700i_0)
        quietly recode qs700?_status (1=1) (else=0), generate( ///
            nqs700a_1 nqs700b_1 nqs700c_1 nqs700d_1 nqs700e_1 nqs700f_1 nqs700g_1 nqs700h_1 nqs700i_1)
        quietly recode qs700?_status (2=1) (else=0), generate( ///
            nqs700a_2 nqs700b_2 nqs700c_2 nqs700d_2 nqs700e_2 nqs700f_2 nqs700g_2 nqs700h_2 nqs700i_2)
        quietly recode qs700?_status (3=1) (else=0), generate( ///
            nqs700a_3 nqs700b_3 nqs700c_3 nqs700d_3 nqs700e_3 nqs700f_3 nqs700g_3 nqs700h_3 nqs700i_3)
        quietly recode qs700?_status (4=1) (else=0), generate( ///
            nqs700a_4 nqs700b_4 nqs700c_4 nqs700d_4 nqs700e_4 nqs700f_4 nqs700g_4 nqs700h_4 nqs700i_4)
        label values nqs700*
        order nqs700*, alphabetic last
        collapse (sum) nqs700*, by(wave age_band rural mode_review)
        export delimited using "`run'/endes_phq_item_routing.csv", replace
    restore
    preserve
        quietly keep if positive_weight
        collapse (count) n=health_weight (min) minimum=health_weight (p1) p01=health_weight ///
            (p50) median=health_weight (p99) p99=health_weight (max) maximum=health_weight, by(wave)
        export delimited using "`run'/endes_weight_check.csv", replace
    restore
    preserve
        quietly describe, replace clear
        export delimited using "`run'/endes_codebook.csv", replace
    restore

    quietly save "`working'/ENDES_coded.dta", replace
    tempname receipt
    file open `receipt' using "`run'/endes_signature.txt", write text replace
    file write `receipt' "series=`series'" _n "Stata/`edition' " (c(stata_version)) " " (c(born_date)) _n ///
        "observations=`total'" _n "variables=`columns'" _n "signature=`signature'" _n
    file close `receipt'
    display "ENDES_PREPARATION_OK `series' `total' rows `columns' fields `signature'"
    log close endes_prep
    program drop append_endes_wave read_endes_module
    exit
}

* PRONATEL roster and service chronology. Each row is one roster entry or one sourced event.
if "`series'" == "pronatel" {
    local working "`run'"
    if "`run'" == "" {
        local working "${econ_dropbox}/3 Data/2 Working"
        local run "${econ_dropbox}/3 Data/0 Support docs/PRONATEL"
    }

    log using "`run'/pronatel_preparation.log", text replace name(pronatel_prep)
    local edition = cond(c(MP), "MP", cond(c(SE), "SE", "BE"))
    display "Stata/`edition' " c(stata_version) " revision " c(born_date)
    display "PRONATEL evidence input: `inputs'"

    tempfile sources roster workbook_roster
    quietly import delimited using "`inputs'/sources.csv", clear varnames(1) stringcols(_all) encoding("utf-8")
    quietly save "`sources'"

    * Read the later PRONATEL roster from the pinned workbook. Its date is regional.
    quietly import delimited using "`inputs'/workbook_source.csv", clear ///
        varnames(1) stringcols(_all) encoding("utf-8")
    local workbook_path = source_file[1]
    local workbook_source = source_id[1]
    local workbook_hash = sha256[1]
    display "Regional roster workbook: `workbook_path'"
    display "Recorded workbook SHA-256: `workbook_hash'"
    quietly append using "`sources'"
    quietly save "`sources'", replace

    import excel using "${econ_dropbox}/`workbook_path'", sheet("Export") cellrange(A2) allstring clear
    rename (B C D E F G H I J K L M N) ///
        (locality10 workbook_locality workbook_district workbook_province workbook_region ///
        workbook_intervention workbook_status workbook_date_raw workbook_schools workbook_health_posts ///
        workbook_police workbook_cad workbook_wifi)
    generate int workbook_excel_row = _n + 1
    generate int workbook_region_operation = daily(workbook_date_raw,"MDY")
    destring workbook_schools workbook_health_posts workbook_police workbook_cad workbook_wifi, replace
    drop A
    quietly save "`workbook_roster'"

    quietly import delimited using "`inputs'/roster_geoperu_20240416.csv", clear ///
        varnames(1) stringcols(_all) encoding("utf-8")
    keep if py_ban_anc == "PY_REGIONAL"
    rename (cod_ccpp nom_ccpp estado_py iiee_py eess_py) ///
        (locality10 locality_name roster_status roster_schools roster_health_posts)
    destring roster_schools roster_health_posts, replace
    generate str28 project = ustrregexs(1) if ustrregexm(nom_proyec, "^\[REGIONAL\]\[(.+?)\]$")
    generate str36 event_id = "GEO20240416-" + locality10
    generate str20 scope = "locality"
    generate str20 evidence_grade = "published_roster"
    generate str20 geography_status = "roster_code"
    generate str26 event_type = "roster_snapshot"
    generate str24 source_id = "GEO20240416"
    generate str80 source_locator = "PY_REGIONAL, COD_CCPP " + locality10
    generate str30 service = "Regional roster designation"
    generate str24 roster_vintage = "GeoPeru 2024-04-16"
    generate str14 date_precision = "snapshot day"
    generate str10 date_min_raw = "2024-04-16"
    generate str10 date_max_raw = "2024-04-16"
    drop py_ban_anc nom_proyec

    * The two snapshots describe roster membership. Unmatched localities stay in the file.
    merge 1:1 locality10 using "`workbook_roster'", generate(roster_merge)
    generate byte roster_in_geoperu = inlist(roster_merge,1,3)
    generate byte roster_in_workbook = inlist(roster_merge,2,3)

    * GeoPeru remains the primary citation for its rows. The Excel row identifies the second source.
    replace project = workbook_region if roster_merge==2
    replace locality_name = workbook_locality if roster_merge==2
    replace event_id = "PRWB20261124-" + locality10 if roster_merge==2
    replace scope = "locality" if roster_merge==2
    replace evidence_grade = "supplied_roster" if roster_merge==2
    replace geography_status = "roster_code" if roster_merge==2
    replace event_type = "roster_snapshot" if roster_merge==2
    replace source_id = "`workbook_source'" if roster_merge==2
    replace source_locator = "Export, Excel row " + strofreal(workbook_excel_row) if roster_merge==2
    replace service = "Regional roster designation" if roster_merge==2
    replace roster_vintage = "Received 2026-11-24" if roster_merge==2
    drop roster_merge

    quietly save "`roster'"

    quietly import delimited using "`inputs'/events.csv", clear varnames(1) stringcols(_all) encoding("utf-8")
    quietly append using "`roster'"
    merge m:1 source_id using "`sources'", keep(master match) generate(source_merge)

    generate int event_first = daily(date_min_raw,"YMD")
    generate int event_last = daily(date_max_raw,"YMD")
    generate int source_date = daily(source_date_raw,"YMD")
    generate byte verified_venue = geography_status=="verified" & ///
        ustrregexm(locality10,"^[0-9]{10}$") & !missing(facility_id) & ///
        inlist(scope,"facility","public venue")

    * A witnessed link bounds first use from above for that service. It supplies no start day or uninterrupted use.
    generate int first_usable_earliest = event_first if source_merge==3 & verified_venue & ///
        inlist(event_type,"local_service_start","local_start_window")
    generate int first_usable_latest = event_last if source_merge==3 & verified_venue & ///
        (inlist(event_type,"local_service_start","local_start_window","usable_service_observed") | ///
        event_type=="provisional_service_observed")
    generate int installation_pending_asof = event_last if source_merge==3 & verified_venue & ///
        event_type=="installation_incomplete" & !missing(event_first,event_last) & event_first==event_last
    generate str10 start_status = "unresolved"
    replace start_status = "bounded" if !missing(first_usable_earliest) | !missing(first_usable_latest)
    replace start_status = "exact" if event_type=="local_service_start" & ///
        !missing(first_usable_earliest,first_usable_latest) & first_usable_earliest==first_usable_latest

    * Only an explicit finding for this venue can define a waiting, operating or interrupted interval.
    generate int waiting_from = event_first if source_merge==3 & verified_venue & ///
        event_type=="documented_waiting" & !missing(event_first,event_last) & event_first<=event_last
    generate int waiting_through = event_last if !missing(waiting_from)
    generate int operating_from = event_first if source_merge==3 & verified_venue & ///
        event_type=="documented_operation_window" & !missing(event_first,event_last) & event_first<=event_last
    generate int operating_through = event_last if !missing(operating_from)
    generate int interruption_from = event_first if source_merge==3 & verified_venue & ///
        event_type=="documented_interruption" & !missing(event_first,event_last) & event_first<=event_last
    generate int interruption_through = event_last if !missing(interruption_from)
    format event_first event_last source_date first_usable_earliest first_usable_latest installation_pending_asof ///
        waiting_from waiting_through operating_from operating_through interruption_from ///
        interruption_through %tdCCYY-NN-DD

    label data "PRONATEL regional roster and sourced service events"
    label variable event_id "Source-record ID, unique within this dataset"
    label variable roster_in_geoperu "Code listed in the April 2024 GeoPeru regional roster"
    label variable roster_in_workbook "Code listed in the PRONATEL workbook received 24 November 2026"
    label variable workbook_excel_row "Row of the source workbook on the Export sheet"
    label variable workbook_region_operation "Regional project date printed in the workbook"
    label variable workbook_date_raw "Original regional workbook date cell"
    label variable workbook_schools "School count reported in the roster workbook"
    label variable workbook_health_posts "Health facility count reported in the roster workbook"
    label variable workbook_police "Police station count reported in the roster workbook"
    label variable workbook_cad "Digital access centre count reported in the roster workbook"
    label variable workbook_wifi "Public Wi-Fi square count reported in the roster workbook"
    format workbook_region_operation %tdCCYY-NN-DD
    char _dta[workbook_source] "`workbook_path'"
    char _dta[workbook_sha256] "`workbook_hash'"
    label variable verified_venue "Audited locality and service-venue identifier"
    label variable event_first "Earliest date of this event in the source"
    label variable event_last "Latest date of this event in the source"
    label variable first_usable_earliest "Lower bound on first usable service at this venue and service type"
    label variable first_usable_latest "Upper bound from witnessed or explicitly dated first service"
    label variable start_status "Evidence for first usable service, by event"
    label variable installation_pending_asof "Verified incomplete installation on this day"
    label variable waiting_from "Start of affirmed waiting interval for this venue and service"
    label variable waiting_through "End of affirmed waiting interval for this venue and service"
    label variable operating_from "Start of documented usable service interval"
    label variable operating_through "End of documented usable service interval"
    label variable interruption_from "Start of documented interruption interval"
    label variable interruption_through "End of documented interruption interval"
    char _dta[grain] "One roster designation snapshot or one sourced chronology event"
    char _dta[use] "Verified timing is specific to the stated service and venue"

    order event_id project project_id scope locality10 locality_name facility_id operator_site_id ///
        site_name service intended_users event_type event_first event_last date_precision start_status source_id
    sort event_id
    compress

    preserve
    generate byte observations = 1
    collapse (sum) observations, by(project scope service event_type start_status)
    export delimited using "`run'/pronatel_event_counts.csv", replace
    restore

    quietly datasignature
    local signature "`r(datasignature)'"
    quietly save "`working'/PRONATEL_coded.dta", replace
    display "PRONATEL_PREPARATION_OK " _N " records " "`signature'"
    log close pronatel_prep
    exit
}

* Frozen Stage 02 replay. Preserve the existing working and coded data contracts.

* The historical series uses the pilot's seven rounds. The extension adds 2019 and 2023.
if !inlist("`series'", "historical", "extended") {
    display as error "Choose historical or extended for the ENDES series."
    exit 198
}
local waves 2017 2018 2020 2021 2022 2024 2025
if "`series'" == "extended" local waves 2017 2018 2019 2020 2021 2022 2023 2024 2025

log using "`run'/prep.log", text name(preparation)
local edition = cond(c(MP), "MP", cond(c(SE), "SE", "BE"))
display as text "Stata/`edition' " c(stata_version) ", " c(processors) " processor(s)"
display as text "Input vintage: `inputs'"
display as text "Dataset series: `series'"

tempfile module_map roster health households housing working coded
tempname merge_audit

quietly import delimited using "`inputs'/core/modules.csv", clear stringcols(_all)
if "`series'" == "extended" {
    tempfile core_map
    quietly save "`core_map'"
    quietly import delimited using "`inputs'/extension/modules.csv", clear stringcols(_all)
    quietly keep wave module source source_sha256 member file format encoding separator expected_rows input_sha256
    quietly append using "`core_map'"
}
quietly destring wave expected_rows, replace
isid wave module
assert inlist(format, "csv", "sav", "dta")
assert strlen(input_sha256) == 64 & strlen(source_sha256) == 64
quietly save "`module_map'"

quietly import delimited using "`inputs'/roster_geoperu_20240416.csv", clear ///
    varnames(1) stringcols(1/5) encoding("utf-8")
isid cod_ccpp
assert ustrregexm(cod_ccpp, "^[0-9]{10}$")
assert _N == 6945
tabulate py_ban_anc
keep if py_ban_anc == "PY_REGIONAL"
assert _N == 6848
generate str32 project = ustrregexs(1) if ustrregexm(nom_proyec, "^\[REGIONAL\]\[(.+?)\]$")
assert !missing(project)
replace project = ustrregexra(ustrnormalize(ustrupper(project), "nfkd"), "\p{Mark}", "")
rename cod_ccpp candidate_locality10
rename nom_ccpp roster_locality_name
keep candidate_locality10 roster_locality_name project estado_py iiee_py eess_py
quietly save "`roster'"

local items qs700a qs700b qs700c qs700d qs700e qs700f qs700g qs700h qs700i
postfile `merge_audit' int wave str24 relation str8 cardinality long ///
    master_before using_before master_only using_only matched master_retained ///
    using "`run'/merge_counts.dta"

local first = 1
foreach wave of local waves {
    foreach module in csalud01 rech0 rech23 {
        quietly use "`module_map'", clear
        quietly keep if wave == `wave' & module == "`module'"
        assert _N == 1
        local file = file[1]
        local fmt = format[1]
        local encoding = encoding[1]
        local sep = separator[1]
        local expected = expected_rows[1]
        local hash = input_sha256[1]
        local parent_hash = source_sha256[1]
        display as text "INPUT `wave' `module' `file' sha256=`hash' source_sha256=`parent_hash'"
        if "`fmt'" == "csv" {
            local delimiter ","
            if "`sep'" == "semicolon" local delimiter ";"
            if "`sep'" == "pipe" local delimiter "|"
            assert inlist("`sep'", "comma", "semicolon", "pipe")
            quietly import delimited using "`inputs'/`file'", clear ///
                varnames(1) case(lower) stringcols(_all) delimiters("`delimiter'") ///
                bindquote(strict) encoding("`encoding'")
            assert _N == `expected'
        }
        if "`fmt'" == "sav" quietly import spss using "`inputs'/`file'", clear case(lower)
        if "`fmt'" == "dta" {
            quietly use "`inputs'/`file'", clear
            rename *, lower
        }
        assert _N > 0

        if "`module'" == "csalud01" {
            local numbers qs23 qsintm qsinty peso15_amas qssexo qsnumero qsresult qhcluster `items'
            local strings hhid
            local destination "`health'"
            local n_health = _N
        }
        if "`module'" == "rech0" {
            local numbers hv001 hv022 hv023 hv024 hv025
            local strings hhid codccpp nomccpp
            if `wave' != 2017 local strings `strings' ubigeo
            local destination "`households'"
            local n_0 = _N
        }
        if "`module'" == "rech23" {
            local numbers sh61q
            if `wave' == 2017 local numbers `numbers' shprovin shdistri
            local strings hhid
            local destination "`housing'"
            local n_23 = _N
        }
        keep `strings' `numbers'
        foreach field of local strings {
            confirm string variable `field'
        }
        foreach field of local numbers {
            capture confirm numeric variable `field'
            if _rc {
                quietly replace `field' = subinstr(strtrim(`field'), ",", ".", .)
                quietly destring `field', replace
                confirm numeric variable `field'
            }
        }
        quietly replace hhid = strtrim(hhid)
        isid hhid
        display as text "KEY CHECK `wave' `module' " as result _N as text " unique HHIDs"
        quietly save "`destination'", replace
    }

    * Start from the selected health respondents and retain that unit after both household joins.
    quietly use "`health'", clear
    label drop _all
    foreach m in 0 23 {
        local household_file "`households'"
        if `m' == 23 local household_file "`housing'"
        quietly merge 1:1 hhid using "`household_file'", generate(merge_rech`m') nolabel
        display as text "JOIN `wave': CSALUD01 to RECH`m'"
        tabulate merge_rech`m', missing
        quietly count if merge_rech`m' == 1
        local master_only = r(N)
        quietly count if merge_rech`m' == 2
        local using_only = r(N)
        quietly count if merge_rech`m' == 3
        local matched = r(N)
        assert `master_only' + `matched' == `n_health'
        assert `using_only' + `matched' == `n_`m''
        post `merge_audit' (`wave') ("health_rech`m'") ("1:1") ///
            (`n_health') (`n_`m'') (`master_only') (`using_only') (`matched') (`n_health')
        assert merge_rech`m' != 1
        quietly drop if merge_rech`m' == 2
        label drop _all
    }
    assert _N == `n_health'
    generate int wave = `wave'
    if `wave' == 2017 {
        generate str6 ubigeo = string(hv024, "%02.0f") + string(shprovin, "%02.0f") ///
            + string(shdistri, "%02.0f") if inrange(hv024,1,98) & inrange(shprovin,1,98) ///
            & inrange(shdistri,1,98) & hv024 == floor(hv024) ///
            & shprovin == floor(shprovin) & shdistri == floor(shdistri)
    }
    generate byte youth = inrange(qs23,15,29)
    generate byte rural = (hv025 == 2) if inlist(hv025,1,2)
    assert qs23 == floor(qs23) if youth
    if !`first' quietly append using "`working'"
    quietly save "`working'", replace
    quietly keep if wave == `wave'

    * The PHQ score uses all nine items in their valid range.
    local valid_items
    foreach field of local items {
        quietly generate byte valid_`field' = `field' if inlist(`field',0,1,2,3)
        local valid_items `valid_items' valid_`field'
    }
    quietly egen byte nphq = rownonmiss(`valid_items')
    quietly egen byte phq9 = rowtotal(`valid_items')
    quietly replace phq9 = . if nphq != 9
    drop `valid_items'
    assert inrange(phq9,0,27) if nphq == 9
    assert missing(phq9) == (nphq != 9)
    generate byte positive_weight = peso15_amas > 0 & peso15_amas < .
    generate byte eligible = youth & nphq == 9 & positive_weight
    generate byte rural_youth = eligible & rural == 1

    * Retain the pilot key rule for reconciliation and the component-length rule for later diagnostics.
    generate byte pilot_key_valid = ustrregexm(strtrim(ubigeo) + strtrim(codccpp), "^[0-9]{10}$")
    generate byte locality_key_valid = ustrregexm(strtrim(ubigeo), "^[0-9]{6}$") ///
        & ustrregexm(strtrim(codccpp), "^[0-9]{4}$")
    generate str10 candidate_locality10 = strtrim(ubigeo) + strtrim(codccpp) if pilot_key_valid
    generate str10 locality10 = candidate_locality10 if locality_key_valid
    assert pilot_key_valid if locality_key_valid

    quietly merge m:1 candidate_locality10 using "`roster'", generate(merge_roster) nolabel
    display as text "JOIN `wave': health records to regional roster by ten-digit code"
    tabulate merge_roster, missing
    quietly count if merge_roster == 1
    local master_only = r(N)
    quietly count if merge_roster == 2
    local using_only = r(N)
    quietly count if merge_roster == 3
    local matched = r(N)
    assert `master_only' + `matched' == `n_health'
    egen byte roster_key_tag = tag(candidate_locality10) if merge_roster == 3
    quietly count if roster_key_tag == 1
    assert `using_only' + r(N) == 6848
    post `merge_audit' (`wave') ("health_regional_roster") ("m:1") ///
        (`n_health') (6848) (`master_only') (`using_only') (`matched') (`n_health')
    quietly drop if merge_roster == 2
    drop roster_key_tag
    assert _N == `n_health'
    assert pilot_key_valid if merge_roster == 3

    generate byte roster_designated = (merge_roster == 3) if locality_key_valid
    generate byte roster_group = cond(!locality_key_valid, 3, cond(roster_designated, 1, 2))
    label define roster_group 1 "Regional roster match" 2 "Valid key outside regional roster" ///
        3 "Invalid locality key", replace
    label values roster_group roster_group
    generate byte name_disagree = 0
    foreach name in nomccpp roster_locality_name {
        quietly generate strL normal_`name' = ustrregexra(ustrnormalize(ustrupper(`name'),"nfkd"),"\p{Mark}","")
        quietly replace normal_`name' = strtrim(ustrregexra(normal_`name', "[^A-Z0-9]+", " "))
        quietly replace normal_`name' = "NAN" if missing(`name')
    }
    quietly replace name_disagree = normal_nomccpp != normal_roster_locality_name if merge_roster == 3
    drop normal_nomccpp normal_roster_locality_name
    generate int visit_month = ym(qsinty,qsintm) if inlist(qsinty,wave,wave+1) ///
        & inrange(qsintm,1,12) & qsintm == floor(qsintm)
    format visit_month %tm
    generate byte home_internet = sh61q if inlist(sh61q,0,1)
    label variable home_internet "Household internet (SH61Q, 0/1)"
    label variable visit_month "Final health-module visit month (actual calendar)"
    label variable phq9 "Nine valid two-week PHQ items, 0 to 27"

    if !`first' quietly append using "`coded'"
    quietly save "`coded'", replace
    local first = 0
}
postclose `merge_audit'
use "`run'/merge_counts.dta", clear
isid wave relation
export delimited using "`run'/merge_counts.csv"

foreach data in working coded {
    quietly use "``data''", clear
    isid wave hhid, sort
    quietly compress
    label data "Private ENDES `series' vintage"
    char _dta[series] "`series'"
    datasignature
    save "`run'/`data'.dta"
}
display as result "ECONTHAKI_PREPARATION_OK `series'"
log close preparation

