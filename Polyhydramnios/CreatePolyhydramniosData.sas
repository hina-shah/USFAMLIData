
libname famdat  "F:\Users\hinashah\SASFiles";
libname epic "F:\Users\hinashah\SASFiles\epic";

**** Path where the sas programs reside in ********;
%let MainPath= F:\Users\hinashah\SASFiles\USFAMLIData;
%let ReportsOutputPath = F:\Users\hinashah\SASFiles\PolyhydramniosReports;
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
%let epic_ga_table = b1_ga_table_epic;
%let pndb_ga_table = b1_ga_table_pndb;
%let r4_ga_table = b1_ga_table_r4;
%let sr_ga_table = b1_ga_table_sr;
%let ga_final_table = b1_ga_table;

******* Define global values *******;
%let max_ga_cycle = 308;
%let ga_cycle = 280;

* ********************** Biometry variables *********;
**** Path where the biom sas programs reside in ********;
%let BiomPath= &MainPath.\FAMLI_Biom;
%let biom_final_output_table = b1_biom_all;
%let biom_subset_measures = b1_biom_subset_measures;

**** create subset ********;
%include "&MainPath/Polyhydramnios/B1_dataset_processing_with_no_biometry.sas";

**** Create gestational ages ********;
%include "&MainPath/FAMLI_GA/B1_MAIN_create_ga.sas";

**** Create biometry table ********;
%include "&MainPath/FAMLI_Biom/B1_MAIN_create_biometry_tables.sas";


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

ods pdf file='F:/Users/hinashah/SASFiles/polyhydramnios_analysis.pdf' startpage=NO;
title;
proc sql;
select 'Number of studies with Amniotic Fluid Index LEN q1 (Quadrant 1)' as title, count(*) as count
    from (select * from famdat.polyhydramnios_complete where not missing(afiq1_1));

select 'Number of studies with Amniotic Fluid Index LEN q2 (Quadrant 2)' as title, count(*) as count
    from (select * from famdat.polyhydramnios_complete where not missing(afiq2_1));

select 'Number of studies with Amniotic Fluid Index LEN q3 (Quadrant 3)' as title, count(*) as count
    from (select * from famdat.polyhydramnios_complete where not missing(afiq3_1));

select 'Number of studies with Amniotic Fluid Index LEN q4 (Quadrant 4)' as title, count(*) as count
    from (select * from famdat.polyhydramnios_complete where not missing(afiq4_1));

select 'Number of ALL patients:' as title, count(*) as count
    from (select distinct PatientID from famdat.b1_biom_all);

select 'Number of patients with GA>=140:' as title, count(*) as count
    from (select distinct PatientID from famdat.b1_biom_all where ga_edd>=140);
    
%macro createreports(tablename=, subsetstring=);

proc sql;
select 'Number of studies with an AFI' as title, "&subsetstring" as subsettype, count(*) as count
    from (select * from &tablename. where not missing(AFI));
select 'Number of patients with AFI calculated' as title, count(*) as count 
     from (select distinct PatientID from &tablename. where not missing(AFI));

select 'Total number of ultrasounds with AFI or calculated MVP present' as title, "&subsetstring" as subsettype, count(*) as count from
    (select * from &tablename. where not missing(AFI) or not missing(CalcMVP));
select 'Number of patients with AFI calculated' as title, count(*) as count 
     from (select distinct PatientID from &tablename. where not missing(AFI) or not missing(CalcMVP));


select "Number of cases when MVP = MAX(AFIQs) <= 2" as title, "&subsetstring" as subsettype, count(*) as count from
    (select * from &tablename. where CalcMVP <= 2 and not missing(CalcMVP));
select 'Number of Patients for Above:' as title, count(*) as count from
    (select distinct PatientID from &tablename. where CalcMVP <= 2 and not missing(CalcMVP) );

select 'Number of cases when MVP = MAX(AFIQs) >8' as title, "&subsetstring" as subsettype, count(*) as count from
    (select * from &tablename. where CalcMVP >8 and not missing(CalcMVP));
select 'Number of Patients for Above:' as title, count(*) as count from
    (select distinct PatientID from &tablename. where CalcMVP >8 and not missing(CalcMVP) );

select 'Number of cases when AFI <=5' as title, "&subsetstring" as subsettype, count(*) as count from
    (select * from &tablename. where AFI <=5 and not missing(AFI));
select 'Number of Patients for Above:' as title, count(*) as count from
    (select distinct PatientID from &tablename. where AFI <= 5 and not missing(AFI));

select 'Number of cases when AFI > 24' as title, "&subsetstring" as subsettype, count(*) as count from
    (select * from &tablename. where AFI > 24 and not missing(AFI));
select 'Number of Patients for Above:' as title, count(*) as count from
    (select distinct PatientID from &tablename. where AFI > 24 and not missing(AFI) );

select 'Number of cases when MVP = MAX(AFIQs)<=2, and AFI <=5 (and vice versa)' as title, "&subsetstring" as subsettype,
    'AFI <= 5 and CalcMVP <=2' as condition, count(*) as count from 
    (select * from &tablename. where AFI <= 5 and CalcMVP <=2 and not missing(AFI) and not missing(CalcMVP));
select 'Number of Patients for Above:' as title, count(*) as count from
    (select distinct PatientID from &tablename. where AFI <= 5 and CalcMVP <=2 and not missing(AFI) and not missing(CalcMVP) );

select 'Number of cases when MVP = MAX(AFIQs) > 8, and AFI > 24 (and vice versa)' as title, "&subsetstring" as subsettype,
    'AFI > 24 and CalcMVP > 8' as condition, count(*) as count from 
    (select * from &tablename. where AFI > 24 and CalcMVP > 8 and not missing(AFI) and not missing(CalcMVP));
select 'Number of Patients for Above:' as title, count(*) as count from
    (select distinct PatientID from &tablename. where AFI > 24 and CalcMVP > 8 and not missing(AFI) and not missing(CalcMVP) );


select 'Number of cases when MVP = MAX(AFIQs) < 8, and AFI >=24 (and vice versa)' as title, "&subsetstring" as subsettype,
    'AFI >= 24 and CalcMVP < 8' as condition, count(*) as count from 
    (select * from &tablename. where AFI >=24  and CalcMVP < 8 and not missing(AFI) and not missing(CalcMVP));
select 'Number of Patients for Above:' as title, count(*) as count from
    (select distinct PatientID from &tablename. where AFI >=24  and CalcMVP < 8 and not missing(AFI) and not missing(CalcMVP) );

select 'Number of cases when MVP = MAX(AFIQs) >= 8, and AFI < 24 (and vice versa)' as title, "&subsetstring" as subsettype,
    'AFI < 24 and CalcMVP >= 8' as condition, count(*) as count from 
    (select * from &tablename. where AFI < 24 and CalcMVP >= 8 and not missing(AFI) and not missing(CalcMVP));
select 'Number of Patients for Above:' as title, count(*) as count from
    (select distinct PatientID from &tablename. where AFI < 24 and CalcMVP >= 8 and not missing(AFI) and not missing(CalcMVP) );

%mend;

*%createreports(tablename=famdat.polyhydramnios_with_afi_mvp, subsetstring=ALL);

proc sql;
create table famdat.polyhydramnios_last_20_weeks as
    select * from famdat.polyhydramnios_with_afi_mvp
    where ga_edd >= 140;
 
%createreports(tablename=famdat.polyhydramnios_last_20_weeks, subsetstring= GA>=140);

%ds2csv(
    data=famdat.polyhydramnios_last_20_weeks,
    runmode=b,
    csvfile=F:/Users/hinashah/SASFiles/polyhydramnios_last_20_weeks.csv   
);

title 'Scatter plot/regression for all AFI/MVP values with GA > 20 weeks';
/*--Set output size--*/
ods graphics / reset imagemap;

/*--SGPLOT proc statement--*/
proc sgplot data=FAMDAT.POLYHYDRAMNIOS_LAST_20_WEEKS;
    /*--Fit plot settings--*/
    reg x=CalcMVP y=AFI / nomarkers CLM CLI alpha=0.01 name='Regression' LINEATTRS=(color=red);

    /*--Scatter plot settings--*/
    scatter x=CalcMVP y=AFI / transparency=0.0 name='Scatter';

    /*--X Axis--*/
    xaxis grid;

    /*--Y Axis--*/
    yaxis grid;
run;

ods graphics / reset;

proc sql;
create table work.subset_small_values as
    select AFI, CalcMVP from famdat.polyhydramnios_last_20_weeks
    where AFI <= 5 and CalcMVP <=2 and not missing(AFI) and not missing(CalcMVP)
;

create table work.subset_large_values  as
    select AFI, CalcMVP from famdat.polyhydramnios_last_20_weeks
    where AFI > 24 and CalcMVP > 8 and not missing(AFI) and not missing(CalcMVP)
; 


title 'Analysis on AFI>24 and MVP >8';
proc means data=work.subset_large_values;
run;

ods noproctitle;
ods graphics / imagemap=on;
title;
proc corr data=WORK.SUBSET_LARGE_VALUES pearson nosimple noprob 
        plots=matrix(histogram);
run;

ods graphics on;
proc corr data=WORK.SUBSET_LARGE_VALUES
          plots=scatter nocorr nosimple;
   var AFI CalcMVP;
 run;
ods graphics off;


title 'Analysis on AFI<=5 and MVP <=2';

proc means data=work.subset_small_values;
run;

ods noproctitle;
ods graphics / imagemap=on;
title;
proc corr data=WORK.SUBSET_SMALL_VALUES pearson nosimple noprob 
        plots=matrix(histogram);
run;

ods graphics on;
proc corr data=WORK.SUBSET_SMALL_VALUES
          plots=scatter nocorr nosimple;
   var AFI CalcMVP;
 run;
ods graphics off;

ods pdf close;