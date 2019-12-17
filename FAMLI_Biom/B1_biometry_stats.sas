
%macro checknotcm(tablename=, prefix=);
data _null_;
set famdat.&tablename;
array biomvars &prefix.:;
do i=1 to dim(biomvars);
    if not missing(&prefix.{i}) then
        do;
        pos = find(&prefix.{i}, 'cm', 'it') + find(&prefix.{i}, 'centimeter', 'it');
        if pos = 0 then put &prefix.{i};
        end;
    end;
run;
%mend checknotcm;

data _null_;
set famdat.Biomvar_details;
call execute( catt('%checknotcm(tablename=', varname, ', prefix=', shortname, ');'));
run;
libname famdat  "F:\Users\hinashah\SASFiles";

%let tablename = b1_biometry_20191111_101654;

proc sql;
select count (distinct PatientID) into :numPatients from
famdat.&tablename;

proc sql;
create table famdat.b1_biom_missinggas as
select * 
from famdat.&tablename
where missing(ga_lmp) and missing(ga_doc) and missing(ga_edd);

proc sql ;
select count(distinct PatientID) into :emptyGAs from
famdat.b1_biom_missinggas;

%put &numPatients;
%put &emptyGAs;


proc contents data = famdat.b1_biometry_20191111_101654 varnum;
run;


%macro checknotcm(tablename=, prefix=);
data &tablename;
set famdat.&tablename;
array biomvars &prefix.:;
do i=1 to dim(biomvars);
	if not missing(biomvars{i}) then
	do;
		pos = find(biomvars{i}, 'cm', 'it') + find(biomvars{i}, 'centimeter', 'it');
		if pos = 0 then 
		do;
			posmm = find(biomvars{i}, 'mm', 'it') + find(biomvars{i}, 'millimeter', 'it');
			if posmm > 0 then 
			do;
			    put biomvars{i};
				biomvars{i} = compress(biomvars{i},'','A')/10.0;
			end;
		end;
		else biomvars{i} = compress(biomvars{i},'','A');
	end; 
end;
run;
%mend checknotcm;

data _null_;
set famdat.Biomvar_details;
call execute( catt('%checknotcm(tablename=', varname, ', prefix=', shortname, ');'));
run;


data _null_;
set famdat.Biom_femur_length;
array biomvars fl:;
do i=1 to dim(biomvars);
	put i;
end;
run;
