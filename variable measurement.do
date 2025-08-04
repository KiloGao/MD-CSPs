

*******************************************************
*       Befroe regression - variable measurement      *
*******************************************************
clear all
global dataroot "E:\Files\PhDs\Umd\stata"
cd "$dataroot"
set more off

global troot "E:\Files\PhDs\Umd\transfer"
global merge "E:\Files\PhDs\Umd\data\merge"


***1. SalesPrice
use trans_prop_cross_section, clear

ren SALEAMOUNT SalesPrice
ren TOTALAREASQUAREFOOTAGEALLBUILDIN TotalSQFT
gen SalesPricePerSQFT=SalesPrice/TotalSQFT

sum SalesPrice SalesPricePerSQFT
drop if SalesPrice==.
drop if SalesPrice<1000

**adjust price to 2024, using CPI from U.S. Bureau of Labor Statistics https://data.bls.gov/timeseries/CUUR0000SA0?years_option=all_years
merge m:1 year using "$troot\cpi.dta"
keep if _merge==3
drop _merge

gen saleprice_2023=SalesPrice/cpi_index_2023*100
gen salepricepersqft_2023=SalesPricePerSQFT/cpi_index_2023*100
gen lnsaleprice_2023=ln(saleprice_2023+1)
gen salepricepersqft_2023=ln(salepricepersqft_2023+1)
sum saleprice_2023 salepricepersqft_2023 lnsaleprice_2023 salepricepersqft_2023


***2. Treatment
gen treat=0
replace treat=1 if dist<=1000
gen post = 0
replace post = 1 if transdate>=open_pre6
gen treat_post=treat*post


***3. Property characteristics
ren TOTALNUMBEROFSTORIES TotalFloors
ren TOTALNUMBEROFBATHROOMSALLBUILDIN TotalBathroomNum
ren TOTALLIVINGAREASQUAREFEETALLBUIL LivingSQFT
ren GARAGEORPARKINGSQUAREFEET GarageSQFT
ren ASSESSEDTOTALVALUE Totalvalue

*nearest metro distance
merge m:1 state using metro_coor
keep if _merge ==3
drop _merge state
	
reshape long latitude2 longitude2, i(CLIP) j(metro_id)
geodist latitude longitude latitude2 longitude2, gen(dist)

replace dist=dist*1000
bys CLIP: egen mindist=min(dist)
gen a=dist-mindist
gen c=0
replace c=1 if (-0.1<=a&a<=0.1)
keep if c==1
ren mindist dist_metro
gen lnmetro=ln(dist_metro+1)


***4. Time-varying controls

*zipcode
drop zipcode
gen zipstr=SITUSZIPCODE
tostring zipstr, force replace
gen zipcode=substr(zipstr,1,5)
gen citycode=substr(zipstr,1,3)
destring zipcode citycode, force replace

*countycode
egen countycode=group(SITUSCOUNTY)

*1) Building age
gen BuildingAge_e=year-ACTUALYEARBUILTSTATIC 
replace BuildingAge_e=year-YEARBUILT if BuildingAge_e<=0|BuildingAge_e==.
drop if BuildingAge_e>300
drop if BuildingAge_e<0
gen lnage=ln(BuildingAge_e+1)

*2) Building improvement
gen buildimp=0
replace buildimp=1 if ACTUALYEARBUILTSTATIC>=2013 & year>=ACTUALYEARBUILTSTATIC

*3) Population density
merge m:1 year zipcode using "$merge\data_merge.dta", force
drop if _merge==2
drop _merge

merge m:1 zipcode using "$merge\landarea.dta", force
drop if _merge==2
drop _merge

gen density=population/landarea*10000
replace density=density/1000

*4) Average income
gen income=ln(household_mean_income+1)

*5) Household
gen housesize=population/household_num
gen lnhousenum=ln(household_num+1)


***5. Robustness checks

*1) Sale price per sqft
gen SalesPricePerSQFT=SalesPrice/TotalSQFT
gen salepricepersqft_2023=SalesPricePerSQFT/cpi_index_2023*100

*2) Business establishment
merge m:1 year zipcode using "$merge\business_merge.dta", force
drop if _merge==2
drop _merge
bys zipcode: mipolate estab year, epolate gen(estabi) 
replace estab=estabi if year==2023
replace estab=0 if estab==.
drop estabi
gen lnestab=ln(estab+1)

*3) Solar farms
use MD_USPVDB, clear
ren xlong longitude
ren ylat latitude
duplicates tag longitude, generate(dup1)
duplicates tag latitude, generate(dup2)
drop dup1 dup2
egen ll=group(longitude latitude)
duplicates tag ll, generate(dup)
count if dup!=0  //26 obs
duplicates drop ll, force  //0 obs
gen solarfarm_id=_n
save MD_USPVDB, replace

use MD_USPVDB, clear
ren p_state state
ren longitude longitude2
ren latitude latitude2
keep state solarfarm_id latitude2 longitude2
reshape wide latitude2 longitude2, i(state) j(solarfarm_id)
save coor_USPVDB.dta, replace

use crosection3000_2013_2023, clear
merge m:1 state using coor_USPVDB
keep if _merge ==3
drop _merge
duplicates drop CLIP, force
keep CLIP latitude longitude latitude21-latitude289
reshape long latitude2 longitude2, i(CLIP) j(solarfarm_id)
geodist latitude longitude latitude2 longitude2, gen(dist)
replace dist = dist*1000
sum dist
save CLIP_USPVDB, replace

use CLIP_USPVDB, clear
merge m:1 solarfarm_id using MD_USPVDB
keep if _merge ==3
drop _merge
gen dist4000=0
replace dist4000=1 if dist<=4000
bys CLIP: egen countdist4000=sum(dist4000)
sum countdist4000
keep if dist4000!=0
bys CLIP: egen earlyeardist4000=min(p_year)
duplicates drop CLIP, force
save CLIP_USPVDB_4000, replace

use crosection3000_2013_2023, clear
merge m:1 CLIP using CLIP_USPVDB_4000
drop _merge
replace dist4000=0 if dist4000==.
gen treatyear_USPVDB1000=0
replace treatyear_USPVDB1000=1 if year>=p_year
gen SFs=dist1000*treatyear_USPVDB1000

*4) Rooftop PVs
import delimited "E:\Files\PhDs\Umd\Zillow\24\ZAsmt\Main.txt"
keep v1 v82 v83
ren v1 id
ren v82 latitude
ren v83 longitude
save MD_Zillow_coor, replace

import delimited "E:\Files\PhDs\Umd\Zillow\24\ZAsmt\Building.txt"
keep if v32=="SO"
keep v1
ren v1 id
save MD_Zillow_roofpvhouse, replace

use MD_Zillow_coor, clear
merge 1:1 id using MD_Zillow_roofpvhouse, force
keep if _merge ==3
drop _merge
drop if latitude==.
save MD_Zillow_roofpvcoor, replace

use MD_Zillow_roofpvcoor, clear
gen roof_id=_n
gen state="MD"
ren longitude longitude2
ren latitude latitude2
keep state roof_id latitude2 longitude2
reshape wide latitude2 longitude2, i(state) j(roof_id)
save rooftop_coor_Zillow.dta, replace

use crosection3000_2013_2023, clear
merge m:1 state using rooftop_coor_Zillow
keep if _merge ==3
drop _merge

duplicates drop CLIP, force
keep CLIP latitude longitude latitude21-latitude2449
reshape long latitude2 longitude2, i(CLIP) j(roof_id)

save CLIP_rooftop_Zillow, replace

use CLIP_rooftop_Zillow, clear
geodist latitude longitude latitude2 longitude2, gen(dist)
replace dist = dist*1000
sum dist
sum if dist==0
sum dist if dist!=0
bys CLIP: egen mindist=min(dist) 
duplicates drop CLIP, force
gen roofpv=0
replace roofpv=1 if mindist<=10
sort roofpv
save CLIP_rooftoppv_Zillow, replace


***6. Heterogeneity

*1) rural
sum density
gen Rural2=0
replace Rural2=1 if density<=0.5 & year==2018
bys zipcode: egen rural2=max(Rural2)

*2) environmental awareness
gen highco=0
replace highco=1 if county=="ANNE ARUNDEL"
replace highco=1 if county=="BALTIMORE"
replace highco=1 if county=="BALTIMORE CITY"
replace highco=1 if county=="CHARLES"
replace highco=1 if county=="HOWARD"
replace highco=1 if county=="MONTGOMERY"
replace highco=1 if county=="PRINCE GEORGE'S"

*3) income level
xtile LMI=household_mean_income, nq(2)
replace LMI=0 if LMI==1
replace LMI=1 if LMI==2

*4) CSP size
xtile size2=size_mw, nq(2)
replace size2=0 if size2==2

*5) education level
gen edu2=ratio_under9grade_25_
xtile ED2=edu2, nq(2)
replace ED2=0 if ED2==2

*6) greenfield
gen green2=0
replace green2=1 if lu_code==21|lu_code==22|lu_code==41|lu_code==42|lu_code==43|lu_code==73|lu_code==191


