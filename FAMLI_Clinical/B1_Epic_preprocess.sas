/*
 * Preprocess EPIC dataset to get maternal clinical information like HIV, Hypertension, and Diabetes
 */


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
prxmatch('/^(O24\.4|648\.83).*/', ref_bill_code) as gest_diabetes,
prxmatch('/^(I10|401\.0|401\.1|401\.9|O10|O11|642\.0|642\.1|642\.3|642\.9).*/', ref_bill_code) as chr_htn,
prxmatch('/^(O11|O13|O14|O15|642\.[3-7]).*/', ref_bill_code) as preg_htn
from epic.diagnosis;
quit;

data labs_pre;
set epic.labs;
result_num = input(result, ? 8.);
run;

proc sql;
create table pregnancies as 
select distinct PatientID, DOC, coalesce(delivery_date, episode_working_edd) + 42 as end_of_preg format mmddyy10.
from epic_maternal_info where not missing(DOC)
order by PatientID;

proc sort data= pregnancies out=WORK.SORTTempTableSorted;
	by PatientID DOC;
run;

proc transpose data=WORK.SORTTempTableSorted prefix=startdate
		out=b1_pregnancies_arr_DOC (drop=_NAME_);
	var DOC;
	by PatientID;	
run;

proc transpose data=WORK.SORTTempTableSorted prefix=enddate
		out=b1_pregnancies_arr_edd(drop=_NAME_);
	var end_of_preg;
	by PatientID;
run;

proc sql;
create table famdat.b1_Epic_pregnancies_arr as
select a.*, b.* from
b1_pregnancies_arr_DOC as a full join 
b1_pregnancies_arr_edd as b on
a.PatientID = b.PatientID;


proc sql noprint;
select name into :dropstarts separated by ' '  
   from dictionary.columns
     where libname='FAMDAT' and memname='B1_EPIC_PREGNANCIES_ARR' and name contains "startdate";
quit;

proc sql noprint;
select name into :dropends separated by ' '  
   from dictionary.columns
     where libname='FAMDAT' and memname='B1_EPIC_PREGNANCIES_ARR' and name contains "enddate";
quit;

%macro deleteRecordsOfPrevPregnancies(inputtable=,outputtable=,datevariable=);
	proc sql;
	create table with_prev_endstart as 
	select a.*, b.* from
	&inputtable as a left join famdat.b1_epic_pregnancies_arr as b
	on 
	a.PatientID = b.PatientID;
	
	*Mark the ones that are in a previous pregnancy;
	data marked (drop=i);
	set with_prev_endstart;
	array sdates startdate:;
	array edates enddate:;
	in_prev = 0;
	do i=1 to dim(sdates);
		if sdates{i} < DOC then do; /* if in a previous pregnancy*/
			if &datevariable >= sdates{i} and &datevariable <= edates{i} + 42 
				then in_prev = 1;
		end;
	end;
	run;
	
	proc sql;
	delete * from marked where in_prev=1;
	
	data &outputtable (drop=in_prev &dropstarts. &dropends.);
	set marked;
	run;
%mend;