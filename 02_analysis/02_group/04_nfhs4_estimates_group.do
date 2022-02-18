******************************************************
*File to merge 100 samples from nfhs 2 with estimates 
******************************************************

**************************************************
*Preamble
**************************************************
	set more off
	
	*Set user

	
	*Log
	cap log close
	log using "$dir/02_logs/02analysis_nfhs4_group_ci.txt", text replace

**************************************************
*append and merge
**************************************************

	forval x = 1(1)100 {
	use "$dir\04_input\resamples\bstraps\nfhs4\group\nfhs4_rep`x'_group.dta", clear 
	keep female age_group caste_religion nmx lx ex 
	cap rename nmx nmx_rep`x'
	cap rename lx lx_rep`x' 
	cap rename ex ex_rep`x'
	save "$dir\04_input\resamples\bstraps\nfhs4\group\nfhs4_rep`x'_group.dta", replace
	}
	
	*fmerge all reps 
	use "$dir\04_input\resamples\bstraps\nfhs4\group\nfhs4_rep1_group.dta", clear 
	
	forval x = 2(1)100 {
	fmerge 1:1 caste_religion female age_group using ///
	"$dir\04_input\resamples\bstraps\nfhs4\group\nfhs4_rep`x'_group.dta", nogen 
	}
	

********************************************************
*calculate se	
********************************************************
	preserve
	*ex se 
	keep caste_religion female age_group ex*
	
	egen mean = rowmean(ex_rep1-ex_rep100)
	
	forval x = 1(1)100 {
	gen dev`x' = (ex_rep`x' - mean)^2
	}
	
	egen dev_total = rowtotal(dev1-dev100)
	gen se_ex = sqrt(dev_total / 99)
	
	keep caste_religion female age_group se_ex
	gen round = 4
	
	save "$dir\04_input\resamples\bstraps\nfhs4\nfhs4_ex_se_group.dta", replace
	
	restore 
	
	*nmx se 
	preserve
	keep caste_religion female age_group nmx*
	
	egen mean = rowmean(nmx_rep1-nmx_rep100)
	
	forval x = 1(1)100 {
	gen dev`x' = (nmx_rep`x' - mean)^2
	}
	
	egen dev_total = rowtotal(dev1-dev100)
	gen se_nmx = sqrt(dev_total / 99)
	
	keep caste_religion female age_group se_nmx
	gen round = 4
	
	save "$dir\04_input\resamples\bstraps\nfhs4\nfhs4_nmx_se_group.dta", replace
	restore 
	
	*lx se 
	keep caste_religion female age_group lx*
	
	egen mean = rowmean(lx_rep1-lx_rep100)
	
	forval x = 1(1)100 {
	gen dev`x' = (lx_rep`x' - mean)^2
	}
	
	egen dev_total = rowtotal(dev1-dev100)
	gen se_lx = sqrt(dev_total / 99)
	
	keep caste_religion female age_group se_lx
	gen round = 4
	
	save "$dir\04_input\resamples\bstraps\nfhs4\nfhs4_lx_se_group.dta", replace
	
*********************************************************
*gen estimates, lci and uci 
*********************************************************

	*Import SRS
	use "$dir/00_raw/srs_2012.dta", clear 
		
	keep female n nax nmx_srs age_group
	
		*Save
		tempfile srs
		save `srs'

	*Import child person years and append adult person years 
	use "$dir/04_input/nfhs4_child_person_years.dta", clear 
	
	append using "$dir/04_input/nfhs4_adult_person_years.dta"	
	
	*collapse
	fcollapse (sum) deaths person_years ///
	, by(caste_religion age_group female)
	
		g nmx = deaths / person_years
	
	*Merge srs
	merge m:1 female age_group using `srs', nogen

	*Sort and order
	sort caste_religion female age_group

	*Order
	order caste_religion female age_group n nmx nax 

	**Make life tables
	
	*nqx
	cap drop nqx
	gen nqx = (n*nmx) / (1 + (n-nax)*nmx)
	replace nqx = 1 if nqx==.
		
	*radix
	cap drop lx
	sort caste_religion female age_group
	by caste_religion female: gen lx = 1 if _n==1
		
	*lx
	forval i=2(1)19 {
		by caste_religion female : replace lx = (lx[_n-1]*(1-nqx[_n-1])) if _n==`i'
	}
	
	*nLx
	cap drop nLx
	gen nLx=.
	forval i=1(1)18 {
		by caste_religion female : replace nLx = (lx[_n+1]*n) + (lx*nqx*nax) if _n==`i'
	}
	by caste_religion female: replace nLx = lx/nmx if _n==19
	
	*Total PY (for Tx)
	cap drop total_py
	bysort caste_religion female: egen total_py = total(nLx) 

	*Tx
	cap drop Tx
	gen Tx = .
	by caste_religion female: replace Tx = total_py - sum(nLx) + nLx

	*ex
	cap drop ex
	gen ex = Tx / lx
	
	*Keep only ex's
	keep caste_religion female age_group nmx nmx_srs ex lx
	
	*merge ex se 
	merge 1:1 caste_religion female age_group using ///
	"$dir\04_input\resamples\bstraps\nfhs4\nfhs4_ex_se_group.dta", nogen

	gen ex_lci = ex - 1.96*se_ex
	gen ex_uci = ex + 1.96*se_ex
	
	*merge nmx se 
	merge 1:1 caste_religion female age_group using ///
	"$dir\04_input\resamples\bstraps\nfhs4\nfhs4_nmx_se_group.dta", nogen 

	gen nmx_lci = nmx - 1.96*se_nmx
	gen nmx_uci = nmx + 1.96*se_nmx
	
	*merge lx se 
	merge 1:1 caste_religion female age_group using ///
	"$dir\04_input\resamples\bstraps\nfhs4\nfhs4_lx_se_group.dta", nogen 

	gen lx_lci = lx - 1.96*se_lx
	gen lx_uci = lx + 1.96*se_lx

	
	
********************************************************
*save 
*******************************************************

	saveold "$dir/05_out/estimates/nfhs4_group_life_tables_se.dta", replace 
