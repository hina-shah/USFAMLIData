
/*************************************************************************

Program Name: Super Learner maternal clinical database creation
Author: Hina Shah

Purpose: Build a database with maternal clinical information.

Data Inputs: PNDB dataset (this an excel sheet converted to a sas dataset after
changing all the NULL text to empy cell). This dataset contains around 34K births
and their related information.

EPIC library: This is the EPIC dataset which has data stored in various tables. THe
ones of importance are ob_dating, labs, medications, vitals, delivery, social_hx, diagnoses.
Outputs: A unified database file for all biometry measurements: B1_MATERNAL_INFO
******************************************************************************/

****** Call PNDB logic **************;
%include "&ClinicalPath/B1_get_pndb_mat_info.sas";

***** Call Epic logic ***************;
%include "&ClinicalPath/B1_get_epic_mat_info.sas";

***** Merge the tables into one ********;
* Find studies not populated by epic;
proc sql;
create table lo_studies as
    select filename
    from famdat.&ga_table. 
    where filename 
    not in
    (   
        select filename 
        from famdat.&mat_info_epic_table.
    )
;

*Try to fill them up with pndb;
proc sql;
create table pndb_leftovers as
    select * 
    from famdat.&mat_info_pndb_table.
    where filename in 
        (
            select filename 
            from lo_studies
        )
;

*Combine the tables;
proc sql;
create table famdat.&mat_final_output_table. as
    select * from pndb_leftovers
        OUTER UNION CORR
        select * from famdat.&mat_info_epic_table.;

data famdat.&mat_final_output_table.;
retain filename ga PatientID studydate DOC episode_working_edd ga_from_edd delivery_date
    mom_birth_date mom_age_edd mom_weight_oz mom_height_in
    birth_wt_gms birth_ga_days
    hiv tobacco_use tobacco_pak_per_day smoking_quit_days
    chronic_htn preg_induced_htn
    diabetes gest_diabetes;
set famdat.&mat_final_output_table.;
    ga_from_edd  = &ga_cycle. - (episode_working_edd - studydate);
    if mom_height_in < &min_height. or mom_height_in > &max_height. then mom_height_in = .;
    if mom_weight_oz < &min_weight.*16 or mom_weight_oz > &max_weight.*16 then mom_weight_oz = .;
run;

*************** Adding labels to the data *******************;
proc sql;
    alter table famdat.&mat_final_output_table.
    modify filename label="Name of SR file",
            ga label='Gestational ages from estimated EDD from various sources',
            PatientID label='ID of Patientes',
            studydate label='Date of the study/us',
            DOC label='Date of Conception (derived from episode working edd)',
            episode_working_edd label='Working EDD for pregnancy (derived when from PNDB)',
            ga_from_edd label='Gestational age based on working edd',
            mom_birth_date label='Mom birth date',
            mom_age_edd label='Age of mom at EDD',
            delivery_date label='Date of delivery',
            fetal_growth_restriction label='Fetal Growth Restriction Y/N',
            mom_weight_oz label='Weight of mom pre-pregnancy (oz)',
            mom_height_in label='Height of mom in (in)',
            birth_wt_gms label='Weight of baby at birth (gms)',
            birth_ga_days label='Gestational age at birth',
            hiv label='HIV (Y/N)',
            tobacco_use label='Tobacco use status',
            tobacco_pak_per_day label='Tobacco packs per day',
            chronic_htn label='Chronic hypertension (Y/N)',
            preg_induced_htn label='Pregnancy Induced Hypertension Y/N',
            diabetes label='Diabetes Y/N',
            gest_diabetes label='Gestational diabetes Y/N',
            smoking_quit_days label='Days since quit smoking';
quit;


ods pdf file="&ReportsOutputPath.\B1_Clinical_Details.pdf";

title 'Contents of Maternal Clinical information';
*************** Show contents *******************;
proc contents data=famdat.&mat_final_output_table. varnum;
run;

*********** Statistics on the complete table ****************;
title 'Statistics on gestational age from Structured reports and R4';
proc univariate data=famdat.&mat_final_output_table.;
var ga;
run;

title "Minimum and Maximum Dates";
proc sql;
    select "studydate" label="Date variable", min(studydate)
        format=YYMMDD10. label="Minimum date" , max(studydate)
        format=YYMMDD10. label="Maximum date" from famdat.&mat_final_output_table.;
quit;

title 'Frequencies on various clinical variables';
%macro runFreqOnFinalTable(title=,varname=);
    title "&title.";
    proc freq data=famdat.&mat_final_output_table.;
    TABLES &varname. / missing;
    run;
%mend;

data famdat.biomvar_details;
length title $ 100;
length varname $ 25;
infile datalines delimiter=',';
input tagname $ varname $;
call execute( catt('%runFreqOnFinalTable(title=', title, ', varname=', varname, ');'));
datalines;
Tobacco use, tobacco_use
HIV, hiv
Gestational Diabetes,gest_diabetes
Diabetes,diabetes
Chronic Hypertension,chronic_htn
Pregnancy Induced Hypertension,preg_induced_htn
Fetal Growth Restriction,fetal_growth_restriction
;
run;

ods pdf close;