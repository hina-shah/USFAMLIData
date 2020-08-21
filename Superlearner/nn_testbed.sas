
libname sldat 'P:\Users\hinashah\SASFiles\SLData';

PROC HPNEURAL DATA = sldat.sl_finalrandselecttable1_subset ;
    FORMAT ga_edd;
    TARGET ga_edd / LEVEL = INT;
    INPUT hiv current_smoker former_smoker chronic_htn preg_induced_htn diabetes gest_diabetes / LEVEL = NOM;;
    INPUT fl_1 bp_1 ac_1 hc_1 mom_age_edd mom_weight_lb mom_height_in / LEVEL = INT;;
    HIDDEN 64;
    HIDDEN 32;
    HIDDEN 16;
    HIDDEN 8;
    HIDDEN 4;
    TRAIN OUTMODEL = __nnmod NUMTRIES=50 MAXITER=200;
  PROC HPNEURAL DATA = sldat.sl_finalrandselecttable1_subset;
    SCORE OUT=out_nn (DROP=_WARN_ RENAME=(p_ga_edd = p_nn)) MODEL = __nnmod;
    ID _ALL_;
  RUN;

data out_nn;
set out_nn;
nn_diff = p_nn - ga_edd;
nn_diff_abs = abs(nn_diff);
nn_diff_se = nn_diff ** 2;
ga_edd_weeks = ga_edd/7.;
diffhadlock = hadlock_ga - ga_edd;
diffintergrowth = intergrowth_ga - ga_edd;
hadlockse = diffhadlock**2;
intergrowthse = diffintergrowth**2;
    
run;

proc means data = out_nn mean std median q1 q3;
    var ga_edd p_nn nn_diff diffhadlock diffintergrowth 
                nn_diff_abs hadlock_ga_diff intergrowth_ga_diff
                nn_diff_se hadlockse intergrowthse;
run;

ods graphics/reset border=off height=5in width=5in;
proc sgplot data = out_nn noautolegend noborder;
    title1; title2;
    scatter x = ga_edd_weeks y = nn_diff / markerattrs = (color=green symbol=CircleFilled) transparency=0.7;
    yaxis label="Superlearner Difference (days)" values=(-35 to 35 by 5) offsetmin=0 offsetmax=0 grid;
    xaxis label="Ground Truth GA (weeks)" values=(12 to 44 by 1) offsetmin=0 offsetmax=0 grid;
    refline 0 / axis=y lineattrs=(color=black thickness=2);
run;
