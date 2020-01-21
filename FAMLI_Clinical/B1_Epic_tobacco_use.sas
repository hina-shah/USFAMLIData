
/*
* Script to extract maternal tobacco use information before pregnancy from the Epic datasets.
* Assumes that the epic_maternal_info exists in the work library.
*/

/******************* TOBACCO USE **************************/
proc sql;
*Get the tobacco use entries from the social_hx dataset;
create table tobacco_use as
select a.*, b.smoking_tob_use_c, b.tobacco_pak_per_dy, b.smoking_quit_date, b.contact_date
from
epic_maternal_info as a left join epic.social_hx as b
on
a.PatientID = b.pat_mrn_id and b.contact_date <= a.studydate
where b.smoking_tob_use_c in ('CURRENT EVERY DAY SMOKER', 'NEVER SMOKER', 'FORMER SMOKER');

*Extract the most recent one before ultrasound;
create table tobacco_use_max as
select a.*
from tobacco_use as a
inner join
(SELECT PatientID, studydate, MAX(contact_date) as max_date
from tobacco_use
GROUP BY PatientID, studydate) as b
on a.PatientID=b.PatientID and a.studydate = b.studydate and b.max_date = a.contact_date;

*Integrate back into epic_maternal_info;
create table tobacco_use_social_hx as
select a.*, b.smoking_tob_use_c, b.tobacco_pak_per_dy, b.smoking_quit_date, b.contact_date
from epic_maternal_info as a left join tobacco_use_max as b
on
a.PatientID = b.PatientID and a.studydate = b.studydate;

proc sql;
*For rest of the patients extract diagnoses from the diagnosis dataset, and count the number of times the diagnoses
were entered;
create table occurence_counts as
select distinct PatientID, studydate, filename, count(*) as icd_count, 'Diagnosed Nicotine User' as smoking_tob_use_c
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
group by PatientID, studydate;

*Count the number of times the ICD9 codes were entered before an us and extract rows with count > 2;
*Coalesce/merge based on the findings;
create table epic_maternal_info as
select a.filename, a.PatientID, a.studydate, a.ga, a.episode_working_edd, a.mom_birth_date, a.mom_age_edd, a.DOC,
a.mom_weight_oz, a.mom_height_in, coalesce(a.smoking_tob_use_c, b.smoking_tob_use_c) as tobacco_use,
a.tobacco_pak_per_dy as tobacco_pak_per_day, a.studydate - a.smoking_quit_date as smoking_quit_days
from
tobacco_use_social_hx as a left join
occurence_counts as b
on
a.PatientID = b.PatientID and a.studydate = b.studydate and b.icd_count > 1;
