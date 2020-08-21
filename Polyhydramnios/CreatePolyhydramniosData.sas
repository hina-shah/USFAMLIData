
libname famdat  "F:\Users\hinashah\SASFiles";
libname epic "F:\Users\hinashah\SASFiles\epic720";
libname uslib 'F:\Groups\Restricted_access_data\Ultrasound\';
libname polylib 'F:\Users\hinashah\SASFiles\Polyhydramnios';

**** Path where the sas programs reside in ********;
%let HomePath = F:\Users\hinashah\SASFiles;
%let MainPath= &HomePath.\USFAMLIData;
%let ReportsOutputPath = &HomePath.\Polyhydramnios;
%let maintablename = famli_b1_dicom_sr; /* This is the original SR generated table. Copied.*/
%let pndb_table = pndb_famli_records_with_matches;
%let r4_table = unc_famli_r4data20190820;

************** OVERALL output tables ***************;
%let famli_table = famdat.famli_b1_subset;
%let famli_studies = famdat.b1_patmrn_studytm;

* ********************** GA variables *************;
**** Path where the ga sas programs reside in ********;
%let GAPath= &MainPath.\FAMLI_GA;

****** Names of the main tables to be used ********;
%let epic_ga_table = poly_b1_ga_table_epic;
%let pndb_ga_table = poly_b1_ga_table_pndb;
%let r4_ga_table = poly_b1_ga_table_r4;
%let sr_ga_table = poly_b1_ga_table_sr;
%let ga_final_table = poly_b1_ga_table;

******* Define global values *******;
%let max_ga_cycle = 308;
%let ga_cycle = 280;

* ********************** Biometry variables *********;
**** Path where the biom sas programs reside in ********;
%let BiomPath= &MainPath.\FAMLI_Biom;
%let biom_final_output_table = b1_biom_all;
%let biom_subset_measures = b1_biom_subset_measures;

* ********************** Clinical variables *********;
**** Path where the clinical sas programs reside in ********;
%let ClinicalPath= &MainPath.\FAMLI_Clinical;

****** Names of the main tables to be used ********;
%let ga_table = poly_b1_ga_table;

****** Names of output tables to be generated *****;
%let mat_info_pndb_table = poly_b1_maternal_info_pndb;
%let mat_info_epic_table = poly_b1_maternal_info_epic;
%let mat_final_output_table = poly_b1_maternal_info;

******* Define global values *******;
%let max_ga_cycle = 308;
%let ga_cycle = 280;
%let min_height = 40;
%let max_height = 90;
%let min_weight = 90; /* in lbs */
%let max_weight = 400; /* in lbs */

**** create subset ********;
%include "&MainPath/Polyhydramnios/B1_dataset_processing_with_no_biometry.sas";

**** Create gestational ages ********;
%include "&MainPath/FAMLI_GA/B1_MAIN_create_ga.sas";

**** Create biometry table ********;
%include "&MainPath/FAMLI_Biom/B1_MAIN_create_biometry_tables.sas";

**** Create maternal information ********;
%include "&MainPath/FAMLI_Clinical/B1_MAIN_create_clinical.sas";


%macro createEFTable(biometry=, biomvname=, shortname=);
    * read the biometry tags;
    proc sql;
    create table temp_&biomvname (drop=Derivation Equation) as
        select filename, PatientID, studydttm, tagname, tagcontent, numericvalue, Derivation, Equation
        from &famli_table
        where 
            missing(Derivation) and 
            tagname = "&biometry"
    ;
    
    * Remove duplicate tag contents;
    create table WORK.temp_&biomvname._unique as
    select numericvalue, filename, PatientID, studydttm
    from temp_&biomvname
    group by filename
    order by filename;

    * delete not needed tables;
    proc delete data=temp_&biomvname;
    run;

    * Create columns for each biometry measurement;
    proc sort data= WORK.temp_&biomvname._unique out=WORK.SORTTempTableSorted;
        by PatientID studydttm filename;
    run;

    proc transpose data=WORK.SORTTempTableSorted prefix=&shortname
            out=WORK.&biomvname(drop=_Name_);
        var numericvalue;
        by PatientID studydttm filename;
    run;

    * Convert data to numerical values, and convert mms to cms;
    data famdat.&biomvname;
    set work.&biomvname;
    run;

    proc delete data=WORK.SORTTempTableSorted WORK.&biomvname WORK.temp_&biomvname._unique;
    run;

%mend;

%macro createColNamesMacro(macroname=, varname=);
    proc sql noprint;
    select name into :&macroname separated by ', '  
       from dictionary.columns
         where libname='FAMDAT' and memname='B1_BIOM_ALL' and name contains "&varname";
    quit;
%mend;

data colvardetails;
length macroname $ 10;
length varname $ 10;
infile datalines delimiter=',';
input macroname $ varname $;
call execute( catt('%createColNamesMacro(macroname=', macroname, ', varname=', varname, ');'));
datalines;
mvps,mvp_
afiq1s,afiq1_
afiq2s,afiq2_
afiq3s,afiq3_
afiq4s,afiq4_
;
run;

proc sql;
create table famdat.polyhydramnios_complete as
select filename, PatientID, studydate, ga_edd, &mvps, &afiq1s, &afiq2s, &afiq3s, &afiq4s
from famdat.b1_biom_all
where (not missing(mvp_1) or  (not missing(afiq1_1) or not missing(afiq2_1) or not missing(afiq3_1) or not missing(afiq4_1)))
;
quit;

proc datasets lib=famdat memtype=data nolist;
   modify polyhydramnios_complete;
     attrib _all_ label=' ';
run;

%createEFTable(biometry=Estimated Weight, biomvname=est_fet_wt, shortname=efw_);

proc sql noprint;
create table famdat.polyhydramnios_with_afi_mvp as 
select a.*, b.efw_1 from
famdat.polyhydramnios_complete as a left join famdat.est_fet_wt as b
on
a.filename=b.filename and a.PatientID= b.PatientID;

data famdat.polyhydramnios_with_afi_mvp;
set famdat.polyhydramnios_with_afi_mvp;
label CalcMVP='Calculated MVP';
label AFI='Amniotic Fluid Index sum';
label maxafiq1='MaxAFIQuad1';
label maxafiq2='MaxAFIQuad2';
label maxafiq3='MaxAFIQuad3';
label maxafiq4='MaxAFIQuad4';

maxafiq1 = max(&afiq1s);
maxafiq2 = max(&afiq2s);
maxafiq3 = max(&afiq3s);
maxafiq4 = max(&afiq4s);

CalcMVP = max(maxafiq1, maxafiq2, maxafiq3, maxafiq4);
AFI = maxafiq1+maxafiq2+maxafiq3+maxafiq4;
run;

%ds2csv(
    data=famdat.polyhydramnios_with_afi_mvp,
    runmode=b,
    csvfile=F:/Users/hinashah/SASFiles/polyhydramnios_all.csv   
);

%include "&MainPath/Polyhydramnios/AddClinicalInformation.sas";

data famdat.poly_with_afi_mvp_clinical;
set famdat.poly_with_afi_mvp_clinical;
label ga_edd='Clinician approved GA';
label delivery_methdo='Delivery method';
label delivery_blood_loss='Blood Loss at Delivery';
label cord_prolapse='Cord Prolaps Y/N';
label delivery_resusitation='Delivery resusitation method';
label living_status='Living Status';
label baby_icu_yn='Baby ICU admission Y/N';
label prem_rupture='Premature rupture Y/N';
label congenital_anomalies='Congenital Anomalies Y/N';
label meconium='Meconium Y/N';
label labor_induction='Labor Induction Y/N';
run;

%ds2csv(
    data=famdat.poly_with_afi_mvp_clinical,
    runmode=b,
    csvfile=F:/Users/hinashah/SASFiles/polyhydramnios_all_clinical.csv   
);

%include "&MainPath/Polyhydramnios/Polyhydramnios_Analysis.sas";

