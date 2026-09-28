/*******************************************************************************
Title:   Table 2 Replication for Antman and Cortes (2023)
Purpose: Replicate Table 2, eq. (1) with county and birth-year FE.
         Panel A: Hispanic, born 1941-45 vs 1931-35
         Panel B: Hispanic placebo, born 1926-30 vs 1921-25
         Panel C: non-Hispanic white, born 1941-45 vs 1931-35
Author:  Ibraheem Saqib Ellahi
Date:    Spring 2026
*******************************************************************************/

version 16
clear all
set more off
capture log close table2
log using "$log/04_table2.log", replace text name(table2)

use "$clean/antman_cortes_clean.dta", clear
datasignature confirm


* 1. Panel Definitions
********************************************************************************

* Sample, post variable, coefficient label for each panel
local if_A   "hispanic == 1 & sample_tables == 1 & !missing(hiseg)"
local post_A "post_mendez"
local lab_A  "High segregation \ensuremath{\times} post-Mendez cohort"
local csv_A  "High segregation x post-Mendez cohort"

local if_B   "hispanic == 1 & sample_placebo == 1 & !missing(hiseg)"
local post_B "placebo_post"
local lab_B  "High segregation \ensuremath{\times} placebo post-Mendez cohort"
local csv_B  "High segregation x placebo post-Mendez cohort"

local if_C   "nhwhite == 1 & sample_tables == 1 & !missing(hiseg)"
local post_C "post_mendez"
local lab_C  "High segregation \ensuremath{\times} post-Mendez cohort"
local csv_C  "High segregation x post-Mendez cohort"


* 2. Regressions and Export
********************************************************************************

foreach panel in A B C {

    eststo clear
    local post "`post_`panel''"

    foreach var in yrsed jrhigh hschool {
        * Eq (1): DiD term + controls, county and birth-year FE, clustered by county
        regress `var' c.hiseg#c.`post' female census1990 census2000 ///
            i.countyfip i.birthyr if `if_`panel'', vce(cluster countyfip)
        estadd ysumm
        estadd local fe_birth "Yes"
        estadd local fe_county "Yes"
        eststo `var'_`panel'
    }

    local models "yrsed_`panel' jrhigh_`panel' hschool_`panel'"

    * Log copy
    esttab `models', keep(c.hiseg#c.`post') b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        stats(ymean N r2, fmt(3 %9.0fc 3)) mtitles("Years of ed" "Jr high" "High school")

    * LaTeX fragment (stars need \sym defined in paper preamble)
    esttab `models' using "$tab/table2_panel`panel'.tex", replace booktabs fragment ///
        keep(c.hiseg#c.`post') coeflabels(c.hiseg#c.`post' "`lab_`panel''") ///
        b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("Years of education" "Jr. High School" "High School") ///
        stats(ymean N r2 fe_birth fe_county, fmt(3 %9.0fc 3 0 0) ///
            labels("Mean (y-variable)" "Number of observations" "R\textsuperscript{2}" ///
            "Birth cohort fixed effects" "County fixed effects")) ///
        nonotes

    * CSV twin
    esttab `models' using "$tab/table2_panel`panel'.csv", replace ///
        keep(c.hiseg#c.`post') coeflabels(c.hiseg#c.`post' "`csv_`panel''") ///
        b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("Years of education" "Jr. High School" "High School") ///
        stats(ymean N r2 fe_birth fe_county, fmt(3 %9.0fc 3 0 0) ///
            labels("Mean (y-variable)" "Number of observations" "R-squared" ///
            "Birth cohort fixed effects" "County fixed effects")) ///
        nonotes
}

log close table2
