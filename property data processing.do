

*******************************************************
*          Property Data - Get SFR then Clean         *
*******************************************************
clear all
set more off
global proot "E:\Files\PhDs\Umd\property"
cd "$proot"

*MD
import delimited "$proot\md_data_1.txt", clear bindquotes(nobind) stripquote(no) case(preserve)
import delimited "$proot\md_data_2.txt", clear bindquotes(nobind) stripquote(no) case(preserve)
import delimited "$proot\md_data_3.txt", clear bindquotes(nobind) stripquote(no) case(preserve)

*append data
use proper_1, clear
append using proper_2, force 
append using proper_3, force 
save property

use property, clear
drop PREVIOUSPARCELNUMBER PREVIOUSPARCELSEQUENCENUMBER JURISDICTIONCOUNTYCODE TAXABLEOTHERVALUE  TOTALNUMBEROF1BEDROOMS TOTALNUMBEROF2BEDROOMS TOTALNUMBEROF3BEDROOMS TOTALNUMBEROFEFFICIENCYUNITS RECORDACTIONINDICATOR

*keep SFR
gen SFR = 1 if LANDUSECODE==112 | LANDUSECODE==163
replace SFR =0 if SFR==.
keep if SFR==1 

*drop mult-/missing-addresses
drop if MULTIORSPLITPARCELCODE!=""
drop MULTIORSPLITPARCELCODE
drop if PARCELLEVELLATITUDE==. | PARCELLEVELLONGITUDE==. | MAILINGSTREETADDRESS==""

sort SITUSSTATE SITUSCOUNTY SITUSCITY SITUSZIPCODE MAILINGSTREETADDRESS 
tab ASSESSEDYEAR
**Only current assessment data here

save "property.dta",replace


******************************************************
*    Transaction - Clean and Match with Property     *
******************************************************
clear all
set more off
global troot "E:\Files\PhDs\Umd\transfer"
cd "$troot"

foreach n in 1 2 3 4 5 6 7 8 9{
clear
import delimite "$troot\md_data_`n'.txt", clear bindquotes(nobind) stripquote(no) case(preserve)

*drop Arm's length transaction
drop if SHORTSALEINDICATOR==1
drop if FORECLOSUREREOINDICATOR==1
drop if FORECLOSUREREOSALEINDICATOR==1
drop if NEWCONSTRUCTIONINDICATOR==1
drop if INVESTORPURCHASEINDICATOR==1 
drop if INTERFAMILYRELATEDINDICATOR==1

*drop could not be matched with tax roll
drop if PENDINGRECORDINDICATOR=="Y"

*drop unverifiable address
drop if STANDARDIZEDADDRESSCONFIDENCECOD==""

*Check cash based transaction
tab CASHPURCHASEINDICATOR
save "$troot\trans`n'.dta", replace
}


*Merge Data
use trans1, clear

foreach n in 2 3 4 5 6 7 8 9{
append using trans`n', force 
}

save trans_all, replace


*Merge Data
use "$proot\property.dta", clear
keep CLIP
save "$proot\property_id", replace

use trans_all, clear
merge m:1 CLIP using "$proot\property_id.dta"

drop if _merge==1|_merge==2
drop _merge
save transfer, replace


******************************************************
*            CSP location data processing            *
******************************************************
set more off

rename id cs_id
rename latitude latitude2
rename longitude longitude2

* convert date format
ren expectedinservicedate insdate
gen open=date(insdate, "YMD") 
format open %td
gen openyear=year(open)
gen openmonth=month(open)
tab openyear, m
drop if missing(open)

save cs_station.dta, replace

keep state cs_id latitude2 longitude2
reshape wide latitude2 longitude2, i(state) j(cs_id)

save cs_station_coor.dta, replace


*******************************************************
*              Sample data preprocessing              *
*******************************************************
clear all
set more off
set maxvar 120000
set matsize 11000

*property id = CLIP
*station id = cs_id
*transfer id = transid

global troot "E:\Files\PhDs\Umd\transfer"
global proot "E:\Files\PhDs\Umd\property"
global dataroot "E:\Files\PhDs\Umd\stata"

use "$troot\transfer.dta", clear

gen transid = _n
gen transdate = SALEDERIVEDDATE
tostring transdate, force replace
gen year=substr(transdate,1,4)
gen month=substr(transdate,5,2)
gen day=substr(transdate,7,2)
destring year month day, force replace
tab year, m

merge m:1 CLIP using "$proot\property.dta", force
drop if _merge==2
drop _merge
save trans, replace

*properties that near CSP within `n' km
use "$troot\trans.dta", clear

rename SITUSSTATE state
merge m:1 state using cs_station_coor
keep if _merge ==3
drop _merge

rename PARCELLEVELLATITUDE latitude
rename PARCELLEVELLONGITUDE longitude

keep transid latitude longitude latitude21-longitude2153
reshape long latitude2 longitude2, i(transid) j(cs_id)
	
*sample too large, so use subsamples
savesome if transid<=700000 using trans_cs_station_1.dta, replace
savesome if transid>700000 & transid<=1400000 using trans_cs_station_2.dta, replace
savesome if transid>1400000 & transid<=2100000 using trans_cs_station_3.dta, replace
savesome if transid>2100000 using trans_cs_station_4.dta, replace

local filenames: dir . files "trans_cs_station_*.dta"

foreach i of local filenames{
	use `i', clear
	geodist latitude longitude latitude2 longitude2, gen(dist)
	save `i', replace
}

*merge all dta
use trans_cs_station_1.dta, clear
append using trans_cs_station_2, force
append using trans_cs_station_3, force
append using trans_cs_station_4, force
save trans_cs_station.dta, replace

*keep critic variables
use trans, clear
keep transid transdate
destring transdate, force replace
save trans_onlydate, replace

use cs_station, clear
keep cs_id r_m size_mw open
save cs_station_onlydate, replace

use trans, clear
keep transid CLIP
save trans_onlyid, replace

local filenames: dir . files "trans_cs_station_*.dta"
foreach i of local filenames{
	use `i', clear
	merge m:1 transid using trans_onlydate
    drop if _merge != 3
    drop _merge
	
	merge m:1 cs_id using cs_station_onlydate
    drop if _merge != 3
    drop _merge
	
	merge m:1 transid using trans_onlyid
    drop if _merge != 3
    drop _merge
	
	g open_str=string(open, "%td")
	g opent=date(open_str, "DMY")
	g opent_pre6=opent-182
	g temp1=string(opent_pre6, "%td")
	g temp2=date(temp1, "DMY")
	g temp3=string(year(temp2))+string(month(temp2), "%02.0f")+string(day(temp2), "%02.0f")
	destring temp3, gen(open_pre6)
	drop open temp1 temp2 temp3

	g temp1=string(opent, "%td")
	g temp2=date(temp1, "DMY")
	g temp3=string(year(temp2))+string(month(temp2), "%02.0f")+string(day(temp2), "%02.0f")
	destring temp3, gen(open)
	drop opent opent_pre6 temp1 temp2 temp3
	
	save `i', replace
}


*******************************************************
*       cross section data sample preprocessing       *
*******************************************************
clear
foreach n in 1 2 3 4{
use "$dataroot\trans_cs_station_`n'.dta", clear
replace dist = dist*1000-r_m 
tab CLIP if dist<0
drop if dist<0
**convert unit to meter

*calculate dist to the nearest CSP of each property
bys transid: egen mindist=min(dist) 
gen a=dist-mindist
gen c=0
replace c=1 if (-1<=a&a<=1)
keep if c==1
drop a c

tabstat dist, statistics(mean n sd min q p90 max)
egen group=group(CLIP)
summarize group

save cross_section_`n'.dta, replace
}

use cross_section_1, clear
append using cross_section_2, force
append using cross_section_3, force
append using cross_section_4, force

duplicates tag transid, generate(dup)
drop if dup==1
drop dup
save cross_section, replace

use "$troot\trans", clear
gen transdate_str=transdate
destring transdate, force replace
merge 1:1 transid using cross_section, force
keep if _merge==3
drop _merge

merge m:1 cs_id using "$dataroot\cs_station.dta"
drop if _merge==2
drop _merge
save trans_prop_cross_section, replace

keep if dist<=3000
keep if year>=2013 & year<=2023
save crosection3000_2013_2023, replace


*******************************************************
*   cross-section with PSM data sample preprocessing  *
*******************************************************
use crosection3000_2013_2023, clear

forvalues i = 2013(1)2023{
preserve
keep if year==`i'
set seed 1234
gen tmp = runiform()
sort tmp
psmatch2 treat $pcontrol, out(lnsaleprice_2023) logit neighbor(1) ate 
drop if _weight == .
save psm_`i'.dta, replace
restore
}

use psm_2013, clear
forvalues i = 2014(1)2023{
append using psm_`i'.dta
}
save psm_crosection_1, replace


*******************************************************
*          Hedonic data sample preprocessing          *
*******************************************************
merge m:1 CLIP using "$proot\property.dta", force
drop if _merge==2
drop _merge
save trans, replace

foreach n in 1 2 3 4{
use "$dataroot\trans_cs_station_`n'.dta", clear
replace dist = dist*1000-r_m 
tab CLIP if dist<0
drop if dist<0
**convert unit to meter

*properties that have been sold more than once
bys CLIP: gen n_import = _N
bys CLIP transid: gen n_trans = _N
keep if n_import > n_trans
drop n_import n_trans

gen v3 = (dist<=3000)
bys transid: egen sum3 = sum(v3)
drop if v3==0
bys transid: egen mindist = min(dist) 
bys transid: egen minopen = min(open) 
gen a=dist-mindist
gen b=open-minopen
gen c=0
replace c=1 if (-1<=a&a<=1)&(-1<=b&b<=1)
keep if c==1
drop a b c v3
*c=1 means for properties near more than one station, but the closest site is the earliest

gen post = 0
replace post = 1 if transdate>=open_pre6
bys CLIP: egen sumpost = sum(post)
drop if sumpost < 1
drop sumpost

tabstat dist, statistics(mean n sd min q p90 max)
egen group=group(CLIP)
summarize group

save buffer3000_`n'.dta, replace
}

*append group data and merge with sample data
use buffer3000_1, clear
foreach n in 2 3 4{
append using buffer3000_`n', force
append using buffer3000_`n', force
append using buffer3000_`n', force
}

duplicates tag transid, generate(dup)
drop if dup==1
drop dup
save buffer3000, replace

use "$troot\trans", clear
merge 1:1 transid using buffer3000, force
keep if _merge==3
drop _merge

merge m:1 cs_id using "$dataroot\cs_station.dta"
drop if _merge==2
drop _merge
save trans_prop_3000, replace

keep if year>=2013 & year<=2023

bys CLIP: gen n_import = _N
bys CLIP transid: gen n_trans = _N
gen a=0
replace a=1 if n_import > n_trans
keep if n_import > n_trans
drop n_import n_trans a
**keep properties that have been sold more than once

drop post
gen post = 0
replace post = 1 if transdate>=open_pre6
bys CLIP: egen sumpost = sum(post)
drop if sumpost<1
drop sumpost
**check again properties with at least one sale after the open date of CSP  

drop group
egen group=group(CLIP)
summarize group	
save hedonic3000_2013_2023, replace


******************************************************
*         IV zip-code level data processing          *
******************************************************

*improt year-month nasa data
ren code zip_id
g ym_str=string(ym)
g year=substr(ym_str,1,4)
g month=substr(ym_str,5,2)
destring year month, force replace
save nasa_month.dta, replace

bys zip_id year: egen ymean_ph=mean(mean_ph)
bys zip_id year: egen ymean_t=mean(mean_t)
bys zip_id year: egen ymean_pv=mean(mean_pv)
egen a=group(zip_id year)
duplicates drop a, force
drop ym month mean_ph mean_t mean_pv ym_str a
save nasa_year.dta, replace

use crosection3000_2013_2023, clear
egen zip_id=group(zipcode)
merge m:1 zip_id year month using nasa_month
drop if _merge==2
drop _merge

merge m:1 zip_id year using nasa_year
drop if _merge==2
drop _merge

bys zipcode ym: egen mean_lnsaleprice=mean(lnsaleprice_2023)
egen zip_ym=group(zipcode ym)
duplicates drop zip_ym, force
merge 1:1 zipcode ym using iv_zipym
drop if _merge==1
drop _merge

save ivsample_zipym, replace 

