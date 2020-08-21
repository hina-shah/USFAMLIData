options nonotes;
dm "log; clear; out; clear; results; clear;";

%let target_location = P:\Users\hinashah\SASFiles\IVF_Analysis_New;

libname famdat  "P:\Users\hinashah\SASFiles";
libname sldat "&target_location.";

%let ivf_edd_table = famdat.b1_epic_emb_trans_last_entry;
%let full_table = famdat.b1_full_table;

ods pdf file="&target_location.\CreateTablesOutput.pdf" startpage=no;

title;
proc sql;
create table ivf_studies as 
select a.*
from 
    &full_table as a 
    inner join
    &ivf_edd_table as b 
on
    a.PatientID = b.pat_mrn_id 
    and
    abs(a.episode_edd - b.embryo_episode_working_edd) <= 42
;

proc sql;
select "Number of Ultrasounds initially:", count(*) from ivf_studies;
select "Number of pregnancies initially:", count(*) from (select distinct PatientID, episode_edd from ivf_studies where not missing(episode_edd));
select "Number of patients initially:", count(*) from  (select distinct PatientID from ivf_studies );
select "Number of studies with ages outside of range (13,49): ", count(*) from
    (select distinct filename from ivf_studies where not missing(mom_age_edd) and (mom_age_edd < 13 or mom_age_edd > 49));


data sldat.SL_Table1_All (drop=mom_weight_oz);
set ivf_studies;
    
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
run;

proc means data=sldat.SL_Table1_All n nmiss median q1 q3;
run;

proc freq data=sldat.SL_Table1_All;
    tables hiv chronic_htn preg_induced_htn diabetes gest_diabetes current_smoker 
        former_smoker smoker_status;
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
    select filename, PatientID, studydate, lmp, ga_edd, ga_edd_weeks, trimester, episode_edd,
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

title 'Processing the dataset without missing information';
%RandomStudySelection(indata= sldat.SL_Table1_NonMissing,
                            out_suffix=
                            );
                            

title 'Processing the dataset with categorical variables forbinary variable';
* Select random studies when binary variables are converted to categorical variables;
%RandomStudySelection(indata= sldat.SL_Table1_Categorical,
                            out_suffix=_Cat
                            );

ods pdf close;