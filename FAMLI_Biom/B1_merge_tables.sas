
* Macro to merge two datasets ;
* Ideally would use a full join - but it was giving some errors during testing;

%macro mergedatasets(set1=, set2=, outset=);
    %let sortvars = filename PatientID;
    proc sort data=&set1 out=work._tmpsort1_;
        by &sortvars;
    run;
    proc sort data=&set2 out=work._tmpsort2_;
        by &sortvars;
    run;
    data &outset;
        merge _tmpsort1_ _tmpsort2_;
        by &sortvars;
    run;
    proc delete data=work._tmpsort1_ work._tmpsort2_;
    run;
%mend;

* macro to just set one dataset;
%macro setdataset(setin=, setout=);
    data &setout;
    set &setin;
    run;
%mend;

%let outputset = 'ds_biometry_';

proc format;
  picture myfmt low-high = '%Y%0m%0d_%0H%0M%0S' (datatype = datetime) ;
run ;

data _null_;
set outlib.biomvar_details (drop=tagname shortname);
%global biom_created_table;
newvar = put(datetime(),myfmt.);
completename = cats(&outputset, newvar);
put completename=;
call symput('biom_created_table', completename );
if _n_=1 then
    call execute( catt('%setdataset(setin=outlib.', varname, ', setout=outlib.', completename, ');'));
else
    call execute( catt('%mergedatasets(set1=outlib.', completename, ', set2=outlib.', varname, ', outset=outlib.', completename, ');'));
run;

* merge with the gestational age table;
%mergedatasets(set1=&ga_final_table., set2=outlib.&biom_created_table., outset=&biom_final_output_table.);

* Adding R4 biometries when requested. ;
%if &USE_R4_STUDIES. = 1 %then %do;
	
	data prev;
	set &biom_final_output_table.(drop=studydttm episode_edd edd_source);
	run;

	proc sql;
	select 'With Missing biometries before adding R4: ', count(*) from prev where 
		missing(fl_1) and missing(crl_1) and
        missing(bp_1) and missing(ac_1) and 
        missing(tcd_1) and missing(afiq1_1) and 
        missing(afiq2_1) and missing(afiq3_1) and 
        missing(afiq4_1) and missing(hc_1) and 
        missing(mvp_1); 

	create table prev_join
	as 
		select a.*, coalesce(b.First_Trimester_CRL, b.Second_Trimester_CRL)/10. as r4_crl, 
			b.Second_Trimester_BPD/10. as r4_bpd,
			b.Second_Trimester_HC/10. as r4_hc,
			b.Second_Trimester_AC/10. as r4_ac,
			b.Second_Trimester_FL/10. as r4_fl
		from
			prev as a
			left join
			outlib.biom_r4_table as b
		on
			a.PatientID = b.PatientID
			and
			a.studydate = b.studydate;
	
	data &biom_final_output_table. (drop=r4_crl r4_bpd r4_hc r4_ac r4_fl);
	set prev_join;
		crl_1 = coalesce(crl_1, r4_crl);
		bp_1 = coalesce(bp_1, r4_bpd);
		hc_1 = coalesce(hc_1, r4_hc);
		ac_1 = coalesce(ac_1, r4_ac);
		fl_1 = coalesce(fl_1, r4_fl);
	run;
	
	proc sql;
	select 'With Missing biometries after adding R4: ', count(*) from &biom_final_output_table. where 
		missing(fl_1) and missing(crl_1) and
        missing(bp_1) and missing(ac_1) and 
        missing(tcd_1) and missing(afiq1_1) and 
        missing(afiq2_1) and missing(afiq3_1) and 
        missing(afiq4_1) and missing(hc_1) and 
        missing(mvp_1); 
%end;
%else %do;
	data &biom_final_output_table.;
	set &biom_final_output_table.(drop=studydttm episode_edd edd_source);
	run;
%end;

proc sql;
delete *
    from &biom_final_output_table.
    where
        missing(fl_1) and missing(crl_1) and 
        missing(bp_1) and missing(ac_1) and 
        missing(tcd_1) and missing(afiq1_1) and 
        missing(afiq2_1) and missing(afiq3_1) and 
        missing(afiq4_1) and missing(hc_1) and 
        missing(mvp_1)
;

select 'Number of studies with any biometry information: ', count(*) from &biom_final_output_table.;
