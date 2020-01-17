/*libname famdat "F:\Users\hinashah\SASFiles";
libname epic "F:\Users\hinashah\SASFiles\epic";

**** Path where the sas programs reside in ********;
%let Path= F:\Users\hinashah\SASFiles\USFAMLIData\FAMLI_Clinical;
*/

*Create a table with the studies that were not filled up by pndb;
proc sql;
create table lo_studies as
select *, coalesce(ga_lmp, ga_doc, ga_edd, ga_unknown, ga_extrap) as ga
from famdat.b1_biom where filename not in
(select filename from famdat.b1_maternal_info_pndb);

create table epic_maternal_info as
select distinct a.filename, a.PatientID, a.studydttm, a.ga, b.episode_working_edd, b.birth_date as mom_birth_date format mmddyy10.
from 
lo_studies as a left join epic.ob_dating as b on
(a.PatientID = b.pat_mrn_id) and (b.episode_working_edd > datepart(a.studydttm) ) 
and (b.episode_working_edd < (datepart(a.studydttm) + (300-a.ga)));
quit;

data epic_maternal_info;
set epic_maternal_info;
if not missing(episode_working_edd) and not missing(mom_birth_date) then
do;
	mom_age_edd = yrdif(mom_birth_date, episode_working_edd, 'AGE');
	format mom_age_edd 3.2;
end;

if not missing(episode_working_edd) then
do;
	DOC = episode_working_edd - 280;
	format DOC mmddyy10.;
end;
run;

/******************* HEIGHTS AND WEIGHT ******************/
%include "&Path/B1_Epic_height_and_weight.sas";

/******************* TOBACCO USE **************************/
%include "&Path/B1_Epic_tobacco_use.sas";

/******************* BIRTH WEIGHT AND GA AT BIRTH ******************/
%include "&Path/B1_Epic_birth_weight_ga.sas";

/*************************** Preprocessing for HIV, Diabetes and fetal grwoth restriction *********************/
%include "&Path/B1_Epic_preprocess.sas";

/******************* FETAL GROWTH RESTRICTION ******************/
%include "&Path/B1_Epic_fetal_growth_restriction.sas";

/******************* HIV ******************/
%include "&Path/B1_Epic_HIV.sas";

/******************* Diabetes and Gestational diabetes ******************/
%include "&Path/B1_Epic_diabetes.sas";

/******************* Hypertension (chronic and pregnancy induced) ******************/
%include "&Path/B1_Epic_hypertension.sas";


/****************** Create final table ******************/
proc sql;
create table famdat.&mat_info_epic_table. as
select * from epic_maternal_info where not missing(episode_working_edd) or not missing(mom_birth_date) or 
			mom_weight_oz > 0 or mom_height_in > 0 or not missing(tobacco_use) or not missing(fetal_growth_restriction) or 
			not missing(birth_wt_ounces) or hiv eq 1 or gest_diabetes eq 1 or diabetes eq 1 or chronic_htn eq 1 or preg_induced_htn eq 1;

/******************** FINAL STATS *************************/
proc sql;
create table counts as 
select filename, PatientID, ga, count(*) as cnt 
from epic_maternal_info 
group by filename, PatientID, ga;

%include "&Path/B1_Epic_stats.sas";
