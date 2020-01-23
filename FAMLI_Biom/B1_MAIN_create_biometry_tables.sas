
/*************************************************************************

Program Name: Super Learner fetal biometry database creation
Author: Hina Shah

Purpose: Build a database with fetal biometry and gestational ages from 
the databse of Structured reports.

Data Inputs: SR dataset from B1 (for the time being) that contains at least
the following columns => 
Filename - name of the structured report
PatientID - ID of the patient
studydttm - time stamp for the structured report file
studydate - date the study was done
alert - explained in B1_dataset_processing
lastsrofstudy - set to 1 if this is the last SR for that study
anybiometry - set to 1 if the SR contains at least one biometry group
tagname - name of the tags in SR
tagcontent - content of the tags
Derivation - indicates if tagcontent is a measurement or derived value
Equation - indicates the equation used to generate the derivation

Outputs: A unified database file for all biometry measurements: B1_BIOM
******************************************************************************/

libname famdat  "F:\Users\hinashah\SASFiles";

**** Path where the sas programs reside in ********;
%let Path= F:\Users\hinashah\SASFiles\USFAMLIData\FAMLI_Biom;
%let maintablename = famli_b1_dicom_sr;
%let r4_table = unc_famli_r4data20190820;

**** create subset and some statistics ********;
%include "&Path/B1_dataset_processing.sas";

**** create biometry tables ********;
%include "&Path/B1_create_biometry_tables.sas";

**** create GA tables ********;
%include "&Path/B1_create_GA_tables.sas";

**** merge all the tables ********;
%include "&Path/B1_merge_tables.sas";

**** fill any missing GAs using R4 database ********;
%include "&Path/B1_missing_ga_fill.sas";

**** create pregnancies table and extrapolate more gas ********;
%include "&Path/B1_create_pregnancies.sas";

*************** Adding labels to the data *******************;
proc sql;
	alter table famdat.b1_biom
	modify filename label="Name of SR file",
			PatientID label='ID of Patientes', 
			studydate label='Date of the study/us',
			ga_edd label='GA based on EDD from SR (ultrasound)',
			ga_doc label = 'GA based on DOC from SR (ivf)',
			ga_lmp label = 'GA based on LMP from SR',
			ga_unknown label = 'GA from the R4 database', 
			ga_extrap label = 'GA extrapolated from any of the other values',
			fl_1 label = 'Femur lengths',
			ac_1 label = 'Abdominal Circumferences',
			bp_1 label = 'Biparietal Diameter',
			afiq1_1 label = 'Amniotic Fluid Index (Quarter 1)',
			afiq2_1 label = 'Amniotic Fluid Index (Quarter 2)',
			afiq3_1 label = 'Amniotic Fluid Index (Quarter 3)',
			afiq4_1 label = 'Amniotic Fluid Index (Quarter 4)',
			crl_1 label = 'Crown Rump Length',
			hc_1 label = 'Head Circumference',
			mvp_1 label = 'Max Vertical Pocket',
			tcd_1 label = 'Trans Cerebellar Diameter'
			;
quit;

proc contents data=famdat.b1_biom varnum;
run;
