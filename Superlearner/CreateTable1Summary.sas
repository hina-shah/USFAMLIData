* Create statistics table;

libname sldat '/folders/myfolders/SLData';

%let full_table = sldat.sl_table1_all;
%let subset_table = sldat.sl_finalrandselecttable1_subset;

%macro createTableStatistic(tablename=);
	*proc univariate data= &tablename. notabcontents  ;
	*	variables fl_1 hc_1 bp_1 ac_1 mom_weight_oz mom_height_in mom_age_edd;
		
	proc means data=&tablename. median q1 q3;
	    vars fl_1 hc_1 bp_1 ac_1 mom_weight_lb mom_height_in mom_age_edd; 
	run;
	
	proc freq data=&tablename.;
		tables hiv gest_diabetes preg_induced_htn 
				diabetes chronic_htn former_smoker current_smoker / missing;
	run;
	
	*proc freq data=&tablename.;
	*	tables tobacco_use /missing;
	*run;
	
%mend;

%createTableStatistic(tablename=&subset_table.);


%createTableStatistic(tablename=&full_table.);


