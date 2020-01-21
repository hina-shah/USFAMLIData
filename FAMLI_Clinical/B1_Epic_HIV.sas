/******************* HIV ******************/
/*
 * LOGIC:
 * I have to look for any 2 instances of:
 * any lab that contains HIV with a positive result during pregnancy prior to the ultrasound
 * any lab with HIV RNA Quant with a positive result during pregnancy prior to the ultrasound
 * HIV RNA Quant ordered more than once (no matter the result?​) during pregnancy prior to the ultrasound. Yes, because a patient could have an undetectable viral load through the whole pregnancy so it could always be negative. And this is just one criteria, because they need two instances.
 * 2 instances of ICD diagnoses codes logged during pregnancy prior to the ultrasound
 * Any medication ordered prior to the ultrasound.
 */

*Get labs;
proc sql;
create table labs as
select a.filename, a.PatientID, a.studydate, b.lab_name, b.result from
epic_maternal_info as a inner join
(
select distinct * from labs_pre where
(prxmatch('/HIV/', lab_name) > 0 and prxmatch('/^(positive|reactive|detected)/', lowcase(result)) eq 1) or
(prxmatch('/^(HIV RNA, QUANT)/', upcase(lab_name) ) > 0 and not missing(result_num))
) as b on
(a.PatientID = b.pat_mrn_id) and
(datepart(b.result_time) >= (a.DOC)) and
(datepart(b.result_time) <= a.studydate)
;

* Get counts for RNA Quant orders;
create table rna_quant_counts as
select filename, PatientID, studydate, sum(hiv_orders) as hiv_quant_count_occ
from
(
select a.*, b.hiv_orders from
epic_maternal_info as a inner join
(select pat_mrn_id, result_time, prxmatch('/^(HIV RNA, QUANT)/', upcase(lab_name) ) > 0 as hiv_orders from
labs_pre ) as b
on
(a.PatientID = b.pat_mrn_id) and
(datepart(b.result_time) >= (a.DOC)) and
(datepart(b.result_time) <= a.studydate) and
b.hiv_orders = 1)
group by PatientID, studydate, filename;

delete * from rna_quant_counts where hiv_quant_count_occ <2;

*Get medications;
proc sql;
create table medications as
select a.filename, a.PatientID, a.studydate, b.med_Name from
epic_maternal_info as a inner join
(
select distinct * from
epic.medications
where
prxmatch('/emtricitabine|dolutegravir|tenofovir|truvada|ritonavir|darunavir|raltegravir|norvir|prezista|lamivudine|zidovudine/', lowcase(med_name)) > 0) as b
on
(a.PatientID = b.pat_mrn_id) and
(datepart(b.order_inst) >= (a.DOC)) and
(datepart(b.order_inst) <= a.studydate);

*Get ICD code counts;
proc sql;
create table diagnoses as
select filename, PatientID, studydate, sum(hiv) as count_occ
from
(
select a.*, b.hiv from
epic_maternal_info as a inner join
epic_diagnosis_pre as b
on
(a.PatientID = b.pat_mrn_id) and
(b.contact_date >= (a.DOC)) and
(b.contact_date <= a.studydate) and
b.hiv = 1)
group by PatientID, studydate, filename;

delete * from diagnoses where count_occ < 2;

*put everything together;
proc sql;
create table all_together as
select * from
diagnoses OUTER UNION CORR
    (select * from medications OUTER UNION CORR
        (select * from labs OUTER UNION CORR
            select * from rna_quant_counts));

* Count number of rows per study -> which gives us study instances ;
create table per_study_counts as
select filename, PatientID, studydate, count(*) as count_per_study
from all_together
group by filename, PatientID, studydate;

* Left join into the main table;
create table epic_maternal_info as
select a.*, b.count_per_study > 1 as hiv from
epic_maternal_info as a left join
per_study_counts as b
on
a.PatientID = b.PatientID and
a.filename = b.filename and
a.studydate = b.studydate;
