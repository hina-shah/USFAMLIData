*Superlearner call two 19mar20.sas;
options nocenter nodate pageno=1 fullstimer;

%let serverpath = P:/Users/hinashah;
%let suffix = _subset;
%let tablename = SL_FinalRandSelectTable1&suffix.;
%let sl_table = c&suffix.;
%let lib_path = &serverpath./SASFiles/SLData_exp;

ods listing gpath="&lib_path/" image_dpi=500;

*Point and include the SL macro;
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\super_learner_macro.sas";

libname sldat "&lib_path.";

ods pdf file="&lib_path./Report&suffix..pdf";

*Look at data;
proc contents data = sldat.&tablename.;
    title1 "Superlearner call 19mar20";
    title2 "Table1 Data predictions";
proc means data = sldat.&tablename.;
run;

*Linear regression predictions;
proc genmod data = sldat.&tablename.;
    model ga_edd = fl_1 bp_1 ac_1 hc_1 mom_age_edd mom_weight_lb mom_height_in
                    hiv current_smoker former_smoker chronic_htn preg_induced_htn diabetes gest_diabetes;
    output out = b p = d1;
run;

proc surveyselect data=sldat.&tablename. samprate=0.8 out=t outall;
run;
data train(drop=Selected) test(drop=Selected);
set t;
if Selected=1 then output train;
else output test;
run;

*Superlearner predctions;
TITLE "Super learner fit";
%SuperLearner(Y = ga_edd,
              binary_predictors = hiv current_smoker former_smoker chronic_htn preg_induced_htn diabetes gest_diabetes,
              continuous_predictors = fl_1 bp_1 ac_1 hc_1 mom_age_edd mom_weight_lb mom_height_in,
              indata = b,
			  /*preddata = test,*/
              outdata = sldat.&sl_table.,
              library = gam lasso hpglm rf nn,
              folds = 10,
              method = NNLS,
              dist = GAUSSIAN );
run;

*X = fl_1 bp_1 ac_1 hc_1 mom_age_edd mom_weight_lb mom_height_in
                    hiv current_smoker former_smoker chronic_htn preg_induced_htn diabetes gest_diabetes,

              
;
 
*Look at output;
proc contents data = sldat.&sl_table.;
proc corr data = sldat.&sl_table.;
    var ga_edd;
    with p_sl_full p_gam_full p_hpglm_full p_rf_full p_nn_full;

*MSE;
data sldat.&sl_table.;
    set sldat.&sl_table.;
    slse = (ga_edd - p_sl_full)**2;
    diffsl = p_sl_full - ga_edd;
    diffhadlock = hadlock_ga - ga_edd;
    diffintergrowth = intergrowth_ga - ga_edd;
    absdiffsl = abs(diffsl);
    hadlockse = diffhadlock**2;
    intergrowthse = diffintergrowth**2;
    ga_edd_weeks = ga_edd/7.;

proc means data = sldat.&sl_table. mean std median q1 q3;
    var ga_edd p_sl_full diffsl diffhadlock diffintergrowth 
                absdiffsl hadlock_ga_diff intergrowth_ga_diff
                slse hadlockse intergrowthse;
run;

*Plots;
ods graphics/reset imagename="SL plot 1 (GA vs SL)" border=off imagefmt=png height=5in width=5in;
proc sgplot data = sldat.&sl_table. noautolegend noborder;
    title1; title2;
    scatter x = ga_edd_weeks y = diffsl / markerattrs = (color=green symbol=CircleFilled) transparency=0.7;
    yaxis label="Superlearner Difference (days)" values=(-35 to 35 by 5) offsetmin=0 offsetmax=0 grid;
    xaxis label="Ground Truth GA (weeks)" values=(12 to 44 by 1) offsetmin=0 offsetmax=0 grid;
    refline 0 / axis=y lineattrs=(color=black thickness=2);
run;

ods graphics/reset imagename="SL plot 2 (GA vs Hadlock)" border=off imagefmt=png height=5in width=5in;
proc sgplot data = sldat.&sl_table. noautolegend noborder;
    title1; title2;
    scatter x = ga_edd_weeks y = diffhadlock / markerattrs = (color=green symbol=CircleFilled) transparency=0.7;
    yaxis label="Hadlock Difference (days)" values=(-35 to 35 by 5) offsetmin=0 offsetmax=0 grid;
    xaxis label="Ground Truth GA (weeks)" values=(12 to 44 by 1) offsetmin=0 offsetmax=0 grid;
    refline 0 / axis=y lineattrs=(color=black thickness=2);
run;

ods graphics/reset imagename="SL plot 3 (GA vs Intergrowth)" border=off imagefmt=png height=5in width=5in;
proc sgplot data = sldat.&sl_table. noautolegend noborder;
    title1; title2;
    scatter x = ga_edd_weeks y = diffintergrowth / markerattrs = (color=green symbol=CircleFilled) transparency=0.7;
    yaxis label="Intergrowth Difference (days)" values=(-35 to 35 by 5) offsetmin=0 offsetmax=0 grid;
    xaxis label="Ground Truth GA (weeks)" values=(12 to 44 by 1) offsetmin=0 offsetmax=0 grid;
    refline 0 / axis=y lineattrs=(color=black thickness=2);
run;

ods graphics/reset imagename="SL plot 4 (SL Diff Boxplot)" border=off imagefmt=png height=5in width=5in;
proc sgplot data=sldat.&sl_table.;
    vbox diffsl / fillattrs=(color=CXCAD5E5) name='Box';
    xaxis fitpolicy=splitrotate;
    yaxis grid;
run;
ods graphics/reset imagename="SL plot 5 (Hadlock Diff Boxplot)" border=off imagefmt=png height=5in width=5in;
proc sgplot data=sldat.&sl_table.;
    vbox diffhadlock / fillattrs=(color=CXCAD5E5) name='Box';
    xaxis fitpolicy=splitrotate;
    yaxis grid;
run;
ods graphics/reset imagename="SL plot 6 (Intergrowth Diff Boxplot)" border=off imagefmt=png height=5in width=5in;
proc sgplot data=sldat.&sl_table.;
    vbox diffintergrowth / fillattrs=(color=CXCAD5E5) name='Box';
    xaxis fitpolicy=splitrotate;
    yaxis grid;
run;

ods pdf close;
