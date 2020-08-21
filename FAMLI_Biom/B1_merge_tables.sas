
* Macro to merge two datasets ;
* Ideally would use a full join - but it was giving some errors during testing;

%macro mergedatasets(set1=, set2=, outset=);
    %let sortvars = filename PatientID;
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

%let outputset = 'ds_biometry_';

proc format;
  picture myfmt low-high = '%Y%0m%0d_%0H%0M%0S' (datatype = datetime) ;
run ;

data _null_;
set famdat.biomvar_details (drop=tagname shortname);
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
%mergedatasets(set1=&ga_final_table., set2=&biom_created_table., outset=&biom_final_output_table.);

data famdat.&biom_final_output_table.;
set famdat.&biom_final_output_table.(drop=studydttm episode_edd edd_source);
run;

proc sql;
delete *
    from famdat.&biom_final_output_table.
    where
        missing(fl_1) and missing(crl_1) and 
        missing(bp_1) and missing(ac_1) and 
        missing(tcd_1) and missing(afiq1_1) and 
        missing(afiq2_1) and missing(afiq3_1) and 
        missing(afiq4_1) and missing(hc_1) and 
        missing(mvp_1)
;
    