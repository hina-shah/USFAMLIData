*libname famdat '/folders/myfolders/';

/* Create the subset from the dataset where
 we extract last sr for the day, have at least one biometry in the sr,
 and there is no alert (i.e. no non-fetal, test, multi-pregnancy ultrasounds)*/
/*
The 'alert' field will have either of the following notes:
'age < 18 years', 'age < 18 years; non-singleton', 'non-fetal ultrasound',
'non-singleton', 'non-singleton; non-fetal ultrasound', {none} - everything else */

proc sql noprint; 
create table famdat.famli_b1_subset as
select *
from famdat.&maintablename 
where (missing(alert) or alert = 'age < 18 years') and lastsrofstudy=1 and anybiometry=1;

%let famli_table = famdat.famli_b1_subset;

/* This will store instances of a structured report*/
proc sql noprint;
create table famdat.b1_patmrn_studytm
as
select distinct PatientID, studydttm, studydate, filename
	from &famli_table;
run;

/* This indicates the number of days that a patient visited for a study*/
proc sql noprint;
create table famdat.b1_patmrn_studydate
as 
select distinct PatientID, studydate
	from &famli_table;
run;

proc freq data=famdat.b1_patmrn_studytm order=freq noprint;
	tables PatientID / nocum nopercent out=famdat.b1_pat_freq_sorted;
run;


/* Lookup instances where there are more than one structured reports in the same day*/
/* Basically do a freq on pat_id and studydate*/
proc freq data=famdat.b1_patmrn_studytm noprint;
	tables PatientID*studydate / nocum nopercent out=sameday_freq_b1;
run;

proc sort data=sameday_freq_b1 out=famdat.b1_sameday_freq_sorted;
	by descending COUNT;
run;

proc delete data=sameday_freq_b1;
run;
