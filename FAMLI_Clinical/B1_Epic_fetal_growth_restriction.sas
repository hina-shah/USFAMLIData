/******************* FETAL GROWTH RESTRICTION ******************/
proc sql;
create table epic_maternal_info as
select distinct a.*, b.fetal_growth_restriction
from
epic_maternal_info as a left join
epic_diagnosis_pre as b
on
(a.PatientID = b.pat_mrn_id) and
(b.contact_date >= (a.episode_working_edd - &ga_cycle.)) and
(b.contact_date <= a.studydate) and
b.fetal_growth_restriction = 1
order by a.PatientID;
quit;
