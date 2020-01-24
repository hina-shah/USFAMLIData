libname famdat "F:\Users\hinashah\SASFiles";
%let b1_biom_table = b1_biom;

*For studies that do have a known gestational age, create a start date for the pregnancy;
data biom_with_startdate  (drop=ga);
set famdat.&b1_biom_table;

ga = coalesce(ga_lmp, ga_edd, ga_doc, ga_unknown);
if not missing(ga) then
do;
	startdate = studydate - ga;
	format startdate mmddyy10.;
end;
run;

*Create a table of a patient and all start dates for the patient;
proc sql;
create table b1_pregnancies as 
select distinct PatientID, startdate
from biom_with_startdate where not missing(startdate);
quit;

proc delete data=biom_with_startdate;
run;

* Create columns for each pregnancy start date and the final table;
proc sort data= b1_pregnancies out=WORK.SORTTempTableSorted;
	by PatientID startdate;
run;

proc transpose data=WORK.SORTTempTableSorted prefix=startdate
		out=b1_pregnancies_arr(drop=_Name_);
	var startdate;
	by PatientID;
run;

proc delete data = work.SORTTempTableSorted;
run;

*Need a pass through data to eliminate closer values;
data _null_;
set b1_pregnancies_arr(obs=1);
    array sdates startdate:;
    call symput('n_startdts',trim(left(put(dim(sdates),8.))));
run;

data famdat.b1_pregnancies(drop = startdate: i j);
set b1_pregnancies_arr;
array sdates startdate:;
array docs(&n_startdts.);
format docs1-docs&n_startdts mmddyy10.;
j=1;
docs{1} = sdates{1};
do i=2 to dim(sdates);
	if not missing(sdates{i}) then 	do;
		if sdates{i} - docs{j} > 30 then j = j+1;
		docs{j} = sdates{i};
	end;
end;
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
array sdates docs:;
if (missing(ga_lmp) and missing(ga_edd) and missing(ga_doc) and missing(ga_unknown)) then
do;
	do i=1 to dim(sdates);
		if not missing(sdates{i}) then
		do;
			ga = studydate - sdates{i};
			if ga > 0 and ga < 280 then
				ga_extrap = ga;
		end;
	end;
end;
run;

proc sql;
create table famdat.b1_biom as
select filename, PatientID, studydate, ga_lmp, ga_doc, ga_edd, ga_unknown, ga_extrap, * from
work.b1_biom_fill_ga_more;
quit;

proc sql noprint;
select name into :dropped separated by ' '  
   from dictionary.columns
     where libname='FAMDAT' and memname='B1_BIOM' and name contains "docs";
quit;

data famdat.b1_biom;
  set famdat.b1_biom;
  drop &dropped;
run;

proc sql;
create table famdat.b1_biom_missinggas_after as
select filename, PatientID, studydate
from famdat.b1_biom
where missing(ga_lmp) and missing(ga_doc) and missing(ga_edd) and missing(ga_unknown) and missing(ga_extrap);
quit;