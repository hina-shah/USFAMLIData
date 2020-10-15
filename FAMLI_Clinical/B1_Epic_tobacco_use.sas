
/*
* Script to extract maternal tobacco use information before pregnancy from the Epic datasets.
* Assumes that the epic_maternal_info exists in the work library.
*/

/******************* TOBACCO USE **************************/

proc sql;
create table patstudies as
select distinct PatientID, studydate, episode_working_edd
from epic_maternal_info;

proc sql;
*Get the tobacco use entries from the social_hx dataset;
create table tobacco_use as
	select distinct a.*, 
			case b.smoking_tob_use_c
                when 'CURRENT EVERY DAY SMOKER' then 'CURRENT SMOKER'
                when 'CURRENT SOME DAY SMOKER' then 'CURRENT SMOKER'
				when 'FORMER SMOKER' then 'FORMER SMOKER'
				when 'HEAVY TOBACCO SMOKER' then 'CURRENT SMOKER'
				when 'LIGHT TOBACCO SMOKER' then 'CURRENT SMOKER'
				when 'NEVER SMOKER' then 'NEVER SMOKER'
				when 'PASSIVE SMOKE EXPOSURE - NEVER SMOKER' then 'NEVER SMOKER'
				when 'NEVER ASSESSED' then ''
				when 'SMOKER, CURRENT STATUS UNKNOWN' then ''
				when 'UNKNOWN IF EVER SMOKED' then ''
                else ''
                end as smoking_tob_use_c,
			b.tobacco_pak_per_dy, b.smoking_quit_date, b.contact_date
	from
		patstudies as a 
		left join 
		epic.social_hx as b
	on
		a.PatientID = b.pat_mrn_id
		and b.contact_date <= a.episode_working_edd
;

*Extract the most recent one before ultrasound;
create table tobacco_use_max as
	select a.*
	from 
		tobacco_use as a
		inner join
		(
			SELECT PatientID, studydate, MAX(contact_date) as max_date
			from tobacco_use
			where not missing(smoking_tob_use_c)
			GROUP BY PatientID, studydate
		) as b
	on 
		a.PatientID = b.PatientID and
		a.studydate = b.studydate and 
		b.max_date = a.contact_date
;

data tobacco_use_max;
set tobacco_use_max;
row = _n_;
run;

* Even with the same date use the latest intry in the table. ;
proc sql;
create table tobacco_use_max as
	select distinct a.*
		from 
			tobacco_use_max as a 
			inner join 
			( 
				select PatientID, studydate, max(row) as max_line
				from tobacco_use_max
				group by PatientID, studydate
			) as b
		on 
			a.PatientID = b.PatientID and 
			a.studydate = b.studydate and
			a.row = b.max_line
;


*Integrate back into epic_maternal_info;
create table tobacco_use_social_hx as
	select distinct a.*, b.smoking_tob_use_c, b.tobacco_pak_per_dy, b.smoking_quit_date, b.contact_date
	from 
		epic_maternal_info as a 
		left join 
		tobacco_use_max as b
	on
		a.PatientID = b.PatientID and 
		a.studydate = b.studydate
;

proc freq data = tobacco_use_social_hx;
tables smoking_tob_use_c/missing;
run;

proc sql;
select count(*) from (select distinct PatientID from tobacco_use_social_hx where missing(smoking_tob_use_c));


proc sql;
*For rest of the patients extract diagnoses from the diagnosis dataset, and count the number of times the diagnoses
were entered;
create table occurence_counts as
	select distinct PatientID, studydate, filename, count(*) as icd_count, 
		'Diagnosed Nicotine User' as smoking_tob_use_c
	from
	( /* List studies with acceptable ICD codes during the pregnancy duration of the study */
		select distinct a.*, b.effective_date_dt as contact_date_diag format mmddyy10., b.ref_bill_code
		from
			epic_maternal_info as a 
			inner join 
			epic.diagnosis as b
		on
			a.PatientID = b.pat_mrn_id and 
			prxmatch('/^(F17|305\.1|O99\.3|Z71\.6|Z72\.0).*/', ref_bill_code)=1 and
			b.effective_date_dt <= a.episode_working_edd and
			b.effective_date_dt >= a.DOC
		where a.PatientID in
			(
				select PatientID 
				from tobacco_use_social_hx 
				where missing(smoking_tob_use_c)
			)
	)
	group by PatientID, studydate
;



data occurence_counts;
set occurence_counts;
if icd_count >1 then output;
run;

*Count the number of times the ICD9 codes were entered before an us and extract rows with count > 2;
*Coalesce/merge based on the findings;
proc sql;
create table epic_maternal_info as
	select distinct  a.filename, 
		a.PatientID, 
		a.studydate, 
		a.ga, 
		a.episode_working_edd, 
		a.mom_birth_date, 
		a.mom_age_edd, 
		a.DOC,
		a.mom_weight_oz, 
		a.mom_height_in, 
		coalesce(a.smoking_tob_use_c, b.smoking_tob_use_c) as tobacco_use,
		a.tobacco_pak_per_dy as tobacco_pak_per_day,
		a.studydate - a.smoking_quit_date as smoking_quit_days
	from
		tobacco_use_social_hx as a 
		left join
		occurence_counts as b
	on
		a.PatientID = b.PatientID and 
		a.studydate = b.studydate and 
		a.filename = b.filename 
;

title 'Frequencie on tobacco use diagnoses';
proc freq data = epic_maternal_info;
tables tobacco_use/missing;
run;
title;
proc sql;
select 'Number of patients with missing tobacco use info:', count(*) from (select distinct PatientID from epic_maternal_info where missing(tobacco_use));
