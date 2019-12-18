*libname famdat '/folders/myfolders/';

%let famli_table = famdat.famli_b1_subset;

%macro createGaTable(gatag=, gvarname=);
	proc sql noprint;
		create table work.&gvarname (drop=tagname) as 
		select filename, PatientID, studydttm, tagname, tagcontent as ga
			from &famli_table
			where(tagname = "&gatag");
	quit;

	data famdat.&gvarname (drop=ga);
	set work.&gvarname;
	ga = compress(ga, '','A');
	&gvarname = input(ga, 4.);
	run;

	proc delete data=work.&gvarname;
	run;
%mend createGaTable;

data famdat.gavar_details;
length tagname $ 40;
length varname $ 20;
infile datalines delimiter=','; 
input tagname $ varname $;
call execute( catt('%createGaTable(gatag=', tagname, ', gvarname=', varname, ');'));
datalines;
Gestational Age by EDD,ga_edd
Gestational Age by Conception Date,ga_doc
Gestational Age by LMP,ga_lmp
;
run;
