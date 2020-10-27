ods pdf file= "&ReportsOutputPath./polyhydramnios_analysis.pdf" startpage=NO;
title;
proc sql;
select 'Number of studies with Amniotic Fluid Index LEN q1 (Quadrant 1)' as title, count(*) as count
    from (select * from outlib.polyhydramnios_complete where not missing(afiq1_1));

select 'Number of studies with Amniotic Fluid Index LEN q2 (Quadrant 2)' as title, count(*) as count
    from (select * from outlib.polyhydramnios_complete where not missing(afiq2_1));

select 'Number of studies with Amniotic Fluid Index LEN q3 (Quadrant 3)' as title, count(*) as count
    from (select * from outlib.polyhydramnios_complete where not missing(afiq3_1));

select 'Number of studies with Amniotic Fluid Index LEN q4 (Quadrant 4)' as title, count(*) as count
    from (select * from outlib.polyhydramnios_complete where not missing(afiq4_1));

select 'Number of ALL patients:' as title, count(*) as count
    from (select distinct PatientID from &biom_final_output_table.);

select 'Number of patients with GA>=140:' as title, count(*) as count
    from (select distinct PatientID from &biom_final_output_table. where ga_edd>=140);
    
%macro createreports(tablename=, subsetstring=);

	proc sql;
	select 'Number of studies with an AFI' as title, "&subsetstring" as subsettype, count(*) as count
	    from (select * from &tablename. where not missing(AFI));
	select 'Number of patients with AFI calculated' as title, count(*) as count 
	     from (select distinct PatientID from &tablename. where not missing(AFI));

	select 'Total number of ultrasounds with AFI or calculated MVP present' as title, "&subsetstring" as subsettype, count(*) as count from
	    (select * from &tablename. where not missing(AFI) or not missing(CalcMVP));
	select 'Number of patients with AFI calculated' as title, count(*) as count 
	     from (select distinct PatientID from &tablename. where not missing(AFI) or not missing(CalcMVP));


	select "Number of cases when MVP = MAX(AFIQs) <= 2" as title, "&subsetstring" as subsettype, count(*) as count from
	    (select * from &tablename. where CalcMVP <= 2 and not missing(CalcMVP));
	select 'Number of Patients for Above:' as title, count(*) as count from
	    (select distinct PatientID from &tablename. where CalcMVP <= 2 and not missing(CalcMVP) );

	select 'Number of cases when MVP = MAX(AFIQs) >8' as title, "&subsetstring" as subsettype, count(*) as count from
	    (select * from &tablename. where CalcMVP >8 and not missing(CalcMVP));
	select 'Number of Patients for Above:' as title, count(*) as count from
	    (select distinct PatientID from &tablename. where CalcMVP >8 and not missing(CalcMVP) );

	select 'Number of cases when AFI <=5' as title, "&subsetstring" as subsettype, count(*) as count from
	    (select * from &tablename. where AFI <=5 and not missing(AFI));
	select 'Number of Patients for Above:' as title, count(*) as count from
	    (select distinct PatientID from &tablename. where AFI <= 5 and not missing(AFI));

	select 'Number of cases when AFI > 24' as title, "&subsetstring" as subsettype, count(*) as count from
	    (select * from &tablename. where AFI > 24 and not missing(AFI));
	select 'Number of Patients for Above:' as title, count(*) as count from
	    (select distinct PatientID from &tablename. where AFI > 24 and not missing(AFI) );

	select 'Number of cases when MVP = MAX(AFIQs)<=2, and AFI <=5 (and vice versa)' as title, "&subsetstring" as subsettype,
	    'AFI <= 5 and CalcMVP <=2' as condition, count(*) as count from 
	    (select * from &tablename. where AFI <= 5 and CalcMVP <=2 and not missing(AFI) and not missing(CalcMVP));
	select 'Number of Patients for Above:' as title, count(*) as count from
	    (select distinct PatientID from &tablename. where AFI <= 5 and CalcMVP <=2 and not missing(AFI) and not missing(CalcMVP) );

	select 'Number of cases when MVP = MAX(AFIQs) > 8, and AFI > 24 (and vice versa)' as title, "&subsetstring" as subsettype,
	    'AFI > 24 and CalcMVP > 8' as condition, count(*) as count from 
	    (select * from &tablename. where AFI > 24 and CalcMVP > 8 and not missing(AFI) and not missing(CalcMVP));
	select 'Number of Patients for Above:' as title, count(*) as count from
	    (select distinct PatientID from &tablename. where AFI > 24 and CalcMVP > 8 and not missing(AFI) and not missing(CalcMVP) );


	select 'Number of cases when MVP = MAX(AFIQs) < 8, and AFI >=24 (and vice versa)' as title, "&subsetstring" as subsettype,
	    'AFI >= 24 and CalcMVP < 8' as condition, count(*) as count from 
	    (select * from &tablename. where AFI >=24  and CalcMVP < 8 and not missing(AFI) and not missing(CalcMVP));
	select 'Number of Patients for Above:' as title, count(*) as count from
	    (select distinct PatientID from &tablename. where AFI >=24  and CalcMVP < 8 and not missing(AFI) and not missing(CalcMVP) );

	select 'Number of cases when MVP = MAX(AFIQs) >= 8, and AFI < 24 (and vice versa)' as title, "&subsetstring" as subsettype,
	    'AFI < 24 and CalcMVP >= 8' as condition, count(*) as count from 
	    (select * from &tablename. where AFI < 24 and CalcMVP >= 8 and not missing(AFI) and not missing(CalcMVP));
	select 'Number of Patients for Above:' as title, count(*) as count from
	    (select distinct PatientID from &tablename. where AFI < 24 and CalcMVP >= 8 and not missing(AFI) and not missing(CalcMVP) );

%mend;

*%createreports(tablename=famdat.polyhydramnios_with_afi_mvp, subsetstring=ALL);

  
%createreports(tablename=outlib.polyhydramnios_last_20_weeks, subsetstring= GA>=140);

%ds2csv(
    data=outlib.polyhydramnios_last_20_weeks,
    runmode=b,
    csvfile=&OutlibPath./polyhydramnios_last_20_weeks.csv   
);

title 'Scatter plot/regression for all AFI/MVP values with GA > 20 weeks';
/*--Set output size--*/
ods graphics / reset imagemap;

/*--SGPLOT proc statement--*/
proc sgplot data=OUTLIB.POLYHYDRAMNIOS_LAST_20_WEEKS;
    /*--Fit plot settings--*/
    reg x=CalcMVP y=AFI / nomarkers CLM CLI alpha=0.01 name='Regression' LINEATTRS=(color=red);

    /*--Scatter plot settings--*/
    scatter x=CalcMVP y=AFI / transparency=0.0 name='Scatter';

    /*--X Axis--*/
    xaxis grid;

    /*--Y Axis--*/
    yaxis grid;
run;

ods graphics / reset;

proc sql;
create table work.subset_small_values as
    select AFI, CalcMVP from outlib.polyhydramnios_last_20_weeks
    where AFI <= 5 and CalcMVP <=2 and not missing(AFI) and not missing(CalcMVP)
;

create table work.subset_large_values  as
    select AFI, CalcMVP from outlib.polyhydramnios_last_20_weeks
    where AFI > 24 and CalcMVP > 8 and not missing(AFI) and not missing(CalcMVP)
; 


title 'Analysis on AFI>24 and MVP >8';
proc means data=work.subset_large_values;
run;

ods noproctitle;
ods graphics / imagemap=on;
title;
proc corr data=WORK.SUBSET_LARGE_VALUES pearson nosimple noprob 
        plots=matrix(histogram);
run;

ods graphics on;
proc corr data=WORK.SUBSET_LARGE_VALUES
          plots=scatter nocorr nosimple;
   var AFI CalcMVP;
 run;
ods graphics off;


title 'Analysis on AFI<=5 and MVP <=2';

proc means data=work.subset_small_values;
run;

ods noproctitle;
ods graphics / imagemap=on;
title;
proc corr data=WORK.SUBSET_SMALL_VALUES pearson nosimple noprob 
        plots=matrix(histogram);
run;

ods graphics on;
proc corr data=WORK.SUBSET_SMALL_VALUES
          plots=scatter nocorr nosimple;
   var AFI CalcMVP;
 run;
ods graphics off;

%macro clinicalreport(table=, keepmax=, title=);
	title &title.;

	proc sql;
	create table s as
	select * from &table. where ga_edd >=140;

	select 'Number of cases: ', count(*) from s;
	select 'Number of patients: ', count(*) from (select distinct PatientID from s);
	select 'Number of pregnancies: ', count(*) from (select distinct PatientID, episode_edd from s);
	
	%if keepmax=1 %then %do;
		proc sql;
		create table sm as
		select *, max(AFI) as mafi from s
		group by PatientID, episode_edd;
	%end;
	%else %do;
		proc sql;
		create table sm as
		select *, min(AFI) as mafi from s
		group by PatientID, episode_edd;
	%end;
	
	data s;
	set sm;
	if AFI = mafi then output;
	run;

	title;
	proc sql;
	select 'Number of cases after choosing max/min AFI: ', count(*) from s;
	select 'Number of patients after choosing max/min AFI : ', count(*) from (select distinct PatientID from s);
	select 'Number of pregnancies after choosing max/min AFI: ', count(*) from (select distinct PatientID, episode_edd from s);
	

	proc freq data=s;
		tables delivery_method 
			living_status 
			baby_icu_yn 
			prem_rupture 
			congenital_anomalies 
			labor_induction 
			chronic_htn 
			preg_induced_htn
			diabetes
			gest_diabetes
			meconium
			post_partum_hemorrhage / missing
			;
	run;

%mend;

proc sql;
create table subset as 
select * from outlib.poly_with_afi_mvp_clinical where AFI > 24 and not missing(AFI);

%clinicalreport(table=subset, keepmax=1, title='AFI>24');

proc sql;
create table subset as 
select * from outlib.poly_with_afi_mvp_clinical where CalcMVP >8 and not missing(CalcMVP);

%clinicalreport(table=subset, keepmax=1, title='MVP>8');

proc sql;
create table subset as 
select * from outlib.poly_with_afi_mvp_clinical where AFI > 24 and CalcMVP > 8 and not missing(AFI) and not missing(CalcMVP);

%clinicalreport(table=subset, keepmax=1, title='AFI>24 and MVP>8');

proc sql;
create table subset as 
select * from outlib.poly_with_afi_mvp_clinical where AFI <= 5 and not missing(AFI);

%clinicalreport(table=subset, keepmax=0, title='AFI<=5');

proc sql;
create table subset as 
select * from outlib.poly_with_afi_mvp_clinical where CalcMVP <= 2 and not missing(CalcMVP);

%clinicalreport(table=subset, keepmax=0, title='MVP<=2');

proc sql;
create table subset as 
select * from outlib.poly_with_afi_mvp_clinical where AFI <= 5 and CalcMVP <=2 and not missing(AFI) and not missing(CalcMVP);

%clinicalreport(table=subset, keepmax=0, title='AFI<=5 and MVP<=2');

proc sql;
create table subset as 
select * from outlib.poly_with_afi_mvp_clinical where AFI >=24  and CalcMVP < 8 and not missing(AFI) and not missing(CalcMVP);

%clinicalreport(table=subset, keepmax=1, title='AFI>=24 and MVP<8');

proc sql;
create table subset as 
select * from outlib.poly_with_afi_mvp_clinical  where AFI < 24 and CalcMVP >= 8 and not missing(AFI) and not missing(CalcMVP);

%clinicalreport(table=subset, keepmax=1, title='AFI<24 and MVP>=8');


ods pdf close;
