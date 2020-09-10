
%let volume_table = outlib.c1_studies_volumes;

title 'Counts for pulled out volumes';

proc sql;
create table &volume_table. as 
	select distinct PID, StudyID, study_dttm, path, file 
	from uslib.famli_c1_instancetable 
	where Volume='DICOM'
;

select 'Number of volumes: ', count(*) from &volume_table.;
select 'Number of patients: ', count(*) from (select distinct PID from &volume_table.);
select 'Number of studies: ', count(*) from (select distinct StudyID from &volume_table.);
select 'Min: ', min(PID), 'Max: ', max(PID) from &volume_table.;

create table &volume_table. as 
	select a.*, b.ga
	from 
		&volume_table. as a 
		left join
		&sr_ga_table as b
		on
		a.StudyID = b.StudyID
;

select 'Number of missing: ', count(*) from (select * from &volume_table. where missing(ga));
select 'Number of studies with missing', count(*) from (select distinct StudyID from &volume_table. where missing(ga));

proc sql;
create table volumes_subset as
select * from &volume_table. where not missing(ga);

data volumes_subset (keep=PID StudyID file_path ga);
set volumes_subset;
file_path = prxchange('s/F:/\work\hinashah\data\famli/', 1, path);
file_path = translate(file_path, '/', '\');
file_path = cats(file_path, '/', file);
run;


%ds2csv (
   data= volumes_subset, 
   runmode=b, 
   csvfile=&ServerPath.\C1Data\c1_volumes_ga.csv
 );


ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=volumes_subset;
    histogram ga /;
    xaxis values=(0 to 280 by 7) grid;
	yaxis grid;
run;

ods graphics / reset;

proc sql;
create table c1_kretz_table as 
	select distinct PID, StudyID, path, file 
	from uslib.famli_c1_instancetable
	where Volume='Kretz' and
	StudyID in (select StudyID from volumes_subset)
;

data k_volumes_subset (keep=PID StudyID file_path);
set c1_kretz_table;
file_path = cats(path, '/', file);
run;


%ds2csv (
   data= k_volumes_subset, 
   runmode=b, 
   csvfile=&ServerPath.\C1Data\c1_kretzvolumes.csv
 );
