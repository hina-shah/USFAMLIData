
libname famdat "F:\Users\hinashah\SASFiles\B1Data";
title 'Number of studies with any data from epic';
proc sql;
select count(*) from &mat_info_epic_table.;

title 'Number of studies with known tobacco use';
proc sql;
select count(*) from 
	(
		select * 
		from famdat.b1_maternal_info_epic 
		where not missing(tobacco_use)
	);

title 'Number of studies with hiv';
proc sql;
select count(*) from 
	(
		select * 
		from famdat.b1_maternal_info_epic 
		where hiv eq 1
	);

title 'Number of studies with gestational diabetes';
proc sql;
select count(*) from 
	(
		select * 
		from famdat.b1_maternal_info_epic
		where gest_diabetes eq 1
	);

title 'Number of studies with diabetes';
proc sql;
select count(*) from 
	(
		select * 
		from famdat.b1_maternal_info_epic 
		where diabetes eq 1
	);

title 'Number of studies with chronic hypertension';
proc sql;
select count(*) from 
	(
		select * 
		from famdat.b1_maternal_info_epic 
		where chronic_htn eq 1
	);

title 'Number of studies with gest_htn';
proc sql;
select count(*) from 
	(
		select * 
		from famdat.b1_maternal_info_epic 
		where preg_induced_htn eq 1
	);

title 'Number of studies with fetal growth restriction';
proc sql;
select count(*) from 
	(
		select * from famdat.b1_maternal_info_epic 
		where fetal_growth_restriction eq 1
	);
