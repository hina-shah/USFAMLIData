
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

**** create biometry tables ********;
%include "&BiomPath/B1_create_biometry_tables.sas";

**** merge all the tables ********;
%include "&BiomPath/B1_merge_tables.sas";

*************** Adding labels to the data *******************;
proc sql;
    alter table famdat.&biom_final_output_table.
    modify filename label="Name of SR file",
            PatientID label='ID of Patientes', 
            studydate label='Date of the study/us',
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

data famdat.&biom_final_output_table.;
retain filename PatientID studydate
    fl_: ac_: bp_: hc_: tcd_: crl_: afiq1_: afiq2_: afiq3_: afiq4_: mvp_;
set famdat.&biom_final_output_table.;
run;

***************** Create a subset table with only first/last biometry values and their means *************;
%include "&BiomPath/B1_create_biom_subset.sas";

******************* Output the data ***************************;
ods pdf file= "&ReportsOutputPath.\B1_Biom_Details.pdf";

title 'Contents for the biometry table';

proc contents data=famdat.&biom_final_output_table. varnum;
run;

ods pdf close;