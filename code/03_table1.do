/*******************************************************************************
Title:   Table 1 Replication for Antman and Cortes (2023)
Purpose: Replicate Table 1: means [SD] by HiSeg/LoSeg and cohort, HiSeg-LoSeg
         gaps, and the 2x2 difference-in-differences. Hispanic sample,
         robust SE (as in the paper's notes).
Author:  Ibraheem Saqib Ellahi
Date:    Spring 2026
*******************************************************************************/

version 16
clear all
set more off
capture log close table1
log using "$log/03_table1.log", replace text name(table1)

use "$clean/antman_cortes_clean.dta", clear
datasignature confirm

* Hispanic, HiSeg/LoSeg counties, born 1931-35 or 1941-45
keep if hispanic == 1 & sample_tables == 1 & !missing(hiseg)
count


* 1. Helper to Store a Table Column
********************************************************************************

* Table 1 has outcomes as rows, so each column posted as own "model"
* with coefs named yrsed jrhigh hschool. Mean columns get V = 0 (no SE, no stars)
program define post_column, eclass
    syntax, b(name) v(name) n(integer) [sd(name) dof(integer 0)]
    if `dof' > 0 {
        ereturn post `b' `v', obs(`n') dof(`dof')
    }
    else {
        ereturn post `b' `v', obs(`n')
    }
    if "`sd'" != "" ereturn matrix sd = `sd'
    ereturn local cmd "post_column"
end

local outcomes "yrsed jrhigh hschool"


* 2. Means and SDs by Group
********************************************************************************

* p = post_mendez, h = hiseg
foreach p in 1 0 {
    foreach h in 1 0 {
        matrix M = J(1, 3, .)
        matrix S = J(1, 3, .)
        matrix V = J(3, 3, 0)
        local j = 0
        foreach var in yrsed jrhigh hschool {
            local ++j
            summarize `var' if post_mendez == `p' & hiseg == `h'
            matrix M[1, `j'] = r(mean)
            matrix S[1, `j'] = r(sd)
        }
        matrix colnames M = `outcomes'
        matrix colnames S = `outcomes'
        matrix colnames V = `outcomes'
        matrix rownames V = `outcomes'
        count if post_mendez == `p' & hiseg == `h'
        post_column, b(M) v(V) sd(S) n(`r(N)')
        eststo mean_p`p'_h`h'
    }
}


* 3. HiSeg - LoSeg Gap Within Cohort
********************************************************************************

foreach p in 1 0 {
    matrix B = J(1, 3, .)
    matrix V = J(3, 3, 0)
    local j = 0
    foreach var in yrsed jrhigh hschool {
        local ++j
        regress `var' hiseg if post_mendez == `p', robust
        matrix B[1, `j'] = _b[hiseg]
        matrix V[`j', `j'] = _se[hiseg]^2
        * same N, df for all 3
        if `j' == 1 {
            local n = e(N)
            local df = e(df_r)
        }
        assert e(N) == `n' & e(df_r) == `df'
    }
    matrix colnames B = `outcomes'
    matrix colnames V = `outcomes'
    matrix rownames V = `outcomes'
    post_column, b(B) v(V) n(`n') dof(`df')
    eststo gap_p`p'
}


* 4. Difference-in-Differences
********************************************************************************

matrix B = J(1, 3, .)
matrix V = J(3, 3, 0)
local j = 0
foreach var in yrsed jrhigh hschool {
    local ++j
    regress `var' c.hiseg##c.post_mendez, robust
    matrix B[1, `j'] = _b[c.hiseg#c.post_mendez]
    matrix V[`j', `j'] = _se[c.hiseg#c.post_mendez]^2
    if `j' == 1 {
        local n = e(N)
        local df = e(df_r)
    }
    assert e(N) == `n' & e(df_r) == `df'
}
matrix colnames B = `outcomes'
matrix colnames V = `outcomes'
matrix rownames V = `outcomes'
post_column, b(B) v(V) n(`n') dof(`df')
eststo did


* 5. Export
********************************************************************************

* Column order follows paper: 1941-45 High, Low, gap; 1931-35 High, Low, gap; DiD
local models "mean_p1_h1 mean_p1_h0 gap_p1 mean_p0_h1 mean_p0_h0 gap_p0 did"

* SD in brackets under means, SE in parens under gaps & DiD
local cells `"cells("b(fmt(3) star)" "sd(fmt(3) par([ ])) & se(fmt(3) par pattern(0 0 1 0 0 1 1))")"'

local rows `"coeflabels(yrsed "Years of Education" jrhigh "Jr. High (8+ years of education)" hschool "High School (12+ years of education)")"'

* Log copy
esttab `models', `cells' star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Hi 41-45" "Lo 41-45" "Gap 41-45" "Hi 31-35" "Lo 31-35" "Gap 31-35" "DiD") ///
    nonumbers collabels(none) stats(N, fmt(%9.0fc)) modelwidth(11)

* LaTeX fragment (stars need \sym defined in paper preamble)
* Long headers split over two lines so table fits the page
esttab `models' using "$tab/table1_summary.tex", replace booktabs fragment ///
    `cells' star(* 0.10 ** 0.05 *** 0.01) `rows' ///
    mgroups("\begin{tabular}{c}Panel A. Treatment group\tabularnewline 1941--45 birth cohorts (ages 2--6)\end{tabular}" ///
        "\begin{tabular}{c}Panel B. Comparison group\tabularnewline 1931--35 birth cohorts (ages 12--16)\end{tabular}" "", ///
        pattern(1 0 0 1 0 0 1) prefix(\multicolumn{@span}{c}{) suffix(}) span ///
        erepeat(\cmidrule(lr){@span})) ///
    mtitles("High" "Low" "\ensuremath{\Delta^{\mathrm{treatment}}}" ///
        "High" "Low" "\ensuremath{\Delta^{\mathrm{comparison}}}" ///
        "\begin{tabular}{c}\ensuremath{\Delta^{\mathrm{treatment}}}\tabularnewline \ensuremath{-\,\Delta^{\mathrm{comparison}}}\end{tabular}") ///
    nonumbers collabels(none) stats(N, fmt(%9.0fc) labels("Number of observations")) ///
    nonotes

* CSV twin
esttab `models' using "$tab/table1_summary.csv", replace ///
    `cells' star(* 0.10 ** 0.05 *** 0.01) `rows' ///
    mtitles("High 1941-45" "Low 1941-45" "Gap 1941-45" "High 1931-35" "Low 1931-35" "Gap 1931-35" "DiD") ///
    nonumbers collabels(none) stats(N, fmt(%9.0fc) labels("Number of observations")) ///
    nonotes

log close table1
