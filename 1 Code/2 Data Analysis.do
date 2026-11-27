version 16.0
args inputs run series

* Modern descriptive exhibits
if "`series'" == "modern" {
    local coded "`run'"
    local figures "`run'"
    local tables "`run'"
    local numbers "`run'"
    local receipts "`run'"
    if "`run'" == "" {
        local coded "${econ_dropbox}/3 Data/3 Coded"
        local figures "`c(pwd)'/2 Output/Figures"
        local tables "`c(pwd)'/2 Output/Tables"
        local numbers "`c(pwd)'/2 Output/Numbers"
        local receipts "${econ_dropbox}/3 Data/0 Support docs/PRONATEL"
    }
    local evidence "${econ_dropbox}/3 Data/0 Support docs/PRONATEL/Public records search 2026-11-27"
    log using "`receipts'/endes_pronatel_descriptives.log", text replace name(modern_descriptives)
    display "Integrated source: `coded'/Data Analysis.dta"
    display "Named documentary layer: `evidence'/verified_service_and_roster_records.csv"
    tempfile reference_dates sensitivity new_records venue_records venue_keys venue_support

    * Read the same whole-project reference clock as the merge, independently of ENDES coverage.
    use "`inputs'/PRONATEL_coded.dta", clear
    keep if scope=="project" & event_type=="regional_operation" & source_merge==3 & ///
        !missing(event_first,event_last) & event_first==event_last
    keep project event_first source_id evidence_grade
    rename (project event_first source_id evidence_grade) ///
        (pronatel_project pronatel_ref_date pronatel_ref_source pronatel_ref_grade)
    quietly save "`reference_dates'"

    * Figure 1. Count all roster localities, whether ENDES sampled them or not.
    use "`inputs'/PRONATEL_coded.dta", clear
    keep if event_type=="roster_snapshot"
    rename project pronatel_project
    merge m:1 pronatel_project using "`reference_dates'", keep(master match) nogenerate
    generate str9 pronatel_phase = ""
    replace pronatel_phase = "base" if workbook_intervention=="Proyecto Regional Amazonas"
    replace pronatel_phase = "expansion" if workbook_intervention=="Proyecto Regional Amazonas - Ampliación"
    generate int workbook_date_only = workbook_region_operation if missing(pronatel_ref_date) & roster_in_workbook==1
    generate byte reference_day = !missing(pronatel_ref_date)
    generate byte workbook_day_only = missing(pronatel_ref_date) & !missing(workbook_date_only)
    generate byte no_day = !reference_day & !workbook_day_only
    collapse (sum) reference_day workbook_day_only no_day, ///
        by(pronatel_project pronatel_phase pronatel_ref_date pronatel_ref_source pronatel_ref_grade workbook_date_only)
    generate long roster_localities = reference_day+workbook_day_only+no_day
    quietly summarize roster_localities, meanonly
    local roster_total = r(sum)
    generate int documented_year = year(pronatel_ref_date)
    generate int workbook_only_year = year(workbook_date_only)
    format pronatel_ref_date workbook_date_only %tdCCYY-NN-DD
    export delimited using "`numbers'/pronatel_rollout_coverage.csv", datafmt replace

    collapse (sum) reference_day workbook_day_only no_day ///
        (max) documented_year workbook_only_year, by(pronatel_project)
    generate str45 project_label = strproper(pronatel_project)
    replace project_label = project_label+" ("+string(documented_year,"%4.0f")+")" if !missing(documented_year)
    replace project_label = project_label+" ("+string(workbook_only_year,"%4.0f")+")" ///
        if missing(documented_year) & !missing(workbook_only_year)
    graph hbar (sum) reference_day workbook_day_only no_day, over(project_label, label(labsize(vsmall))) stack ///
        scheme(s2color) graphregion(color(white) margin(l=9 r=7)) plotregion(color(white)) ///
        bar(1, color("39 87 130")) bar(2, color("187 120 52")) bar(3, color("193 203 211")) ///
        title("PRONATEL regional milestone coverage", size(medium)) ///
        subtitle("All 21 projects in the union of the two rosters", size(small)) ///
        ytitle("Distinct roster localities") ylabel(, grid labsize(small)) ///
        legend(order(1 "Documented day" 2 "Workbook date only" 3 "No date") rows(1) size(vsmall) region(lstyle(none))) ///
        note("GeoPerú April 2024 and the workbook received November 2026." ///
             "Denominator = `roster_total' localities. Workbook dates are a sensitivity.", size(vsmall)) ///
        xsize(10) ysize(8) scale(.86)
    graph export "`figures'/pronatel_rollout_coverage.pdf", as(pdf) replace

    * Table 1. Survey scope, snapshot membership and the formal milestone clock.
    use "`coded'/Data Analysis.dta", clear
    keep if main_wave==1 & eligible_rural_youth==1
    generate int calendar_year = year(last_visit_first)
    generate byte interviews = 1
    generate str22 roster_membership = "Geography hold" if missing(pronatel_link)
    replace roster_membership = "Outside both snapshots" if pronatel_link==1
    replace roster_membership = "GeoPeru only" if roster_in_geoperu==1 & roster_in_workbook==0
    replace roster_membership = "Workbook only" if roster_in_geoperu==0 & roster_in_workbook==1
    replace roster_membership = "Both snapshots" if roster_in_geoperu==1 & roster_in_workbook==1
    preserve
    egen byte localities = tag(locality10 calendar_year pronatel_project pronatel_phase ///
        roster_membership pronatel_timing) if !missing(pronatel_link), missing
    collapse (sum) interviews localities, by(calendar_year pronatel_project pronatel_phase ///
        roster_membership pronatel_timing pronatel_ref_date pronatel_ref_source)
    format pronatel_ref_date %tdCCYY-NN-DD
    export delimited using "`tables'/endes_pronatel_merge_and_milestone.csv", datafmt replace
    restore

    * These rows use identical rules for each sample. Omission uses survey wave.
    tempname support_table
    postfile `support_table' str24 sample long eligible_interviews geography_interviews geography_localities ///
        exact_matches exact_localities geography_holds site_holds outside_both invalid_visit_bounds ///
        dated_site_clear dated_site_clear_localities before on_or_after crossing no_reference_date ///
        workbook_only_before workbook_only_on_or_after workbook_only_crossing using "`sensitivity'"
    foreach sample in all usual usual_no_2020 usual_no_2021 usual_no_2020_2021 {
        preserve
        if "`sample'"!="all" keep if usual_resident==1
        if inlist("`sample'","usual_no_2020","usual_no_2020_2021") drop if wave==2020
        if inlist("`sample'","usual_no_2021","usual_no_2020_2021") drop if wave==2021
        generate byte geography_ok = !missing(pronatel_link)
        generate byte matched = pronatel_link==3
        generate byte geography_held = pronatel_timing==7
        generate byte site_held = pronatel_timing==8
        generate byte outside = pronatel_link==1
        generate byte invalid_visit = pronatel_timing==6
        generate byte dated = inlist(pronatel_timing,1,2,3,5)
        generate byte before = pronatel_timing==1
        generate byte on_or_after = pronatel_timing==2
        generate byte crossing = pronatel_timing==3
        generate byte no_reference = pronatel_timing==5
        generate byte wb_before = pronatel_workbook_timing==1
        generate byte wb_on_or_after = pronatel_workbook_timing==2
        generate byte wb_crossing = pronatel_workbook_timing==3
        egen byte geography_sites = tag(locality10) if geography_ok
        egen byte matched_sites = tag(locality10) if matched
        egen byte dated_sites = tag(locality10) if dated
        collapse (sum) interviews geography_ok geography_sites matched matched_sites geography_held site_held ///
            outside invalid_visit dated dated_sites before on_or_after crossing no_reference wb_before wb_on_or_after wb_crossing
        post `support_table' ("`sample'") (interviews[1]) (geography_ok[1]) (geography_sites[1]) (matched[1]) (matched_sites[1]) ///
            (geography_held[1]) (site_held[1]) (outside[1]) (invalid_visit[1]) (dated[1]) (dated_sites[1]) ///
            (before[1]) (on_or_after[1]) (crossing[1]) (no_reference[1]) (wb_before[1]) (wb_on_or_after[1]) (wb_crossing[1])
        restore
    }
    postclose `support_table'
    use "`sensitivity'", clear
    export delimited using "`tables'/endes_pronatel_support_sensitivity.csv", replace

    * Table 2. Compare selected documentary records to the project calendar.
    import delimited using "`evidence'/verified_service_and_roster_records.csv", ///
        clear varnames(1) stringcols(_all) encoding("utf-8")
    keep if inlist(event_id,"MOQ01","MOQ05","TAC03","TAC06","SM01","LL04")
    rename (project locality10_if_adjudicated) (pronatel_project locality10)
    generate int event_first = daily(date_lower,"YMD")
    generate int event_last = daily(date_upper,"YMD")
    generate str34 evidence_layer = "27 November public-record audit"
    keep event_id pronatel_project locality10 place venue_or_scope audience evidence_class ///
        event_first event_last date_semantics finding remaining_gap source_url source_locator evidence_layer
    quietly save "`new_records'"

    use "`inputs'/PRONATEL_coded.dta", clear
    keep if inlist(event_id,"AN-QUEN-OBS","J-RAC-H-OBS","LL-RAMAL-OBS","L-CHI-EXC","J-TRANS-21")
    rename (project site_name service intended_users event_type date_precision source_note) ///
        (pronatel_project place venue_or_scope audience evidence_class date_semantics finding)
    generate str34 evidence_layer = "Prepared PRONATEL chronology"
    keep event_id pronatel_project locality10 place venue_or_scope audience evidence_class ///
        event_first event_last date_semantics finding source_url source_locator evidence_layer
    append using "`new_records'"
    merge m:1 pronatel_project using "`reference_dates'", keep(master match) nogenerate
    format pronatel_ref_date event_first event_last %tdCCYY-NN-DD
    generate str38 relation_to_reference = "No documented project day" if missing(pronatel_ref_date)
    replace relation_to_reference = "Before formal day" if !missing(event_last,pronatel_ref_date) & event_last<pronatel_ref_date
    replace relation_to_reference = "On or after formal day" if !missing(event_first,pronatel_ref_date) & event_first>=pronatel_ref_date
    replace relation_to_reference = "Spans formal day" if !missing(event_first,event_last,pronatel_ref_date) & ///
        event_first<pronatel_ref_date & event_last>=pronatel_ref_date
    replace relation_to_reference = "By-date bound on or after formal day" if missing(event_first) & ///
        !missing(event_last,pronatel_ref_date) & event_last>=pronatel_ref_date
    quietly save "`venue_records'"

    * Pair documentary records with exact survey codes only to check calendar support.
    keep if !missing(locality10)
    keep event_id locality10 event_first event_last
    quietly save "`venue_keys'"
    use wave main_wave eligible_rural_youth locality10 pronatel_link service_site_review recall_first recall_last ///
        using "`coded'/Data Analysis.dta", clear
    keep if main_wave==1 & eligible_rural_youth==1 & !missing(pronatel_link)
    joinby locality10 using "`venue_keys'", unmatched(using)
    generate byte exact_overlap = !missing(wave)
    generate byte site_clear_date = exact_overlap & service_site_review==0 & !missing(recall_first,recall_last)
    generate byte event_day_in_recall = site_clear_date & inrange(event_last,recall_first,recall_last) ///
        if !missing(event_last) & (missing(event_first) | event_first==event_last)
    collapse (max) exact_overlap site_clear_date event_day_in_recall, by(event_id)
    quietly save "`venue_support'"

    use "`venue_records'", clear
    merge 1:1 event_id using "`venue_support'", keep(master match) nogenerate
    generate str40 endes_geography = "No adjudicated code for this record" if missing(locality10)
    replace endes_geography = "No eligible ENDES match" if exact_overlap==0
    replace endes_geography = "Exact match, no site-clear dates" if exact_overlap==1 & site_clear_date==0
    replace endes_geography = "Exact match, site-clear dates available" if site_clear_date==1
    generate str44 endes_calendar = "Record day outside all recall envelopes" if site_clear_date==1 & event_day_in_recall==0
    replace endes_calendar = "Record day can overlap a recall window" if event_day_in_recall==1
    replace endes_calendar = "No point-date check" if missing(endes_calendar)
    order pronatel_project place venue_or_scope audience pronatel_ref_date relation_to_reference ///
        evidence_class event_first event_last date_semantics endes_geography endes_calendar
    sort pronatel_project event_first event_last event_id
    drop locality10 exact_overlap site_clear_date event_day_in_recall
    export delimited using "`tables'/pronatel_named_venue_comparison.csv", datafmt replace
    log close modern_descriptives
    exit
}

* Frozen Stage 02 descriptive replay
log using "`run'/analysis.log", text name(descriptive)
local edition = cond(c(MP), "MP", cond(c(SE), "SE", "BE"))
display as text "Stata/`edition' " c(stata_version) ", " c(processors) " processor(s)"
display as text "Input vintage: `inputs'"
display as text "Dataset series: `series'"

tempfile panel counts reference pair_overlap dates calendar_support pre_post precision
tempname survey overlap repeated

use wave hhid qs23 qsinty qs700a qs700b qs700c qs700d qs700e qs700f qs700g qs700h qs700i ///
    peso15_amas qhcluster hv001 hv022 youth rural nphq phq9 positive_weight eligible rural_youth ///
    pilot_key_valid locality_key_valid candidate_locality10 locality10 merge_roster roster_designated ///
    roster_group name_disagree visit_month home_internet project using "`run'/coded.dta", clear
local coded_series : char _dta[series]
assert "`coded_series'" == "`series'"
isid wave hhid
levelsof wave, local(waves)
quietly save "`panel'"

* Reconcile sample flow against the saved pilot benchmarks.
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
export delimited using "`run'/wave_counts.csv"
quietly save "`counts'"

import delimited using "`inputs'/muestra.csv", clear case(lower)
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
export delimited using "`run'/pilot_reconciliation.csv"

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
export delimited using "`run'/missingness.csv", nolabel

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
export delimited using "`run'/phq_raw_codes.csv", nolabel

use "`panel'", clear
keep if eligible
generate int visit_year = year(dofm(visit_month))
generate byte visit_month_number = month(dofm(visit_month))
generate byte people = 1
quietly collapse (sum) people, by(wave visit_year visit_month_number rural roster_group)
export delimited using "`run'/visit_month_counts.csv", nolabel

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
    people_a_shared people_b_shared name_disagreement_shared using "`pair_overlap'"
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
use "`pair_overlap'", clear
export delimited using "`run'/locality_pair_overlap.csv"

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
export delimited using "`run'/locality_block_overlap.csv"

import delimited using "`inputs'/regional_dates.csv", clear varnames(1) stringcols(_all)
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
export delimited using "`run'/regional_calendar_merge.csv", nolabel
restore
drop if merge_dates == 2
format launch_day earliest_day latest_day %tdCCYY-NN-DD
* Compare survey visit months with regional anchors while allowing for the PHQ recall window.
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
quietly save "`calendar_support'"

egen byte locality_tag = tag(wave project visit_month locality10), missing
egen byte psu_tag = tag(wave project visit_month hv001) if hv001 > 0 & hv001 < ., missing
generate byte people = 1
collapse (sum) people localities=locality_tag psus=psu_tag, ///
    by(wave project visit_month launch_month event_month pilot_period bounded_period earlier_period)
format visit_month launch_month %tm
export delimited using "`run'/regional_calendar_support.csv"

postfile `repeated' str32 project str18 rule long pre_people post_people window_people ///
    unknown_month pre_ccpp post_ccpp ccpp_both people_pre_both people_post_both using "`pre_post'"
foreach rule in pilot_period bounded_period earlier_period {
    quietly use "`calendar_support'", clear
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
use "`pre_post'", clear
isid project rule
export delimited using "`run'/regional_pre_post.csv"

* Estimate each round's rural mean as a survey domain within its full design frame.
postfile `survey' int wave long domain_n frame_n dropped_domain design_psus domain_psus ///
    design_strata strata_df double kish_n mean_phq9 se ci_lower ci_upper using "`precision'"
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
use "`precision'", clear
isid wave
export delimited using "`run'/rural_descriptive_precision.csv"
display as result "ECONTHAKI_ANALYSIS_OK `series'"
log close descriptive


