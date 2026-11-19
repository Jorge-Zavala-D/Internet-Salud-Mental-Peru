version 16.0
args series
tempfile panel counts reference dates support
tempname survey overlap repeated

use wave hhid qs23 qsinty qs700a qs700b qs700c qs700d qs700e qs700f qs700g qs700h qs700i peso15_amas qhcluster hv001 hv022 youth rural nphq phq9 positive_weight eligible rural_youth pilot_key_valid locality_key_valid candidate_locality10 locality10 merge_roster roster_designated roster_group name_disagree visit_month home_internet project using "${econ_run}/coded.dta", clear
local coded_series : char _dta[series]
assert "`coded_series'" == "`series'"
isid wave hhid
levelsof wave, local(waves)
quietly save "`panel'"

local metrics health_n youth_n eligible_n rural_n nextyear_n invalid_total invalid_rural ///
    valid_total valid_rural observed_ccpp matched_people matched_ccpp discordant_people ///
    discordant_ccpp missing_home_net

generate byte health_n = 1
generate byte youth_n = youth
generate byte eligible_n = eligible
generate byte rural_n = rural_youth
generate byte nextyear_n = eligible & qsinty == wave + 1
generate byte invalid_total = eligible & !pilot_key_valid
generate byte invalid_rural = rural_youth & !pilot_key_valid
generate byte valid_total = eligible & pilot_key_valid
generate byte valid_rural = rural_youth & pilot_key_valid
egen byte observed_ccpp = tag(wave candidate_locality10) if valid_rural
generate byte matched_people = valid_rural & merge_roster == 3
egen byte matched_ccpp = tag(wave candidate_locality10) if matched_people
generate byte discordant_people = matched_people & name_disagree
egen byte discordant_ccpp = tag(wave candidate_locality10) if discordant_people
generate byte missing_home_net = valid_rural & missing(home_internet)

generate byte age_missing = missing(qs23)
generate byte youth_weight_valid = youth & positive_weight
generate byte youth_phq_complete = youth & nphq == 9
generate byte eligible_urban = eligible & rural == 0
generate byte eligible_residence_unknown = eligible & missing(rural)
generate byte eligible_visit_missing = eligible & missing(visit_month)
generate byte matched_visit_missing = matched_people & missing(visit_month)
generate byte key_rule_disagrees = eligible & locality_key_valid != pilot_key_valid
assert eligible == rural_youth + eligible_urban + eligible_residence_unknown
assert valid_rural + invalid_rural == rural_youth
collapse (sum) `metrics' age_missing youth_weight_valid youth_phq_complete ///
    eligible_urban eligible_residence_unknown eligible_visit_missing matched_visit_missing ///
    key_rule_disagrees, by(wave)
isid wave
export delimited using "${econ_run}/wave_counts.csv"
quietly save "`counts'"

import delimited using "${econ_inputs}/muestra.csv", clear case(lower)
rename anio wave
unab truncated : ccpp_con_algun_nombre_no_ident*
local legacy filas_salud edad_15_29 phq9_completo_peso_positivo jovenes_rurales ///
    visitas_en_anio_siguiente sin_clave_10_digitos_total sin_clave_10_digitos_rural ///
    elegibles_con_llave_valida jovenes_rurales_con_llave_valida ccpp_rurales ///
    con_codigo_en_padron ccpp_con_codigo_en_padron personas_con_nombre_no_identico ///
    `truncated' sin_dato_internet_hogar
rename (`legacy') (`metrics')
isid wave
foreach metric of local metrics {
    rename `metric' ref_`metric'
}
quietly save "`reference'"

quietly use "`counts'", clear
quietly keep wave `metrics'
quietly merge 1:1 wave using "`reference'", keep(master match) nogen
tempfile recon_frame
tempname reconciliation
postfile `reconciliation' int wave str24 metric long observed benchmark using "`recon_frame'"
forvalues row = 1/`=_N' {
    foreach metric of local metrics {
        post `reconciliation' (wave[`row']) ("`metric'") (`metric'[`row']) (ref_`metric'[`row'])
    }
}
postclose `reconciliation'
quietly use "`recon_frame'", clear
generate long difference = observed - benchmark if !missing(benchmark)
generate str24 status = cond(missing(benchmark),"no historical benchmark", ///
    cond(difference == 0,"equal","investigate"))
sort wave metric
isid wave metric
order wave metric observed benchmark difference status
tabulate status
export delimited using "${econ_run}/pilot_reconciliation.csv"

use "`panel'", clear
keep if youth
generate byte phq_incomplete = nphq != 9
generate byte phq_no_valid_items = nphq == 0
generate byte weight_missing = missing(peso15_amas)
generate byte weight_nonpositive = !missing(peso15_amas) & peso15_amas <= 0
generate byte final_visit_missing = missing(visit_month)
generate byte no_home_internet_code = missing(home_internet)
generate byte youth_records = 1
quietly collapse (sum) youth_records phq_incomplete phq_no_valid_items weight_missing ///
    weight_nonpositive final_visit_missing no_home_internet_code, by(wave rural roster_group)
export delimited using "${econ_run}/missingness.csv", nolabel

quietly use "`panel'", clear
quietly keep if youth
keep wave hhid rural roster_group qs700a qs700b qs700c qs700d qs700e qs700f qs700g qs700h qs700i
quietly expand 9
quietly bysort wave hhid: generate byte item_number = _n
generate double raw_code = .
local item_number = 0
foreach letter in a b c d e f g h i {
    local ++item_number
    quietly replace raw_code = qs700`letter' if item_number == `item_number'
}
generate str6 item = "qs700" + substr("abcdefghi",item_number,1)
generate byte people = 1
quietly collapse (sum) people, by(wave rural roster_group item raw_code)
order wave rural roster_group item raw_code people
export delimited using "${econ_run}/phq_raw_codes.csv", nolabel

use "`panel'", clear
keep if eligible
generate int visit_year = year(dofm(visit_month))
generate byte visit_month_number = month(dofm(visit_month))
generate byte people = 1
quietly collapse (sum) people, by(wave visit_year visit_month_number rural roster_group)
export delimited using "${econ_run}/visit_month_counts.csv", nolabel

quietly use "`panel'", clear
quietly keep if rural_youth & locality_key_valid
quietly collapse (count) people=eligible (max) discordance=name_disagree, ///
    by(locality10 roster_designated wave)
isid wave locality10
bysort locality10 (wave): assert roster_designated == roster_designated[1]
foreach wave of local waves {
    quietly egen long people`wave' = total(cond(wave == `wave',people,0)), by(locality10)
    quietly egen byte discordance`wave' = max(cond(wave == `wave',discordance,0)), by(locality10)
}
quietly bysort locality10 (wave): keep if _n == 1
postfile `overlap' int wave_a wave_b str20 scope long localities_a localities_b shared ///
    people_a_shared people_b_shared name_disagreement_shared using "`support'"
foreach a of local waves {
    foreach b of local waves {
        if `a' >= `b' continue
        foreach scope in all_rural_keys regional_roster {
            local in_scope "1"
            if "`scope'" == "regional_roster" local in_scope "roster_designated == 1"
            quietly count if (`in_scope') & people`a' > 0
            local n_a = r(N)
            quietly count if (`in_scope') & people`b' > 0
            local n_b = r(N)
            local in_both "(`in_scope') & people`a' > 0 & people`b' > 0"
            quietly count if `in_both'
            local n_shared = r(N)
            quietly summarize people`a' if `in_both', meanonly
            local n_people_a = r(sum)
            quietly summarize people`b' if `in_both', meanonly
            local n_people_b = r(sum)
            quietly count if (`in_both') & (discordance`a' | discordance`b')
            post `overlap' (`a') (`b') ("`scope'") (`n_a') (`n_b') (`n_shared') ///
                (`n_people_a') (`n_people_b') (r(N))
        }
    }
}
postclose `overlap'
use "`support'", clear
export delimited using "${econ_run}/locality_pair_overlap.csv"

use "`panel'", clear
keep if rural_youth & locality_key_valid & roster_designated == 1
generate byte early = wave <= 2018 if inlist(wave,2017,2018,2024,2025)
quietly bysort locality10: egen byte has_early = max(early == 1)
quietly bysort locality10: egen byte has_late = max(early == 0)
quietly bysort locality10: egen byte any_name_disagreement = max(name_disagree)
quietly keep if !missing(early)
generate byte shared_person = has_early & has_late
quietly egen byte period_locality = tag(project early locality10)
quietly egen byte shared_locality = tag(project early locality10) if shared_person
quietly egen byte discordant_shared = tag(project early locality10) if shared_person & any_name_disagreement
collapse (sum) period_locality shared_locality shared_person discordant_shared, by(project early)
export delimited using "${econ_run}/locality_block_overlap.csv"

import delimited using "${econ_inputs}/regional_dates.csv", clear varnames(1) stringcols(_all)
isid project
assert _N == 10
generate int launch_day = daily(osiptel_date,"YMD")
generate int earliest_day = daily(earliest_date,"YMD")
generate int latest_day = daily(latest_date,"YMD")
assert !missing(launch_day,earliest_day,latest_day)
assert inrange(launch_day,earliest_day,latest_day)
keep project launch_day earliest_day latest_day
quietly save "`dates'"
use "`panel'", clear
keep if rural_youth & locality_key_valid & roster_designated == 1
quietly merge m:1 project using "`dates'", generate(merge_dates) nolabel
tabulate merge_dates, missing
preserve
generate byte rows = 1
collapse (sum) rows, by(merge_dates)
export delimited using "${econ_run}/regional_calendar_merge.csv", nolabel
restore
drop if merge_dates == 2
format launch_day earliest_day latest_day %tdCCYY-NN-DD
generate int launch_month = mofd(launch_day)
generate int event_month = visit_month - launch_month
generate int visit_earliest = dofm(visit_month)
generate int visit_latest = dofm(visit_month+1)-1
generate byte pilot_period = 0 if !missing(visit_month,launch_day)
replace pilot_period = -1 if !missing(pilot_period) & visit_month < launch_month
replace pilot_period = 1 if !missing(pilot_period) & visit_month > launch_month+1
generate byte bounded_period = 0 if !missing(pilot_period)
replace bounded_period = -1 if !missing(bounded_period) & visit_latest < earliest_day
replace bounded_period = 1 if !missing(bounded_period) & visit_earliest-14 > latest_day
generate int alt_month = mofd(earliest_day)
generate byte earlier_period = 0 if !missing(pilot_period)
replace earlier_period = -1 if !missing(earlier_period) & visit_month < alt_month
replace earlier_period = 1 if !missing(earlier_period) & visit_month > alt_month+1
assert bounded_period == pilot_period if !missing(pilot_period) & pilot_period != 0 ///
    & earliest_day == latest_day
keep wave project locality10 hv001 visit_month launch_day launch_month event_month ///
    pilot_period bounded_period earlier_period
quietly save "`support'", replace

egen byte locality_tag = tag(wave project visit_month locality10), missing
egen byte psu_tag = tag(wave project visit_month hv001) if hv001 > 0 & hv001 < ., missing
generate byte people = 1
collapse (sum) people localities=locality_tag psus=psu_tag, ///
    by(wave project visit_month launch_month event_month pilot_period bounded_period earlier_period)
format visit_month launch_month %tm
export delimited using "${econ_run}/regional_calendar_support.csv"

postfile `repeated' str32 project str18 rule long pre_people post_people window_people ///
    unknown_month pre_ccpp post_ccpp ccpp_both people_pre_both people_post_both using "`dates'", replace
foreach rule in pilot_period bounded_period earlier_period {
    quietly use "`support'", clear
    quietly keep if !missing(launch_day)
    quietly bysort project locality10: egen byte has_pre = max(`rule' == -1)
    quietly bysort project locality10: egen byte has_post = max(`rule' == 1)
    quietly egen byte one = tag(project locality10)
    quietly levelsof project, local(projects) clean
    foreach project of local projects {
        quietly count if project == "`project'" & `rule' == -1
        local n_pre = r(N)
        quietly count if project == "`project'" & `rule' == 1
        local n_post = r(N)
        quietly count if project == "`project'" & `rule' == 0
        local n_window = r(N)
        quietly count if project == "`project'" & missing(`rule')
        local n_unknown = r(N)
        quietly count if project == "`project'" & one & has_pre
        local loc_pre = r(N)
        quietly count if project == "`project'" & one & has_post
        local loc_post = r(N)
        quietly count if project == "`project'" & one & has_pre & has_post
        local loc_both = r(N)
        quietly count if project == "`project'" & `rule' == -1 & has_post
        local people_pre = r(N)
        quietly count if project == "`project'" & `rule' == 1 & has_pre
        post `repeated' ("`project'") ("`rule'") (`n_pre') (`n_post') (`n_window') ///
            (`n_unknown') (`loc_pre') (`loc_post') (`loc_both') (`people_pre') (r(N))
    }
}
postclose `repeated'
use "`dates'", clear
isid project rule
export delimited using "${econ_run}/regional_pre_post.csv"

postfile `survey' int wave long domain_n frame_n dropped_domain design_psus domain_psus ///
    design_strata strata_df double kish_n mean_phq9 se ci_lower ci_upper using "`dates'", replace
foreach wave of local waves {
    quietly use "`panel'", clear
    quietly keep if wave == `wave'
    quietly count if rural_youth
    local domain_n = r(N)
    generate byte survey_frame = positive_weight & hv001 > 0 & hv022 > 0 & !missing(hv001,hv022)
    quietly count if rural_youth & !survey_frame
    local missing_design = r(N)
    quietly keep if survey_frame
    quietly count
    local frame_n = r(N)
    assert hv001 == qhcluster if !missing(qhcluster)
    quietly egen byte sampled_psu = tag(hv022 hv001) if rural_youth
    quietly count if sampled_psu == 1
    local domain_psus = r(N)
    quietly generate double squared_weight = peso15_amas^2
    quietly summarize peso15_amas if rural_youth, meanonly
    local sum_w = r(sum)
    quietly summarize squared_weight if rural_youth, meanonly
    local kish = `sum_w'^2/r(sum)
    quietly generate byte phq_for_domain = cond(rural_youth,phq9,0)
    quietly svyset hv001 [pweight=peso15_amas], strata(hv022) singleunit(centered)
    quietly svy, subpop(rural_youth): mean phq_for_domain
    local avg = _b[phq_for_domain]
    local se = _se[phq_for_domain]
    local half = invttail(e(df_r),0.025)*`se'
    assert !missing(`avg',`se',`half')
    post `survey' (`wave') (`domain_n') (`frame_n') (`missing_design') (e(N_psu)) ///
        (`domain_psus') (e(N_strata)) (e(df_r)) (`kish') (`avg') (`se') ///
        (`avg'-`half') (`avg'+`half')
}
postclose `survey'
use "`dates'", clear
isid wave
export delimited using "${econ_run}/rural_descriptive_precision.csv"
display as result "ECONTHAKI_ANALYSIS_OK `series'"


