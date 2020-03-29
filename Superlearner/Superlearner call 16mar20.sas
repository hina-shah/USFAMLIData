*Superlearner call 16mar20.sas;
options nocenter pagesize=60 linesize=100 nodate pageno=1;
dm "log; clear; out; clear;";
ods listing gpath="F:\Users\hinashah\SASFiles" image_dpi=500;

*Point and include the SL macro;
%INCLUDE "F:\Users\hinashah\SASFiles\USFAMLIData\Superlearner\super_learner_macro.sas";

*Read ACTG320 data;
data a;
    infile "F:\Users\hinashah\SASFiles\USFAMLIData\Superlearner\actg320.23nov16.dat";
    input id 1-6 male 8 black 10 hispanic 12 idu 14 art 16 delta 18 drop 20 r 22
        age 24-25 karnof 27-29 days 31-33 cd4 35-37 stop 39-41;
run;

*Look at data;
proc contents data = a;
    title1 "Superlearner call 16mar20";
    title2 "ACTG320 data";
proc means data = a;
run;

*Logistic regression predictions;
proc logistic data = a desc;
    model delta = male black hispanic idu art age karnof cd4;
    output out = b p = d1;
proc means data = b;
    var d1;
    title2 "Predicted value of AIDS/death from logistic regression";
run;

*Superlearner predctions;
TITLE "Super learner fit";
%SuperLearner(Y = delta,
              X = male black hispanic idu art age karnof cd4,
              indata = b, 
              outdata = c,
              library = logit gam lasso rf nn,
              folds = 10, 
              method = NNLS, 
              dist = BERNOULLI );
run;

*Look at output;
proc contents data = c;
proc corr data = c;
    var d1;
    with p_sl_full p_logit_full p_gam_full p_lasso_full p_rf_full p_nn_full;

*MSE;
data c;
    set c;
    d1se = (delta - d1)**2;
    slse = (delta - p_sl_full)**2;
proc means data = c mean;
    var d1se slse;
run;

*Plots;
ods graphics/reset imagename="SL plot" border=off imagefmt=png height=5in width=5in;
proc sgplot data = c noautolegend noborder;
    title1; title2;
    scatter x = d1 y = p_sl_full / markerattrs = (color = green);
    xaxis label="Logit model" values=(0 to .6 by .2) offsetmin=0 offsetmax=0 grid;
    yaxis label="Superlearner" values=(0 to .6 by .2) offsetmin=0 offsetmax=0 grid;
run;

run;
quit;
run;
