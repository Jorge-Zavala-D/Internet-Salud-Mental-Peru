* 1. Standard Stata configuration
version 16.0
clear all
set more off
set linesize 140

* 2. Git checkout and Dropbox paths
* Start in the checkout root. Use an absolute protected run path for ENDES.
* Frozen replay still accepts its original Dropbox-relative run path.
args inputs run_folder series
local checkout "`c(pwd)'"
do ".local/paths.local.do"
local run "`run_folder'"
if !regexm("`run_folder'", "^([A-Za-z]:|/)") local run "${econ_dropbox}/`run_folder'"

* 3. User-written dependencies
* This workflow uses only built-in Stata commands.

* 4. Data preparation, then descriptive analysis for frozen replays
do "`checkout'/1 Code/1 Data Preparation.do" "`inputs'" "`run'" "`series'"
if inlist("`series'", "historical", "extended") do "`checkout'/1 Code/2 Data Analysis.do" "`inputs'" "`run'" "`series'"
