/*
 * Get delivery dates and gestational ages and baby weight at birth from epic
 */

/******************* BIRTH WEIGHT AND GA AT BIRTH ******************/
proc sql;
*gather birth weight and ga days -> assumes that the study patients also delivered here.;
create table epic_maternal_info as
select distinct a.*, b.birth_wt_ounces, b.ga_days as birth_ga_days, datepart(b.delivery_dttm_utc) as delivery_date format mmddyy10.
from 
epic_maternal_info as a left join 
epic.delivery as b on
(a.PatientID = b.pat_mrn_id) and (b.estimate_delivery_date = a.episode_working_edd);
quit;
