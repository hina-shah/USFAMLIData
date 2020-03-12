
%macro mergedatasets(set1=, set2=, outset=);
	%let sortvars = pid StudyID;
	proc sort data=famdat.&set1 out=work._tmpsort1_;
		by &sortvars;
	run;
	proc sort data=famdat.&set2 out=work._tmpsort2_;
		by &sortvars;
	run;
	data famdat.&outset;
		merge _tmpsort1_ _tmpsort2_;
		by &sortvars;
	run;
	proc delete data=work._tmpsort1_ work._tmpsort2_;
	run;
%mend;

* macro to just set one dataset;
%macro setdataset(setin=, setout=);
	data famdat.&setout;
	set famdat.&setin;
	run;
%mend;

%let outputset = 'c1_ds_biometry_';

proc format;
  picture myfmt low-high = '%Y%0m%0d_%0H%0M%0S' (datatype = datetime) ;
run ;

data _null_;
set famdat.c1_biomvar_details (drop=tagname shortname);
%global biom_created_table;
newvar = put(datetime(),myfmt.);
completename = cats(&outputset, newvar);
put completename=;
call symput('biom_created_table', completename );
if _n_=1 then
	call execute( catt('%setdataset(setin=', varname, ', setout=', completename, ');'));
else
	call execute( catt('%mergedatasets(set1=', completename, ', set2=', varname, ', outset=', completename, ');'));
run;


* merge with the gestational age table;
%mergedatasets(set1=&c1_ga_table., set2=&biom_created_table., outset=&biom_final_output_table.);
