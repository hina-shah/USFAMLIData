
/* 
This is a wrapper to the super leaner macro
The macro should be included from an external script.

*/
options nocenter nodate pageno=1 fullstimer;

%macro SuperLearnerWrapper(
    indata=,
    outdata=,
    train_proportion=1,
    outpdfpath=,
    use_patient_split=0
);

%LET Y = ga_edd;
%LET binary_predictors = hiv current_smoker former_smoker chronic_htn preg_induced_htn diabetes gest_diabetes;
%LET continuous_predictors = fl_1 bp_1 ac_1 hc_1 mom_age_edd mom_weight_lb mom_height_in;
%LET library = gam lasso hpglm rf nn nn15 nn6 nn50 nn100 hadlock intergrowth nichd;
%LET folds = 10;

data &indata. (drop=scg bpg hcg flg acg);
set &indata.;
if hc_1 > 0 and bp_1 > 0 and ac_1 >0 and fl_1>0
        then
        do;
            scg = 10.0;
            bpg = bp_1*scg;
            hcg = hc_1*scg;
            flg = fl_1*scg;
            acg = ac_1*scg;
            nichd_ga = 10.6 - (0.1683*bpg) + (0.0452*hcg) + (0.0302*acg) + 
                   (0.0576*flg) + (0.0025*bpg*bpg) + 
                   (0.0017*flg*flg) + (0.0005*(bpg * acg)) -
                   (0.0052*(bpg * flg )) - (0.0003*(hcg * acg)) + 
                   (0.0008*(hcg * flg)) + (0.0006*(acg* flg));
            nichd_ga = nichd_ga*7.0;
    end;
    
run;

ods pdf file="&outpdfpath";

/* Look at the data */

proc contents data = &indata.;
    title1 "Superlearner GA predictions";
    title2 "Table1 Data predictions";
proc means data = &indata.;
run;

%IF &train_proportion. < 1 %THEN %DO;

    %PUT ********* IN TRAIN/TEST MODE ***************;
    
    %IF &use_patient_split. = 1 %THEN %DO;
        proc sql;
        create table patids_to_split as 
            select distinct PatientID from &indata.
        ;
        proc sql;
        select "Number of patients in input dataset: ", count(*) from patids_to_split;
        
        %LET to_split_data = patids_to_split;
    %END;
    %ELSE %DO;
        %LET to_split_data = &indata.;
    %END;
    
    proc surveyselect data=&to_split_data. samprate=&train_proportion. out=t outall seed=1234;
    run;
    data train(drop=Selected) testset(drop=Selected);
    set t;
    if Selected=1 then output train;
    else output testset;
    run;
    
    %IF &use_patient_split. = 1 %THEN %DO;
        data train_pids;
        set train;
        data test_pids;
        set testset;
        run;
        
        proc sql;
        select "Number of patients in train dataset: ", count(*) from train_pids;
        select "Number of patients in test dataset: ", count(*) from test_pids;
        
        create table train as
            select * from &indata. 
            where PatientID in (select * from train_pids);
        create table testset as
            select * from &indata.
            where PatientID in (select * from test_pids);

        select "Number of studies in train dataset: ", count(*) from train;
        select "Number of studies in test dataset: ", count(*) from testset;
        
    %END;
    
    %LET test=testset;
%END;
%ELSE %DO;
    %PUT ********* IN FULL DATA MODE ***************;
    data train;
    set &indata.;
    run;
    %LET test=;
%END;

TITLE "Super learner fit test/train";
%SuperLearner(Y = &Y.,
              binary_predictors = &binary_predictors.,
              continuous_predictors = &continuous_predictors.,
              indata = train,
              preddata = &test.,
              outdata = &outdata.,
              library = &library.,
              folds = &folds.,
              method = NNLS,
              dist = GAUSSIAN );
run;
proc contents data = &outdata.;
proc corr data = &outdata.;
    var ga_edd;
    with p_sl_full p_gam_full p_hpglm_full p_rf_full 
        p_nn15_full p_nn100_full p_nn50_full p_nn6_full p_nn_full
        p_hadlock_full p_intergrowth_full p_nichd_full;

*MSE;
data &outdata.;
    set &outdata.;
    slse = (ga_edd - p_sl_full)**2;
    diffsl = p_sl_full - ga_edd;
    diffhadlock = hadlock_ga - ga_edd;
    diffintergrowth = intergrowth_ga - ga_edd;
    diffnichd = nichd_ga - ga_edd;
    absdiffsl = abs(diffsl);
    absdiffnichd = abs(diffnichd);
    hadlockse = diffhadlock**2;
    intergrowthse = diffintergrowth**2;
    nichdse = diffnichd**2;
    ga_edd_weeks = ga_edd/7.;
run;

TITLE "Tabular analysis for the fit";
proc means data = &outdata. mean std median q1 q3;
    var ga_edd p_sl_full diffsl diffhadlock diffintergrowth diffnichd
                absdiffsl hadlock_ga_diff intergrowth_ga_diff absdiffnichd
                slse hadlockse intergrowthse nichdse;
run;

%IF &train_proportion. < 1 %THEN %DO;

proc means data = &outdata. mean std median q1 q3;
    title1 "Stats on the training set";
    where __train=1;
    var ga_edd p_sl_full diffsl diffhadlock diffintergrowth diffnichd
                absdiffsl hadlock_ga_diff intergrowth_ga_diff absdiffnichd
                slse hadlockse intergrowthse nichdse;
run;

proc means data = &outdata. mean std median q1 q3;
    title1 "Stats on the test set"; 
    where __train=0;
    var ga_edd p_sl_full diffsl diffhadlock diffintergrowth diffnichd
                absdiffsl hadlock_ga_diff intergrowth_ga_diff absdiffnichd
                slse hadlockse intergrowthse nichdse;
run;

%END;;

TITLE "Plots for the Training data or ALL";
*Plots;
%createplots( fig_name = SL_Train_plot1,
              dataset = &outdata.,
              y_variable=diffsl,
              y_name = Super Learner,
              train=1
    );
    
%createplots( fig_name = SL_Train_plot2,
              dataset = &outdata.,
              y_variable=diffhadlock,
              y_name = Hadlock,
              train=1
    );

%createplots( fig_name = SL_Train_plot3,
              dataset = &outdata.,
              y_variable=diffintergrowth,
              y_name = Intergrowth,
              train=1
    );

%createplots( fig_name = SL_Train_plot4,
              dataset = &outdata.,
              y_variable=diffnichd,
              y_name = NICHD,
              train=1
    );

%IF &train_proportion. < 1 %THEN %DO;
TITLE "Plots for the Testing data";
%createplots( fig_name = SL_Test_plot1,
              dataset = &outdata.,
              y_variable=diffsl,
              y_name = Super Learner,
              train=0
    );
    
%createplots( fig_name = SL_Test_plot2,
              dataset = &outdata.,
              y_variable=diffhadlock,
              y_name = Hadlock,
              train=0
    );

%createplots( fig_name = SL_Test_plot3,
              dataset = &outdata.,
              y_variable=diffintergrowth,
              y_name = Intergrowth,
              train=0
    );

%createplots( fig_name = SL_Test_plot4,
              dataset = &outdata.,
              y_variable=diffnichd,
              y_name = NICHD,
              train=0
    );
%END;

ods pdf close;
%mend;


%macro createplots(fig_name=, 
                    dataset=,
                    y_variable=,
                    y_name=,
                    train=
                    );
%if &train.=0 %then %let mark_color=red;
%else %let mark_color=green;;
    
    ods graphics/reset LOESSMAXOBS=20000 imagename="&fig_name. (GA vs &y_name.)" border=off imagefmt=png height=5in width=5in;
    proc sgplot data = &dataset. noautolegend noborder;
        title1; title2;
        where __train=&train;
        scatter x = ga_edd_weeks y = &y_variable. / markerattrs = (color=&mark_color. symbol=CircleFilled) transparency=0.7;
        loess x = ga_edd_weeks y = &y_variable. / nomarkers lineattrs=(thickness=3 color=blue);
        ellipse x = ga_edd_weeks y=&y_variable. / lineattrs = (color=purple);
        yaxis label="&y_name. Difference (days)" values=(-35 to 35 by 5) offsetmin=0 offsetmax=0 grid;
        xaxis label="Ground Truth GA (weeks)" values=(12 to 44 by 1) offsetmin=0 offsetmax=0 grid;
        refline 0 / axis=y lineattrs=(color=black thickness=2);
    run;
    ods graphics/reset;
%mend;


%MACRO nn50_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* neural network regression*/
  &suppresswarn %__SLwarning(%str(This functionality (neural networks) is still experimental));
  

  PROC HPNEURAL DATA = &indata  ;
   ODS SELECT NONE;
   TARGET &Y / LEVEL = INT;
   %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
        INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = NOM;;
   %IF (&continuous_predictors~=) %THEN 
         INPUT &continuous_predictors / LEVEL = INT;;
   HIDDEN 50;
   TRAIN OUTMODEL = nnmod MAXITER=200;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (DROP=_WARN_ RENAME=(p_&Y = p_nn50&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn50_cn;

%MACRO nn100_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* neural network regression*/
  &suppresswarn %__SLwarning(%str(This functionality (neural networks) is still experimental));
  

  PROC HPNEURAL DATA = &indata  ;
   ODS SELECT NONE;
   TARGET &Y / LEVEL = INT;
   %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
        INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = NOM;;
   %IF (&continuous_predictors~=) %THEN 
         INPUT &continuous_predictors / LEVEL = INT;;
   HIDDEN 100;
   TRAIN OUTMODEL = nnmod MAXITER=200;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (DROP=_WARN_ RENAME=(p_&Y = p_nn100&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn100_cn;


%MACRO hadlock_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* neural network regression*/
  data &outdata;
  set &indata;
  p_hadlock&SUFF. = hadlock_ga;
  run;
%MEND hadlock_cn;

%MACRO intergrowth_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* neural network regression*/
  data &outdata;
  set &indata;
  p_intergrowth&SUFF. = intergrowth_ga;
  run;
%MEND intergrowth_cn;

%MACRO nichd_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* neural network regression*/
  data &outdata;
  set &indata;
  p_nichd&SUFF. = nichd_ga;
  run;
%MEND nichd_cn;