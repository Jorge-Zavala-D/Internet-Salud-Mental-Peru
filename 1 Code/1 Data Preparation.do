* Run through 0 Master.do. The private input register preserves native INEI vintages.
version 16.0
args series
local waves 2017 2018 2020 2021 2022 2024 2025
if "`series'" == "extended" local waves 2017 2018 2019 2020 2021 2022 2023 2024 2025

tempfile module_map roster health households housing working coded
tempname merge_audit

quietly import delimited using "${econ_inputs}/core/modules.csv", clear stringcols(_all)
if "`series'" == "extended" {
    tempfile core_map
    quietly save "`core_map'"
    quietly import delimited using "${econ_inputs}/extension/modules.csv", clear stringcols(_all)
    quietly keep wave module source source_sha256 member file format encoding separator expected_rows input_sha256
    quietly append using "`core_map'"
}
quietly destring wave expected_rows, replace
isid wave module
assert inlist(format, "csv", "sav", "dta")
assert strlen(input_sha256) == 64 & strlen(source_sha256) == 64
quietly save "`module_map'"

quietly import delimited using "${econ_inputs}/roster_geoperu_20240416.csv", clear ///
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
    using "${econ_run}/merge_counts.dta"

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
        confirm file "${econ_inputs}/`file'"
        if "`fmt'" == "csv" {
            local delimiter ","
            if "`sep'" == "semicolon" local delimiter ";"
            if "`sep'" == "pipe" local delimiter "|"
            assert inlist("`sep'", "comma", "semicolon", "pipe")
            quietly import delimited using "${econ_inputs}/`file'", clear ///
                varnames(1) case(lower) stringcols(_all) delimiters("`delimiter'") ///
                bindquote(strict) encoding("`encoding'")
            assert _N == `expected'
        }
        if "`fmt'" == "sav" quietly import spss using "${econ_inputs}/`file'", clear case(lower)
        if "`fmt'" == "dta" {
            quietly use "${econ_inputs}/`file'", clear
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
use "${econ_run}/merge_counts.dta", clear
isid wave relation
export delimited using "${econ_run}/merge_counts.csv"

foreach data in working coded {
    quietly use "``data''", clear
    isid wave hhid, sort
    quietly compress
    label data "Private ENDES `series' vintage"
    char _dta[series] "`series'"
    datasignature
    save "${econ_run}/`data'.dta"
}
display as result "ECONTHAKI_PREPARATION_OK `series'"

