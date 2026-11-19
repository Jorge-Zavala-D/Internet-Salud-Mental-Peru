* Run from the active checkout root. Modes: check, smoke, prep, analysis, all.
* Adopt a project-level Stata version after both coauthors verify their installations.
version 16.0
set more off
args mode inputs run series
if "`mode'" == "" local mode "check"
if !inlist("`mode'", "check", "smoke", "prep", "analysis", "all") {
    display as error "Use check, smoke, prep, analysis, or all."
    exit 198
}
capture confirm file "1 Code/0 Master.do"
if _rc {
    display as error "Change cd to this checkout's repository root first."
    exit 601
}
global econ_repo "`c(pwd)'"
* An explicit checkout-specific setting takes precedence over a machine-wide one.
global econ_dropbox ""
capture confirm file ".local/paths.local.do"
if !_rc do ".local/paths.local.do"
if "${econ_dropbox}" == "" {
    global econ_dropbox : environment ECONTHAKI_DROPBOX
}
if "${econ_dropbox}" == "" {
    display as error "Supply ECONTHAKI_DROPBOX or configure .local/paths.local.do."
    exit 198
}
foreach folder in "3 Data/0 Support docs" "3 Data/1 Raw" "3 Data/2 Working" "3 Data/3 Coded" {
    mata: st_local("exists", strofreal(direxists(st_global("econ_dropbox") + "/`folder'")))
    if real("`exists'") != 1 {
        display as error "Check the local Dropbox setting and folder: `folder'"
        exit 601
    }
}
global econ_support "${econ_dropbox}/3 Data/0 Support docs"
global econ_raw     "${econ_dropbox}/3 Data/1 Raw"
global econ_working "${econ_dropbox}/3 Data/2 Working"
global econ_coded   "${econ_dropbox}/3 Data/3 Coded"
global econ_output  "${econ_repo}/2 Output"
display as result "Project folders resolved. Requested mode: `mode'"
if "`mode'" == "check" exit
if "`mode'" == "smoke" {
    do "1 Code/setup_smoke.do"
    exit
}
* Production requires a declared vintage and a fresh private output directory.
if "`inputs'" == "" | "`run'" == "" {
    display as error "Supply the input vintage and private run directory after the mode."
    exit 198
}
if "`series'" == "" local series historical
if !inlist("`series'", "historical", "extended") {
    display as error "Use historical or extended."
    exit 198
}
global econ_inputs "`inputs'"
global econ_run "`run'"
foreach path in econ_inputs econ_run {
    mata: st_local("exists", strofreal(direxists(st_global("`path'"))))
    if real("`exists'") != 1 {
        display as error "Directory unavailable: `path'."
        exit 601
    }
}
if inlist("`mode'", "prep", "all") confirm file "1 Code/1 Data Preparation.do"
if inlist("`mode'", "analysis", "all") confirm file "1 Code/2 Data Analysis.do"
confirm file "${econ_inputs}/core/modules.csv"
if "`series'" == "extended" confirm file "${econ_inputs}/extension/modules.csv"
if inlist("`mode'", "analysis", "all") {
    confirm file "${econ_inputs}/muestra.csv"
    confirm file "${econ_inputs}/regional_dates.csv"
}
forvalues section = 1/2 {
    local stage prep
    local script "1 Code/1 Data Preparation.do"
    if `section' == 2 {
        local stage analysis
        local script "1 Code/2 Data Analysis.do"
    }
    if !inlist("`mode'", "`stage'", "all") continue
    if "`stage'" == "analysis" confirm file "${econ_run}/coded.dta"
    log using "${econ_run}/`stage'.log", text name(econ_stage)
    local edition = cond(c(MP), "MP", cond(c(SE), "SE", "BE"))
    display as text "Stata/`edition' " c(stata_version) ", " c(processors) " processor(s)"
    display as text "Dataset series: `series'"
    display as text "Stage: `script'"
    display as text "Input vintage: ${econ_inputs}"
    display as text "Output directory: ${econ_run}"
    capture noisily do "`script'" "`series'"
    local stage_rc = _rc
    display as text "Stage return code: `stage_rc'"
    log close econ_stage
    if `stage_rc' exit `stage_rc'
}
