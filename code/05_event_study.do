/*******************************************************************************
Title:   Event Study for Antman and Cortes (2023) Replication
Purpose: Figure 2 (jr high) plus appendix Figures A1 (years of education) and
         A2 (high school). Model:
         Y_ict = a + sum over t in 1921-45, t != 1931, of
                 pi_t (HiSeg_c x 1[birthyr = t]) + X_ict b + mu_c + delta_t + e_ict
         Sample: Hispanic, born 1921-45, HiSeg or LoSeg county.
         Reference cohort 1931 (age 16 in 1947). X = female, census1990,
         census2000. County and birth-year FE. SE clustered by county. 90% CIs.
Author:  Ibraheem Saqib Ellahi
Date:    Spring 2026
*******************************************************************************/

version 16
clear all
set more off
capture log close es
log using "$log/05_event_study.log", replace text name(es)

use "$clean/antman_cortes_clean.dta", clear
datasignature confirm


* 1. Sample and Interaction Terms
********************************************************************************

keep if es_sample == 1
count

* Each cohort needs HiSeg and LoSeg obs or its interaction not identified
tab birthyr hiseg

* HiSeg x cohort dummies, 1931 left out as reference (age 16 in 1947)
* Built by hand so omitted cohort fixed, not picked by factor-variable base rules
forvalues t = 1921/1945 {
    if `t' != 1931 {
        gen byte hs_`t' = hiseg * (birthyr == `t')
        label variable hs_`t' "HiSeg x Born `t'"
    }
}
confirm new variable hs_1931


* 2. Regressions, One per Outcome
********************************************************************************

tempname memhold bt st tcrit
tempfile coefs
postfile `memhold' str8 outcome int birthyr int age1947 double coef double se ///
    double p double lo90 double hi90 long nobs using "`coefs'"

foreach var in jrhigh yrsed hschool {

    regress `var' hs_* female census1990 census2000 i.countyfip i.birthyr, vce(cluster countyfip)

    * 24 interactions, NONE dropped for collinearity
    local nint = 0
    forvalues t = 1921/1945 {
        if `t' != 1931 {
            assert _se[hs_`t'] > 0
            local ++nint
        }
    }
    display "`var': `nint' interactions estimated, reference cohort 1931"
    assert `nint' == 24

    * 90% CI uses t w/ clustered df, same as regress
    scalar `tcrit' = invttail(e(df_r), 0.05)

    forvalues t = 1921/1945 {
        if `t' == 1931 {
            post `memhold' ("`var'") (`t') (1947 - `t') (0) (0) (.) (0) (0) (e(N))
        }
        else {
            scalar `bt' = _b[hs_`t']
            scalar `st' = _se[hs_`t']
            post `memhold' ("`var'") (`t') (1947 - `t') (`bt') (`st') ///
                (2 * ttail(e(df_r), abs(`bt' / `st'))) ///
                (`bt' - `tcrit' * `st') (`bt' + `tcrit' * `st') (e(N))
        }
    }
}

postclose `memhold'


* 3. Coefficient Data Set, by Age in 1947
********************************************************************************

use "`coefs'", clear

label variable outcome "Outcome (jrhigh, yrsed, hschool)"
label variable birthyr "Birth Year"
label variable age1947 "Age in 1947 (Mendez Decision)"
label variable coef "HiSeg x Cohort Coefficient (1931 = 0)"
label variable se "SE, Clustered by County"
label variable p "p-value"
label variable lo90 "90% CI Lower Bound"
label variable hi90 "90% CI Upper Bound"
label variable nobs "Regression N"

* Stars & point labels for plots
gen stars = cond(p < 0.01, "***", cond(p < 0.05, "**", cond(p < 0.10, "*", "")))
label variable stars "Significance Stars (10/5/1 percent)"

gen coef_lab = strtrim(string(coef, "%9.3f")) + stars
replace coef_lab = "0" if birthyr == 1931
label variable coef_lab "Point Label for Plots"

gen lab_pos = cond(coef >= 0, 12, 6)
label variable lab_pos "Label Position (12 above, 6 below)"

* Stagger labels: flip to other side if same side as next-older cohort
* and nearly same height
* Cutoff scales with each outcome's CI range
gen neg_age = -age1947
sort outcome neg_age
by outcome: egen double ci_hi = max(hi90)
by outcome: egen double ci_lo = min(lo90)
sort outcome neg_age
by outcome: replace lab_pos = 18 - lab_pos if _n > 1 & lab_pos == lab_pos[_n-1] ///
    & abs(coef - coef[_n-1]) < 0.04 * (ci_hi - ci_lo)
drop neg_age ci_hi ci_lo
assert inlist(lab_pos, 12, 6)

* 25 cohorts x 3 outcomes, reference cohort pinned at 0
assert _N == 75
isid outcome birthyr
assert coef == 0 & se == 0 if birthyr == 1931

sort outcome age1947
order outcome birthyr age1947 coef se p lo90 hi90 stars coef_lab nobs

save "$tab/eventstudy_coefs.dta", replace
export delimited using "$tab/eventstudy_coefs.csv", replace

* Verify against paper Figure 2 (jr high)
list age1947 birthyr coef se p coef_lab if outcome == "jrhigh", sep(0) noobs


* 4. Figures
********************************************************************************

* Figure 2 in paper, A1/A2 in its appendix
local fname_jrhigh  "fig2_eventstudy_jrhigh"
local fname_yrsed   "figA1_eventstudy_yrsed"
local fname_hschool "figA2_eventstudy_hschool"

* Paper's y-axis for jr high, auto for other two
local ylab_jrhigh  "-0.4(0.2)0.4"
local ylab_yrsed   "#7"
local ylab_hschool "#7"

foreach var in jrhigh yrsed hschool {

    * room under CI band for group labels
    quietly summarize lo90 if outcome == "`var'"
    local ymin = r(min)
    quietly summarize hi90 if outcome == "`var'"
    local ymax = r(max)
    local ytxt = `ymin' - 0.1 * (`ymax' - `ymin')

    * Blue dashed at 16 & 12, red at 6 & 2, as in paper
    twoway ///
        (rarea hi90 lo90 age1947 if outcome == "`var'", color(gs13) lwidth(none)) ///
        (connected coef age1947 if outcome == "`var'", lcolor(black) mcolor(black) ///
            msymbol(plus) mlabel(coef_lab) mlabvposition(lab_pos) mlabsize(vsmall) mlabcolor(black)), ///
        yline(0, lcolor(black) lwidth(thin)) ///
        xline(16 12, lpattern(dash) lcolor(navy)) ///
        xline(6 2, lpattern(dash) lcolor(red)) ///
        xscale(reverse) ///
        xlabel(2(1)15 16 "16{sup:†}" 17(1)26, labsize(small)) ///
        ylabel(`ylab_`var'', angle(0) labsize(small)) ///
        yscale(range(`ytxt' `ymax')) ///
        text(`ytxt' 14 "Old group", color(navy) size(small)) ///
        text(`ytxt' 4 "Young group", color(red) size(small)) ///
        ytitle("") ///
        xtitle("Age at Mendez versus Westminster Decision") ///
        legend(order(2 "Difference between high and low likelihood" "segregated counties (high - low)") ///
            ring(0) position(11) cols(1) region(lcolor(black) fcolor(white)) size(small)) ///
        graphregion(color(white))

    graph export "$fig/`fname_`var''.png", replace width(2000)
    graph export "$fig/`fname_`var''.pdf", replace
}


* 5. Appendix Table of Event-Study Coefficients
********************************************************************************

* One row / cohort, 3 outcomes side by side
* Body rows only, paper supplies tabular wrapper & header
preserve
keep outcome age1947 birthyr coef se stars
reshape wide coef se stars, i(age1947 birthyr) j(outcome) string
gsort -age1947

gen str244 row = string(age1947) + " & " + string(birthyr)
label variable row "LaTeX table row"

* Reference cohort prints as 0 with no SE
foreach o in jrhigh yrsed hschool {
    replace row = row + " & " ///
        + cond(birthyr == 1931, "0", strtrim(string(coef`o', "%9.3f")) ///
            + cond(stars`o' == "", "", "\sym{" + stars`o' + "}")) ///
        + " & " ///
        + cond(birthyr == 1931, "", "(" + strtrim(string(se`o', "%9.3f")) + ")")
}

* Row end from char(92) so Stata can't collapse the 2 backslashes
replace row = row + " " + char(92) + char(92)

file open tex using "$tab/eventstudy_coefs.tex", write replace text
forvalues i = 1/`=_N' {
    file write tex (row[`i']) _n
}
file close tex
restore


log close es
