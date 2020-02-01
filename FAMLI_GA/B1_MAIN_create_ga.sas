/*************************************************************************

Program Name: Gathering gestational ages from various sources.
Author: Hina Shah

Purpose: Build a dataset with gestational age information.

Data Inputs: PNDB, Structure reports, EPIC, and R4 databases. 

EPIC library: This is the EPIC dataset which has data stored in various tables. THe
ones of importance are ob_dating, labs, medications, vitals, delivery, social_hx, diagnoses.

Outputs: A unified database file for all biometry measurements: B1_all_gas
******************************************************************************/

*libname famdat "\folders\myfolders";
*libname epic "\folders\myfolders\epic";

libname famdat  "F:\Users\hinashah\SASFiles";
libname epic "F:\Users\hinashah\SASFiles\epic";

**** Path where the sas programs reside in ********;
%let Path= F:\Users\hinashah\SASFiles\USFAMLIData\FAMLI_GA;

****** Names of the main tables to be used ********;
%let pndb_table = pndb_famli_records;
%let r4_table = unc_famli_r4data20190820;
%let famli_table = famdat.famli_b1_subset;
%let epic_ga_table = b1_ga_table_epic;
%let pndb_ga_table = b1_ga_table_pndb;
%let r4_ga_table = b1_ga_table_r4;
%let sr_ga_table = b1_ga_table_sr;
%let ga_final_table = b1_ga_table;

**** create GA tables from SR ********;
%include "&Path/B1_create_GA_tables_SR.sas";

**** create GA tables from R4 ********;
%include "&Path/B1_create_GA_tables_R4.sas";

**** create GA tables from Epic ********;
%include "&Path/B1_create_GA_tables_Epic.sas";

**** create GA tables from PNDB ********;
%include "&Path/B1_create_GA_tables_PNDB.sas";

**** combine all tables ********;
%include "&Path/B1_combine_GA_tables.sas";

*************** Adding labels to the data *******************;
proc sql;
	alter table famdat.&ga_final_table.
	modify filename label="Name of SR file",
			ga_edd label='Gestational ages from Estimated Due date',
			PatientID label='ID of Patientes',
			studydate label='Date of the study/us',
			episode_edd  label='Estimated Due Date',
			edd_source label='Source for EDD estimation'
			;
quit;

*************** Show contents *******************;
proc contents data=famdat.&ga_final_table. varnum;
run;

*********** Statistics on the complete table ****************;
title 'Statistics on gestational age from Structured reports and R4';
proc univariate data=famdat.&ga_final_table.;
var ga_edd;
run;

title "Minimum and Maximum Dates";
proc sql;
	select "studydate" label="Date variable", min(studydate)
		format=YYMMDD10. label="Minimum date" , max(studydate)
		format=YYMMDD10. label="Maximum date" from famdat.&ga_final_table.;
quit;
