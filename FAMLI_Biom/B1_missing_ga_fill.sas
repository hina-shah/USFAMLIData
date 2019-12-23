libname famdat '/folders/myfolders/';
%let b1_biom_table = b1_biometry_20191218_133525;
%let r4_table = unc_famli_r4data20190820;

* Trying to fill gestational ages from the R4 database;
proc sql;
create table famdat.b1_biom_missinggas as
select filename, PatientID, studydttm
from famdat.&b1_biom_table
where missing(ga_lmp) and missing(ga_doc) and missing(ga_edd);

create table r4_studies_b1missingga as
select * from famdat.&r4_table where
NameOfFile in (select substr(filename,1,27) from famdat.b1_biom_missinggas);

create table famdat.b1_biom as
select A.*, B.egadays as ga_unknown from
famdat.&b1_biom_table as A left join 
(select NameOfFile, ExamDate, medicalrecordnumber, egadays from r4_studies_b1missingga) as B 
on B.NameOfFile = substr(A.filename,1,27) and datepart(A.studydttm) = B.ExamDate
;

create table famdat.b1_biom as
select distinct filename, PatientID, studydttm, ga_lmp, ga_doc, ga_edd, ga_unknown, * from
famdat.b1_biom;

create table famdat.b1_biom_missinggas_after as
select filename, PatientID, studydttm
from famdat.b1_biom
where missing(ga_lmp) and missing(ga_doc) and missing(ga_edd) and missing(ga_unknown);
quit;
