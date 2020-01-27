*libname famdat '/folders/myfolders/';

/* Create the subset from the dataset where
 we extract last sr for the day, have at least one biometry in the sr,
 and there is no alert (i.e. no non-fetal, test, multi-pregnancy ultrasounds)
 */

/*
The 'alert' field will have either of the following notes:
'age < 18 years', 'age < 18 years; non-singleton', 'non-fetal ultrasound',
'non-singleton', 'non-singleton; non-fetal ultrasound', {none} - everything else 
*/

proc sql noprint; 
create table famdat.famli_b1_subset as
	select *
	from famdat.&maintablename 
	where 
	(
		missing(alert) or 
		alert = 'age < 18 years'
	) and 
	lastsrofstudy=1 and 
	anybiometry=1;

%let famli_table = famdat.famli_b1_subset;

/* This will store instances of a structured report*/
proc sql noprint;
create table famdat.b1_patmrn_studytm as
	select distinct PatientID, studydttm, studydate, filename
	from &famli_table;

*Trying to remove duplicates using ids;
create table dups as
	select distinct ids, count_ids 
	from 
	(
		select substr(filename, 1,23) as ids, count( substr(filename, 1,23)) as count_ids
		from famdat.b1_patmrn_studytm
		group by substr(filename, 1,23) 
	) 
	where
		count_ids > 1 and 
		count_ids < 100 
	order by count_ids desc;

create table famdat.b1_deleted_records as
	select * from famdat.b1_patmrn_studytm 
	where substr(filename, 1,23) in 
		(
			select ids from dups
		);

delete * from famdat.b1_biom 
	where substr(filename, 1,23) in 
		(
			select ids from dups
		);


data famdat.b1_patmrn_studytm(drop= s studydttm);
	set famdat.b1_patmrn_studytm;
	s = substr(filename, 14,10);
	if prxmatch('/[0-9]{4}-[0-9]{2}-[0-9]{2}/',s) = 1 then
		studydate = input(s, yymmdd10.);
	else studydate = datepart(studydttm);

	format studydate mmddyy10.;
run;
