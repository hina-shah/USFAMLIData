libname famdat '/folders/myfolders/';
libname epic '/folders/myfolders/epic';
%let missinggatable = b1_biom_missinggas;
%let othertable = ob_dating;


%macro estimateGAfromLMP(patid=, usdate=);
	proc sql;
		select min(usdiff) into :ga2 from
		(
		select user_entered_date, &usdate - user_entered_date as usdiff
		from work.epic_lmp 
		where pat_mrn_id EQ "&patid" 
		having usdiff GE 0 ); 
	quit;
	
	%put "&ga2";
	&ga2


/*	proc sql noprint;
		create table work._lmps_ as
		select min(usdiff) as ga from
		(
		select user_entered_date, &usdate - user_entered_date as usdiff
		from work.epic_lmp 
		where pat_mrn_id EQ "&patid" 
		having usdiff GE 0 ); 
*/	
	
%mend estimateGAfromLMP;

proc sql noprint;
	create table work.epic_lmp as select distinct pat_mrn_id, user_entered_date
		from epic.&othertable 
where ob_dating_event EQ 'LAST MENSTRUAL PERIOD' and user_entered_date NE .;

data work.ga_lmp;
	set famdat.&missinggatable(obs=25);
	* try estimate ga from lmp ;
	if not missing(PatientID) then
		do;
		call execute(catt('%estimateGAfromLMP(patid=', PatientID, ', usdate=', datepart(studydttm), ');'));
		put "&ga2";
		end;
run;

/*
proc sql;
create table commonids as
select distinct(a.PatientID)
from famdat.&missinggatable as a inner join  epic.&othertable as b
on a.PatientID = b.pat_mrn_id;

proc sql;
select * from epic.delivery
where missing(gestational_age);
*/