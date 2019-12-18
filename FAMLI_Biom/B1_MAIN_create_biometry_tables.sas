
/*************************************************************************

Program Name: Super Learner database creation
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

Outputs: A unified database file for all biometry measurements: B1_BIOMETRY
******************************************************************************/

libname famdat  "F:\Users\hinashah\SASFiles";

**** Path where the sas programs reside in ********;
%let Path= F:\Users\hinashah\SASFiles\USFAMLIData\FAMLI_Biom;
%let maintablename = famli_b1_dicom_sr;

**** create subset and some statistics ********;
%include "&Path/B1_dataset_processing.sas";

**** create biometry tables ********;
%include "&Path/B1_create_biometry_tables.sas";

**** create GA tables ********;
%include "&Path/B1_create_GA_tables.sas";

**** merge all the tables ********;
%include "&Path/B1_merge_tables.sas";
