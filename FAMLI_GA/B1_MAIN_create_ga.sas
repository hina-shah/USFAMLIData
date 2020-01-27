/*************************************************************************

Program Name: Gathering gestational ages from various sources.
Author: Hina Shah

Purpose: Build a dataset with gestational age information.

Data Inputs: PNDB, Structure reports, EPIC, and R4 databases. 

EPIC library: This is the EPIC dataset which has data stored in various tables. THe
ones of importance are ob_dating, labs, medications, vitals, delivery, social_hx, diagnoses.

Outputs: A unified database file for all biometry measurements: B1_all_gas
******************************************************************************/

libname famdat "\folders\myfolders";
libname epic "\folders\myfolders\epic";

*libname famdat  "F:\Users\hinashah\SASFiles";
*libname epic "F:\Users\hinashah\SASFiles\epic";

**** Path where the sas programs reside in ********;
%let Path= F:\Users\hinashah\SASFiles\USFAMLIData\FAMLI_GA;

****** Names of the main tables to be used ********;
%let pndb_table = pndb_famli_records;
%let r4_table = unc_famli_r4data20190820;
