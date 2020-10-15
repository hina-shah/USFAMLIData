
/************ R4 ************/
proc sql;
	create table &r4_ga_table. as
	select distinct medicalrecordnumber, put(input(medicalrecordnumber,12.),z12.)  as PatientID,
			EDD, NameofFile, egadays, ExamDate, studydate, 'R4' as edd_source,
			NumberOfFetuses
	from &r4_table.
	where not missing(egadays);
