%let serverpath = P:/Users/hinashah;
%let lib_path = &serverpath./SASFiles/IVF_Analysis_New;

%let suffix =;
%let tablename = sl_finalrandselecttable1&suffix.;
%let sl_table = ivf_cv_an&suffix.;

ods listing gpath="&lib_path/" image_dpi=500;

*Point and include the SL macro;
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\super_learner_macro.sas";
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\super_learner_wrapper_macro.sas";
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\sas_superlearner_extra_learners.sas";

libname sldat "&lib_path.";

%LET Y = ga_edd;
%LET binary_predictors = hiv current_smoker former_smoker chronic_htn preg_induced_htn diabetes gest_diabetes;
%LET continuous_predictors = fl_1 bp_1 ac_1 hc_1 mom_age_edd mom_weight_lb mom_height_in;
%LET library = gam lasso hpglm rf  nn nn15 nn6 nn50 nn100 nn500 hadlock intergrowth nichd;
%LET folds = 10;

%CVSuperLearner(Y = &Y.,
              binary_predictors = &binary_predictors.,
              continuous_predictors = &continuous_predictors.,
              indata = sldat.&tablename.,
              library = &library.,
              folds = &folds.,
              method = NNLS,
              dist = GAUSSIAN );
run;
