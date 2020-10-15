
libname famdat  "P:\Users\hinashah\SASFiles\B1Data";
libname sldat "P:\Users\hinashah\SASFiles\SLData_BW";

%let inputtable = famdat.b1_full_table;

ods pdf file="P:\Users\hinashah\SASFiles\SLData_BW\CreateBirthWeightTablesOutput.pdf";

proc sql;
create table sldat.SL_BWTable1_All as
    select filename, PatientID, studydate, lmp, ga_edd, episode_edd,
                    fl_1, fl_2, bp_1, bp_2, hc_1, hc_2, ac_1, ac_2,
                    mom_age_edd, mom_weight_oz, mom_height_in, hiv, tobacco_use,
                    chronic_htn, preg_induced_htn, diabetes, gest_diabetes, delivery_date, birth_wt_gms
    from &inputtable.
;

select "Number of Ultrasounds initially:", count(*) from sldat.SL_BWTable1_All;
select "Number of pregnancies initially:", count(*) from (select distinct PatientID, episode_edd from sldat.SL_BWTable1_All where not missing(episode_edd));
select "Number of patients initially:", count(*) from  (select distinct PatientID from sldat.SL_BWTable1_All );
select "Number of studies with ages outside of range (13,49): ", count(*) from
    (select distinct filename from sldat.SL_BWTable1_All where not missing(mom_age_edd) and (mom_age_edd < 13 or mom_age_edd > 49));


proc sql;
create table with_ga_del as
    select * from &inputtable. 
    where /*not missing(ga_edd) and */ not missing(delivery_date)
    order by PatientID, studydate
;

select "Number of Ultrasounds with a delivery date:", count(*) from with_ga_del;
select "Number of pregnancies with a delivery date:", count(*) from (select distinct PatientID, delivery_date from with_ga_del);
select "Number of patients with a delivery date:", count(*) from  (select distinct PatientID from with_ga_del );

proc sql;
create table last_studies as
    select a.* 
    from 
        with_ga_del as a
        inner join
        (select PatientID, delivery_date, max(studydate) as last_study
            from with_ga_del
            group by PatientID, delivery_date
        ) as b
     on
        a.PatientID = b.PatientID and
        a.delivery_date = b.delivery_date and
        a.studydate = b.last_study
;

select "Number of Last Ultrasounds with a delivery date:", count(*) from last_studies;
select "Number of pregnancies (last ultr) with a delivery date:", count(*) from (select distinct PatientID, delivery_date from last_studies);
select "Number of patients (last ultr) with a delivery date:", count(*) from  (select distinct PatientID from last_studies );


data sldat.SL_BWTable1_All (drop=mom_weight_oz);
set last_studies;
    
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
    
    if fl_mean > 0 and bp_mean>0 and ac_mean >0 and hc_mean>0 then do;
        hadlock_bw = 10 ** (1.3596 + 0.0064 * hc_mean + 0.0424 * ac_mean + 0.174 * fl_mean + 
                        0.00061* bp_mean * ac_mean - 0.00386 *ac_mean * fl_mean);
        
        ott_bw = (10 ** (-2.0661 + 0.04355 * hc_mean + 0.05394 * ac_mean - 
                        0.0008582 * hc_mean * ac_mean + 1.2594 * fl_mean/ac_mean)) *1000;
        
        absdiffhadlock = abs(hadlock_bw-birth_wt_gms);
        absdiffott = abs(ott_bw - birth_wt_gms);
        diffhadlock = hadlock_bw - birth_wt_gms;
        diffott = ott_bw - birth_wt_gms;
    end;
    
    if not missing(delivery_date) and delivery_date - studydate <=7 then output;
run;

proc sql;
select "Number of Ultrasounds del-studydate <=7:", count(*) from sldat.SL_BWTable1_All;
select "Number of pregnancies initially del-studydate <=7:", count(*) from (select distinct PatientID, episode_edd from sldat.SL_BWTable1_All where not missing(episode_edd));
select "Number of patients initially del-studydate <=7:", count(*) from  (select distinct PatientID from sldat.SL_BWTable1_All );


proc sgscatter data=sldat.SL_BWTable1_All; 
matrix birth_wt_gms hadlock_bw ott_bw / diagonal=(histogram kernel) ;
run;
proc means data=sldat.SL_BWTable1_All N NMISS  MEDIAN Q1 Q3 MEAN MIN MAX STD; 
var ga_edd birth_wt_gms hadlock_bw ott_bw;
run;

title;
ods graphics/reset;


* For variable to be fed into the superlearner chose them to be always present;
proc sql;
create table sldat.SL_BWTable1_NonMissing as
    select  filename, PatientID, studydate, delivery_date, episode_edd, ga_edd, birth_wt_gms,
                    fl_1, bp_1, hc_1,ac_1,
                    mom_age_edd, mom_weight_lb, mom_height_in, hiv, current_smoker, former_smoker,
                    chronic_htn, preg_induced_htn, diabetes, gest_diabetes, hadlock_bw, ott_bw,
                    absdiffhadlock, absdiffott, diffhadlock, diffott
    from sldat.SL_BWTable1_All
    where
        not missing(birth_wt_gms) and birth_wt_gms > 0
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
select "Number of Ultrasounds with complete information:", count(*) from sldat.SL_BWTable1_NonMissing;

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
    select "Number of Pregnancies with complete information (&out_suffix):", count(*) from (select distinct PatientID, delivery_date from &indata.);
    
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
        csvfile=P:/Users/hinashah/SASFiles/SL_BWFinalRandSelectTable1&out_suffix..csv   
    );

%MEND;

%RandomStudySelection(indata= sldat.SL_BWTable1_NonMissing,
                            out_suffix=
                            );

title ;
proc sgscatter data=sldat.SL_FinalRandSelectTable1; 
matrix birth_wt_gms hadlock_bw ott_bw / diagonal=(histogram kernel) ;
run;

title 'Distribution of BirthWeights Selected dataset';
proc sgplot data= sldat.SL_FinalRandSelectTable1 nocycleattrs;
  *histogram birth_wt_gms / fillattrs=graphdata1 name='gt' binstart=100  binwidth=300 transparency=0.9;
  *histogram hadlock_bw / fillattrs=graphdata2 name='had' binstart=100 binwidth=300 transparency=0.9;
  *histogram ott_bw / fillattrs=graphdata3 name='ott' binstart=100 binwidth=300 transparency=0.9;
  
  density birth_wt_gms / lineattrs=graphdata1 legendlabel='Ground Truth Birthweight';
  density hadlock_bw / lineattrs=graphdata2 legendlabel='Hadlock Birthweight';
  density ott_bw / lineattrs=graphdata3 legendlabel='Ott birthweight';
  
  keylegend / location=inside position=topright across=1 noborder;
  yaxis offsetmin=0;
  xaxis label='Weight (gms)';
run;

proc means data=sldat.SL_FinalRandSelectTable1 N NMISS  MEDIAN Q1 Q3 MEAN MIN MAX STD; 
output out=mean_data;
var ga_edd birth_wt_gms hadlock_bw ott_bw;
run;

ods pdf close;

/******* Call superlearner analysis ******************/

%let serverpath = P:/Users/hinashah;
%let lib_path = &serverpath./SASFiles/SLData_BW;

%let suffix =;
%let tablename = sl_finalrandselecttable1&suffix.;
%let sl_table = bw_est&suffix.;

ods listing gpath="&lib_path/" image_dpi=150;

*Point and include the SL macro;
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\super_learner_macro.sas";
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\bw_super_learner_wrapper_macro.sas";
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\sas_superlearner_extra_learners.sas";

libname sldat "&lib_path.";

%BWSuperLearnerWrapper(
    indata=sldat.&tablename,
    outdata=sldat.&sl_table,
    outpdfpath=&lib_path./BW_Report&suffix..pdf,
    train_proportion=0.8,
    use_patient_split=0
);
