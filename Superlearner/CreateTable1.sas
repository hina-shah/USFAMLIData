
libname famdat  "F:\Users\hinashah\SASFiles";
libname sldat "F:\Users\hinashah\SASFiles\SLData";

%let inputtable = famdat.b1_full_table;

proc sql;
create table sldat.SL_Table1_All as
    select filename, PatientID, studydate, lmp, ga_edd, episode_edd,
                    fl_1, fl_2, bp_1, bp_2, hc_1, hc_2, ac_1, ac_2,
                    mom_age_edd, mom_weight_oz, mom_height_in, hiv, tobacco_use,
                    chronic_htn, preg_induced_htn, diabetes, gest_diabetes
    from &inputtable.
;

select 'Number of Ultrasounds initially:', count(*) from sldat.SL_Table1_All;
select 'Number of pregnancies initially:', count(*) from (select distinct PatientID, episode_edd from sldat.SL_Table1_All where not missing(episode_edd));
select 'Number of patients initially:', count(*) from  (select distinct PatientID from sldat.SL_Table1_All );
proc means data=sldat.SL_Table1_All NMISS N; run;

proc sort data=sldat.SL_Table1_All out=sldat.SL_Table1_All;
by tobacco_use;
run;

data sldat.SL_Table1_All;
set sldat.SL_Table1_All;
by tobacco_use;
if not missing(tobacco_use) and first.tobacco_use then tobacco_use_num+1;

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

* For variable to be fed into the superlearner chose them to be always present;
proc sql;
create table sldat.SL_Table1_NonMissing as
    select  filename, PatientID, studydate, lmp, ga_edd, episode_edd,
                    fl_1, bp_1, hc_1,ac_1,
                    mom_age_edd, mom_weight_oz, mom_height_in, hiv, tobacco_use_num,
                    chronic_htn, preg_induced_htn, diabetes, gest_diabetes, hadlock_ga, intergrowth_ga,
                    hadlock_ga_diff, intergrowth_ga_diff, hadlock_intergrowth_diff
    from sldat.SL_Table1_All
    where
        not missing(ga_edd) and not missing(episode_edd)
        and not missing(fl_1) and fl_1>0 
        and not missing(bp_1) and bp_1>0 
        and not missing(hc_1) and hc_1>0
        and not missing(ac_1) and ac_1>0 
        and not missing(mom_age_edd) and not missing (mom_weight_oz)
        and not missing(mom_height_in)
        and not missing(hiv) and not missing(tobacco_use)
        and not missing(chronic_htn) and not missing(preg_induced_htn) 
        and not missing(diabetes) and not missing(gest_diabetes)
;

select 'Number of Ultrasounds with complete information:', count(*) from sldat.SL_Table1_NonMissing;

* Get the pregnancies from this table ;
proc sql;
create table sldat.SL_NonMissingPregnancies as 
    select distinct PatientID, episode_edd
    from sldat.SL_Table1_NonMissing
    group by PatientID
;

select 'Number of Pregnancies with complete information:', count(*) from sldat.SL_NonMissingPregnancies;
select 'Number of patients from above:', count(*) from (select distinct patientID from sldat.SL_NonMissingPregnancies);
   
* Chose a random pregnancy for the patient;
proc surveyselect data=sldat.SL_NonMissingPregnancies out=sldat.SL_RandSelectPregnancies n=1 noprint;
Strata PatientID;
run;

* extract corresponding ultrasounds with non-missing data;
proc sql;
create table sldat.SL_SelectedPregnancies_US as
select distinct a.PatientID, a.episode_edd, b.studydate
    from
        sldat.SL_RandSelectPregnancies as a
        inner join
        sldat.SL_Table1_NonMissing as b
    on
        a.PatientID = b.PatientID and
        a.episode_edd = b.episode_edd
    order by PatientID
;
select 'Number of Ultrasounds for the randomly selected pregnancies:', count(*) from sldat.SL_SelectedPregnancies_US;
    

* Randomly chose one ultrasound per patient;
proc surveyselect data=sldat.SL_SelectedPregnancies_US out=sldat.SL_RandSelectUS n=1 noprint;
Strata PatientID;
run;

* Now, extract all the data with these randomly chosen set;
proc sql;
 create table sldat.SL_FinalRandSelectTable1 as
 select distinct a.*
 from 
    sldat.SL_Table1_NonMissing as a
    inner join
    sldat.SL_RandSelectUS as b
 on
    a.PatientID = b.PatientID and
    a.episode_edd = b.episode_edd and
    a.studydate = b.studydate
;

proc sql;
delete * 
    from sldat.SL_FinalRandSelectTable1 
    where filename in 
            (select filename 
                from 
                    (
                    select filename, count(*) as cnt 
                    from sldat.SL_FinalRandSelectTable1 
                    group by PatientID
                    )
                where cnt > 1 and prxmatch('/SRc./', filename)=1
             ) 
;

select 'Number of Ultrasound studies to be fed to SL:', count(*) from sldat.SL_FinalRandSelectTable1;

/*--Set output size--*/
ods graphics / reset  imagemap
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

title 'Statistics on gestational age for selected studies';
proc univariate data=sldat.SL_FinalRandSelectTable1;
var ga_edd;
run;

proc univariate data=sldat.SL_FinalRandSelectTable1 noprint;
    histogram ga_edd;
run;

ods graphics / reset;