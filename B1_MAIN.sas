
/*************************************************************************

Program Name: B1_MAIN
Author: Hina Shah

Purpose: Main script to generate Gestational Age, Biometry and Clinical info tables

Data Inputs: PNDB, Structure reports, EPIC, and R4 databases. 

Outputs: b1_ga_table - table with gestational ages,
    b1_biom - table with biometry measurements
    b1_maternal_info - tbale with maternal and birth clinical information.
    other tables generated by the scripts
******************************************************************************/



*libname famdat "\folders\myfolders";
*libname epic "\folders\myfolders\epic";

%let ServerPath = H:\Users\hinashah\SASFiles;

libname famdat  "&ServerPath.\InputData";
libname epic "&ServerPath.\InputData\epic720";
libname uslib "&ServerPath.\InputData\Ultrasound";
libname outlib "&ServerPath.\B1Data928";

**** USE R4 TO INCLUDE STUDIES PRIO TO 2012? ****;
%let USE_R4_STUDIES = 1;
%let ONLY_BIOMETRY = 1;

**** Path where the sas programs reside in ********;
%let MainPath= &ServerPath.\USFAMLIData;
%let ReportsOutputPath = &ServerPath.\Reports;

*************** INPUT Datasets ********************;
%let maintablename = famdat.famli_b1_dicom_sr; /* This is the original SR generated table. Copied.*/
%let pndb_table = famdat.pndb_famli_records_with_matches; /*This has all the data from PNDB*/
%let r4_table = famdat.unc_famli_r4data20190820;

************** OVERALL output tables ***************;
%let famli_table = outlib.famli_b1_subset;
%let famli_studies = outlib.b1_patmrn_studytm;

* ********************** GA variables *************;
**** Path where the ga sas programs reside in ********;
%let GAPath= &MainPath.\FAMLI_GA;

****** Names of the main tables to be used ********;
%let epic_ga_table = outlib.b1_ga_table_epic;
%let pndb_ga_table = outlib.b1_ga_table_pndb;
%let r4_ga_table = outlib.b1_ga_table_r4;
%let sr_ga_table = outlib.b1_ga_table_sr;
%let ga_final_table = outlib.b1_ga_table;

* ********************** Clinical variables **********;
**** Path where the clinical sas programs reside in ********;
%let ClinicalPath= &MainPath.\FAMLI_Clinical;

****** Names of the main tables to be used ********;
%let ga_table = outlib.b1_ga_table;

****** Names of output tables to be generated *****;
%let mat_info_pndb_table = outlib.b1_maternal_info_pndb;
%let mat_info_epic_table = outlib.b1_maternal_info_epic;
%let mat_final_output_table = outlib.b1_maternal_info;

******* Define global values *******;
%let max_ga_cycle = 308;
%let ga_cycle = 280;
%let min_height = 40;
%let max_height = 90;
%let min_weight = 90; /* in lbs */
%let max_weight = 400; /* in lbs */

* ********************** Biometry variables *********;
**** Path where the biom sas programs reside in ********;
%let BiomPath= &MainPath.\FAMLI_Biom;
%let biom_final_output_table = outlib.b1_biom;
%let biom_subset_measures = outlib.b1_biom_subset_measures;

**** create subset ********;
%include "&MainPath/B1_dataset_processing.sas";

**** Create gestational ages ********;
%include "&MainPath/FAMLI_GA/B1_MAIN_create_goa.sas";

**** Create maternal information ********;
%include "&MainPath/FAMLI_Clinical/B1_MAIN_create_clinical.sas";

**** Create biometry table ********;
%include "&MainPath/FAMLI_Biom/B1_MAIN_create_biometry_tables.sas";

****** Create the large table ********;
proc sql;
create table full_join as
    select distinct a.*, b.* 
    from 
        outlib.b1_ga_table as a 
        left join
        outlib.b1_biom as b
    on
        a.PatientID = b.PatientID and
        a.studydate = b.studydate and
        a.filename = b.filename;

create table outlib.b1_full_table as
    select distinct a.*, b.* 
    from 
        full_join as a 
        left join
        outlib.b1_maternal_info as b
    on
        a.PatientID = b.PatientID and
        a.studydate = b.studydate and
        a.filename = b.filename;

data outlib.b1_full_table;
set outlib.b1_full_table(drop= episode_working_edd ga_from_edd);
run;

proc delete data = full_join;
run;

* Create the table that has ultrasounds for UNC-delivered pregnancies and had antenatal care;


proc sql;
select "Number of pregnancies overall:", count(*) from (select distinct PatientID, episode_edd from outlib.b1_full_table where not missing(episode_edd));
select "Number of pregnancies PNDB:", count(*) from (select distinct PatientID, episode_edd from outlib.b1_full_table where edd_source="PNDB" and not missing(episdoe_edd));


proc sql;
create table outlib.b1_studies_with_del as
select * from outlib.b1_full_table
where not missing(delivery_date);

select 'Number of studies with delivery data available: ', count(*) from outlib.b1_studies_with_del;
select 'Number of pregnancies:', count(*) from  (select distinct PatientID, episode_edd from outlib.b1_studies_with_del where not missing(episode_edd));


proc sql;
create table delivery_encounters as
select distinct a.filename, a.PatientID, a.delivery_date, 
                a.DOC,
                b.pat_enc_csn_id
from
    outlib.b1_full_table as a
    inner join
    epic.medications as b
on
    a.PatientID  = b.pat_mrn_id
    and datepart(b.order_inst) >= a.delivery_date 
    and datepart(b.order_inst) <= a.delivery_date + 1
    and b.med_type = 'INPATIENT MEDICATION'
;

create table rpr_matches as
select distinct a.filename, a.PatientID, a.delivery_date
from 
    delivery_encounters as a
    inner join
    epic.labs as b
on
    a.PatientID = b.pat_mrn_id
    and b.pat_enc_csn_id not in (select distinct pat_enc_csn_id from delivery_encounters)
    and prxmatch('/^(RPR|RPR Titer)/', b.lab_name) > 0
    and datepart(b.result_time) <= a.delivery_date
    and datepart(b.result_time) >= a.DOC
;

proc sql;
create table outlib.b1_selected_studies
as select * from outlib.b1_full_table where filename in (select filename from rpr_matches)
or edd_source='PNDB';
;

select 'The number of studies selected', count(*) from outlib.b1_selected_studies;
select 'PNDB studies out of these:', count(*) from outlib.b1_selected_studies where edd_source='PNDB';
select 'Number of pregnancies above:', count(*) from (select distinct PatientID, episode_edd from outlib.b1_selected_studies where not missing(episode_edd));
select 'Number of PNDB pregnancies above:', count(*) from (select distinct PatientID, episode_edd from outlib.b1_selected_studies where edd_source='PNDB' and not missing(episode_edd));

proc sql;
select 'Number of patients', count(*) from (select distinct PatientID from outlib.b1_full_table);
