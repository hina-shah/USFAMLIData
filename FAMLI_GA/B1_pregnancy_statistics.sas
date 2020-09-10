
title 'Number of Patients in B1 with SR';
proc sql;
select count(*) from (select distinct PatientID from famdat.famli_b1_dicom_sr);
quit;

title 'Number of Studies in B1 with SR';
proc sql;
select count(*) from (select distinct filename from famdat.famli_b1_dicom_sr);
quit;

title 'Excluded: Number of Studies with no biometry measurements';
proc sql;
select count(*) from (select distinct filename from famdat.famli_b1_dicom_sr where anybiometry ne 1);
quit;

title 'Excluded: Number of Studies with non-fetal ultrasounds';
proc sql;
select count(*) from (select distinct filename from famdat.famli_b1_dicom_sr where alert contains 'non-fetal ultrasound');
quit;

title 'Excluded: Number of multifetal studies';
proc sql;
select count(*) from (select distinct filename from famdat.famli_b1_dicom_sr where alert contains 'non-singleton');
quit;

title 'Included: Number of studies';
proc sql;
select count(*) from outlib.b1_biom;
quit;

title 'Included: Number of patients';
proc sql;
select count(*) from (select distinct PatientID from outlib.b1_biom);
quit;

proc sql;
select count(*) from (select distinct filename from famdat.famli_b1_dicom_sr where lastsrofstudy ne 1);
quit;

*Convert all pregnancies into a single column dataset;
proc sql noprint;
select name into :docsvar separated by ' '
from dictionary.columns
where libname = "OUTLIB" and
memname = "B1_PREGNANCIES" and name contains 'docs';
quit;
proc sort data=OUTLIB.B1_PREGNANCIES out=work.__tmp__;
	by PatientID;
run;

proc transpose data=work.__tmp__ out=WORK.Stacked(drop=_Label_ _Level_
		rename=(col1=DOC)) name=_Level_;
	var &docsvar;
	by  PatientID;
run;

proc delete data=WORK.__tmp__;
run;

proc sql;
create table b1_pregnancies as
select * from work.stacked where not missing(DOC)
order by PatientID, DOC;
quit;

* Create the statistics ;

proc sql;
title 'Number of pregnancies';
select count(*) into :num_pregnancies from b1_pregnancies;
quit;

* Get number of pregnancies per patient;
proc sql;
create table preg_counts as
select PatientID, count(*) as count_pregnancies from b1_pregnancies group by PatientID;

ods graphics / reset width=6.4in height=4.8in imagemap;
proc sgplot data=WORK.PREG_COUNTS;
	title height=14pt "Histogram of number of pregnancies per patient";
	histogram count_pregnancies / datalabel=count datalabelattrs=(size=20) scale=count;
	yaxis grid;
run;

ods graphics / reset;
title;

* Get the first ultrasound for this pregnancy from b1_bim;
proc sql;
create table studies_per_preg as 
select a.*, datepart(b.studydttm) as studydate format mmddyy10., coalesce(b.ga_lmp, b.ga_edd, b.ga_doc, b.ga_unknown, b.ga_extrap) as ga
from 
b1_pregnancies as a left join 
outlib.b1_biom as b on
a.PatientID = b.PatientID and datepart(b.studydttm) > a.DOC - 25 and datepart(b.studydttm) < a.DOC + 280;

create table min_dates as 
select a.* 
from 
studies_per_preg as a inner join
(select PatientID, DOC, min(studydate) as min_studydate from studies_per_preg group by PatientID, DOC) as b
on
a.PatientID = b.PatientID and a.DOC = b.DOC and a.studydate = b.min_studydate;

ods graphics / reset width=6.4in height=4.8in imagemap;
proc sgplot data=WORK.min_dates;
	title height=14pt "Histogram of gestational ages at first ultrasound";
	histogram ga / datalabel=count datalabelattrs=(size=20) scale=count;
	yaxis grid;
run;

ods graphics / reset;
title;



