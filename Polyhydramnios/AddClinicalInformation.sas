/********** Other clinical information from EPIC & PNDB***********/

/** Get the delivery columns **/
proc sql;
create table epic_delivery_columns as
select pat_mrn_id, episode_id, delivery_dttm_utc, 
	prxmatch('/meconium/', lower(delivery_complication_list)) > 0 as meconium,
	prxmatch('/cord prolapse/', lower(delivery_complication_list)) > 0 as cord_prolapse,
	case 
		when prxmatch('/c-section/', lower(delivery_method)) > 0 then 'C-SECTION'
		when prxmatch('/(vaginal, spontaneous)|(vbac, spontaneous)/', lower(delivery_method)) >0 then 'VAGINAL'
		when prxmatch('/(vaginal, forceps)|(vbac, forceps)/', lower(delivery_method)) > 0 
				or forceps_use = 'Y' then 'FORCEPS'
		when prxmatch('/(vaginal, vacuum)|(vbac, vacuum)/', lower(delivery_method)) > 0 
				or vacuum_use = 'Y' then 'VACUUM'
		when prxmatch('/vaginal, breech/', lower(delivery_method)) > 0 then 'BREECH'
		else 'OTHER' 
	end as delivery_method,
	case
		when prxmatch('/dry and stimulate/', lower(delivery_resusitation_list))>0 then 'DRY AND STIMULATE'
		when prxmatch('/suctioning/', lower(delivery_resusitation_list))>0 then 'SUCTIONING'
		when prxmatch('/intubation/', lower(delivery_resusitation_list))>0 then 'INTUBATION'
		when prxmatch('/oxygen/', lower(delivery_resusitation_list))>0 then 'OXYGEN'
		when prxmatch('/ppv/', lower(delivery_resusitation_list))>0 then 'PPV'
		when prxmatch('/epinephrine/', lower(delivery_resusitation_list))>0 then 'EPINEPHRINE'
		when prxmatch('/umbilical catheter/', lower(delivery_resusitation_list))>0 then 'UMBILICAL CATHETHER'
		when prxmatch('/surfactant/', lower(delivery_resusitation_list))>0 then 'SURFACTANT'
		when prxmatch('/volume expansion/', lower(delivery_resusitation_list))>0 then 'VOLUME EXPANSION'
		when prxmatch('/naloxone/', lower(delivery_resusitation_list))>0 then 'NALOXONE'
		else 'OTHER'
	end as delivery_resusitation,
	delivery_blood_loss, 
	apgar1, apgar5, 
	living_status,
	baby_icu_yn
from epic.delivery
;

/** Get the diagnosis information **/ /* during pregnancy*/
proc sql;
create table epic_del_diagnosis_pre as
	select pat_mrn_id, effective_date_dt,
		prxmatch('/O42/', ref_bill_code) >0  as prem_rupture,
		prxmatch('/P96.83|779.84/', ref_bill_code)>0 as meconium_diag
	from epic.diagnosis;
quit;

/** Induction of labor from procedures**/ /* within 72 hours of delivery*/
proc sql;
create table labor_induction_table as
select distinct pat_mrn_id, service_date, prxmatch('/3E033VJ/', procedure_code) > 0 as labor_induction 
	from epic.procedures
	where  prxmatch('/3E033VJ/', procedure_code) > 0;

/** Glucose treatment medications **/ /* during the pregnancy */
proc sql;
create table glucose_medications as 
select distinct pat_mrn_id, order_inst, 
		prxmatch('/insulin/', lowcase(med_name)) > 0 as insulin,
		prxmatch('/glyburide/', lowcase(med_name)) > 0 as glyburide,
		prxmatch('/metformin/', lowcase(med_name)) > 0 as metformin
	from
            epic.medications
            where
                prxmatch('/insulin|glyburide|metformin/', lowcase(med_name)) > 0 and
                prxmatch('/outpatient|discharge/', lowcase(med_type)) > 0
;

/*** Congentical anomalies ***/ /* during pregnancy and after (4 weeks) */
proc sql;
create table congenital_anomalies as
select distinct mom_mrn_id, effective_date_dt, prxmatch('/^Q[0-9]*/', ref_bill_code) > 0 as anomalies
	from epic.neo_diagnosis
	where prxmatch('/^Q[0-9]*/', ref_bill_code) > 0
;

/**** PNDB data ****/
%let pndb_table = pndb_famli_records_with_matches;
data pndb_preprocess (keep= HospNum Mom_EpicMRN MRN delivery_date delivery_method delivery_blood_loss);
set famdat.&pndb_table;

format delivery_date mmddyy10.;
if not missing(Mom_EpicMRN) then
	MRN = put(input(Mom_EpicMRN, best12.), z12.);
delivery_date = M_PDT0107;
if V_LAD0702 =1 or W_LAD0705=1 then delivery_method = 'C-SECTION';
else if V_LAD0702=0 and W_LAD0705=0 then delivery_method = 'VAGINAL';
delivery_blood_loss = C_CLD0304;

if not missing(Mom_EpicMRN) then output;
run;

/***** Combine EPIC and PNDB ****/
proc sql;
create table pndb_epic_delivery_data as 
	select coalesce(a.pat_mrn_id, b.MRN) as PatientID, coalesce( datepart(a.delivery_dttm_utc), b.delivery_date) as delivery_date format mmddyy10.,
	coalesce(a.delivery_method, b.delivery_method) as delivery_method, coalesce(a.delivery_blood_loss, b.delivery_blood_loss) as delivery_blood_loss,
	a.meconium, a.cord_prolapse, a.delivery_resusitation, a.apgar1, a.apgar5, a.living_status, a.baby_icu_yn
	from 
		epic_delivery_columns as a
		full join
		pndb_preprocess as b
	on a.pat_mrn_id = b.MRN and datepart(a.delivery_dttm_utc) =b.delivery_date
;

/********* Add information to the clinical data table **********/

proc sql;
create table poly_b1_maternal_info as
select distinct a.filename, a.PatientID, a.studydate, a.ga_from_edd, a.delivery_date, a.birth_wt_gms, a.birth_ga_days, 
	a.chronic_htn, a.preg_induced_htn, a.diabetes, a.gest_diabetes,
	b.delivery_method, b.delivery_blood_loss, b.meconium, b.cord_prolapse, b.delivery_resusitation, b.apgar1, b.apgar5, b.living_status, b.baby_icu_yn
from 
	famdat.poly_b1_maternal_info as a 
	left join
	pndb_epic_delivery_data as b 
on 
	a.PatientID = b.PatientID 
	and a.delivery_date = b.delivery_date
;

/******** Add rest of the information (glucose medication, congenital anomalies, labor induction, prolapsed_cord ****/
proc sql;
create table mat_info_labor as 
select distinct a.*, b.labor_induction
from 
	poly_b1_maternal_info as a 
	left join
	labor_induction_table as b
on
	a.PatientID = b.pat_mrn_id and
	abs(a.delivery_date - b.service_date) <=3
;
update mat_info_labor
	set labor_induction = 0
	where missing(labor_induction)
;

/* Get meconium and premature rupture diagnoses*/
proc sql;
create table del_mec_prem as
select distinct PatientID, delivery_date, sum(prem_rupture) > 0 as prem_rupture, sum(meconium_diag) > 0 as meconium_diag
from 
	(
		select distinct a.PatientID, a.delivery_date, b.prem_rupture, b.meconium_diag
		from
			mat_info_labor as a
			left join
			epic_del_diagnosis_pre as b 
		on a.PatientID = b.pat_mrn_id and 
			b.effective_date_dt <= a.delivery_date and 
			b.effective_date_dt >= (a.delivery_date - a.birth_ga_days) and
			(b.prem_rupture=1 or b.meconium_diag=1)	
	)
group by PatientID, delivery_date;


proc sql;
create table del_anomalies as
select distinct PatientID, delivery_date, sum(anomalies) > 0 as congenital_anomalies
from 
	(
		select distinct a.PatientID, a.delivery_date, b.anomalies
		from
			mat_info_labor as a
			left join
			congenital_anomalies as b 
		on a.PatientID = b.mom_mrn_id and 
			b.effective_date_dt <= a.delivery_date +28 and 
			b.effective_date_dt >= (a.delivery_date - a.birth_ga_days)
	)
group by PatientID, delivery_date;

proc sql;
create table del_medications as
select distinct PatientID, delivery_date, sum(insulin) > 0 as insulin, sum(glyburide) > 0 as glyburide,
		sum(metformin) > 0 as metformin
from 
	(
		select distinct a.PatientID, a.delivery_date, b.insulin, b.glyburide, b.metformin
		from
			mat_info_labor as a
			left join
			glucose_medications as b 
		on a.PatientID = b.pat_mrn_id and 
			b.order_inst <= a.delivery_date and 
			b.order_inst >= (a.delivery_date - a.birth_ga_days) and
			(b.insulin=1 or b.glyburide=1 or b.metformin=1) and
			(a.gest_diabetes=1 or a.diabetes=1)
	)
group by PatientID, delivery_date;

proc sql;
create table mec_prem_anomalies as
select a.*, b.*
	from 
		del_mec_prem as a 
		full join
		del_anomalies as b
	on
		a.PatientID = b.PatientID
		and a.delivery_date = b.delivery_date
;

proc sql;
create table famdat.clinical_all_together as
select distinct a.filename, a.PatientID, a.studydate, a.ga_from_edd, a.delivery_date, a.birth_wt_gms, a.birth_ga_days, 
	a.chronic_htn, a.preg_induced_htn, a.diabetes, a.gest_diabetes,
	a.delivery_method, a.delivery_blood_loss, a.cord_prolapse, a.delivery_resusitation, a.labor_induction, a.apgar1, a.apgar5,
	a.living_status, a.baby_icu_yn, coalesce(a.meconium, b.meconium_diag) as meconium, 
	b.prem_rupture,  b.congenital_anomalies
from 
	mat_info_labor as a
	left join
	mec_prem_anomalies as b
on
	a.PatientID = b.PatientID
	and a.delivery_date = b.delivery_date
;

proc sql;
create table famdat.poly_with_afi_mvp_clinical as
select distinct
	o.*,  a.delivery_date, a.birth_wt_gms, a.birth_ga_days, 
	a.chronic_htn, a.preg_induced_htn, a.diabetes, a.gest_diabetes,
	a.delivery_method, a.delivery_blood_loss, a.cord_prolapse, a.delivery_resusitation, a.labor_induction, a.apgar1, a.apgar5,
	a.living_status, a.baby_icu_yn, a.meconium, 
	a.prem_rupture,  a.congenital_anomalies
from famdat.polyhydramnios_with_afi_mvp as o
	left join 
	famdat.clinical_all_together as a
on
	o.PatientID = a.PatientID 
	and a.filename = o.filename
;


