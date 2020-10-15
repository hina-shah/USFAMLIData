
proc sql;
create table epic_maternal_info as 
    select distinct a.filename, a.PatientID, a.studydate,
            a.ga_edd as ga, a.episode_edd as episode_working_edd,
            b.birth_date as mom_birth_date format mmddyy10.
    from
        &ga_table. as a
        inner join 
        epic.ob_history as b
    on
        (a.PatientID = b.pat_mrn_id) 
		and not missing(a.episode_edd)
/*		and*/
/*        (a.episode_edd > b.episode_working_edd - 21) and*/
/*		(a.episode_edd < b.episode_working_edd + 21)*/
;
quit;

proc sql;
select 'Number studies with matched patients from EPIC: ', count(*) from epic_maternal_info;
select 'Number of patients here: ', count(*) from (select distinct PatientID from epic_maternal_info);
select 'Number of studies with missing birth dates: ', count(*) from epic_maternal_info where missing(mom_birth_date);

data epic_maternal_info;
set epic_maternal_info;
if not missing(episode_working_edd) and not missing(mom_birth_date) then
do;
    mom_age_edd = yrdif(mom_birth_date, episode_working_edd, 'AGE');
    format mom_age_edd 3.2;
end;

if not missing(episode_working_edd) then
do;

    DOC = episode_working_edd - &ga_cycle.;
    format DOC mmddyy10.;
end;
run;

/******************* HEIGHTS AND WEIGHT ******************/
%include "&ClinicalPath/B1_Epic_height_and_weight.sas";

/******************* TOBACCO USE **************************/
%include "&ClinicalPath/B1_Epic_tobacco_use.sas";

/******************* BIRTH WEIGHT AND GA AT BIRTH ******************/
%include "&ClinicalPath/B1_Epic_birth_weight_ga.sas";

/*************************** Preprocessing for HIV, Diabetes and fetal grwoth restriction *********************/
%include "&ClinicalPath/B1_Epic_preprocess.sas";

/******************* FETAL GROWTH RESTRICTION ******************/
%include "&ClinicalPath/B1_Epic_fetal_growth_restriction.sas";

/******************* HIV ******************/
%include "&ClinicalPath/B1_Epic_HIV.sas";

/******************* Diabetes and Gestational diabetes ******************/
%include "&ClinicalPath/B1_Epic_diabetes.sas";

/******************* Hypertension (chronic and pregnancy induced) ******************/
%include "&ClinicalPath/B1_Epic_hypertension.sas";

/****************** Create final table ******************/
proc sql;
create table &mat_info_epic_table. as
    select * 
    from epic_maternal_info 
    where 
        (
        not missing(episode_working_edd) or 
        not missing(mom_birth_date) or
        mom_weight_oz > 0 or 
        mom_height_in > 0 or 
        not missing(tobacco_use) or 
        not missing(fetal_growth_restriction) or
        not missing(birth_wt_gms) or 
        hiv eq 1 or 
        gest_diabetes eq 1 or 
        diabetes eq 1 or 
        chronic_htn eq 1 or 
        preg_induced_htn eq 1
        )
;

/******************** FINAL STATS *************************/
proc sql;
create table counts as
    select filename, PatientID, ga, count(*) as cnt
    from epic_maternal_info
    group by filename, PatientID, ga
;
