
libname famdat '/folders/myfolders/';
libname epic '/folders/myfolders/epic';

*Create a table with the studies that were not filled up by pndb;
proc sql;
create table lo_studies as
select *, coalesce(ga_lmp, ga_doc, ga_edd, ga_unknown, ga_extrap) as ga
from famdat.b1_biom where filename not in
(select filename from famdat.b1_maternal_info);

create table epic_maternal_info as
select distinct a.filename, a.PatientID, a.studydttm, a.ga, b.episode_working_edd, b.birth_date
from 
lo_studies as a left join epic.ob_dating as b on
(a.PatientID = b.pat_mrn_id) and (b.episode_working_edd > datepart(a.studydttm) ) 
and (b.episode_working_edd < (datepart(a.studydttm) + (300-a.ga)));
quit;

data epic_maternal_info;
set epic_maternal_info;
if not missing(episode_working_edd) and not missing(birth_date) then
do;
	MomAgeEDD = yrdif(birth_date, episode_working_edd, 'AGE');
	format MomAgeEDD 3.2;
end;

if not missing(episode_working_edd) then
do;
	DOC = episode_working_edd - 280;
	format DOC mmddyy10.;
end;
run;

/******************* HEIGHTS AND WEIGHT PREPROCESSING - create a date of conception table ******************/
proc sql;
create table DOCs as
select distinct PatientID, DOC from epic_maternal_info where not missing(DOC);

/******************* WEIGHTS ******************/
* from the DOCs left join with weight and the date being before the first 8 weeks of the pregnancy;
proc sql;
create table before as
select distinct a.PatientID, a.DOC, b.weight_oz, b.recorded_time
from
DOCs as a left join epic.vitals as b on
a.PatientID = b.pat_mrn_id and b.recorded_time < DHMS(a.DOC,0,0,0)
where not missing(b.weight_oz) and not missing(b.recorded_time)
order by PatientID, DOC;

create table maxbefore as
select a.PatientID, a.DOC, a.weight_oz, b.max_date
from before as a
inner join 
(SELECT PatientID, DOC, MAX(recorded_time) as max_date
from before
GROUP BY PatientID, DOC) as b
on a.PatientID=b.PatientID and a.DOC=b.DOC and b.max_date = a.recorded_time and b.max_date > DHMS(a.DOC-365, 0,0,0);

create table after as
select distinct a.PatientID, a.DOC, b.weight_oz, b.recorded_time
from
DOCs as a left join epic.vitals as b on
a.PatientID = b.pat_mrn_id and b.recorded_time >= DHMS(a.DOC,0,0,0)
where not missing(b.weight_oz) and not missing(b.recorded_time)
order by PatientID, DOC;

create table minafter as
select a.PatientID, a.DOC, a.weight_oz, b.min_date
from after as a
inner join 
(SELECT PatientID, DOC, MIN(recorded_time) as min_date
from after
GROUP BY PatientID, DOC) as b
on a.PatientID=b.PatientID and a.DOC=b.DOC and b.min_date = a.recorded_time and b.min_date < DHMS(a.DOC+280,0,0,0);

proc sql;
create table weights as 
select coalesce(a.PatientID, b.PatientID) as PatientID, coalesce(a.DOC, b.DOC) as DOC format mmddyy10., 
coalesce(a.weight_oz, b.weight_oz) as weight_oz, datepart(coalesce(a.max_date, b.min_date)) as wt_rec_date format mmddyy10.
from maxbefore as a full join minafter as b
on a.PatientID = b.PatientID and a.DOC=b.DOC;

* Join with the maternal info dataset ;
create table epic_maternal_info as
select distinct a.*, b.weight_oz
from
epic_maternal_info as a left join weights as b 
on
a.PatientID=b.PatientID and a.DOC=b.DOC;

/******************* HEIGHTS ******************/
proc sql;
create table before as
select distinct a.PatientID, a.DOC, b.height_in, b.recorded_time
from
DOCs as a left join epic.vitals as b on
a.PatientID = b.pat_mrn_id and b.recorded_time < DHMS(a.DOC,0,0,0)
where not missing(b.height_in) and not missing(b.recorded_time)
order by PatientID, DOC;

create table maxbefore as
select a.PatientID, a.DOC, a.height_in, b.max_date
from before as a
inner join 
(SELECT PatientID, DOC, MAX(recorded_time) as max_date
from before
GROUP BY PatientID, DOC) as b
on a.PatientID=b.PatientID and a.DOC=b.DOC and b.max_date = a.recorded_time;

create table after as
select distinct a.PatientID, a.DOC, b.height_in, b.recorded_time
from
DOCs as a left join epic.vitals as b on
a.PatientID = b.pat_mrn_id and b.recorded_time >= DHMS(a.DOC,0,0,0)
where not missing(b.height_in) and not missing(b.recorded_time)
order by PatientID, DOC;

create table minafter as
select a.PatientID, a.DOC, a.height_in, b.min_date
from after as a
inner join 
(SELECT PatientID, DOC, MIN(recorded_time) as min_date
from after
GROUP BY PatientID, DOC) as b
on a.PatientID=b.PatientID and a.DOC=b.DOC and b.min_date = a.recorded_time;

proc sql;
create table heights as 
select coalesce(a.PatientID, b.PatientID) as PatientID, coalesce(a.DOC, b.DOC) as DOC format mmddyy10., 
coalesce(a.height_in, b.height_in) as height_in, datepart(coalesce(a.max_date, b.min_date)) as ht_rec_date format mmddyy10.
from maxbefore as a full join minafter as b
on 
a.PatientID = b.PatientID and a.DOC=b.DOC;

* Join with the maternal info dataset ;
create table epic_maternal_info as
select distinct a.*, b.height_in
from
epic_maternal_info as a left join heights as b 
on
a.PatientID=b.PatientID and a.DOC=b.DOC;

/******************* TOBACCO USE **************************/
proc sql;
*Get the tobacco use entries from the social_hx dataset;
create table tobacco_use as
select a.*, b.smoking_tob_use_c, b.tobacco_pak_per_dy, b.smoking_quit_date, b.contact_date
from
epic_maternal_info as a left join epic.social_hx as b 
on
a.PatientID = b.pat_mrn_id and b.contact_date <= datepart(a.studydttm)
where b.smoking_tob_use_c in ('CURRENT EVERY DAY SMOKER', 'NEVER SMOKER', 'FORMER SMOKER');

*Extract the most recent one before ultrasound;
create table tobacco_use_max as
select a.*
from tobacco_use as a
inner join 
(SELECT PatientID, studydttm, MAX(contact_date) as max_date
from tobacco_use
GROUP BY PatientID, studydttm) as b
on a.PatientID=b.PatientID and a.studydttm = b.studydttm and b.max_date = a.contact_date;

*Integrate back into epic_maternal_info;
create table tobacco_use_social_hx as
select a.*, b.smoking_tob_use_c, b.tobacco_pak_per_dy, b.smoking_quit_date, b.contact_date
from epic_maternal_info as a left join tobacco_use_max as b
on
a.PatientID = b.PatientID and a.studydttm = b.studydttm;

proc sql;
*For rest of the patients extract diagnoses from the diagnosis dataset, and count the number of times the diagnoses
were entered;
create table occurence_counts as 
select distinct PatientID, studydttm, filename, count(*) as icd_count, 'Diagnosed Nicotine User' as smoking_tob_use_c 
from 
( /* List studies with acceptable ICD codes during the pregnancy duration of the study */
select distinct a.*, b.contact_date as contact_date_diag format mmddyy10., b.ref_bill_code 
from
epic_maternal_info as a inner join epic.diagnosis as b
on
a.PatientID = b.pat_mrn_id and prxmatch('/^(F17|305\.1).*/', ref_bill_code)=1 and 
b.contact_date <= a.episode_working_edd and
b.contact_date >= a.DOC
where a.PatientID in 
(
select PatientID from tobacco_use_social_hx where missing(smoking_tob_use_c)
)
) 
group by PatientID, studydttm; 

*Count the number of times the ICD9 codes were entered before an us and extract rows with count > 2;
*Coalesce/merge based on the findings;
create table epic_maternal_info as 
select a.filename, a.PatientID, a.studydttm, a.ga, a.episode_working_edd, a.birth_date, a.MomAgeEDD, a.DOC,
a.weight_oz, a.height_in, coalesce(a.smoking_tob_use_c, b.smoking_tob_use_c) as tobacco_use, a.tobacco_pak_per_dy, datepart(a.studydttm) - a.smoking_quit_date as smoking_quit_days
from
tobacco_use_social_hx as a left join 
occurence_counts as b
on 
a.PatientID = b.PatientID and a.studydttm = b.studydttm and b.icd_count > 1;

/******************* BIRTH WEIGHT AND GA AT BIRTH ******************/
proc sql;
*gather birth weight and ga days -> assumes that the study patients also delivered here.;
*This actually should not be the case. Should create separate tables for the other fields and do full join;
create table epic_maternal_info as
select distinct a.*, b.birth_wt_ounces, b.ga_days as birth_ga_days
from 
epic_maternal_info as a left join 
epic.delivery as b on
(a.PatientID = b.pat_mrn_id) and (b.estimate_delivery_date = a.episode_working_edd);
quit;

/*************************** Preprocessing for HIV, Diabetes and fetal grwoth restriction *********************/
*Creating boolean columns for HIV, Diabetes, Gestational diabetes and fetal growth restriction from the diagnosis table;
*These booleans are encounter based;
*These will be converted to pregnancy diagnoses at a later stage;
proc sql;
create table epic_diagnosis_pre as 
select pat_mrn_id, study_id, contact_date, ref_bill_code, icd_code_set, dx_name, 
find(dx_name, 'poor fetal growth', 'i') > 0 as fetal_growth_restriction,
(find(dx_name, 'human immunodeficiency virus', 'i') >0 and prxmatch('/^(B20|042|O98\.7|V08|Z21).*/', ref_bill_code)) as hiv, 
prxmatch('/^(E08|E09|E10|E11|E13|O24\.0|O24\.1|O24\.3|O24\.8|250|648\.0).*/', ref_bill_code) as diabetes,
prxmatch('/^(O24\.4|648\.83).*/', ref_bill_code) as gest_diabetes from epic.diagnosis;
quit;

/******************* FETAL GROWTH RESTRICTION ******************/
proc sql;
create table epic_maternal_info as
select distinct a.*, b.fetal_growth_restriction 
from
epic_maternal_info as a left join 
epic_diagnosis_pre as b 
on
(a.PatientID = b.pat_mrn_id) and 
(b.contact_date >= (a.episode_working_edd - 280)) and 
(b.contact_date <= datepart(a.studydttm)) and
b.fetal_growth_restriction = 1
order by a.PatientID;
quit;

/******** Change encoding? *********/
libname epic_asc '/folders/myfolders/epic_asc'  ;
proc copy noclone in=epic out=epic_asc;
   select medications;
run;

/******************* HIV ******************/
*Get labs;
proc sql;
create table hiv_labs as
select * from epic.labs where 
find(lab_name, 'HIV', 'i') > 0;

*Get medications;
proc sql;
create table hiv_medications as 
select * from epic.medications where med_name in 
('Emtricitabine', 'Dolutegravir', 'Tenofovir', 'Truvada', 
'Ritonavir', 'Darunavir', 'Raltegravir', 'Norvir', 'Prezista', 'Lamivudine', 'Zidovudine');

*Get ICD code counts;

*put everything together;

/******************* Diabetes ******************/


/******************* Gestational Diabetes ******************/

/******************** FINAL STATS *************************/
proc sql;
create table counts as 
select filename, PatientID, ga, count(*) as cnt 
from epic_mat_info_fetgwth 
group by filename, PatientID, ga;
