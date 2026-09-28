/*******************************************************************************
Title:   Master File for Antman and Cortes (2023) Replication
Purpose: Set paths, load vendored estout, run code/01-06 in order.
         Start Stata in the repo root, then: do run.do
         One file only: global only "04", then do run.do
Author:  Ibraheem Saqib Ellahi
Date:    Spring 2026
*******************************************************************************/

version 16
clear all
set more off
capture log close _all


* 1. Paths
********************************************************************************

* Fails here if Stata not in repo root
confirm file "run.do"

* Forward slashes so Windows paths work in strings
global root = subinstr(c(pwd), "\", "/", .)
global raw   "$root/data/raw"
global clean "$root/data/clean"
global fig   "$root/output/figures"
global tab   "$root/output/tables"
global log   "$root/output/logs"

* Folders may be missing after clean unzip
capture mkdir "$clean"
capture mkdir "$root/output"
capture mkdir "$fig"
capture mkdir "$tab"
capture mkdir "$log"

* Named log so do-files below can open/close their own
log using "$root/run.log", replace text name(master)


* 2. Environment
********************************************************************************

display "Stata version: " c(stata_version)
display "OS:            " c(os) " (" c(osdtl) ")"
display "Root:          $root"
display "Started:       " c(current_date) " " c(current_time)

* Vendored estout first on adopath, never ssc install
adopath ++ "$root/code/ado/estout"
which esttab
which estout
which eststo
which estadd
which estpost

* raw extract MUST be in place
confirm file "$raw/data-CA.dta"


* 3. Pipeline
********************************************************************************

* Blank = everything
assert inlist("$only", "", "01", "02", "03", "04", "05", "06")

if "$only" == "" | "$only" == "01" do "$root/code/01_build_data.do"
if "$only" == "" | "$only" == "02" do "$root/code/02_figure1.do"
if "$only" == "" | "$only" == "03" do "$root/code/03_table1.do"
if "$only" == "" | "$only" == "04" do "$root/code/04_table2.do"
if "$only" == "" | "$only" == "05" do "$root/code/05_event_study.do"
if "$only" == "" | "$only" == "06" do "$root/code/06_prose_numbers.do"


* 4. Done
********************************************************************************

if "$only" == "" display "All outputs regenerated: " c(current_date) " " c(current_time)
else display "Ran only $only: " c(current_date) " " c(current_time)

* Reset switch for next run
global only ""

log close master
