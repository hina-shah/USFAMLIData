*Superlearner call two 19mar20.sas;
options nocenter nodate pageno=1 fullstimer;
ods listing gpath="F:/Users/hinashah/SASFiles/SLData" image_dpi=500;

*Point and include the SL macro;
%INCLUDE "F:\Users\hinashah\SASFiles\USFAMLIData\Superlearner\super_learner_macro.sas";

libname sldat "F:\Users\hinashah\SASFiles\SLData";

*Look at data;
proc contents data = sldat.SL_FinalRandSelectTable1_subset;
    title1 "Superlearner call 19mar20";
    title2 "Table1 Data predictions";
proc means data = sldat.SL_FinalRandSelectTable1_subset;
run;

*Linear regression predictions;
proc genmod data = sldat.SL_FinalRandSelectTable1_subset;
    model ga_edd = fl_1 bp_1 ac_1 hc_1 mom_age_edd mom_weight_oz mom_height_in
                    hiv tobacco_use_num chronic_htn preg_induced_htn diabetes gest_diabetes;
    output out = b p = d1;
proc means data = b;
    var d1;
    title2 "Predicted value of GA_EDD from linear regression";
run;

*Superlearner predctions;
TITLE "Super learner fit";
%SuperLearner(Y = ga_edd,
              X = fl_1 bp_1 ac_1 hc_1 mom_age_edd mom_weight_oz mom_height_in
                    hiv tobacco_use_num chronic_htn preg_induced_htn diabetes gest_diabetes,
              indata = b,
              outdata = c,
              library = glm gam lasso rf nn,
              folds = 10,
              method = NNLS,
              dist = GAUSSIAN );
run;

ods pdf file='F:\Users\hinashah\SASFiles\SLData\Report.pdf';
*Look at output;
proc contents data = c;
proc corr data = c;
    var d1;
    with p_sl_full p_logit_full p_gam_full p_lasso_full p_rf_full p_nn_full;

*MSE;
data c;
    set c;
    d1se = (ga_edd - d1)**2;
    slse = (ga_edd - p_sl_full)**2;
    diffreg = d1 - ga_edd;
    diffsl = p_sl_full - ga_edd;
proc means data = c mean std;
    var ga_edd d1 p_sl_full d1se slse diffreg diffsl;
run;

*Plots;
ods graphics/reset imagename="SL plot" border=off imagefmt=png height=5in width=5in;
proc sgplot data = c noautolegend noborder;
    title1; title2;
    scatter x = d1 y = p_sl_full / markerattrs = (color = green);
    xaxis label="Linear model" values=(0 to 350 by 7) offsetmin=0 offsetmax=0 grid;
    yaxis label="Superlearner" values=(0 to 350 by 7) offsetmin=0 offsetmax=0 grid;
    lineparm x=0 y=0 slope=1;
run;

ods graphics/reset imagename="SL plot 2" border=off imagefmt=png height=5in width=5in;
proc sgplot data = c noautolegend noborder;
    title1; title2;
    scatter x = ga_edd y = diffreg / markerattrs = (color = green);
    yaxis label="Difference" values=(100 to -300 by 50) offsetmin=0 offsetmax=0 grid;
    xaxis label="True value" values=(0 to 400 by 50) offsetmin=0 offsetmax=0 grid;
    refline 0 / axis=y lineattrs=(color=black thickness=2);
run;
ods graphics/reset imagename="SL plot 3" border=off imagefmt=png height=5in width=5in;
proc sgplot data = c noautolegend noborder;
    title1; title2;
    scatter x = ga_edd y = diffsl / markerattrs = (color = green);
    yaxis label="Superlearner" values=(100 to -300 by 50) offsetmin=0 offsetmax=0 grid;
    xaxis label="True value" values=(0 to 400 by 50) offsetmin=0 offsetmax=0 grid;
    refline 0 / axis=y lineattrs=(color=black thickness=2);
run;

ods pdf close;
