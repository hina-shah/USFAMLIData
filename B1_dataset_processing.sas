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
create table &famli_table. as
    select *
    from &maintablename.
    where 
    (
        missing(alert) or 
        alert = 'age < 18 years' or
        alert = 'age < 18 years; non-singleton' or
        alert = 'non-singleton'
    ) and 
    lastsrofstudy=1 and 
    anybiometry=1
;

/* This will store instances of a structured report*/
proc sql noprint;
create table &famli_studies. as
    select distinct PatientID, studydttm, studydate, filename
    from &famli_table.;

* Extract studydates from the metadata tags;
proc sql;
create table outlib.instance_studydates as
select distinct PatientID, datepart(study_dttm) as studydate format mmddyy10.
from uslib.famli_b1_instancetable
UNION
select distinct PatientID, datepart(study_dttm) as studydate format mmddyy10.
from uslib.famli_b1b_instancetable
;
select 'Number of studies in B1, b1b', count(*) from outlib.instance_studydates;
select 'Number of patients above:', count(*) from (select distinct PatientID from outlib.instance_studydates);

* Get the structured report instances from the instance table;
* These will be used to be matched against B1 DICOM;
proc sql;
create table outlib.us_sr_studydates as
select file, PatientID, datepart(study_dttm) as studydate format mmddyy10. , study_dttm
from uslib.famli_b1_instancetable
where sr=1
UNION
select file, PatientID, datepart(study_dttm) as studydate format mmddyy10. , study_dttm
from uslib.famli_b1b_instancetable
where sr=1
;
select 'Number of SRs in B1 and B1b', count(*) from outlib.us_sr_studydates;

select  'Number of studies with the SRs of instance table:', count(*) from
(select distinct PatientID, studydate from outlib.us_sr_studydates);
select 'Number of Patients:', count(*) from (select distinct PatientID from outlib.us_sr_studydates);

data outlib.us_sr_studydates (drop=dcm_found);
set outlib.us_sr_studydates;
dcm_found = index(lowcase(file), '.dcm');

if dcm_found > 1 then file_sub = substr(file, 1, dcm_found-1);
else file_sub = file;
run;

proc sql;
create table dicom_sr_filenames as
select distinct filename from &famli_table.
;
select 'Number of last, with biometry SRs in the dicom dataset:', count(*) from dicom_sr_filenames	;

proc sql;
create table b1_patid_studydate as
select distinct a.filename, b.*
from
		&famli_studies. as a
		inner join
		outlib.us_sr_studydates as b
on
	a.filename = b.file_sub
;
select 'Number of files from DICOM dataset that were found in the instancetable, should be the same as above', count(*) from b1_patid_studydate;


proc sql;
create table studydate_files as
select distinct a.*, b.filename, b.study_dttm
from
	outlib.instance_studydates as a
	left join
	b1_patid_studydate as b
on
	a.PatientID = b.PatientID 
	and a.studydate = b.studydate
;
select 'Number of SR studies found in B1 dicom sr:', count(*) from studydate_files where not missing(filename);
select 'Date range for SR studies: ', min(studydate) format mmddyy10., max(studydate) format mmddyy10. from studydate_files where not missing(filename);
select 'Date range of NONSR studies:', min(studydate) format mmddyy10., max(studydate) format mmddyy10. from studydate_files where missing(filename);

proc sql;
	create table r4_table as
	select distinct medicalrecordnumber, put(input(medicalrecordnumber,12.),z12.)  as PatientID,
			EDD, NameofFile, egadays, ExamDate, studydate, NumberOfFetuses, 
			First_Trimester_CRL, 
			Second_Trimester_CRL,
			Second_Trimester_BPD,
			Second_Trimester_HC,
			Second_Trimester_AC,
			Second_Trimester_FL
	from &r4_table.
	where not missing(medicalrecordnumber)
;

proc sql;
select count(*) from r4_table where ExamDate lt '31Jan2012'd;;

data r4_table;
set r4_table;
varcount=cmiss(of First_Trimester_CRL--Second_Trimester_FL); /* This is primarily to ignore studies without biometry information*/
run;

/* Adjust patientID to be of length 12*/
data studydate_files (drop=len_pid);
set studydate_files;
len_pid = length(PatientID);
if len_pid > 12 then PatientID = substr(PatientID, len_pid-11, 12);
else if len_pid < 12 then PatientID = put(input(PatientID, 12.), z12.);
run;

proc sql;
create table studydate_files_r4 as
select distinct a.PatientID, a.studydate, a.study_dttm, coalesce(a.filename, b.NameOfFile) as filename
from
	studydate_files as a
	left join
	r4_table as b
on
	a.PatientID = b.PatientID and
	a.studydate = b.studydate and
/*	b.NumberOfFetuses = '1' and*/
	b.varcount < 6
;
select 'Number of studies after consolidating with R4:', count(*) from studydate_files_r4 where not missing(filename);
select 'Date range for studies with filenames: ', min(studydate) format mmddyy10., max(studydate) format mmddyy10. from studydate_files_r4 where not missing(filename);
select 'Date range studies without filenames', min(studydate) format mmddyy10., max(studydate) format mmddyy10. from studydate_files_r4 where missing(filename);

* Code to start removing duplicates ;
create table b1_patid_studydate_sorted as
select *, count(*) as num_studies_day
from studydate_files_r4
where not missing(study_dttm)
group by PatientID, studydate
;

proc sort data=b1_patid_studydate_sorted out=b1_patid_studydate_sorted ;
by descending study_dttm filename;
run;

proc sql;
create table dups_pre as 
select * from b1_patid_studydate_sorted
where num_studies_day>1;

* Deleting the ones that have a confusing studydttm, and we have >1 filenames for the same patientID but different studydttm;
* 
Removing these because we do not want to have confusing biometry measurements, and right now there's no good way of chosing
between these filenames
;
data outlib.b1_deleted_records(keep= filename);
set dups_pre;
by descending study_dttm filename;
if not (first.study_dttm and first.filename) then output;
run;

proc sql;
select 'Number of records to be deleted', count(*) from outlib.b1_deleted_records;

%if &USE_R4_STUDIES. = 1 %then %do;
	data &famli_studies._all (drop= study_dttm);
	set studydate_files_r4;
	/*set studydate_files;*/
	where not missing(filename);
	run;
%end;
%else %do;
	data &famli_studies._all (drop= study_dttm);
	set studydate_files;
	where not missing(filename);
	run;
%end;

data &famli_studies.;
set &famli_studies._all;
run;

proc sql;
delete * from &famli_studies. 
    where filename in 
        (
            select filename from outlib.b1_deleted_records
        )
;

delete * from &famli_table.
    where filename in 
    (
        select filename from outlib.b1_deleted_records
    )
;

proc sql;
select 'Number of studies finally at the end of data processing:', count(*) from &famli_studies.;
select 'Number of studies in famli table:', count(*) from (select distinct filename from &famli_table.);

/*
data &famli_studies.(drop= s studydttm);
    set &famli_studies.;
    s = substr(filename, 14,10);
    if prxmatch('/[0-9]{4}-[0-9]{2}-[0-9]{2}/',s) = 1 then
        studydate = input(s, yymmdd10.);
    else studydate = datepart(studydttm);

    format studydate mmddyy10.;
run;
*/
