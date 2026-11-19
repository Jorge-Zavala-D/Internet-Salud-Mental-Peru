* Run from the active checkout root. Modes: check, smoke, prep, analysis, all.
* Adopt a project-level Stata version after both coauthors verify their installations.
version 16.0
set more off
args mode
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
* Production do-files are implemented after inspecting the source data.
* Check that every requested stage exists before starting the first stage.
if inlist("`mode'", "prep", "all") confirm file "1 Code/1 Data Preparation.do"
if inlist("`mode'", "analysis", "all") confirm file "1 Code/2 Data Analysis.do"
if inlist("`mode'", "prep", "all") do "1 Code/1 Data Preparation.do"
if inlist("`mode'", "analysis", "all") do "1 Code/2 Data Analysis.do"
