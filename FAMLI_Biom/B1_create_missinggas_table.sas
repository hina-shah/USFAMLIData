
libname famdat '/folders/myfolders/';

proc sql;
create table famdat.b1_biom_missinggas as
select filename, PatientID, studydttm
from famdat.b1_biometry_20191113_153413
where missing(ga_lmp) and missing(ga_doc) and missing(ga_edd);
