
libname famdat  "P:\Users\hinashah\SASFiles\B1Data";
libname sldat "P:\Users\hinashah\SASFiles\SLData_ExtraLearners";

%let inputtable = famdat.b1_full_table;

ods pdf file="P:\Users\hinashah\SASFiles\SLData_ExtraLearners\CreateTablesOutput.pdf";

proc sql;
create table sldat.SL_Table1_All as
    select filename, PatientID, studydate, lmp, ga_edd, episode_edd,
                    fl_1, fl_2, bp_1, bp_2, hc_1, hc_2, ac_1, ac_2,
                    mom_age_edd, mom_weight_oz, mom_height_in, hiv, tobacco_use,
                    chronic_htn, preg_induced_htn, diabetes, gest_diabetes
    from &inputtable.
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
    
    hadlock_ga_diff = abs(hadlock_ga-ga_edd);
    intergrowth_ga_diff = abs(intergrowth_ga - ga_edd);
    hadlock_intergrowth_diff = abs(hadlock_ga_diff - intergrowth_ga_diff);

run;

ods graphics / reset  imagemap;
title "Box plot for the diff in ga of hadlock from edd based for all ";
/*--SGPLOT proc sttatement--*/
proc sgplot data=sldat.SL_Table1_All;
    /*--TITLE and FOOTNOTE--*/
    /*--Box Plot settings--*/
    vbox hadlock_ga_diff / fillattrs=(color=CXCAD5E5) name='Box';

    /*--Category Axis--*/
    xaxis fitpolicy=splitrotate;

    /*--Response Axis--*/
    yaxis grid;
    
run;


title "Box plot for the diff in ga of intergrowth from edd based for all ";
proc sgplot data=sldat.SL_Table1_All;
    /*--TITLE and FOOTNOTE--*/
    /*--Box Plot settings--*/
    vbox intergrowth_ga_diff / fillattrs=(color=CXCAD5E5) name='Box';

    /*--Category Axis--*/
    xaxis fitpolicy=splitrotate;

    /*--Response Axis--*/
    yaxis grid;
run;

title "Box plot for the diff in ga by intergrowth from hadlock for all ";
proc sgplot data=sldat.SL_Table1_All;
    /*--TITLE and FOOTNOTE--*/
    /*--Box Plot settings--*/
    vbox hadlock_intergrowth_diff / fillattrs=(color=CXCAD5E5) name='Box';

    /*--Category Axis--*/
    xaxis fitpolicy=splitrotate;

    /*--Response Axis--*/
    yaxis grid;
run;

title;
ods graphics/reset;
proc means data=sldat.SL_Table1_All N NMISS  MEDIAN Q1 Q3 MEAN MIN MAX STD; run;

* For variable to be fed into the superlearner chose them to be always present;
proc sql;
create table sldat.SL_Table1_NonMissing as
    select  filename, PatientID, studydate, lmp, ga_edd, episode_edd,
                    fl_1, bp_1, hc_1,ac_1,
                    mom_age_edd, mom_weight_lb, mom_height_in, hiv, current_smoker, former_smoker,
                    chronic_htn, preg_induced_htn, diabetes, gest_diabetes, hadlock_ga, intergrowth_ga,
                    hadlock_ga_diff, intergrowth_ga_diff, hadlock_intergrowth_diff
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
        and not missing(hiv) and not missing(tobacco_use)
        and not missing(chronic_htn) and not missing(preg_induced_htn) 
        and not missing(diabetes) and not missing(gest_diabetes)
;
select "Number of Ultrasounds with complete information:", count(*) from sldat.SL_Table1_NonMissing;

create table sldat.SL_Table1_NonMissing as
    select *
    from sldat.SL_Table1_NonMissing
    where hadlock_ga_diff <= 30 and intergrowth_ga_diff <=30;
select "Number of Ultrasounds with complete information and regulating ga_diff:", count(*) from sldat.SL_Table1_NonMissing;


proc sql;
create table sldat.SL_Table1_NonMissing_Two as
    select  filename, PatientID, studydate, lmp, ga_edd, episode_edd,
                    fl_1, fl_2, bp_1, bp_2, hc_1, hc_2, ac_1, ac_2,
                    mom_age_edd, mom_weight_lb, mom_height_in, hiv, current_smoker, former_smoker,
                    chronic_htn, preg_induced_htn, diabetes, gest_diabetes, hadlock_ga, intergrowth_ga,
                    hadlock_ga_diff, intergrowth_ga_diff, hadlock_intergrowth_diff
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
        and not missing(hiv) and not missing(tobacco_use)
        and not missing(chronic_htn) and not missing(preg_induced_htn) 
        and not missing(diabetes) and not missing(gest_diabetes)
;
select "Number of Ultrasounds with complete information and two biometries:", count(*) from sldat.SL_Table1_NonMissing_Two;

%MACRO RandomStudySelection(indata=,
                            out_suffix=
                            )
;

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
label ga_weeks="Gestational Age in weeks";
ga_weeks = ga_edd/7.;
run;

proc univariate data=sldat.SL_FinalRandSelectTable1&out_suffix. noprint;
    title1 "Histogram of gestational ages in weeks &out_suffix ";
    histogram ga_weeks / endpoints= 13 to 43 by 1;
run;

%ds2csv(
    data=sldat.SL_FinalRandSelectTable1&out_suffix.,
    runmode=b,
    labels=N,
    csvfile=P:/Users/hinashah/SASFiles/SL_FinalRandSelectTable1&out_suffix..csv   
);

%MEND;

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

ods graphics / reset;

proc surveyselect data=sldat.SL_FinalRandSelectTable1
      method=srs n=5000 out=sldat.SL_FinalRandSelectTable1_sub5K;
   run;
   
proc surveyselect data=sldat.SL_FinalRandSelectTable1
      method=srs n=10000 out=sldat.SL_FinalRandSelectTable1_sub10K;
   run;

ods pdf close;