
/*************************************************************************

Program Name: Super Learner maternal clinical database creation
Author: Hina Shah

Purpose: Build a database with maternal clinical information.

Data Inputs: PNDB dataset (this an excel sheet converted to a sas dataset after
changing all the NULL text to empy cell). This dataset contains around 34K births
and their related information.

EPIC library: This is the EPIC dataset which has data stored in various tables. THe
ones of importance are ob_dating, labs, medications, vitals, delivery, social_hx, diagnoses.
Outputs: A unified database file for all biometry measurements: B1_MATERNAL_INFP
******************************************************************************/


libname famdat  "F:\Users\hinashah\SASFiles";
libname epic "F:\Users\hinashah\SASFiles\epic";

**** Path where the sas programs reside in ********;
%let Path= F:\Users\hinashah\SASFiles\USFAMLIData\FAMLI_Clinical;

****** Names of the main tables to be used ********;
%let b1_biom_table = b1_biom;
%let pndb_table = pndb_famli_records; 

****** Names of output tables to be generated *****;
%let mat_info_pndb_table = b1_maternal_info_pndb;
%let mat_info_epic_table = b1_maternal_info_epic;
%let final_output_table = b1_maternal_info;

****** Call PNDB logic **************;
%include "&Path/B1_get_pndb_mat_info.sas";

***** Call Epic logic ***************;
%include "&Path/B1_get_epic_mat_info.sas";

***** Merge the tables into one ********;

proc sql;
	create table famdat.&final_output_table. as 
	select * from famdat.&mat_info_pndb_table. 
		OUTER UNION CORR 
		select * from famdat.&mat_info_epic_table.;

*********** Statistics on the complete table ****************;
title 'Statistics on gestational age from Structured reports and R4';
proc univariate data=famdat.&final_output_table.;
var ga;
run;

title "Minimum and Maximum Dates";
proc sql; 
	create table studydates as 
	select datepart(studydttm) as studydate format mmddyy10. 
	from famdat.&final_output_table.;

proc sql;
	select "studydate" label="Date variable", min(studydate) 
		format=YYMMDD10. label="Minimum date" , max(studydate) 
		format=YYMMDD10. label="Maximum date" from FAMDAT.FAMLI_B1_SUBSET;
quit;

%macro runFreqOnFinalTable(title=,varname=);
	title "&title.";
	proc freq data=famdat.&final_output_table.;
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
