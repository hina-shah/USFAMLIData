/*
 * Script to extract maternal hypertension and pregnancy induced hypertension information
 * from the Epic dataset.
 * Assuming existence of epic_maternal_info dataset along with the EPIC library
 */


* Preprocess the vitals dataset;
data bp_vitals (keep=pat_mrn_id recorded_time high_bp low_bp hypertension);
set epic.vitals;
if not missing(blood_pressure) then do;
	pos = find(blood_pressure, '/');
	high_bp = input( substr(blood_pressure, 1, pos-1), 8.);
	low_bp = input(substr(blood_pressure, pos+1), 8.);
	hypertension = high_bp > 140 and low_bp > 90;
end;
run;

/******************* Chronic Hypertension ******************/

/* Chronic hypertension
Any 2 instances of the following before ultrasound, but not in previous pregnancy + 6 weeks:
	* Any medication from 'labetalol tablet', 'nifedipine ER,' 'methyldopa', or 'hydrochlorothiazide'
		prescribed outpatient
	* 2 occurrences of ICD codes for under hypertension
	* at least 2 occurrences of elevated blood pressures prior to 24 hrs of delivery
*/

/*
*Get labs;
proc sql;
create table with_prev as
select a.filename, a.PatientID, a.studyate, a.DOC, a.delivery_date,
	 b.lab_name, b.result, datepart(b.result_time) as result_time format mmddyy10. from
epic_maternal_info as a inner join
(
select distinct * from labs_pre where
(prxmatch('/(protein\/creat ratio)/', lowcase(result_test_name)) > 0 and result_num>0.3)
) as b on
(a.PatientID = b.pat_mrn_id) and
(datepart(b.result_time) >= (a.DOC)) and
(datepart(b.result_time) <= a.studydate) and
a.ga < 140
;

%deleteRecordsOfPrevPregnancies(inputtable=with_prev,outputtable=labs,datevariable=result_time);
*/

*Get medications;
proc sql;
create table with_prev as
select a.filename, a.PatientID, a.studydate, a.DOC, a.delivery_date,
	b.med_Name, datepart(b.order_inst) as order_inst format mmddyy10. from
epic_maternal_info as a inner join
(
select distinct * from
epic.medications
where
(prxmatch('/(labetalol.*tablet)|(nifedipine.*extended release)/', lowcase(medication_name)) >0 or
prxmatch('/(methyldopa)|(hydrochlorothiazide)/', lowcase(med_name)) > 0)
and
prxmatch('/outpatient/', lowcase(med_type)) > 0
) as b
on
(a.PatientID = b.pat_mrn_id) and
/*(datepart(b.order_inst) >= (a.DOC)) and */
(datepart(b.order_inst) <= a.studydate)
and a.ga < 140
;

%deleteRecordsOfPrevPregnancies(inputtable=with_prev,outputtable=medications,datevariable=order_inst);

*Get ICD code counts;
proc sql;
create table with_prev as
select a.*, b.chr_htn, b.contact_date from
epic_maternal_info as a inner join
epic_diagnosis_pre as b
on
(a.PatientID = b.pat_mrn_id) and
/*(b.contact_date >= (a.DOC)) and */
(b.contact_date <= a.studydate) and
b.chr_htn = 1 and
a.ga < 140;
%deleteRecordsOfPrevPregnancies(inputtable=with_prev,outputtable=diagnoses_excl,datevariable=contact_date);

proc sql;
create table diagnoses as
select filename, PatientID, studydate, sum(chr_htn) as count_occ
from
diagnoses_excl
group by PatientID, studydate, filename;

delete * from diagnoses where count_occ < 2;

* Get the high blood pressure vitals;
create table with_prev as
select a.*, b.hypertension, datepart(b.recorded_time) as recorded_time format mmddyy10. from
epic_maternal_info as a inner join
bp_vitals as b
on
(a.PatientID = b.pat_mrn_id) and
(datepart(b.recorded_time) <= a.studydate) and
(datepart(b.recorded_time) < a.delivery_date) and
b.hypertension = 1 and
a.ga < 140;

%deleteRecordsOfPrevPregnancies(inputtable=with_prev,outputtable=vitals_excl,datevariable=recorded_time);

proc sql;
create table vitals as
select filename, PatientID, studydate, sum(hypertension) as chr_htn_count_occ
from vitals_excl
group by PatientID, studydate, filename;

delete * from vitals where chr_htn_count_occ < 2;

*put everything together;
proc sql;
create table all_together as
select * from
diagnoses OUTER UNION CORR
    (select * from medications OUTER UNION CORR
        /*(select * from labs OUTER UNION CORR*/ select * from vitals /*)*/);

* Count number of rows per study -> which gives us study instances ;
create table per_study_counts as
select filename, PatientID, studydate, count(*) as count_per_study
from all_together
group by filename, PatientID, studydate;

* Left join into the main table;
create table epic_maternal_info as
select a.*, b.count_per_study >= 2 as chronic_htn from
epic_maternal_info as a left join
per_study_counts as b
on
a.PatientID = b.PatientID and
a.filename = b.filename and
a.studydate = b.studydate;

/******************* Gestational Hypertension ******************/
/* Pregnancy induced hypertension - this looks correct
Any 2 instances of the following in the last 20 weeks of pregnancy but before ultrasound :
	* Any medication from 'labetalol IV', 'nifedipine 10 mg capsule', 'hydralazine IV', or 'magnesium sulfate'
		as inpatient
	* 2 occurrences of ICD codes for under preeclampsia
	* at least 2 occurrences of elevated blood pressures prior to 24 hrs of delivery
	* positive labs
	* Also require that either a lab or a ICD code diagnoses is present before that study
*/

*Get labs;
proc sql;
create table labs as
select a.filename, a.PatientID, a.studydate, b.lab_name, b.result from
epic_maternal_info as a inner join
(
select distinct * from labs_pre where
(prxmatch('/(protein\/creat ratio)/', lowcase(result_test_name)) > 0 and result_num>0.3)
) as b on
(a.PatientID = b.pat_mrn_id) and
(datepart(b.result_time) >= (a.DOC)+140) and
(datepart(b.result_time) <= a.studydate) and
a.ga >= 140
;

create table labs_count as
select filename, PatientID, studydate, count(*) as labs_count
from
labs
group by filename, PatientID, studydate;

*Get medications;
proc sql;
create table medications as
select a.filename, a.PatientID, a.studydate, b.med_Name from
epic_maternal_info as a inner join
(
select distinct * from
epic.medications
where
(prxmatch('/(labetalol.*intravenous)|(nifedipine 10 mg capsule)|(hydralazine.*injection)/', lowcase(medication_name)) >0 or
prxmatch('/(magnesium sulfate)/', lowcase(med_name)) > 0) and prxmatch('/inpatient/', lowcase(med_type))>0
)as b
on
(a.PatientID = b.pat_mrn_id) and
(datepart(b.order_inst) >= (a.DOC)+140) and
(datepart(b.order_inst) <= datepart(a.studydate))
and a.ga >= 140
;

*Get ICD code counts;
proc sql;
create table diagnoses as
select filename, PatientID, studydate, sum(preg_htn) as count_occ
from
(
select a.*, b.preg_htn from
epic_maternal_info as a inner join
epic_diagnosis_pre as b
on
(a.PatientID = b.pat_mrn_id) and
(b.contact_date >= (a.DOC)+140) and
(b.contact_date <= a.studydate) and
b.preg_htn = 1 and
a.ga > 140)
group by PatientID, studydate, filename;

delete * from diagnoses where count_occ < 2;

* Get the high blood pressure vitals;
proc sql;
create table vitals as
select filename, PatientID, studydate, sum(hypertension) as htn_count_occ
from
(
select a.*, b.hypertension from
epic_maternal_info as a inner join
bp_vitals as b
on
(a.PatientID = b.pat_mrn_id) and
(datepart(b.recorded_time) >= (a.DOC)+140) and
(datepart(b.recorded_time) <= a.studydate) and
(datepart(b.recorded_time) < a.delivery_date) and
b.hypertension = 1 and
a.ga > 140)
group by PatientID, studydate, filename;

delete * from vitals where htn_count_occ < 2;

*put everything together;
proc sql;
create table all_together as
select * from
diagnoses OUTER UNION CORR
    (select * from medications OUTER UNION CORR
        (select * from labs OUTER UNION CORR select * from vitals));

* Count number of rows per study -> which gives us study instances ;
create table per_study_counts as
select filename, PatientID, studydate, count(*) as count_per_study
from all_together
group by filename, PatientID, studydate;

create table per_study_counts_with_diag_labs as
select a.*, b.count_occ from
per_study_counts as a left join diagnoses as b
on
a.PatientID = b.PatientID and
a.studydate = b.studydate and
a.filename = b.filename;

create table per_study_counts_with_diag_labs as
select a.*, b.labs_count from
per_study_counts_with_diag_labs as a left join labs_count as b
on
a.PatientID = b.PatientID and
a.studydate = b.studydate and
a.filename = b.filename;

* Left join into the main table;
create table epic_maternal_info as
select a.*,
(b.count_per_study >= 2 and (b.labs_count>=1 or b.count_occ >=2)) as preg_induced_htn from
epic_maternal_info as a left join
per_study_counts_with_diag_labs as b
on
a.PatientID = b.PatientID and
a.filename = b.filename and
a.studydate = b.studydate;
