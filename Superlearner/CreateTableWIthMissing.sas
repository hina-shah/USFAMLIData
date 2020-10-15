options nonotes;
dm "log; clear; out; clear; results; clear;";

* Script to generate data as input to the SuperLearner macro. This gnerates two sets of data;

%let target_location = P:\Users\hinashah\SASFiles\SLData_Del923Anonym;

libname famdat  "P:\Users\hinashah\SASFiles\B1Data916";
libname sldat "&target_location.";

%let inputtable = famdat.b1_studies_with_del;
/* %let inputtable = famdat.b1_full_table; */

ods pdf file="&target_location.\CreateTablesOutput.pdf" startpage=no;

proc sql;
create table inputtable_u as
select * from 
(
select *, count(*) as study_count 
from &inputtable.
group by PatientID, studydate
) where study_count=1;

title;
proc sql;
create table sldat.SL_Table1_All as
    select filename, PatientID, studydate, lmp, ga_edd, episode_edd,
                    fl_1, fl_2, bp_1, bp_2, hc_1, hc_2, ac_1, ac_2,
                    mom_age_edd, mom_weight_oz, mom_height_in, hiv, tobacco_use,
                    chronic_htn, preg_induced_htn, diabetes, gest_diabetes
/*     from &inputtable. */
    from inputtable_u
;

select "Number of Ultrasounds initially:", count(*) from sldat.SL_Table1_All;
select "Number of pregnancies initially:", count(*) from (select distinct PatientID, episode_edd from sldat.SL_Table1_All where not missing(episode_edd));
select "Number of patients initially:", count(*) from  (select distinct PatientID from sldat.SL_Table1_All );
select "Number of studies with ages outside of range (13,49): ", count(*) from
    (select distinct filename from sldat.SL_Table1_All where not missing(mom_age_edd) and (mom_age_edd < 13 or mom_age_edd > 49));

data sldat.SL_Table1_All (drop=mom_weight_oz);
set sldat.SL_Table1_All;
    
    if not missing(tobacco_use) then do;
        current_smoker = prxmatch('/(CURRENT)|(Diagnosed)/',tobacco_use) > 0;
        former_smoker = prxmatch('/FORMER/', tobacco_use) >0;
        if current_smoker=1 then smoker_status = 1;
        if former_smoker=1 then smoker_status=2;
        if current_smoker=0 and former_smoker=0 then smoker_status=0;
    end;
    
    mom_weight_lb = mom_weight_oz/16.;
    
    fl_mean = fl_1;
    if not missing(fl_2) then fl_mean = mean(fl_1, fl_2);
    
    bp_mean = bp_1;
    if not missing(bp_2) then bp_mean = mean(bp_1, bp_2);
    
    ac_mean = ac_1;
    if not missing(ac_2) then ac_mean = mean(ac_1, ac_2);
    
    hc_mean = hc_1;
    if not missing(hc_2) then hc_mean = mean(hc_1, hc_2);
    
    if fl_mean > 0. and bp_mean > 0. and ac_mean > 0. and hc_mean > 0. then 
        hadlock_ga = (10.85+0.06*hc_mean*fl_mean + 0.67*bp_mean + 0.168*ac_mean)*7;
    
    fl_mean = fl_mean*10;
    bp_mean = bp_mean*10;
    ac_mean = ac_mean*10;
    hc_mean = hc_mean*10;
    
    if hc_mean > 0 then do;
    loghc = log(hc_mean);
    logintergrowth = 0.03243* loghc*loghc + 0.0016644*fl_mean*loghc +3.813;
    intergrowth_ga = exp(logintergrowth);
    end;
    
    if fl_mean > 0. and bp_mean > 0. and ac_mean > 0. and hc_mean > 0. then do;
    
        nichd_ga = 10.6 - (0.1683*bp_mean) + (0.0452*hc_mean) + (0.0302*ac_mean) + 
                   (0.0576*fl_mean) + (0.0025*bp_mean*bp_mean) + 
                   (0.0017*fl_mean*fl_mean) + (0.0005*(bp_mean * ac_mean)) -
                   (0.0052*(bp_mean * fl_mean)) - (0.0003*(hc_mean * ac_mean)) + 
                   (0.0008*(hc_mean * fl_mean)) + (0.0006*(ac_mean * fl_mean));
       nichd_ga = nichd_ga*7.0;
    end;
    
    if ga_edd < 196 then trimester =0; 
    else trimester = 1;
    
    hadlock_intergrowth_diff = abs(absdiffhadlock - absdiffintergrowth);
    
    diffhadlock = hadlock_ga - ga_edd;
    diffintergrowth = intergrowth_ga - ga_edd;
    diffnichd = nichd_ga - ga_edd;
    
    absdiffhadlock = abs(hadlock_ga-ga_edd);
    absdiffintergrowth = abs(intergrowth_ga - ga_edd);
    absdiffnichd = abs(nichd_ga - ga_edd);
    
    sehadlock = diffhadlock**2;
    seintergrowth = diffintergrowth**2;
    senichd = diffnichd**2;
    
    ga_edd_weeks = ga_edd/7.;
    
    fl_mean = fl_mean/10.0;
    hc_mean = hc_mean/10.0;
    ac_mean = ac_mean/10.0;
    bp_mean = bp_mean/100.0;
run;

*Create categorical variables for binary variables;
data sldat.SL_Table1_Categorical;
set sldat.SL_Table1_All;

    if not missing(tobacco_use) then do;
        current_smoker = prxmatch('/(CURRENT)|(Diagnosed)/',tobacco_use) > 0;
        former_smoker = prxmatch('/FORMER/', tobacco_use) >0;
        if current_smoker=1 then smoker_status = 1;
        if former_smoker=1 then smoker_status=2;
        if current_smoker=0 and former_smoker=0 then smoker_status=0;
    end;
    else do;
        current_smoker=2;
        former_smoker=2;
        smoker_status = 3;
    end;
    
    if missing(hiv) then hiv = 2;
    if missing(chronic_htn) then chronic_htn = 2;
    if missing(preg_induced_htn) then preg_induced_htn = 2;
    if missing(diabetes) then diabetes = 2;
    if missing(gest_diabetes) then gest_diabetes = 2;
    
    if fl_1 > 0. and bp_1 > 0. and  hc_1 > 0. and ac_1 > 0. 
        and mom_age_edd >= 13 and mom_age_edd <= 49
        and mom_weight_lb > 0. and mom_height_in > 0.
    then output;
run;
proc sql;
select "Number of Ultrasounds with complete categorical information:", count(*) from sldat.SL_Table1_Categorical;

create table sldat.SL_Table1_Categorical as
    select *
    from sldat.SL_Table1_Categorical
    where absdiffhadlock <= 30 and absdiffintergrowth <=30;
select "Number of Ultrasounds with complete categorical information and regulating ga_diff:", count(*) from sldat.SL_Table1_Categorical;


* For variable to be fed into the superlearner chose them to be always present;
proc sql;
create table sldat.SL_Table1_NonMissing as
    select  filename, PatientID, studydate, lmp, ga_edd, ga_edd_weeks, trimester, episode_edd,
                    fl_1, bp_1, hc_1,ac_1,
                    mom_age_edd, mom_weight_lb, mom_height_in, hiv, current_smoker, former_smoker, smoker_status,
                    chronic_htn, preg_induced_htn, diabetes, gest_diabetes, 
                    hadlock_ga, intergrowth_ga, nichd_ga,
                    absdiffhadlock, absdiffintergrowth, absdiffnichd,
                    diffhadlock, diffintergrowth, diffnichd,
                    sehadlock, seintergrowth, senichd,
                    hadlock_intergrowth_diff
    from sldat.SL_Table1_All
    where
        not missing(ga_edd) and not missing(episode_edd)
        and not missing(fl_1) and fl_1>0 
        and not missing(bp_1) and bp_1>0 
        and not missing(hc_1) and hc_1>0
        and not missing(ac_1) and ac_1>0 
        and not missing(mom_age_edd) and mom_age_edd >= 13 and mom_age_edd <= 49
        and not missing (mom_weight_lb)
        and not missing(mom_height_in)
        and not missing(hiv) 
        and not missing(current_smoker)
        and not missing(former_smoker)
        and not missing(chronic_htn) and not missing(preg_induced_htn) 
        and not missing(diabetes) and not missing(gest_diabetes)
;
select "Number of Ultrasounds with complete information:", count(*) from sldat.SL_Table1_NonMissing;

create table sldat.SL_Table1_NonMissing as
    select *
    from sldat.SL_Table1_NonMissing
    where absdiffhadlock <= 30 and absdiffintergrowth <=30;
select "Number of Ultrasounds with complete information and regulating ga_diff:", count(*) from sldat.SL_Table1_NonMissing;


proc sql;
create table sldat.SL_Table1_NonMissing_Two as
    select  filename, PatientID, studydate, lmp, ga_edd, ga_edd_weeks, trimester, episode_edd,
                    fl_1, fl_2, bp_1, bp_2, hc_1, hc_2, ac_1, ac_2,
                    mom_age_edd, mom_weight_lb, mom_height_in, hiv, current_smoker, former_smoker, smoker_status,
                    chronic_htn, preg_induced_htn, diabetes, gest_diabetes, 
                    hadlock_ga, intergrowth_ga, nichd_ga,
                    absdiffhadlock, absdiffintergrowth, absdiffnichd,
                    diffhadlock, diffintergrowth, diffnichd,
                    sehadlock, seintergrowth, senichd,
                    hadlock_intergrowth_diff
    from sldat.SL_Table1_All
    where
        not missing(ga_edd) and not missing(episode_edd)
        and not missing(fl_1) and fl_1>0 
        and not missing(bp_1) and bp_1>0 
        and not missing(hc_1) and hc_1>0
        and not missing(ac_1) and ac_1>0 
        and not missing(fl_2) and fl_2>0 
        and not missing(bp_2) and bp_2>0 
        and not missing(hc_2) and hc_2>0
        and not missing(ac_2) and ac_2>0 
        and not missing(mom_age_edd) and not missing (mom_weight_lb)
        and not missing(mom_height_in)
        and not missing(hiv) 
        and not missing(current_smoker) 
        and not missing(former_smoker)
        and not missing(chronic_htn) and not missing(preg_induced_htn) 
        and not missing(diabetes) and not missing(gest_diabetes)
;
select "Number of Ultrasounds with complete information and two biometries:", count(*) from sldat.SL_Table1_NonMissing_Two;

%MACRO RandomStudySelection(indata=,
                            out_suffix=
                            );
title;
* Get the pregnancies from this table ;
proc sql;
create table sldat.SL_NonMissingPregnancies&out_suffix. as 
    select distinct PatientID, episode_edd
    from &indata. /*sldat.SL_Table1_NonMissing*/
    group by PatientID
;

select "Number of Pregnancies with complete information (&out_suffix):", count(*) from sldat.SL_NonMissingPregnancies&out_suffix.;
select "Number of patients from above (&out_suffix):", count(*) from (select distinct patientID from sldat.SL_NonMissingPregnancies&out_suffix.);
   
* Chose a random pregnancy for the patient;
proc surveyselect data=sldat.SL_NonMissingPregnancies&out_suffix. out=sldat.SL_RandSelectPregnancies&out_suffix. n=1 noprint;
Strata PatientID;
run;

* extract corresponding ultrasounds with non-missing data;
proc sql;
create table sldat.SL_SelectedPregnancies_US&out_suffix. as
select distinct a.PatientID, a.episode_edd, b.studydate
    from
        sldat.SL_RandSelectPregnancies&out_suffix. as a
        inner join
        &indata. as b
    on
        a.PatientID = b.PatientID and
        a.episode_edd = b.episode_edd
    order by PatientID
;
select "Number of Ultrasounds for the randomly selected pregnancies (&out_suffix):", count(*) from sldat.SL_SelectedPregnancies_US&out_suffix.;
    

* Randomly chose one ultrasound per patient;
proc surveyselect data=sldat.SL_SelectedPregnancies_US&out_suffix. out=sldat.SL_RandSelectUS&out_suffix. n=1 noprint;
Strata PatientID;
run;

* Now, extract all the data with these randomly chosen set;
proc sql;
 create table sldat.SL_FinalRandSelectTable1&out_suffix. as
 select distinct a.*
 from 
    &indata. as a
    inner join
    sldat.SL_RandSelectUS&out_suffix. as b
 on
    a.PatientID = b.PatientID and
    a.episode_edd = b.episode_edd and
    a.studydate = b.studydate
;

proc sql;
delete * 
    from sldat.SL_FinalRandSelectTable1&out_suffix.
    where filename in 
            (select filename 
                from 
                    (
                    select filename, count(*) as cnt 
                    from sldat.SL_FinalRandSelectTable1&out_suffix.
                    group by PatientID
                    )
                where cnt > 1 and prxmatch('/SRc./', filename)=1
             ) 
;

proc sql;
select "Number of Ultrasound studies randomly selected:", count(*) from sldat.SL_FinalRandSelectTable1&out_suffix.;

proc means data=sldat.SL_FinalRandSelectTable1&out_suffix. N NMISS MEDIAN Q1 Q3 MEAN MIN MAX STD; run;

title "Statistics on gestational age for selected studies";
proc univariate data=sldat.SL_FinalRandSelectTable1&out_suffix. noprint;
    title1 "Histogram of gestational ages in days &out_suffix ";
    histogram ga_edd;
run;

data sldat.SL_FinalRandSelectTable1&out_suffix.;
set sldat.SL_FinalRandSelectTable1&out_suffix.;
label ga_edd_weeks="Gestational Age in weeks";
label trimester="2nd or 3rd trimester (0/1)";
label hadlock_ga="Hadlock GA";
label intergrowth_ga="Intergrowth GA";
label nichd_ga = "NICHD GA";
label absdiffhadlock = "Hadlock Absolute Diff";
label absdiffintergrowth = "Intergrowth Absolute Diff";
label absdiffnichd = "NICHD Absolute Diff";
label diffhadlock = "Hadlock Diff";
label diffintergrowth = "Intergrowth Diff";
label diffnichd = "NICHD Diff";
label sehadlock = "Hadlock Squared Error";
label seintergrowth = "Intergrowth Squared Error";
label senichd = "NICHD Squared Error";
run;

proc univariate data=sldat.SL_FinalRandSelectTable1&out_suffix. noprint;
    title1 "Histogram of gestational ages in weeks &out_suffix ";
    histogram ga_edd_weeks / endpoints= 13 to 43 by 1;
run;

title "Frequencies for Categorical Variables";

proc freq data=sldat.SL_FinalRandSelectTable1&out_suffix.;
    tables hiv chronic_htn preg_induced_htn diabetes gest_diabetes current_smoker 
        former_smoker smoker_status;
run;
%MEND;

title 'Processing the dataset without missing information';
* Select random studies for all non-missing;
%RandomStudySelection(indata= sldat.SL_Table1_NonMissing,
                            out_suffix=
                            );
data sldat.SL_Table1_NonMissing_2Trim sldat.SL_Table1_NonMissing_3Trim;
set sldat.SL_Table1_NonMissing;
if ga_edd < 196 then output sldat.SL_Table1_NonMissing_2Trim;
else output sldat.SL_Table1_NonMissing_3Trim;
run;
%RandomStudySelection(indata= sldat.SL_Table1_NonMissing_2Trim,
                            out_suffix= _2Trim
                            );

%RandomStudySelection(indata= sldat.SL_Table1_NonMissing_3Trim,
                            out_suffix= _3Trim
                            );

title 'Processing the dataset with categorical variables forbinary variable';
* Select random studies when binary variables are converted to categorical variables;
%RandomStudySelection(indata= sldat.SL_Table1_Categorical,
                            out_suffix=_Cat
                            );
data sldat.SL_Table1_Cat2Tr sldat.SL_Table1_Cat3Tr;
set sldat.SL_Table1_Categorical;
if ga_edd < 196 then output sldat.SL_Table1_Cat2Tr;
else output sldat.SL_Table1_Cat3Tr;
run;
%RandomStudySelection(indata= sldat.SL_Table1_Cat2Tr,
                            out_suffix= _Cat2Tr
                            );

%RandomStudySelection(indata= sldat.SL_Table1_Cat3Tr,
                            out_suffix= _Cat3Tr
                            );
ods graphics / reset;

proc surveyselect data=sldat.SL_FinalRandSelectTable1_Cat 
      method=srs n=5000 out=sldat.SL_FinalRandSelectTable1_C5k noprint;
   run;

proc surveyselect data=sldat.SL_FinalRandSelectTable1
      method=srs n=5000 out=sldat.SL_FinalRandSelectTable1_sub5K noprint;
   run;
   
proc surveyselect data=sldat.SL_FinalRandSelectTable1
      method=srs n=10000 out=sldat.SL_FinalRandSelectTable1_sub10K noprint;
   run;


%macro deidentify(indata=, outdata=);

    data sldat.&outdata. (keep= ga_edd ga_edd_weeks trimester
                           fl_1 bp_1 hc_1 ac_1 
                           mom_age_edd mom_weight_lb mom_height_in
                           hiv current_smoker former_smoker smoker_status
                           chronic_htn preg_induced_htn
                           diabetes gest_diabetes
                           hadlock_ga intergrowth_ga nichd_ga
                           absdiffhadlock absdiffintergrowth absdiffnichd
                           diffhadlock diffintergrowth diffnichd
                           sehadlock seintergrowth senichd);
    set &indata.;
    run;
    
    %ds2csv(
    data= sldat.&outdata.,
    runmode=b,
    labels=N,
    csvfile=&target_location./&outdata..csv   
    );
    
%mend deidentify;

%deidentify(indata=sldat.SL_FinalRandSelectTable1, outdata=sldata_an);
%deidentify(indata=sldat.SL_FinalRandSelectTable1_cat, outdata=sldata_cat_an);
%deidentify(indata=sldat.SL_FinalRandSelectTable1_cat2tr, outdata=sldata_cat2tr_an);
%deidentify(indata=sldat.SL_FinalRandSelectTable1_cat3tr, outdata=sldata_cat3tr_an);
%deidentify(indata=sldat.SL_FinalRandSelectTable1_2Trim, outdata=sldata_2tr_an);
%deidentify(indata=sldat.SL_FinalRandSelectTable1_3Trim, outdata=sldata_3tr_an);
%deidentify(indata=sldat.SL_FinalRandSelectTable1_C5k, outdata=sldata_cat5k_an);
%deidentify(indata=sldat.SL_FinalRandSelectTable1_sub5K, outdata=sldata_5k_an);
%deidentify(indata=sldat.SL_FinalRandSelectTable1_sub10K, outdata=sldata_10k_an);

ods pdf close;
