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

* Including the on-singletons here since they will be removed at the end of ga calculation;
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
    lastsrofstudy=1 /*and 
    anybiometry=1 */
;

/* This will store instances of a structured report*/
proc sql noprint;
create table &famli_studies. as
    select distinct PatientID, studydttm, studydate, filename
    from &famli_table.;

*Trying to remove duplicates using ids;
create table dups as
    select distinct ids, count_ids 
    from 
    (
        select substr(filename, 1,23) as ids, count( substr(filename, 1,23)) as count_ids
        from &famli_studies
        group by substr(filename, 1,23) 
    ) 
    where
        count_ids > 1 and 
        count_ids < 100 /* Other format files, ex Src* */
    order by count_ids desc;

create table famdat.b1_deleted_records as
    select * from &famli_studies 
    where substr(filename, 1,23) in 
        (
            select ids from dups
        );

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


data &famli_studies.(drop= s studydttm);
    set &famli_studies.;
    s = substr(filename, 14,10);
    if prxmatch('/[0-9]{4}-[0-9]{2}-[0-9]{2}/',s) = 1 then
        studydate = input(s, yymmdd10.);
    else studydate = datepart(studydttm);

    format studydate mmddyy10.;
run;
