
/*************************************************************************

Program Name: B1_MAIN
Author: Hina Shah

Purpose: Main script to generate Gestational Age, Biometry and Clinical info tables

Data Inputs: PNDB, Structure reports, EPIC, and R4 databases. 

Outputs: b1_ga_table - table with gestational ages,
	b1_biom - table with biometry measurements
	b1_maternal_info - tbale with maternal and birth clinical information.
******************************************************************************/



*libname famdat "\folders\myfolders";
*libname epic "\folders\myfolders\epic";

libname famdat  "F:\Users\hinashah\SASFiles";
libname epic "F:\Users\hinashah\SASFiles\epic";

**** Path where the sas programs reside in ********;
%let MainPath= F:\Users\hinashah\SASFiles\USFAMLIData;
%let maintablename = famli_b1_dicom_sr;

**** create subset ********;
%include "&MainPath/B1_dataset_processing.sas";

**** Create gestational ages ********;
%include "&MainPath/FAMLI_GA/B1_MAIN_create_ga.sas";

**** Create maternal information ********;
%include "&MainPath/FAMLI_Clinical/B1_MAIN_create_clinical.sas";

**** Create biometry table ********;
%include "&MainPath/FAMLI_Biom/B1_MAIN_create_biometry_tables.sas";

****** Create the large table ********;
proc sql;
create table full_join as
	select distinct a.*, b.* 
	from 
		famdat.b1_ga_table as a 
		left join
		famdat.b1_biom as b
	on
		a.PatientID = b.PatientID and
		a.studydate = b.studydate and
		a.filename = b.filename;

create table famdat.b1_full_table as
	select distinct a.*, b.* 
	from 
		full_join as a 
		left join
		famdat.b1_maternal_info as b
	on
		a.PatientID = b.PatientID and
		a.studydate = b.studydate and
		a.filename = b.filename;

