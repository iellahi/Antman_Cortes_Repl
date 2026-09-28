/*******************************************************************************
Title:   Years of Schooling Crosswalk
Purpose: EDUCD -> years of schooling (0-20). Called by 01_build_data.do,
         needs educd in memory, creates yrsed.
Author:  Ibraheem Saqib Ellahi
Date:    Spring 2026
*******************************************************************************/

gen yrsed=.
replace yrsed=0 if inlist(educd, 2, 10, 11, 12)
replace yrsed=1 if inlist(educd, 13, 14)
replace yrsed=2 if educd==15
replace yrsed=3 if educd==16
replace yrsed=4 if educd==17
replace yrsed=5 if inlist(educd, 20, 21, 22)
replace yrsed=6 if educd==23
replace yrsed=7 if inlist(educd, 24, 25)
replace yrsed=8 if educd==26
replace yrsed=9 if educd==30
replace yrsed=10 if educd==40
replace yrsed=11 if inlist(educd, 50, 61)
replace yrsed=12 if inlist(educd, 60, 62, 65)  // 12 yrs or GED or <1 yr coll
replace yrsed=13 if inlist(educd, 70, 71) // 1 yr college or 1 yr and no degree
replace yrsed=14 if inlist(educd, 80, 81, 82, 83) // 2 yrs college or Associates
replace yrsed=15 if educd==90
replace yrsed=16 if inlist(educd, 100, 101) // 4 yrs college or Bachelors
replace yrsed=17 if educd==110
replace yrsed=18 if inlist(educd, 111, 114) // 6 yrs college or Masters
replace yrsed=19 if inlist(educd, 112, 115) // 7 yrs college or Prof Deg
replace yrsed=20 if inlist(educd, 113, 116) // 8+ yrs college or doctoral degree

label var yrsed "Years of schooling"
