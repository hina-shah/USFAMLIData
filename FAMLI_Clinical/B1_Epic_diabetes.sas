/******************* Diabetes ******************/
/*
 * Any 1 instance of the following anytime before the study except for previous pregnancies + 6 weeks
 	* Positive result for beta hydroxybutyrate lab
 	* Positive result for A1c lab
 	* Medication use of insulin or glyburide prescribed outpatient
 	* At least 2 instances of diagnoses codes. 
 */


*Get labs;
proc sql;
create table with_prev as
	select a.filename, a.PatientID, a.studydate, a.DOC, a.delivery_date,
		b.lab_name, b.result, datepart(b.result_time) as result_time format mmddyy10. 
	from
		epic_maternal_info as a 
		inner join
		(
			select distinct * from labs_pre where
			(prxmatch('/hydroxybutyrate/', lowcase(lab_name)) > 0 and result_num>0.5) or
			(prxmatch('/a1c/', lowcase(lab_name)) > 0 and result_num>6.5)
		) as b 
	on
		(a.PatientID = b.pat_mrn_id) and
		(datepart(b.result_time) <= a.studydate) and
		a.ga < 140
;

%deleteRecordsOfPrevPregnancies(inputtable=with_prev,outputtable=labs,datevariable=result_time);


*Get medications;
proc sql;
create table with_prev as
	select a.filename, a.PatientID, a.studydate, a.DOC, a.delivery_date,
		b.med_Name, datepart(b.order_inst) as order_inst format mmddyy10. 
	from
		epic_maternal_info as a 
		inner join
		(
			select distinct * from
			epic.medications
			where
				prxmatch('/insulin|glyburide|metformin/', lowcase(med_name)) > 0 and
				prxmatch('/outpatient/', lowcase(med_type)) > 0
		) as b
	on
		(a.PatientID = b.pat_mrn_id) and
		(datepart(b.order_inst) <= a.studydate)
		and a.ga < 140
;

%deleteRecordsOfPrevPregnancies(inputtable=with_prev,outputtable=medications,datevariable=order_inst);


*Get ICD code counts and remove the ones occuring in previous pregnancies + 6 weeks (see macro);
proc sql;
*Get all diagnoses including previous pregnancies;
create table with_prev as
	select a.*, b.effective_date_dt, b.diabetes 
	from
		epic_maternal_info as a 
		inner join
		epic_diagnosis_pre as b
	on
		(a.PatientID = b.pat_mrn_id) and
		(b.effective_date_dt <= a.studydate) and
		b.diabetes = 1 and
		a.ga < 140
;

%deleteRecordsOfPrevPregnancies(inputtable=with_prev,outputtable=diagnoses_excl,datevariable=effective_date_dt);

proc sql;
create table diagnoses as
	select filename, PatientID, studydate, DOC, delivery_date, sum(diabetes) as count_occ
	from diagnoses_excl
	group by PatientID, studydate, filename;

delete * from diagnoses where count_occ < 2;

*put everything together;
proc sql;
create table all_together as
	select * from
	diagnoses OUTER UNION CORR
	    (select * from medications OUTER UNION CORR
	        select * from labs)
;

proc sql;
* Count number of rows per study -> which gives us study instances ;
create table per_study_counts as
	select filename, PatientID, studydate, count(*) as count_per_study
	from all_together
	group by filename, PatientID, studydate;

* Left join into the main table and keep when there are at least
	2 instances per study;
create table epic_maternal_info as
	select a.*, b.count_per_study >= 1 as diabetes 
	from
		epic_maternal_info as a 
		left join
		per_study_counts as b
	on
		a.PatientID = b.PatientID and
		a.filename = b.filename and
		a.studydate = b.studydate
;


/******************* Gestational Diabetes ******************/
/*
 * Any 1 instance of in the last 20 weeks of pregnancy before ultrasound:
 	* Positive result for beta hydroxybutyrate lab
 	* Positive result for A1c lab
 	* Medication use of insulin or glyburide prescribed outpatient
	* At least 2 instances of diagnoses codes. 
 */

*Get labs;
proc sql;
create table labs as
	select a.filename, a.PatientID, a.studydate, b.lab_name, b.result 
	from
		epic_maternal_info as a 
		inner join
		(
			select distinct * from labs_pre 
			where
				(prxmatch('/hydroxybutyrate/', lowcase(lab_name)) > 0 and result_num>0.5) or
				(prxmatch('/a1c/', lowcase(lab_name)) > 0 and result_num>6.5)
		) as b 
	on
		(a.PatientID = b.pat_mrn_id) and
		(datepart(b.result_time) >= (a.DOC + 140)) and
		(datepart(b.result_time) <= a.studydate) and
		a.ga >= 140
;

*Get medications;
proc sql;
create table medications as
	select a.filename, a.PatientID, a.studydate, b.med_Name 
	from
		epic_maternal_info as a 
		inner join
		(
			select distinct * 
			from
			epic.medications
			where
				prxmatch('/insulin|glyburide|metformin/', lowcase(med_name)) > 0 and
				prxmatch('/outpatient/', lowcase(med_type)) > 0
		) as b
	on
		(a.PatientID = b.pat_mrn_id) and
		(datepart(b.order_inst) >= (a.DOC + 140)) and
		(datepart(b.order_inst) <= a.studydate)
		and a.ga >= 140
;

*Get ICD code counts;
proc sql;
create table diagnoses as
	select filename, PatientID, studydate, sum(gest_diabetes) as count_occ
	from
	(
		select a.*, b.gest_diabetes 
		from
			epic_maternal_info as a 
			inner join
			epic_diagnosis_pre as b
		on
			(a.PatientID = b.pat_mrn_id) and
			(b.effective_date_dt >= (a.DOC + 140)) and
			(b.effective_date_dt <= a.studydate) and
			b.gest_diabetes = 1 and
			a.ga >= 140
	)
	group by PatientID, studydate, filename;
	
delete * from diagnoses where count_occ < 2;

*put everything together;
proc sql;
create table all_together as
select * from
diagnoses OUTER UNION CORR
    (select * from medications OUTER UNION CORR
        select * from labs);

* Count number of rows per study -> which gives us study instances ;
create table per_study_counts as
	select filename, PatientID, studydate, count(*) as count_per_study
	from all_together
	group by filename, PatientID, studydate;

* Left join into the main table;
create table epic_maternal_info as
	select a.*, b.count_per_study >= 1 as gest_diabetes 
	from
		epic_maternal_info as a 
		left join
		per_study_counts as b
	on
		a.PatientID = b.PatientID and
		a.filename = b.filename and
		a.studydate = b.studydate
;
	