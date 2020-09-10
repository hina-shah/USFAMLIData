/*************************************************************************

Program Name: Gathering gestational ages from various sources.
Author: Hina Shah

Purpose: Build a dataset with gestational age information.

Data Inputs: PNDB, Structure reports, EPIC, and R4 databases. 

EPIC library: This is the EPIC dataset which has data stored in various tables. THe
ones of importance are ob_dating, labs, medications, vitals, delivery, social_hx, diagnoses.

Outputs: A unified database file for all biometry measurements: B1_all_gas
******************************************************************************/

**** create GA tables from SR ********;
%include "&GAPath/B1_create_GA_tables_SR.sas";

**** create GA tables from R4 ********;
%include "&GAPath/B1_create_GA_tables_R4.sas";

**** create GA tables from Epic ********;
%include "&GAPath/B1_create_GA_tables_Epic.sas";

**** create GA tables from PNDB ********;
%include "&GAPath/B1_create_GA_tables_PNDB.sas";

**** combine all tables ********;
%include "&GAPath/B1_combine_GA_tables.sas";

*************** Adding labels to the data *******************;
proc sql;
    alter table &ga_final_table.
    modify filename label="Name of SR file",
            ga_edd label='Gestational ages from Estimated Due date',
            PatientID label='ID of Patientes',
            studydate label='Date of the study/us',
            episode_edd  label='Estimated Due Date',
            edd_source label='Source for EDD estimation'
            ;
quit;

***************** Create table for pregnancies ***************;
proc sql;
create table outlib.b1_pregnancies as
    select distinct PatientID, episode_edd, count(*) as us_counts label='Number of ultrasounds in that pregnancy' 
    from
    &ga_final_table.
    where not missing(episode_edd)
    group by PatientID, episode_edd
;

***************** Create missing ga table ********************;

proc sql;
create table outlib.b1_missing_ga_studies as
    select filename, PatientID, studydate
    from &famli_studies.
    where filename in
    (
        select filename 
        from &ga_final_table.
        where missing(episode_edd)
    );

***************** Create list of ultrasounds per pregnancy *********;
proc sort data= &ga_final_table. out=WORK.SORTTempTableSorted(keep=PatientID episode_edd studydate ga_edd);
 by PatientID episode_edd studydate;
run;

proc transpose data=WORK.SORTTempTableSorted prefix=us_date_
    out=work.b1_tempusdates(drop=_name_ _label_);
 var studydate;
 by PatientID episode_edd;
run;

proc transpose data=WORK.SORTTempTableSorted prefix=ga_
    out=work.b1_tempga(drop=_name_ _label_);
 var ga_edd;
 by PatientID episode_edd;
run;

data outlib.b1_pregnancies_with_us;
    merge work.b1_tempusdates work.b1_tempga;
    by PatientID episode_edd;
    where not missing(episode_edd);
run;

**** add LMPs ********;
%include "&GAPath/B1_add_LMP.sas";

****** Create report of data ********************;

ods pdf file= "&ReportsOutputPath.\B1_GA_Details.pdf";

*************** Show contents *******************;

title 'Content details for the GA table';
proc contents data=&ga_final_table. varnum;
run;

proc contents data=outlib.b1_pregnancies_with_us varnum;
run;

*********** Statistics on the first ultrasound gestational ages ****************;
title 'Statistics on the first ultrasound gestational ages';
proc means data=outlib.B1_PREGNANCIES_WITH_US n nmiss min mean median max std;
    var ga_1;
run;

proc univariate data=outlib.B1_PREGNANCIES_WITH_US noprint;
    histogram ga_1;
run;

*********** Statistics on the complete table ****************;
title 'Statistics on gestational age on all gestational ages';
proc univariate data=&ga_final_table.;
var ga_edd;
run;

proc univariate data=&ga_final_table. noprint;
    histogram ga_edd;
run;

title "Minimum and Maximum Dates for ultrasounds";
proc sql;
    select "studydate" label="Date variable", min(studydate)
        format=YYMMDD10. label="Minimum date" , max(studydate)
        format=YYMMDD10. label="Maximum date" from &ga_final_table.;
quit;

proc sql;
select 'Number of patinets:', count(*) from 
	(select distinct PatientID from &ga_final_table.);

ods pdf close;
