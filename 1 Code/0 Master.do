* 1. Standard Stata configuration
version 16.0
clear all
set more off
set linesize 140

* 2. Git checkout and Dropbox paths
* Start in the checkout root. Supply an input directory, a run folder relative
* to the project Dropbox, and the series (historical or extended).
args inputs run_folder series
local checkout "`c(pwd)'"
do ".local/paths.local.do"
local run "${econ_dropbox}/`run_folder'"

* 3. User-written dependencies
* This workflow uses only built-in Stata commands.

* 4. Data preparation and descriptive analysis
do "`checkout'/1 Code/1 Data Preparation.do" "`inputs'" "`run'" "`series'"
do "`checkout'/1 Code/2 Data Analysis.do" "`inputs'" "`run'" "`series'"
