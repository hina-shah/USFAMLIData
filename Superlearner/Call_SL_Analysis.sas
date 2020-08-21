%let serverpath = P:/Users/hinashah;
%let lib_path = &serverpath./SASFiles/SLData_ExtraLearners;

%let suffix =;
%let tablename = sl_finalrandselecttable1&suffix.;
%let sl_table = with_extra_learners&suffix.;

ods listing gpath="&lib_path/" image_dpi=500;

*Point and include the SL macro;
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\super_learner_macro.sas";
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\super_learner_wrapper_macro.sas";
%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\sas_superlearner_extra_learners.sas";

libname sldat "&lib_path.";

%SuperLearnerWrapper(
    indata=sldat.&tablename,
    outdata=sldat.&sl_table,
    outpdfpath=&lib_path./ExL_Report&suffix..pdf,
    train_proportion=0.8,
    use_patient_split=0
);
