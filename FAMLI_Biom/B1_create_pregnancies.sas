libname famdat '/folders/myfolders/';
%let b1_biom_table = b1_biom;

*For studies that do have a known gestational age, create a start date for the pregnancy;
data biom_with_startdate  (drop=ga);
set famdat.&b1_biom_table;

if ga_lmp > 0 then
	ga = ga_lmp;
else if ga_edd > 0 then
	ga = ga_edd;
else if ga_doc > 0 then
	ga = ga_doc;
else if ga_unknown > 0 then
	ga = ga_unknown;

if not missing(ga) then
	startdate = datepart(studydttm) - ga;
run;

*Create a table of a patient and all start dates for the patient;
proc sql;
create table b1_pregnancies as 
select distinct PatientID, startdate
from biom_with_startdate;
quit;

data b1_pregnancies;
set b1_pregnancies;
format startdate mmddyy10.;
run;

proc delete data=biom_with_startdate;
run;


* Create columns for each pregnancy start date and the final table;
proc sort data= b1_pregnancies out=WORK.SORTTempTableSorted;
	by PatientID startdate;
run;

proc transpose data=WORK.SORTTempTableSorted prefix=startdate
		out=famdat.b1_pregnancies(drop=_Name_);
	var startdate;
	by PatientID;
run;

proc delete data = work.SORTTempTableSorted;
run;

*Try to extrapolate more missing gestational ages based on pregnancies obtained;
proc sql;
create table biom_with_startdate as
select A.*, B.* from
famdat.b1_biom as A left join famdat.b1_pregnancies as B
on A.PatientID = B.PatientID;
quit;

data b1_biom_fill_ga_more (drop=ga i);
set biom_with_startdate;
array sdates startdate:;
if (missing(ga_lmp) and missing(ga_edd) and missing(ga_doc) and missing(ga_unknown)) then
do;
	do i=1 to dim(sdates);
		if not missing(sdates{i}) then
		do;
			ga = datepart(studydttm) - sdates{i};
			if ga > 0 and ga < 280 then
				ga_extrap = ga;
		end;
	end;
end;
run;

proc sql;
create table famdat.b1_biom as
select filename, PatientID, studydttm, ga_lmp, ga_doc, ga_edd, ga_unknown, ga_extrap, * from
work.b1_biom_fill_ga_more;
quit;

proc sql noprint;
select name into :dropped separated by ' '  
   from dictionary.columns
     where libname='FAMDAT' and memname='B1_BIOM' and name contains "startdate";
quit;

data famdat.b1_biom;
  set famdat.b1_biom;
  drop &dropped;
run;

proc sql;
create table famdat.b1_biom_missinggas_after as
select filename, PatientID, studydttm
from famdat.b1_biom
where missing(ga_lmp) and missing(ga_doc) and missing(ga_edd) and missing(ga_unknown) and missing(ga_extrap);
quit;