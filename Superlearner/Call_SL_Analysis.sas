%let serverpath = H:/Users/hinashah;
%let lib_path = &serverpath./SASFiles/SLData_Del923;

%let suffix =_cat3trg;
%let tablename = sl_finalrandselecttable1&suffix.;
%let sl_table = sl_out_&suffix.;
%let outpdfpath = &lib_path/&sl_table..pdf;
%let figure_suff = &suffix.;
ods listing gpath="&lib_path/" image_dpi=200;

*Point and include the SL macro;
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\super_learner_macro.sas";
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\super_learner_wrapper_macro.sas";
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\sas_superlearner_extra_learners.sas";
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\SLFigures.sas";

libname sldat "&lib_path.";

%LET Y = ga_edd;
%LET ordinal_predictors=  current_smoker former_smoker inf_gender ;
%LET binary_predictors =   hiv chronic_htn preg_induced_htn diabetes gest_diabetes;
%LET continuous_predictors = fl_1 bp_1 ac_1 hc_1 mom_age_edd mom_weight_lb mom_height_in;
%LET library = gampl lasso hpglm rf nn nn15 nn6 nn50 nn100 nn500 hadlock intergrowth nichd;
%LET folds = 10;


%SuperLearnerWrapper(
    indata=sldat.&tablename,
    outdata=sldat.&sl_table,
    outpdfpath=&outpdfpath.,
	fig_suf = &figure_suff.,
    train_proportion=0.8,
    use_patient_split=0,
	Y=&Y.,
	binary_predictors = &binary_predictors.,
	continuous_predictors = &continuous_predictors.,
	ordinal_predictors = &ordinal_predictors.,
	folds=&folds.,
	library = &library.
);
