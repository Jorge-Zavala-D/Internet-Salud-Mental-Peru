* 1. Standard Stata configuration
version 16.0
clear all
set more off
set linesize 140

* 2. Git checkout and Dropbox paths
* Start in the checkout root. An optional run folder can be relative to Dropbox.
args inputs run_folder series
local checkout "`c(pwd)'"
do ".local/paths.local.do"
local run "`run_folder'"
if "`run_folder'" != "" & !regexm("`run_folder'", "^([A-Za-z]:|/)") local run "${econ_dropbox}/`run_folder'"
if "`series'" == "modern" & "`inputs'" == "" local inputs "${econ_dropbox}/3 Data/2 Working"

* 3. User-written dependencies
* This workflow uses only built-in Stata commands.

* 4. Data preparation, then descriptive analysis
do "`checkout'/1 Code/1 Data Preparation.do" "`inputs'" "`run'" "`series'"
if inlist("`series'", "modern", "historical", "extended") do "`checkout'/1 Code/2 Data Analysis.do" "`inputs'" "`run'" "`series'"
