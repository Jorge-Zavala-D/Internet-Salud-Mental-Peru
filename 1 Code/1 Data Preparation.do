version 16.0
args inputs run series

* ENDES survey preparation. Each row represents a selected person in one survey wave.
if inlist("`series'", "endes_pilot", "endes", "endes_with_2015") {
    local dropbox = ustrlower(subinstr("${econ_dropbox}", char(92), "/", .))
    local output = ustrlower(subinstr("`run'", char(92), "/", .))
    if "`dropbox'" == "" | !regexm("`output'", "^([a-z]:/|/)") | ///
        strpos("`output'/", "`dropbox'/") == 1 | strpos("`output'/", "/../") {
        display as error "Load the local project paths and supply an absolute protected run directory."
        exit 198
    }
    log using "`run'/endes_preparation.log", text name(endes_prep)
    local edition = cond(c(MP), "MP", cond(c(SE), "SE", "BE"))
    display "Stata/`edition' " c(stata_version) " revision " c(born_date)
    display "ENDES input register: `inputs'/modules.csv. Series: `series'."
    local first = 2016
    local last = 2025
    if "`series'" == "endes_pilot" local last = 2017
    if "`series'" == "endes_with_2015" local first = 2015

    tempfile inventory health household housing roster appended reviews exceptions lookup points
    quietly import delimited using "`inputs'/modules.csv", clear varnames(1) stringcols(_all) encoding("utf-8")
    quietly destring wave rows variables, replace
    isid wave table
    assert inlist(format,"sav","csv","dta") & strlen(sha256)==64 & rows>0 & variables>0
    assert inlist(role,"core","context")
    keep if inrange(wave,`first',`last')
    if "`series'" == "endes_pilot" assert _N == 62
    if "`series'" == "endes" assert _N == 86
    if "`series'" == "endes_with_2015" assert _N == 89
    export delimited using "`run'/endes_inputs.csv"
    copy "`inputs'/input_provenance.csv" "`run'/endes_evidence.csv"
    quietly save "`inventory'"

    * Attach only the reviewed survey-side flags. Programme designation is a later block.
    quietly import delimited using "`inputs'/locality_reviews.csv", clear stringcols(_all) encoding("utf-8")
    quietly destring wave, replace
    isid wave native_locality10 nomccpp
    assert _N == 138
    assert inrange(wave,2016,2025)
    assert inlist(disposition,"verified","point_review","identity_unresolved")
    quietly save "`reviews'"
    quietly import delimited using "`inputs'/geography_exceptions.csv", clear stringcols(_all) encoding("utf-8")
    quietly destring wave code_switch_review, replace
    isid wave native_locality10 nomccpp
    assert _N == 6 & code_switch_review == 1
    quietly save "`exceptions'"
    if `first' == 2015 {
        quietly import delimited using "`inputs'/2015_locality_lookup.csv", clear stringcols(_all) encoding("utf-8")
        quietly destring x y two_rounds external_agree external_conflict, replace
        isid district6 x y
        assert _N == 943 & substr(locality10,1,6)==district6
        assert inlist(two_rounds,0,1) & inlist(external_agree,0,1) & inlist(external_conflict,0,1)
        rename locality10 candidate_2015
        quietly save "`lookup'"
    }

    tempname imports joins fields
    tempfile import_counts merge_counts source_fields
    local phq_items qs700a qs700b qs700c qs700d qs700e qs700f qs700g qs700h qs700i
    postfile `imports' int wave str32 table str8 role long observations int fields ///
        str40 grain_check using "`import_counts'"
    postfile `joins' int wave str20 relation str5 cardinality long ///
        master_before using_before master_only using_only matched retained using "`merge_counts'"
    postfile `fields' int wave str12 table str32 native_field str12 native_type ///
        str244 native_label using "`source_fields'"

    forvalues year = `first'/`last' {
        quietly use "`inventory'", clear
        quietly keep if wave == `year'
        levelsof table, local(tables) clean
        local core CSALUD01 RECH0 RECH23
        if inlist(`year',2016,2017) local core `core' RECH1
        foreach required of local core {
            quietly count if table == "`required'" & role == "core"
            assert r(N) == 1
        }
        foreach table of local tables {
            quietly use "`inventory'", clear
            quietly keep if wave==`year' & table=="`table'"
            local source = path[1]
            local format = format[1]
            local encoding = encoding[1]
            local separator = separator[1]
            local wanted_rows = rows[1]
            local wanted_columns = variables[1]
            local role = role[1]
            local grain = subinstr(keys[1],";","",.)
            local sha = sha256[1]
            display "Input `year' `table' `source' SHA-256 `sha'"
            if "`format'" == "sav" quietly import spss using "`source'", clear case(lower)
            if "`format'" == "dta" quietly use "`source'", clear
            if "`format'" == "csv" {
                assert inlist("`separator'","comma","semicolon") & "`encoding'"!=""
                local delimiter = cond("`separator'"=="semicolon", ";", ",")
                quietly import delimited using "`source'", clear varnames(1) case(lower) ///
                    stringcols(_all) delimiters("`delimiter'") bindquote(strict) encoding("`encoding'")
            }
            assert _N==`wanted_rows' & c(k)==`wanted_columns'
            if "`role'" == "context" {
                * Published supplementary tables retain their grain in the source files.
                capture isid `grain'
                local result = cond(_rc==0,"candidate key unique","candidate key needs review before use")
                post `imports' (`year') ("`table'") ("`role'") (_N) (c(k)) ("`result'")
                continue
            }
            local survey_vars
            local raw_strings hhid
            if "`table'" == "CSALUD01" {
                local weight peso15_amas
                if `year'==2015 local weight peso15_ajus
                local survey_vars qs23 qssexo qsnumero qhcluster qsresult qsintm qsinty `weight' `phq_items'
                if `year'<=2018 local survey_vars `survey_vars' qsintd
                if `year'>=2019 {
                    capture confirm variable qsintd, exact
                    assert _rc == 111
                }
                if `year'==2016 {
                    foreach staff in qsdni qsant qsaux {
                        capture confirm variable `staff', exact
                        assert _rc == 111
                    }
                }
                local destination "`health'"
            }
            if "`table'" == "RECH0" {
                local lon longitudx
                local lat latitudy
                if `year'==2017 {
                    local lon long_ccpp
                    local lat lat_ccpp
                }
                local survey_vars hv001 hv015 hv022 hv023 hv024 hv025 `lon' `lat'
                if `year'>=2016 local raw_strings `raw_strings' codccpp nomccpp
                if `year'>=2018 local raw_strings `raw_strings' ubigeo
                local destination "`household'"
            }
            if "`table'" == "RECH23" {
                local survey_vars sh61q shprovin shdistri
                local destination "`housing'"
            }
            if "`table'" == "RECH1" {
                local survey_vars hvidx hv104 hv105
                local destination "`roster'"
            }
            local native_size = c(k)
            local n_`table' = _N
            keep `raw_strings' `survey_vars'
            foreach variable of varlist `raw_strings' `survey_vars' {
                local vartype : type `variable'
                local meaning : variable label `variable'
                post `fields' (`year') ("`table'") ("`variable'") ("`vartype'") (`"`meaning'"')
            }
            foreach variable of local raw_strings {
                confirm string variable `variable'
            }
            foreach variable of local survey_vars {
                capture confirm numeric variable `variable'
                if _rc {
                    quietly replace `variable' = subinstr(ustrtrim(`variable'), ",", ".", .)
                    quietly destring `variable', replace
                    confirm numeric variable `variable'
                }
            }
            quietly replace hhid = strtrim(hhid)
            if "`table'" == "RECH1" {
                isid hhid hvidx
                rename (hvidx hv104 hv105) (qsnumero roster_sex roster_age)
            }
            else isid hhid
            post `imports' (`year') ("`table'") ("`role'") (_N) (`native_size') ("verified unique")
            * Value labels are assigned consistently after the native metadata is recorded.
            label drop _all
            if "`table'" == "CSALUD01" {
                generate double health_weight = `weight'
                generate str11 weight_source = upper("`weight'")
                if `year'>=2019 generate byte qsintd = .
                generate byte visit_day_released = (`year'<=2018)
            }
            if "`table'" == "RECH0" {
                rename (`lon' `lat') (longitude_raw latitude_raw)
                if `year'==2015 {
                    generate str4 codccpp = ""
                    generate str1 nomccpp = ""
                }
                if `year'<2018 generate str6 ubigeo = ""
            }
            quietly save "`destination'", replace
        }

        * Keep every selected person. Account for all unused household and roster records.
        quietly use "`health'", clear
        local spine = _N
        foreach relation in household housing {
            local source "`housing'"
            local source_n = `n_RECH23'
            if "`relation'" == "household" {
                local source "`household'"
                local source_n = `n_RECH0'
            }
            quietly merge 1:1 hhid using "`source'", generate(join_result) nolabel
            quietly count if join_result == 1
            local master_only = r(N)
            quietly count if join_result == 2
            local using_only = r(N)
            quietly count if join_result == 3
            local matched = r(N)
            post `joins' (`year') ("`relation'") ("1:1") (`spine') ///
                (`source_n') (`master_only') (`using_only') (`matched') (`spine')
            assert `matched'+`using_only'==`source_n'
            tabulate join_result
            assert `master_only'==0 & `matched'==`spine'
            quietly drop if join_result==2
            drop join_result
        }
        generate byte roster_checked = inlist(`year',2016,2017)
        if inlist(`year',2016,2017) {
            isid hhid qsnumero
            quietly merge 1:1 hhid qsnumero using "`roster'", generate(join_result) nolabel
            quietly count if join_result == 1
            local master_only = r(N)
            quietly count if join_result == 2
            local using_only = r(N)
            quietly count if join_result == 3
            local matched = r(N)
            post `joins' (`year') ("person_roster") ("1:1") (`spine') ///
                (`n_RECH1') (`master_only') (`using_only') (`matched') (`spine')
            assert `matched'+`using_only'==`n_RECH1'
            tabulate join_result
            assert `master_only'==0 & `matched'==`spine'
            quietly drop if join_result==2
            drop join_result
            assert qs23==roster_age if !missing(qs23,roster_age)
            assert qssexo==roster_sex if !missing(qssexo,roster_sex)
            drop roster_age roster_sex
        }
        assert _N == `spine'
        generate int wave = `year'
        if `year' > `first' quietly append using "`appended'"
        quietly save "`appended'", replace
    }
    postclose `imports'
    postclose `joins'
    postclose `fields'


    * Align the survey definitions at respondent-wave grain.
    quietly use "`appended'", clear
    isid wave hhid, sort
    generate byte main_wave = inrange(wave,2016,2025)
    generate byte mode_review = wave == 2020
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

    * Q700 records nine items on the 0–3 scale over the previous 14 days.
    local valid_items
    local item_status
    foreach item of local phq_items {
        generate byte valid_`item' = `item' if inlist(`item',0,1,2,3)
        local valid_items `valid_items' valid_`item'
        generate byte `item'_status = 4
        replace `item'_status = 0 if !missing(valid_`item')
        replace `item'_status = 1 if missing(`item')
        replace `item'_status = 2 if missing(`item') & inlist(qsresult,2,3)
        replace `item'_status = 3 if missing(`item') & qsresult==4
        local item_status `item_status' `item'_status
    }
    egen byte nphq = rownonmiss(`valid_items')
    egen byte phq9 = rowtotal(`valid_items')
    replace phq9 = . if nphq != 9
    assert inrange(phq9,0,27) if nphq==9
    assert missing(phq9) == (nphq!=9)
    assert phq9==qs700a+qs700b+qs700c+qs700d+qs700e+qs700f+qs700g+qs700h+qs700i if nphq==9
    drop `valid_items'
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

    * Keep the released district and settlement fields. The suffix is never inferred from names.
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
    assert native_key_valid<=pilot_geographic_shape
    generate str10 native_locality10 = district6 + locality_suffix if native_key_valid
    generate str10 locality10 = native_locality10
    assert substr(native_locality10,1,6)==district6 & substr(native_locality10,7,4)==locality_suffix if native_key_valid
    assert missing(native_locality10) == !native_key_valid
    merge m:1 wave native_locality10 nomccpp using "`reviews'", keep(master match) nogen
    generate byte locality_review = 0
    replace locality_review = 1 if disposition=="verified"
    replace locality_review = 2 if disposition=="point_review"
    replace locality_review = 3 if disposition=="identity_unresolved"
    drop disposition
    merge m:1 wave native_locality10 nomccpp using "`exceptions'", keep(master match) nogen
    replace code_switch_review = 0 if missing(code_switch_review)
    generate byte service_site_review = locality_review==2

    generate byte sensitivity_broad = 0
    generate byte sensitivity_strict = 0
    generate byte sensitivity_corroborated = 0
    generate byte sensitivity_later_review = 0
    if `first'==2015 {
        generate long x = round(longitude_raw*1000000) if wave==2015
        generate long y = round(latitude_raw*1000000) if wave==2015
        merge m:1 district6 x y using "`lookup'", keep(master match) generate(link2015)
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
        assert missing(locality10) if wave==2015 & !sensitivity_strict
        drop candidate_2015 later_review
    }
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
            isid native_locality10 reference_lon reference_lat
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
            isid native_locality10 longitude_raw latitude_raw
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
    assert locality10==native_locality10 if coordinate_swapped
    generate byte coordinate_status = cond(coordinate_swapped,1,cond(raw_point_plausible,0, ///
        cond(swap_candidate,2,cond(missing(longitude_raw,latitude_raw),3,4))))


    * The survey-only count gates recover the dated audits before any programme linkage.
    local expected_rural 3558 3534 3664 3508 3340 3765 3587 3446 3284 2944
    local expected_shape 3549 3528 3664 3508 3340 3765 3587 3446 3284 2944
    local expected_native 3549 3528 3627 3473 3312 3763 3584 3444 3284 2944
    forvalues year = 2016/`last' {
        local pos = `year'-2015
        local rural_count : word `pos' of `expected_rural'
        local shape_count : word `pos' of `expected_shape'
        local native_count : word `pos' of `expected_native'
        quietly count if wave==`year' & eligible_rural_youth
        assert r(N)==`rural_count'
        quietly count if wave==`year' & eligible_rural_youth & pilot_geographic_shape
        assert r(N)==`shape_count'
        quietly count if wave==`year' & eligible_rural_youth & native_key_valid
        assert r(N)==`native_count'
    }
    quietly count if wave==2016 & eligible_rural_youth & locality_review==1
    assert r(N)==19
    quietly count if wave==2016 & eligible_rural_youth & locality_review==2
    assert r(N)==4
    quietly count if wave==2016 & eligible_rural_youth & locality_review==3
    assert r(N)==1
    if `last'==2025 {
        forvalues code=1/3 {
            local expected : word `code' of 357 41 13
            quietly count if wave>=2017 & eligible_rural_youth & locality_review==`code'
            assert r(N)==`expected'
        }
        quietly count if eligible_rural_youth & code_switch_review
        assert r(N)==18
        quietly count if eligible_rural_youth & coordinate_swapped
        assert r(N)==355
        egen byte swapped_locality = tag(native_locality10) if eligible_rural_youth & coordinate_swapped
        quietly count if swapped_locality==1
        assert r(N)==143
        drop swapped_locality
        quietly count if eligible_rural_youth & swap_candidate & !coordinate_swapped
        assert r(N)==0
    }
    if `first'==2015 {
        quietly count if wave==2015 & eligible_rural_youth
        assert r(N)==3926
        quietly count if sensitivity_broad
        assert r(N)==3145
        quietly count if sensitivity_strict
        assert r(N)==2157
        quietly count if sensitivity_corroborated
        assert r(N)==581
        quietly count if sensitivity_later_review
        assert r(N)==10
        assert !main_wave if sensitivity_broad
    }

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
    label define coordinate_status 0 "Published axes plausible" 1 "Swapped, same-code INEI reference within 1 m" ///
        2 "Swap candidate without reference confirmation" 3 "Source coordinate missing" 4 "Outside geographic range"
    label values age_band age_band
    label values hv025 area
    label values qssexo sex
    label values qsresult health_result
    label values weight_status weight_status
    label values `phq_items' phq_frequency
    label values `item_status' item_status
    label values internet_status internet_status
    label values date_precision date_precision
    label values locality_review locality_review
    label values coordinate_status coordinate_status
    label values main_wave mode_review youth rural positive_weight health_complete home_internet ///
        eligible eligible_rural_youth visit_day_released date_anomaly day_anomaly next_calendar_year ///
        fieldwork_unexpected psu_disagreement survey_design_missing district_conflict district_range_review ///
        pilot_geographic_shape native_key_valid ///
        service_site_review code_switch_review sensitivity_broad sensitivity_strict sensitivity_corroborated ///
        sensitivity_later_review geography_hold locality_usable coordinate_swapped roster_checked ///
        field_staff_removed raw_point_plausible swap_candidate yes_no

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
    foreach item of local phq_items {
        label variable `item'_status "`item' response status"
    }
    label variable nphq "Number of valid Q700 responses (0–9)"
    label variable phq9 "Sum of nine valid Q700 responses, previous 14 days (0–27)"
    label variable health_weight "Native selected-person health weight, unscaled"
    label variable weight_source "Native INEI name of health weight"
    label variable positive_weight "Health weight is finite and positive"
    label variable eligible "Age 15–29, positive health weight and all nine Q700 items valid"
    label variable eligible_rural_youth "Outcome-eligible and rural, before linkage and mode decisions"
    label variable main_wave "In 2016–2025 survey series"
    label variable mode_review "2020 mixed-mode comparability review, individual mode unidentified"
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
    label variable district6 "Validated six-digit survey district"
    label variable codccpp "Original populated-centre suffix"
    label variable nomccpp "Original INEI populated-centre name"
    label variable locality_suffix "Validated four-digit populated-centre suffix"
    label variable pilot_geographic_shape "Native source meets the original pilot district and locality format"
    label variable district_range_review "Six-digit released UBIGEO has a component outside district code ranges"
    label variable native_key_valid "Released district and suffix form a consistent locality key"
    label variable native_locality10 "Ten-digit locality code from released survey fields"
    label variable locality10 "Survey locality key, including approved strict 2015 sensitivity links"
    label variable locality_usable "Code available and survey identity is usable for later linkage"
    label variable case_id "Case in the approved survey name adjudication ledger"
    label variable locality_review "Survey locality identity adjudication status"
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
    label variable roster_checked "2016–2017 selected person verified in the household roster"
    label variable field_staff_removed "Source is 2016 health copy with staff identifier fields omitted"

    order wave hhid qsnumero main_wave eligible eligible_rural_youth sensitivity_strict locality10 ///
        geography_hold visit_month visit_date date_precision phq9 nphq health_weight
    sort wave hhid
    compress
    label data "ENDES selected-person repeated cross-sections, survey preparation"
    char _dta[series] "`series'"
    char _dta[source_vintage] "endes-2016-2017-full-intake-2026-11-20-v1; frozen 2018–2025 and audited 2015"
    char _dta[wave_key] "wave hhid; qsnumero records selected household member"
    char _dta[interview_mode] "2020 mixed mode. Respondent-level administration unverified."
    char _dta[locality_audit] "endes-pronatel-locality-adjudication-2026-11-20-v1"
    char _dta[design] "Native PSU, stratum and domain retained. No assumption of independence across waves."
    quietly datasignature
    local signature "`r(datasignature)'"
    local total = _N
    local columns = c(k)
    quietly save "`appended'", replace

    * Keep one permanent dataset. Detailed quality-control tables stay in the protected run.
    foreach audit in import_counts merge_counts source_fields {
        quietly use "``audit''", clear
        export delimited using "`run'/endes_`audit'.csv"
    }
    quietly use "`appended'", clear
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
        generate byte SiteReview = Rural & service_site_review
        generate byte CodeReview = Rural & code_switch_review
        generate byte VerifiedIdentity = Rural & locality_review==1
        generate byte UnresolvedIdentity = Rural & locality_review==3
        generate byte AxesSwapped = Rural & coordinate_swapped
        collapse (sum) Health Age Weight PHQ Rural Geography Native PilotKeyShape UnknownAge UnknownArea ///
            UnknownInternet WeightMissing WeightNonpositive IncompletePHQ ModeReview DateDay DateMonthOnly ///
            DateUnknown DateOutside InvalidDate NextYear DesignMissing PSUDiffers DistrictConflict DistrictRangeReview SiteReview ///
            CodeReview VerifiedIdentity UnresolvedIdentity AxesSwapped sensitivity_broad sensitivity_strict ///
            sensitivity_corroborated sensitivity_later_review, by(wave)
        export delimited using "`run'/endes_wave_checks.csv"
    restore
    preserve
        contract wave qsinty qsintm qsintd date_precision health_complete mode_review, freq(interviews)
        export delimited using "`run'/endes_visit_calendar.csv"
    restore
    preserve
        contract wave age_band rural mode_review qsresult nphq, freq(interviews)
        export delimited using "`run'/endes_phq_completeness.csv"
    restore
    preserve
        keep wave age_band rural mode_review qs700?_status
        foreach item of local phq_items {
            forvalues status=0/4 {
                generate byte n`item'_`status' = (`item'_status==`status')
            }
        }
        collapse (sum) nqs*, by(wave age_band rural mode_review)
        export delimited using "`run'/endes_phq_item_routing.csv"
    restore
    preserve
        quietly keep if positive_weight
        collapse (count) n=health_weight (min) minimum=health_weight (p1) p01=health_weight ///
            (p50) median=health_weight (p99) p99=health_weight (max) maximum=health_weight, by(wave)
        export delimited using "`run'/endes_weight_check.csv"
    restore
    preserve
        quietly describe, replace clear
        export delimited using "`run'/endes_codebook.csv"
    restore

    quietly save "`run'/ENDES_coded.dta"
    quietly use "`run'/ENDES_coded.dta", clear
    isid wave hhid
    assert _N == `total' & c(k) == `columns'
    quietly datasignature
    assert "`r(datasignature)'" == "`signature'"
    tempname receipt
    file open `receipt' using "`run'/endes_signature.txt", write text
    file write `receipt' "series=`series'" _n "Stata/`edition' " (c(stata_version)) " " (c(born_date)) _n ///
        "observations=`total'" _n "variables=`columns'" _n "signature=`signature'" _n
    file close `receipt'
    display "ENDES_PREPARATION_OK `series' `total' rows `columns' fields `signature'"
    log close endes_prep
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

