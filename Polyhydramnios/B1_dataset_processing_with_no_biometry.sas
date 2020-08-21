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

proc sql;
select 'Initial number of studies' as title, count(*) as count 
from (select distinct filename from famdat.&maintablename );

select 'Initial number of patients' as title, count(*) as count
from (select distinct PatientID from famdat.&maintablename );


proc sql noprint; 
create table &famli_table. as
    select *
    from famdat.&maintablename 
    where 
    (
        missing(alert) or 
        alert = 'age < 18 years' or
        alert = 'age < 18 years; non-singleton' or
        alert = 'non-singleton'
    ) and 
    lastsrofstudy=1 
    /*and  anybiometry=1*/
;

proc sql;
select 'Number of studies in subset is: ', count(*) from
    (select distinct filename from &famli_table.);
select 'Number of patients in subset is: ', count(*) from
    (select distinct PatientID from &famli_table.);

/* This will store instances of a structured report*/
proc sql noprint;
create table &famli_studies. as
    select distinct PatientID, studydttm, studydate, filename
    from &famli_table.;

* Extract studydates from the metadata tags;
/*
proc sql;
create table b1_instance_srs as
select file, datepart(study_dttm) as studydate format mmddyy10. , study_dttm
from uslib.famli_b1_instancetable
where sr='True';

proc sql;
create table famdat.us_sr_studydates as
select * from b1_instance_srs
UNION
select file, datepart(study_dttm) as studydate format mmddyy10. , study_dttm
from uslib.famli_b1b_instancetable
where sr=1
UNION
select file, datepart(study_dttm) as studydate format mmddyy10. , study_dttm
from uslib.famli_b2_instancetable
where sr=1
UNION
select file, datepart(study_dttm) as studydate format mmddyy10. , study_dttm
from uslib.famli_b3prelim_instancetable
where sr=1
UNION
select file, datepart(study_dttm) as studydate format mmddyy10. , study_dttm
from uslib.famli_c1_instancetable
where sr=1
;

data famdat.us_sr_studydates (drop=dcm_found);
set famdat.us_sr_studydates;
dcm_found = index(lowcase(file), '.dcm');

if dcm_found > 1 then file_sub = substr(file, 1, dcm_found-1);
else file_sub = file;
run;
*/
proc sql;
create table b1_patid_studydate as
select distinct a.filename, a.PatientID, b.studydate, b.study_dttm
from
    &famli_studies. as a
    left join
    famdat.us_sr_studydates as b
on
    a.filename = b.file_sub
;

create table b1_patid_studydate_sorted as
select *, count(*) as num_studies_day
from b1_patid_studydate
group by PatientID, studydate
;

proc sort data=b1_patid_studydate_sorted out=b1_patid_studydate_sorted ;
by descending study_dttm filename;
run;

proc sql;
create table dups_pre as 
select * from b1_patid_studydate_sorted
where num_studies_day>1;

data famdat.b1_deleted_records(keep= filename);
set dups_pre;
by descending study_dttm filename;
if not (first.study_dttm and first.filename) then output;
run;

data &famli_studies. (drop=num_studies_day study_dttm);
set b1_patid_studydate_sorted;
run;

proc sql;
delete * from &famli_studies. 
    where filename in 
        (
            select filename from famdat.b1_deleted_records
        )
;

delete * from &famli_table.
    where filename in 
    (
        select filename from famdat.b1_deleted_records
    )
;

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