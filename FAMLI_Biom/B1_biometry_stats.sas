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

