
/* Create raw gestational age values from structured reports */
%macro createGaTable(gatag=, gvarname=);
	proc sql noprint;
		create table outlib.&gvarname (drop=tagname) as 
		select filename, PID as PatientID, StudyID, 
				tagname, numericvalue as &gvarname.
			from &famli_table
			where(tagname = "&gatag");
	quit;

/*	data c1out.&gvarname (drop=ga);*/
/*	set work.&gvarname;*/
/*	ga = compress(ga, '','A');*/
/*	&gvarname = input(ga, 4.);*/
/*	run;*/

	run;
%mend createGaTable;

data outlib.gavar_details;
length tagname $ 40;
length varname $ 20;
infile datalines delimiter=','; 
input tagname $ varname $;
call execute( catt('%createGaTable(gatag=', tagname, ', gvarname=', varname, ');'));
datalines;
Gestational Age by EDD,ga_edd
Gestational Age by Conception Date,ga_doc
Gestational Age by LMP,ga_lmp
GAByLMP, ga_lmp_fam
;
run;

/* Combine everything together with the non-duplicate and 'corrected' study dates*/
proc sql;
create table all_together as
select * from
outlib.ga_edd OUTER UNION CORR
    (select * from outlib.ga_doc OUTER UNION CORR
        select * from outlib.ga_lmp OUTER UNION CORR
			select * from outlib.ga_lmp_fam);

proc sql;
create table &sr_ga_table. as
	select distinct a.PID as PatientID, a.StudyID, a.studydate,
		coalesce(b.ga_edd, b.ga_doc, b.ga_lmp, b.ga_lmp_fam) as ga_raw,
		case 
			when not missing(b.ga_edd) then 'Gestational Age by EDD'
			when not missing(b.ga_doc) then 'Gestational Age by DOC'
			when not missing(b.ga_lmp) then 'Gestational Age by LMP'
			when not missing(b.ga_lmp_fam) then 'Gestational Age by LMP FAM'
		end as ga_type
	from
		&c1_studies. as a 
		inner join
		all_together as b
	on
		a.StudyID = b.StudyID;

title "Counts of raw GAs extracted from SRs";
proc sql;
select '# of total studies: ', count(*) from &c1_studies.;
select '# of observations with raw GA from SR: ', count(*) from &sr_ga_table.;
select '# of studies (might include multiples) from SR: ', count(*) from (select distinct StudyID from &sr_ga_table.);

proc delete data=work.all_together;
	run;

/* Estimate EDDS */

* Group the data by PatientID and sort by studydate ;
proc sql;
create table _tmp_sorted_sr_gas as 
	select distinct * from &sr_ga_table. 
	order by PatientID, studydate;

* Get a list of GAs and Ultrasound dates per patient ,
	this will be created in two tables and then combined into one;

proc transpose data=_tmp_sorted_sr_gas prefix=us_date_ 
		out=work.tempusdates(drop=_name_);
	var studydate;
	by PatientID;
run;

proc sql noprint;
	select name into :us_date_names separated by ', ' 
	from dictionary.columns
	where libname = 'WORK' and memname='TEMPUSDATES' and name contains 'us_date_';

proc transpose data=_tmp_sorted_sr_gas prefix=us_ga_days_
		out=work.tempusga(drop=_name_);
	var ga_raw;
	by PatientID;
run;

proc sql noprint;
	select name into :us_ga_days_names separated by ', ' 
	from dictionary.columns
	where libname = 'WORK' and memname='TEMPUSGA' and name contains 'us_ga_days_';

* Combine the ultrasound dates and gestational ages into one table;
proc sql;
	create table sr_us_gas as 
	select coalesce(a.PatientID, b.PatientID) as PatientID,
		&us_date_names., &us_ga_days_names.
	from 
		work.tempusdates as a 
		full join 
		work.tempusga as b 
	on a.PatientID = b.PatientID;

proc delete data=work._tmp_sorted_sr_gas work.tempusdates work.tempusga;
	run;

* Estimate EDDs;

	*Extract max number of dates we have;
data _null_;
set sr_us_gas(obs=1);
    array usd us_date_:;
    call symput('n_dts',trim(left(put(dim(usd),8.))));
run;

data sr_us_gas_edds;
set sr_us_gas;
	array usd us_date_:;
	array gas us_ga_days_:;
	array edd(&n_dts.);
	format edd1-edd&n_dts. mmddyy10.;
	array js(&n_dts.);
	
	i=1;
	j=1;
	prev_ga = gas{i};
	prev_sd = usd{i};
	edd{j} = usd{i} - gas{i} + 280;
	js{i} = j;
	do i=2 to dim(usd);
		if missing(usd{i}) then leave; * NO more ultrasounds, leave;
		datediff = usd{i} - prev_sd;
		gadiff = gas{i} - prev_ga;
		
		* If in the same pregnancy, then difference between ga's and
		difference between dates would be roughly the same, if not exact.
		Allowing for an error of 21 days for both gestational age measurements;
		
		if abs(datediff - gadiff) >= 42 then do;
			j = j+1;
			edd{j} = usd{i} - gas{i} + 280;
		end;	
		prev_sd = usd{i};
		prev_ga = gas{i};
		js{i} = j;
	end;
run;

* Output the table with each study per row;
data &sr_ga_table._edds (keep=PatientID studydate ga edd edd_source) ;
set sr_us_gas_edds;
	array usd us_date_:;
	array gas us_ga_days_:;
	array edds edd:;
	array jind js:;
	do i=1 to dim(usd);
		if missing(usd{i}) then leave; * NO more ultrasounds, leave;
		studydate = usd{i};
		format studydate mmddyy10.;
		ga = gas{i};
		edd = edds{jind{i}};
		format edd mmddyy10.;
		edd_source = 'SR';
		output;
	end;
run;

proc sql;
select '# observations with EDDs: ', count(*) from &sr_ga_table._edds;

proc sql;
create table &sr_ga_table. as
select distinct a.*, b.ga, b.edd, b.edd_source
from
	&sr_ga_table. as a
	left join
	&sr_ga_table._edds as b
on
	a.PatientID = b.PatientID and a.studydate = b.studydate;

/* Remove duplicates */
proc sql;
select '# of observations in ga table: ', count(*) from &sr_ga_table.;
select '# of studies in ga table: ', count(*) from (select distinct StudyID from &sr_ga_table.);

create table counts as 
select *, count(*) as count from &sr_ga_table. group by StudyID;

delete * from &sr_ga_table. where StudyID in (select StudyID from counts where count > 1);

select '# of observations in ga table: ', count(*) from &sr_ga_table.;
select '# of studies in ga table: ', count(*) from (select distinct StudyID from &sr_ga_table.);

delete * from &c1_studies. where StudyID in (select StudyID from counts where count > 1);



proc delete data=work.sr_us_gas work.sr_us_gas_edds work.counts;
	run;

