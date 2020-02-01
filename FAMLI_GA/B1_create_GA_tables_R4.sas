*libname famdat 'F:\Users\hinashah\SASFiles';
*libname epic 'F:\Users\hinashah\SASFiles\epic';

*libname famdat '/folders/myfolders';
*libname epic '/folders/myfolders/epic';


/************ R4 ************/
proc sql;
	create table famdat.&r4_ga_table. as
	select distinct medicalrecordnumber, put(input(medicalrecordnumber,12.),z12.)  as PatientID,
			EDD, NameofFile, egadays, ExamDate, studydate, 'R4' as edd_source
	from famdat.&r4_table.
	where not missing(egadays);
