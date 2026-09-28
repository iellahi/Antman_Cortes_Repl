/*******************************************************************************
Title:   Data Construction for Antman and Cortes (2023) Replication
Purpose: Clean and prepare 1980, 1990, and 2000 Census data for analysis.
         In:  data/raw/data-CA.dta (IPUMS USA extract, California)
         Out: data/clean/antman_cortes_clean.dta
Author:  Ibraheem Saqib Ellahi
Date:    Spring 2026
*******************************************************************************/

version 16
clear all
set more off
capture log close build
log using "$log/01_build_data.log", replace text name(build)


* 1. County Classification
********************************************************************************

* HiSeg / LoSeg counties from Antman & Cortes (2023) p. 893, fn 15
* HiSeg = above 75th pctile of 1940 Hispanic share, LoSeg = below 25th
clear
input int countyfip byte hiseg str15 county_name
 19 1 "Fresno"
 25 1 "Imperial"
 31 1 "Kings"
 39 1 "Madera"
 47 1 "Merced"
 53 1 "Monterey"
 59 1 "Orange"
 65 1 "Riverside"
 71 1 "San Bernardino"
 83 1 "Santa Barbara"
107 1 "Tulare"
111 1 "Ventura"
113 1 "Yolo"
  7 0 "Butte"
 17 0 "El Dorado"
 23 0 "Humboldt"
 89 0 "Shasta"
 97 0 "Sonoma"
end

label variable hiseg "High Segregation County (Treatment)"
label variable county_name "County Name (HiSeg/LoSeg counties only)"

* Verify: 13 HiSeg, 5 LoSeg, 1 row / county
isid countyfip
count if hiseg == 1
assert r(N) == 13
count if hiseg == 0
assert r(N) == 5

tempfile counties
save "`counties'"


* 2. Census Data and Merge
********************************************************************************

use "$raw/data-CA.dta", clear

* Sample size at each step
count

* countyfip 0 = county not identified by IPUMS
* Gets hiseg = . like other non-study counties
merge m:1 countyfip using "`counties'"
tab _merge

* No county-only rows, every study county in extract
assert _merge != 2
drop _merge

* Study counties by census year
tab county_name year


* 3. Sample Construction I
********************************************************************************

* Keep only people born in California
keep if bpl == 6
count

* keep cohorts 2-26 in 1947
gen age1947 = 1947 - birthyr
label variable age1947 "Age in 1947 (Mendez Decision)"
keep if inrange(age1947, 2, 26)
count

* Hispanic: HISPAN 1-4. Not hispan > 0, code 9 = not reported
gen hispanic = inrange(hispan, 1, 4)
label variable hispanic "Indicator for Hispanic Ethnicity"

* Non-Hispanic white: HISPAN 0 & RACE 1, minus RACED 110 (Spanish write-in)
* RACED 110 = 5 obs in Panel C sample, dropping them matches paper's N
gen nhwhite = hispan == 0 & race == 1 & raced != 110
label variable nhwhite "Non-Hispanic White (HISPAN 0, RACE 1, not RACED 110)"

* Keep Hispanics and Non-Hispanic Whites
keep if hispanic == 1 | nhwhite == 1
count
assert hispanic + nhwhite == 1

* Note: NOT dropping observations based on the HiSeg variable at this stage.


* 4. Sample Construction II
********************************************************************************

* Tables 1/2: treated ages 2-6 in 1947 (born 1941-45)
* Comparison ages 12-16 (born 1931-35)
* 1936-40 left out: partly treated, in elementary school at Mendez (Duflo 2001 style)
gen sample_tables = inrange(age1947, 2, 6) | inrange(age1947, 12, 16)
label variable sample_tables "In Table 1/2 Sample (Ages 2-6 or 12-16)"

* Table 2 Panel B placebo: born 1921-30, done with school before Mendez
gen sample_placebo = inrange(birthyr, 1921, 1930)
label variable sample_placebo "In Table 2 Panel B Placebo Sample (Born 1921-30)"

* Event study: Hispanic, all cohorts 1921-45, HiSeg/LoSeg counties
gen es_sample = hispanic == 1 & inrange(birthyr, 1921, 1945) & !missing(hiseg)
label variable es_sample "Event-study sample (Hispanic, cohorts 1921-45, HiSeg/LoSeg counties)"

* Verify
tab sample_tables hispanic
tab sample_placebo hispanic
tab es_sample


* 5. Variable Construction I
********************************************************************************

* A. Outcome Variables
********************************************************************************

* Years of Education
do "$root/code/lib/yrsed.do"
label variable yrsed "Years of Education"

* crosswalk has to cover every EDUCD code left
count if missing(yrsed)
assert !missing(yrsed)

* Jr. High Completion (8+ years)
gen jrhigh = yrsed >= 8
label variable jrhigh "Completed Jr. High (8+ Years)"

* High School Completion (12+ years)
gen hschool = yrsed >= 12
label variable hschool "Completed High School (12+ Years)"


* B. Explanatory Variables (Difference-in-Differences)
********************************************************************************

* Post-Treatment (PostMendez), born 1941-45
gen post_mendez = inrange(birthyr, 1941, 1945)
label variable post_mendez "Post-Mendez Cohort (Born 1941-45)"

* Interaction Term (DiD Estimator), missing outside HiSeg/LoSeg counties
gen did_interaction = hiseg * post_mendez
label variable did_interaction "HiSeg x PostMendez"

* Placebo post cohort for Panel B, born 1926-30
gen placebo_post = inrange(birthyr, 1926, 1930)
label variable placebo_post "Placebo Post-Mendez Cohort (Born 1926-30)"

* Inspect
summarize yrsed jrhigh hschool hiseg post_mendez did_interaction placebo_post


* 6. Variable Construction II
********************************************************************************

* Table 2 notes: indicator for female, 1990 census, 2000 census
* Fixed effects can be handled directly in regression command

* Female Indicator
gen female = sex == 2
label variable female "Female Indicator (1=Female, 0=Male)"

* Census Year Indicators
gen census1990 = year == 1990
label variable census1990 "Census 1990 Indicator"

gen census2000 = year == 2000
label variable census2000 "Census 2000 Indicator"

* Verify
assert inlist(year, 1980, 1990, 2000)
tab sex female
tab year census1990
tab year census2000


* 7. Analysis Sample Sizes
********************************************************************************

* Tables 1 & 2 Panel A: Hispanic, HiSeg/LoSeg, born 1931-35 or 1941-45
count if hispanic == 1 & sample_tables == 1 & !missing(hiseg)
tab post_mendez hiseg if hispanic == 1 & sample_tables == 1 & !missing(hiseg)

* Table 2 Panel B: Hispanic placebo cohorts
count if hispanic == 1 & sample_placebo == 1 & !missing(hiseg)

* Table 2 Panel C: non-Hispanic whites
count if nhwhite == 1 & sample_tables == 1 & !missing(hiseg)

* Event study
count if es_sample == 1


* 8. Save Working Data Set
********************************************************************************

* Order variables for easier viewing
order countyfip county_name year birthyr age1947 sex race raced hispan educd ///
    yrsed jrhigh hschool hispanic nhwhite hiseg sample_tables post_mendez ///
    did_interaction sample_placebo placebo_post es_sample female census1990 census2000

compress
sort year serial pernum

* Signature so 02-06 confirm same file
datasignature set, reset
save "$clean/antman_cortes_clean.dta", replace

* Verify
describe
codebook, compact

log close build
