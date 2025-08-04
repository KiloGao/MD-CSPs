

*******************************************************
*                Manuscript Results                   *
*******************************************************
clear all
global path "E:\Files\PhDs\Umd\stata"
cd "$path"
set more off

***Figure 2  Price gradient
use trans_prop_cross_section, clear
keep if dist<=5000 & year>=2013

gen points = .
forvalues i = 1/1000 {
	qui:replace points = `i'*5 in `i'
}

gen post=0
replace post=1 if transdate>=open_pre6

global buffercc "BuildingAge_e TotalFloors TotalBathroomNum livingsqft garagesqft totalvalue lnmetro"

qui egen countyyear=group(countycode year)
qui tab countyyear, gen(_IyeaXcou_)

qui reg lnsaleprice_2023 $buffercc i.month _IyeaXcou_*, robust cluster(CLIP) 
predict price_resid, residual 

qui lpoly price_resid dist if post == 0, generate(yhat_before) se(se_before) at(points) degree(1) kernal(gaussian) msymbol(oh) msize(small) mcolor(gs10) ciopts(lwidth(medium))  noscatter nograph
qui lpoly price_resid dist if post == 1, generate(yhat_after) se(se_after) at(points) degree(1) kernal(gaussian) msymbol(oh) msize(small) mcolor(gs10) ciopts(lwidth(medium))  noscatter nograph

twoway (line yhat_before points, lcolor(black) lpattern(solid) msiz(small)) (line yhat_after points, lcolor(black) lpattern(dash) msiz(small)), xtitle("Distance from CSPs (in meters)", size(small)) ytitle("Log Price Residuals", size(small)) xline(1000, lpattern(shortdash) lcolor(chocolate)) yline(0, lpattern(dot) lcolor(teal)) legend(order(1 "Before CSP open" 2 "After CSP open") size(small)) scheme(s1mono) xlabel(, labsize(small)) ylabel(, labsize(small)) yscale(range(-.05 .1))  ylabel(-.05(.05).1)  name(Figure2, replace)


***Figure 3  Regression
use crosection3000_2013_2023, clear

gen cross_sectional=treat
gen cross_sectional2=treat

global tcontrol "lnage rebuild inc2 density inc1 TotalFloors TotalBathroomNum livingsqft garagesqft totalvalue lnmetro"

reghdfe lnsaleprice_2023 hedonic $tcontrol, absorb(month year) vce(cluster CLIP)
est sto basic1
reghdfe lnsaleprice_2023 hedonic_hdfe $tcontrol, absorb(month countycode#year) vce(cluster CLIP)
*coefplot, baselevels drop(_cons) yline(0) levels(95 90)
est sto basic2

preserve
use psm_crosection_1, clear

gen matching_sample=treat
gen matching_sample2=treat

reghdfe lnsaleprice_2023 matching $tcontrol, absorb(month year) vce(cluster CLIP)
est sto basic3
reghdfe lnsaleprice_2023 matching_hdfe $tcontrol, absorb(month countycode#year) vce(cluster CLIP)
est sto basic4
restore

coefplot basic1 basic2 basic3 basic4, baselevels drop(post $tcontrol _cons) vertical xline(0) ylabel(0(0.02)0.06, format(%03.2f) nogrid) yline(0, lp(dash) lcolor(gs10)) ciopts(color(ltblue*0.7)) mcolor(navy) msymbol(diamond) graphregion(color(white)) levels(99 95) legend(on)


***Figure 4  Event study
global control "lnage inc1 inc2 density rebuild"

use hedonic3000_2013_2023, clear
* using excel to generate ralative time group variable at the year-month level, then merge transdate and opendate
merge m:1 year month using "E:\Files\PhDs\Umd\transfer\rtime.dta"
drop if _merge!=3
drop _merge openym
ren t transtime

gen opendate_str=open_pre6
tostring opendate_str, force replace

gen openym=substr(opendate_str,1,6)
destring openym, force replace
merge m:1 openym using "E:\Files\PhDs\Umd\transfer\rtime.dta"
drop if _merge==2
drop _merge opendate_str openym
ren t opentime 

gen pd=0
replace pd=transtime-opentime
sum pd

forvalues i = 6(-1)1{
local j=`i'*12
local k=`i'*12-12
gen pre_`i'=((pd>-`j' & pd<=-`k') & treat==1)
}

forvalues i = 0(1)5{
local j=`i'*12+12
local k=`i'*12
gen las_`i'=((pd<`j' & pd>=`k') & treat==1)
}

global control "lnage inc1 inc2 density rebuild"
reghdfe lnsaleprice_2023 pre_* las_* $control, absorb(CLIP month countycode#year) vce(cluster CLIP) baselevels
est store px1

parmest, norestore
keep if strpos(parm, "pre_") | strpos(parm, "las_")
replace estimate = 0 if parm == "pre_1"
replace min95 = 0 if parm == "pre_1"
replace max95 = 0 if parm == "pre_1"

gen time = .
replace time = -6 if parm == "pre_6"
replace time = -5 if parm == "pre_5"
replace time = -4 if parm == "pre_4"
replace time = -3 if parm == "pre_3"
replace time = -2 if parm == "pre_2"
replace time = -1 if parm == "pre_1"
replace time = 0 if parm == "las_0"
replace time = 1 if parm == "las_1"
replace time = 2 if parm == "las_2"
replace time = 3 if parm == "las_3"
replace time = 4 if parm == "las_4"
replace time = 5 if parm == "las_5"

twoway ///
    (connected estimate time, lcolor(black) mcolor(blue) lwidth(0.4) msymbol(Sh)) ///
    (rarea min95 max95 time, color("155 194 230%30")), ///
    xtitle("Relative year according to the installation of community solar stations") ///
    ytitle("Estimated effects on property transaction price") ///
    xlabel(-6(1)5) ///
    ylabel(-0.5(0.5)1.5, format(%03.1f) nogrid labstyle(angle(0))) ///
    xline(-1, lcolor(gray) lpattern(dash)) ///
    yline(0, lcolor(gray) lpattern(dash)) ///
    legend(off) ///
    graphregion(color(white)) ///
    bgcolor(white) 
	

***Figure 5  Heterogeneity analysis
use psm_crosection_1, clear

global tcontrol "lnage rebuild inc2 density inc1 TotalFloors TotalBathroomNum livingsqft garagesqft totalvalue lnmetro"
local hetero "Urban Rural High_income Low_income High_awareness Low_awareness Large_CSPs Small_CSPs High_education Low_education Brownfield Greenfield"
foreach v of local hetero{
gen `v'=treat
}

reghdfe lnsaleprice_2023 Urban $tcontrol if rural2==0, absorb(month countycode#year) vce(cluster CLIP)
est sto metro
reghdfe lnsaleprice_2023 Rural $tcontrol if rural2==1, absorb(month countycode#year) vce(cluster CLIP)
est sto rural

reghdfe lnsaleprice_2023 High_income $tcontrol if LMI==0, absorb(month countycode#year) vce(cluster CLIP)
est sto HI
reghdfe lnsaleprice_2023 Low_income $tcontrol if LMI==1, absorb(month countycode#year) vce(cluster CLIP)
est sto LMI

reghdfe lnsaleprice_2023 Large_CSPs $tcontrol if size2==0, absorb(month countycode#year) vce(cluster CLIP)
est sto large
reghdfe lnsaleprice_2023 Small_CSPs $tcontrol if size2==1, absorb(month countycode#year) vce(cluster CLIP)
est sto small

reghdfe lnsaleprice_2023 Low_education $tcontrol if ED2==0, absorb(month countycode#year) vce(cluster CLIP)
est sto Ledu
reghdfe lnsaleprice_2023 High_education $tcontrol if ED2==1, absorb(month countycode#year) vce(cluster CLIP)
est sto Hedu

reghdfe lnsaleprice_2023 Low_awareness $tcontrol if highco==0, absorb(month countycode#year) vce(cluster CLIP)
est sto Lawa
reghdfe lnsaleprice_2023 High_awareness $tcontrol if highco==1, absorb(month countycode#year) vce(cluster CLIP)
est sto Hawa

reghdfe lnsaleprice_2023 Brownfield $tcontrol if green2==0, absorb(month countycode#year) vce(cluster CLIP)
est sto Brown
reghdfe lnsaleprice_2023 Greenfield $tcontrol if green2==1, absorb(month countycode#year) vce(cluster CLIP)
est sto Green

coefplot metro rural Hawa Lawa HI LMI Hedu Ledu large small Brown Green, drop($control _cons) vertical  ytitle("Estimated effects on property transaction price") yline(0, lp(dash) lcolor(gs10)) ciopts(recast(rcap) color(%70)) ylabel(-0.1(0.1)0.2, format(%03.1f) nogrid) msymbol(diamond) graphregion(color(white)) levels(95) legend(off)



*******************************************************
*             Supplementary Regressions               *
*******************************************************
clear all
global path "E:\Files\PhDs\Umd\stata"
cd "$path"
set more off

***Supplementary Table1		Basic regressions
use crosection3000_2013_2023, clear
reghdfe lnsaleprice_2023 treat $tcontrol, absorb(month year) vce(cluster CLIP)
est sto basic1
reghdfe lnsaleprice_2023 treat $tcontrol, absorb(month countycode#year) vce(cluster CLIP)
*coefplot, baselevels drop(_cons) yline(0) levels(95 90)
est sto basic2

preserve
use psm_crosection_1, clear
reghdfe lnsaleprice_2023 treat $tcontrol, absorb(month year) vce(cluster CLIP)
est sto basic3
reghdfe lnsaleprice_2023 treat $tcontrol, absorb(month countycode#year) vce(cluster CLIP)
est sto basic4
restore

preserve
use hedonic3000_2013_2023, clear
reghdfe treat treat_post post $control, absorb(CLIP month year) vce(cluster CLIP)
est sto basic5
reghdfe treat treat_post post $control, absorb(CLIP month year#countycode) vce(cluster CLIP)
est sto basic6
restore

esttab basic1 basic2 basic3 basic4 basic5 basic6 using Supplementary_table1.rtf, replace b(4) se(%6.4f) nogaps ar2(4) mtitles star(* 0.1 ** 0.05 *** 0.01)


***Supplementary Table2		Event study & Stacked DID

*1) Event study
use hedonic3000_2013_2023, clear
merge m:1 year month using "E:\Files\PhDs\Umd\transfer\rtime.dta"
drop if _merge!=3
drop _merge openym
ren t transtime

gen opendate_str=open_pre6
tostring opendate_str, force replace

gen openym=substr(opendate_str,1,6)
destring openym, force replace
merge m:1 openym using "E:\Files\PhDs\Umd\transfer\rtime.dta"
drop if _merge==2
drop _merge opendate_str openym
ren t opentime 

gen pd=0
replace pd=transtime-opentime
sum pd

forvalues i = 6(-1)1{
local j=`i'*12
local k=`i'*12-12
gen pre_`i'=((pd>-`j' & pd<=-`k') & treat==1)
}

forvalues i = 0(1)5{
local j=`i'*12+12
local k=`i'*12
gen las_`i'=((pd<`j' & pd>=`k') & treat==1)
}

global control "lnage inc1 inc2 density rebuild"
reghdfe lnsaleprice_2023 pre_* las_* $control, absorb(CLIP month countycode#year) vce(cluster CLIP) baselevels
est store px1

*2) Stacked DID
preserve
gen nevertreat=(treat==0)
gen action=.
replace action=openyear if treat==1
sum action

replace pre_1=0
stackedev lnsaleprice_2023 pre_* las_*, cohort(action) time(year) never_treat(nevertreat) unit_fe(CLIP) clust_unit(CLIP) covariates(lnage inc1 inc2 density rebuild)
est store px2
lincom(las_0 +las_1+ las_2 +las_3+ las_4+ las_5)/6
restore

esttab px1 px2 using Supplementary_table2.rtf, replace b(4) se(%6.4f) nogaps ar2(4) mtitles star(* 0.1 ** 0.05 *** 0.01)


***Supplementary Figure2	Stacked DID
use hedonic3000_2013_2023, clear
global control "lnage inc1 inc2 density rebuild"

merge m:1 year month using "E:\Files\PhDs\Umd\transfer\rtime.dta"
drop if _merge!=3
drop _merge openym
ren t transtime

gen opendate_str=open_pre6
tostring opendate_str, force replace

gen openym=substr(opendate_str,1,6)
destring openym, force replace
merge m:1 openym using "E:\Files\PhDs\Umd\transfer\rtime.dta"
drop if _merge==2
drop _merge opendate_str openym
ren t opentime 

gen pd=0
replace pd=transtime-opentime
sum pd

forvalues i = 6(-1)1{
local j=`i'*12
local k=`i'*12-12
gen pre_`i'=((pd>-`j' & pd<=-`k') & treat==1)
}

forvalues i = 0(1)5{
local j=`i'*12+12
local k=`i'*12
gen las_`i'=((pd<`j' & pd>=`k') & treat==1)
}

gen nevertreat=(treat==0)
gen action=.
replace action=openyear if treat==1
sum action

replace pre_1=0

stackedev lnsaleprice_2023 pre_* las_*, cohort(action) time(year) never_treat(nevertreat) unit_fe(CLIP) clust_unit(CLIP) covariates(lnage inc1 inc2 density rebuild)
coefplot,baselevels omitted keep(pre* ref las*) vertical recast(connect) color(black) order(pre_6 pre_5 pre_4 pre_3 pre_2 pre_1 las_0 las_1 las_2 las_3 las_4 las_5) yline(0,lp(solid) lc(black)) ylabel(-0.5(0.5)1.5) xline(6,lp(dash) lc(black)) xtitle("Relative year according to the installation of community solar projects") ytitle("Estimated effects on property transaction price") title("Stacked DID Method")  ciopts(recast(rcap) lc(black) lp(dash) lw(thin)) scale(1.0) 


***Supplementary Table3		IV method
use ivsample_zipym, clear

gen pv=mean_t*mean_pv
replace pv=pv/100
ivreg2 mean_lnsaleprice (num_css=pv) i.year i.month, i(zipcode) r first


***Supplementary Table4		Robustness checks
global tcontrol "lnage TotalFloors TotalBathroomNum livingsqft garagesqft totalvalue lnmetro inc1 inc2 density rebuild"
global control "lnage inc1 inc2 density rebuild"

use crosection3000_2013_2023, clear
reghdfe lnsalepricepersqft_2023 treat $tcontrol, absorb(month countycode#year) vce(cluster CLIP)
est sto robust1

drop if roofpv==1
reghdfe lnsaleprice_2023 treat $tcontrol lnestab SFs, absorb(month countycode#year) vce(cluster CLIP)
est sto robust2

preserve
use psm_crosection_1, clear
reghdfe lnsalepricepersqft_2023 treat $tcontrol, absorb(month countycode#year) vce(cluster CLIP)
est sto robust3

drop if roofpv==1
reghdfe lnsaleprice_2023 treat $tcontrol lnestab SFs, absorb(month countycode#year) vce(cluster CLIP)
est sto robust4
restore

preserve
use hedonic3000_2013_2023, clear
reghdfe lnsalepricepersqft_2023 treat_post post $control, absorb(CLIP month year#countycode) vce(cluster CLIP)
est sto robust5

drop if roofpv==1
reghdfe lnsaleprice_2023 treat_post post $control lnestab SFs, absorb(CLIP month countycode#year) vce(cluster CLIP)
est sto robust6
restore

esttab robust1 robust2 robust3 robust4 robust5 robust6 using Supplementary_table4.rtf, replace b(4) se(%6.4f) nogaps ar2(4) mtitles star(* 0.1 ** 0.05 *** 0.01)


***Supplementary Table5&6	Heterogeneity analysis
use psm_crosection_1, clear

global tcontrol "lnage rebuild inc2 density inc1 TotalFloors TotalBathroomNum livingsqft garagesqft totalvalue lnmetro"

reghdfe lnsaleprice_2023 treat $tcontrol if rural2==0, absorb(month countycode#year) vce(cluster CLIP)
est sto metro
reghdfe lnsaleprice_2023 treat $tcontrol if rural2==1, absorb(month countycode#year) vce(cluster CLIP)
est sto rural

reghdfe lnsaleprice_2023 treat $tcontrol if highco==1, absorb(month countycode#year) vce(cluster CLIP)
est sto Hawareness
reghdfe lnsaleprice_2023 treat $tcontrol if highco==0, absorb(month countycode#year) vce(cluster CLIP)
est sto Lawareness

reghdfe lnsaleprice_2023 treat $tcontrol if LMI==0, absorb(month countycode#year) vce(cluster CLIP)
est sto Hincome
reghdfe lnsaleprice_2023 treat $tcontrol if LMI==1, absorb(month countycode#year) vce(cluster CLIP)
est sto Lincome

esttab metro rural Hawareness Lawareness Hincome Lincome using Supplementary_table5.rtf, replace b(4) se(%6.4f) nogaps ar2(4) mtitles star(* 0.1 ** 0.05 *** 0.01)

reghdfe lnsaleprice_2023 treat $tcontrol if ED2==0, absorb(month countycode#year) vce(cluster CLIP)
est sto Heducation
reghdfe lnsaleprice_2023 treat $tcontrol if ED2==1, absorb(month countycode#year) vce(cluster CLIP)
est sto Leducation

reghdfe lnsaleprice_2023 treat $tcontrol if size2==0, absorb(month countycode#year) vce(cluster CLIP)
est sto large
reghdfe lnsaleprice_2023 treat $tcontrol if size2==1, absorb(month countycode#year) vce(cluster CLIP)
est sto small

reghdfe lnsaleprice_2023 treat $tcontrol if green2==1, absorb(month countycode#year) vce(cluster CLIP)
est sto Greenfield
reghdfe lnsaleprice_2023 treat $tcontrol if green2==0, absorb(month countycode#year) vce(cluster CLIP)
est sto Brownfield

esttab Heducation Leducation large small Greenfield Brownfield using Supplementary_table6.rtf, replace b(4) se(%6.4f) nogaps ar2(4) mtitles star(* 0.1 ** 0.05 *** 0.01)



