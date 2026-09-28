/*******************************************************************************
Title:   Figure 1 Replication for Antman and Cortes (2023)
Purpose: Replicate estimates for Figure 1
Author:  Ibraheem Saqib Ellahi
Date:    Spring 2026
*******************************************************************************/

version 16
clear all
set more off
capture log close fig1
log using "$log/02_figure1.log", replace text name(fig1)

* Load clean dataset from 01_build_data.do
use "$clean/antman_cortes_clean.dta", clear
datasignature confirm


* 1. Data Preparation
********************************************************************************

* HiSeg & LoSeg counties only
keep if !missing(hiseg)
count

* Group 1: Hispanic in HiSeg
gen ed_hisp_hi = yrsed if hispanic == 1 & hiseg == 1
label variable ed_hisp_hi "Years of Education, Hispanic in HiSeg"

* Group 2: Hispanic in LoSeg
gen ed_hisp_lo = yrsed if hispanic == 1 & hiseg == 0
label variable ed_hisp_lo "Years of Education, Hispanic in LoSeg"

* Group 3: Non-Hispanic White in HiSeg
gen ed_white_hi = yrsed if hispanic == 0 & hiseg == 1
label variable ed_white_hi "Years of Education, Non-Hispanic White in HiSeg"

* Group 4: Non-Hispanic White in LoSeg
gen ed_white_lo = yrsed if hispanic == 0 & hiseg == 0
label variable ed_white_lo "Years of Education, Non-Hispanic White in LoSeg"

* Aggregate to cohort (birth year) means
collapse (mean) mean_hisp_hi=ed_hisp_hi ///
                mean_hisp_lo=ed_hisp_lo ///
                mean_white_hi=ed_white_hi ///
                mean_white_lo=ed_white_lo, by(birthyr)

* labels for graph
label variable mean_hisp_hi "Hispanic in HiSeg"
label variable mean_hisp_lo "Hispanic in LoSeg"
label variable mean_white_hi "Non-Hispanic White in HiSeg"
label variable mean_white_lo "Non-Hispanic White in LoSeg"

* Age at Mendez decision (1947) for x-axis
gen age1947 = 1947 - birthyr
label variable age1947 "Age in 1947 (Mendez Decision)"

* 1 row / cohort, 1921-45
assert _N == 25
order birthyr age1947

* check aggregation
list, sep(0) noobs

* Cohort means for repo
export delimited using "$tab/fig1_cohort_means.csv", replace


* 2. Create the Graph
********************************************************************************

twoway ///
    (line mean_white_hi age1947, lcolor(dkgreen) lpattern(longdash) lwidth(medium)) ///
    (line mean_white_lo age1947, lcolor(orange) lpattern(shortdash) lwidth(medium)) ///
    (line mean_hisp_lo age1947, lcolor(red) lpattern(dash) lwidth(medium)) ///
    (line mean_hisp_hi age1947, lcolor(navy) lpattern(solid) lwidth(medium)), ///
    ///
    /* Y-Axis Label and Range */ ///
    ytitle("Average years of education") ///
    ylabel(8(1)14, angle(0)) ///
    ///
    /* X-Axis Setup */ ///
    xscale(reverse) ///
    xlabel(26(1)2, labsize(small)) ///
    ///
    /* X-Title with Annotations */ ///
    /* separate title lines put text below the numbers */ ///
    xtitle(" " "Completed schooling                                            In school                                            Prior to schooling", size(small)) ///
    ///
    /* Legend Placement */ ///
    legend(order(1 "Non-Hispanic White in HiSeg" ///
                 2 "Non-Hispanic White in LoSeg" ///
                 3 "Hispanic in LoSeg" ///
                 4 "Hispanic in HiSeg") ///
           ring(0) position(5) cols(1) region(lcolor(black) fcolor(white)) size(small)) ///
    ///
    /* Graph Region */ ///
    graphregion(color(white))


* 3. Output the Graph
********************************************************************************

graph export "$fig/fig1_education_by_cohort.png", replace width(2000)
graph export "$fig/fig1_education_by_cohort.pdf", replace

log close fig1
