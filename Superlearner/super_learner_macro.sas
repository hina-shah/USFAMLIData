%PUT super learner macro v1.1.10;
/**********************************************************************************************************************
* Author: Alex Keil
* Program: super_learner_macro.sas
* Version: 1.1.10
* Contact: akeil@unc.edu
* Tasks: general purpose macro to get cross validated predictions from super learner using parametric, semiparametric, 
   and machine learning functions in SAS 
* Requirements:
    Base SAS 9.X (subversion X varies depending on learners used, 9.4+ recommended)
    SAS/OR (14.1+ recommended)
    SAS/STAT (14.1+ recommended)
* Tested on: 
  OS: Windows 8.1 
  Base SAS: 9.4_TS1M3, 9.4_TS1M5
  SAS Analytics: 14.1, 14.3
  R: 3.30
* Highly recommended:
    SAS Enterprise Miner High Performance Procedures (required for many learners)
* Optional for enhancement:
    SAS/IML, R v3.3+ and RLANG system option enabled in sasv9.cvg
* Description: 
super learner macro: this is a macro for making predictions of a binary or continuous variable
  using the super learner algorithm developed by Mark van der Laan and colleagues
   
   This macro implements a version of super learner to generate predictions of a continuous or 
   binary variable. The cross-validation probability of the event from each learner is used to 
   estimate the superlearner coefficients that describe the weighted combination of algorithms
   that go into the superlearer probability/regression function. 
   These coefficients are used with the algorithms fit to the full data to generate predictions. 
   Note that an additional cross-validation step can be used to estimate the cross-validated 
   superlearner algorithm risk to assess the potential for overfit of the superlearner coefficients.
   This step is accessible through the CVSuperLearner macro
   
   More info on the algorithm can be found in section 3.3.2 of "Targeted Learning" by van Der Laan and Rose (1ed);
    specifically, this macro implements the algorithm shown in figure 3.2
  This macro is accompanied by a manuscript:
   Keil, A. P. (2018). Super Learning in the SAS system. arXiv preprint arXiv:1805.08058.
     https://arxiv.org/abs/1805.08058
      
   Currently available learners: 
       linear model, logistic model, lasso (linear and logit), least angle regression, 
       elastic net, generalized additive models, neural net, random forest
       classification/regression trees (cart), boosted cart, bagged cart, multivariate adaptive
       regression spline

This programs structure is: 
  0) main "SuperLearner" and "CVSuperLearner" macro definition (with advanced versions: _SuperLearner and _CVSuperLearner)
  1) helper functions
  2) learners (standardized macro input to allow modularity in adding new learners)
  3) main subfunctions
  4) sample usage with test (comment out for using this in an %include statement)

* Keywords: prediction, causal inference, machine learning, gam, random forest, super learner, cross validation
*           
* Released under the GNU General Public License: http://www.gnu.org/copyleft/gpl.html
* MAJOR UPDATES (MINOR UPDATES LISTED AT BOTTOM OF PROGRAM): 
* 26-Jun-2018: v1.0 released   
**********************************************************************************************************************/

%LET suppresswarn = *; *set to * to turn off all warnings about the correct sas version for each proc, empty otherwise;

%MACRO SuperLearner( Y=,
                     X=,
                     by=,
                     intvars=,
                     binary_predictors=,
                     ordinal_predictors=,
                     nominal_predictors=,
                     continuous_predictors=,
                     id=,
                     weight=, 
                     indata=, 
                     preddata=, 
                     outdata=sl_out,
                     dist=GAUSSIAN,
                     library= glm, 
                     trtstrat=FALSE, 
                     folds=10, 
                     method=BNNLS,
                     /* deprecated */
                     predvar=,
                     gfstrat=, 
                     risk=,
                     cv=
                     );
/*
 Main Super Learner macro parameters:

  Y=, *dependent variable, the variable you are trying to predict
  by=,                    * by variables (do super learner for every value of the by variable - must be only a single variable, and must be sorted!;
  intvars=,               * variables upon which you are interventing (only capable of 1/0 contrasts at this point)
  binary_predictors=,     * binary variables, (including binary intervention variables) 
  ordinal_predictors=,    * ordinal variables, (including ordinal intervention variables) 
  nominal_predictors=,    * nominal variables, (including nominal intervention variables) 
  continuous_predictors=, * continuous variables, (including continuous intervention variables) 
  id=,                    * name of variable of a unique identifier for units (optional)
  weight=,                * variable name for observation weights/importance weights/frequency weights 
  indata=,                * training data (sample data)
  preddata=,              * (optional) data in which you wish to make predictions (if blank, will make predictions in 'indata')
  outdata=,               * name of output dataset with SL + library specific predictions
  dist=,                  * assumed distribution of Y: only supports GAUSSIAN or BERNOULLI;
  library= logit,         * superlearner library (* Enterprise Miner procedure), CASE SENSITIVE (use lowercase), limited to space separated list of:
                            back (backward selection by BIC)
                            bagging (* Bootstrap aggregation of regression/classification trees)
                            bayesnet (* Bayesian network [binary only])
                            boxcox (Box-Cox transformation of target variables, positively bound continuous Y only)
                            boost (* Gradient boosting of regression/classification trees)
                            cvcart (classification/regression tree with cross validated selection of meta parameters)
                            cart (classification/regression tree, no cross validation)
                            enet (elastic net - warning for binary outcome: does not respect [0,1] probability space) 
                            gam (generalized additive model with 3 df splines on all continuous variables)
                            gampl (faster generalized additive model with 3 df splines on all continuous variables)
                            glm (linear or logistic regression: slower wrappers for logit and linreg)
                            knn ([bernoulli only] k-nearest neighbors classification)
                            lar (least angle regression - warning for binary outcome: does not respect [0,1] probability space)
                            lasso (LASSO)
                            lassob (LASSO with glmselect [use caution with binary variables] - may be appropriate for older sas versions)
                            cvlasso (LASSO with cross validated selection of shrinkage parameter)
                            logit (main term logistic regression)
                            linreg (main term linear regression)
                            mars (multivariate adaptive regression splines)
                            mean (marginal mean of the prediction variable)
                            nbayes (* naive Bayes)
                            bspline (b spline regression)
                            pbspline (penalized basis spline regression [SINGLE CONTINUOUS PREDICTOR ONLY])
                            probit (main term probit regression)
                            ridge (ridge regression - warning for binary outcome: does not respect [0,1] probability space)
                            quantreg (Quantile regression for the median - warning for binary outcome: does not respect [0,1] probability space)
                            rf (random forest)
                            rfoob (random forest, using out of bag predictions and modified selection criteria)
                            nn (* neural network)
                            sherwood (* random forest, using proc ARBOR, sampling with replacement)
                            swise (Stepwise model selection with HPGENSELECT - may be appropriate alternative to lasso for older sas versions)
                            **** note that lasso, rf and cart may require >= SAS 9.4 TS1M3 + optional high powered data mining procedures to work
  
                            ALSO includes multiple versions that include all first order interaction terms:
                              backint, logitint, linregint, lassoint, lassobint, cvlassoint, swiseint, larint, enetint, gamint, gamplint, marsint, probitint
                              
                            Included R functions (requires SAS/IML and RLANG system option enabled) allows a limited set of functions that call learners in the R programming language:
                              r_bagging:  Bootstrap aggregation of regression/classification trees (requires ipred, rpart packages)
                              r_bart:  Bayesian additive regression/classification trees (requires dbarts package)
                              r_boost:  Gradient boosting regression/classification (requires xgboost)
                              r_enet:  elastic net regression/classification with cross validated selection of shrinkage parameter (requires glmnet package)
                              r_gam:  generalized additive model (requires gam, foreach, splines packages)
                              r_lasso:  LASSO regression/classification with cross validated selection of shrinkage parameter(requires glmnet package)
                              r_mars: MARS - multivariate adaptive regression splines (requires earth package)
                              r_polymars: MARS - multivariate adaptive polynomial regression splines (requires polspline package)
                              r_ridge:  ridge regression/classification with cross validated selection of shrinkage parameter (requires glmnet package)
                              r_rf: random forest using R superlearner defaults (requires randomForest package)
                              r_sl:  R based super learner with several default learners (glm, lasso, bart, rf, mars) (requires SuperLearner package)
                              r_svm:  support vector machine regression/classification (requires e1071)
                              **** note: package installation should happen automatically when these are used for the first time
                                if RLANG configured correctly

trtstrat=false,           * whether to use stratified (by treatment variable) models (true or false) - deprecated version is gfstrat
folds=10,                  * number of folds for cross validation
method=NNLS,              * fitting approach to estimate coefficients for super learner, the level-1 model using Wolperts term
                            Defaults: NNLS[default for gaussian dist] NNLOGLIK[default for bernoulli dist], 
                            Other options: CCLOGLIK, LOGLIK, CCLS, OLS, CCLAE, NNLAE, LAE
                            Methods are possibly indexed by prefixes: NN, CC, [none], 
                              where NN implies non-negative coefficients that are standardized after fitting to sum to 1. 
                              CC implies a convexity constraint where the super learner fit is subject to a constraint 
                              that forces the coefficients to fall in [0,1] and sum to 1.0. No prefix implies no 
                              constraints (which results in some loss of asymptotic properties such as the oracle property).
                              Note: OLS violates this naming convention, but LS will also be accepted and is equivalent to OLS
                            OLS/LS methods use an L2 loss function (least squares)
                            LOGLIK methods use a loss function corresponding to the binomial likelihood with a logit
                              link function
                            LAE methods use an L1 loss function (least absolute error), which will not penalize 
                              outliers as much as L2 methods, and is also non-differentiable at the minimum
                              which may cause computational difficulties
                            AUC method also exists for binary outcomes, but current implementation is slow and fails frequently 
                              and is not recommended
outresults=sl_summary,
outslrisks=sl_cvrisk,
outslcoefs=sl_coefs,
* other deprecated parameters
gfstrat=false,           * [DEPRECATED] whether to use stratified (by treatment variable) models (true or false), changed to 'trtstrat'
cv=true,                 * [DEPRECATED] whether to cross validate (true or false) - always true
risk=                    * [DEPRECATED] loss function for superlearner coefficient estimation (can be L2 [not case sensitive] or ENTROPY) - replaced by 'dist' and 'method'
)

NOTES:
 GLOBAL MACRO VARIABLES CREATED (IF USER DEFINED VERSIONS OF THESE ARE CREATED THEY WILL BE OVERWRITTEN):
  SLseed, SLShowOnce, SLSampSize, SLsas94, SLsas93, SLsas92, SLPredMiss, SLPBinary, SLIXterms

SAMPLE USAGE (simple confounding problem with all binary covariates, using 4 learners and 5 fold cross-validation): 
%SuperLearner(Y=y,
              intvars=x,
              binary_predictors= x l,
              ordinal_predictors=,
              nominal_predictors=,
              continuous_predictors=,
              weight=, 
              indata=a, 
              preddata=, 
              outdata=sl_testdata,
              library= logit logitint cart nn rf,
              cv=true,
              trtstrat=true, 
              method=NNLOGLIK, 
              dist=BERNOULLI);

*/
/***************************************************************************
Future plans:
1) Save model fits to allow prediction with trained algorithms
2) Enrich the possible treatment interventions 
3) Make custom learners easier to create (needs stable syntax, so not possible with some learners) 
4) Improve documentation
5) Add learners: better variable selection (hpreduce)
6) More robust R coding
***************************************************************************/

/*
SuperLearner:
 this macro is a wrapper for the more advanced _superlearner macro, which may be called by the user
*/
%_SuperLearner(      Y=&Y,
                     X = &X,
                     by=&by,
                     intvars= &intvars ,
                     binary_predictors= &binary_predictors ,
                     ordinal_predictors= &ordinal_predictors ,
                     nominal_predictors= &nominal_predictors ,
                     continuous_predictors= &continuous_predictors,
                     id = &id, 
                     weight=&weight, /* observation weights/importance weights/frequency weights */
                     indata= &indata , 
                     preddata= &preddata , 
                     outdata= &outdata ,
                     dist=&dist ,
                     library=%str(&library) , 
                     trtstrat=&trtstrat , 
                     folds=&folds , 
                     method=&method ,
                     outslrisks=sl_cvrisk ,
                     outslcoefs=sl_coefs ,
                     outresults=sl_summary,
                     printres=TRUE ,
                     printlearner=FALSE,
                     cleanup=TRUE ,
                     trimbound=0.001 ,
                     shuffle=TRUE,
                     seed=12345,
                     slridgepen=0.3, /* ridge regression penalty for methods: RIDGE, NNRIDGE, CCRIDGE */
                     /* kid gloves */
                     runchecks=TRUE , 
                     checkvalid=TRUE,
                     logreport=TRUE,
                     printfolds=TRUE, 
                     verbose=FALSE,
                     speedup=FALSE,
                     simple=TRUE,
                     quietwarning=TRUE,
                     quietnotes=TRUE,
                     timer=TRUE, /* suppress notes being printed to the log */
                     forcer=FALSE, 
                     /* deprecated */
                     getfoldrisks=,
                     predvar= &predvar ,
                     risk=&risk ,
                     cv=&cv ,           
                     gfstrat=&gfstrat
                   
);
%MEND SuperLearner;

%MACRO CVSuperLearner(
                     Y=,
                     X=,
                     binary_predictors=  ,
                     ordinal_predictors=  ,
                     nominal_predictors=  ,
                     continuous_predictors=  ,
                     id=,
                     weight=, /* observation weights/importance weights/frequency weights */
                     indata=  , 
                     dist= GAUSSIAN,
                     library= , 
                     folds= 10, 
                     method= BNNLS
);
/*
CVSuperLearner:
 this macro is a wrapper for the more advanced _cvsuperlearner macro, which may be called by the user
*/

%_CVSuperLearner(
                     Y=&Y,
                     X=&X,
                     binary_predictors= &binary_predictors ,
                     ordinal_predictors= &ordinal_predictors ,
                     nominal_predictors= &nominal_predictors ,
                     continuous_predictors= &continuous_predictors ,
                     id=&id,
                     weight=&weight, /* observation weights/importance weights/frequency weights */
                     indata= &indata , 
                     dist=&dist ,
                     library=%str(&library) , 
                     slfolds=&folds , 
                     cvslfolds=&folds,
                     method=&method ,
                     outcvresults=cvsl_summary,
                     printfoldres=FALSE ,
                     printlearner=FALSE,
                     cleanup=TRUE ,
                     trimbound=0.001 ,
                     shuffle=TRUE,
                     seed=12345,
                     slridgepen=0.3, /* ridge regression penalty for methods: RIDGE, NNRIDGE, CCRIDGE */
                     /* kid gloves */
                     cvrunchecks=TRUE , 
                     cvcheckvalid=TRUE,
                     logreport=FALSE, 
                     printfolds=FALSE, 
                     reportcvfolds=TRUE,  /*report CV fold of folds in log */
                     verbose=FALSE,
                     speedup=FALSE,
                     simple=TRUE,
                     quietwarning=TRUE,
                     quietnotes=TRUE,
                     timer=TRUE
);
%MEND;


/*
main work horse macros: _SuperLearner and _CVSuperLearner;
*/
%MACRO _SuperLearner(Y=,
                     X=,
                     by=,
                     intvars=,
                     binary_predictors=,
                     ordinal_predictors=,
                     nominal_predictors=,
                     continuous_predictors=,
                     id=,
                     weight=, /* observation weights/importance weights/frequency weights */
                     indata=, 
                     preddata=, 
                     outdata=,
                     dist=,
                     library= logit, 
                     trtstrat=false, 
                     folds=10, 
                     method=,
                     outslrisks=sl_cvrisk,
                     outslcoefs=sl_coefs,
                     outresults=sl_summary,
                     printres=FALSE,  /* print summary + coefs and loss of each algorithm */
                     printlearner=FALSE, /* print learner to log each time it is used */
                     cleanup=FALSE,   /* get rid of temporary datasets created by macro */
                     trimbound=0.001, /*trimming of logit variables to ensure boundedness */
                     shuffle=TRUE,    /*randomly shuffle data prior to setting CV folds*/
                     seed=,           /*seed for super learner (shuffling + learners with randomness)*/
                     slridgepen=0.3, /* ridge regression penalty for methods: RIDGE, NNRIDGE, CCRIDGE */
                     runchecks=FALSE, /*check for missing data, proper distribution settings, case of parameter values*/
                     checkvalid=FALSE,  /*remove learners that produce missing values */
                     logreport=FALSE,   /* report useful information, e.g. SL coefficients to the sas log */
                     printfolds=TRUE,  /*report fold of folds in log */
                     verbose=FALSE,     /* print out a few extra things*/
                     speedup=FALSE,       /* do some things to make for faster computation */
                     simple=FALSE,      /* if true, print out a note in final summary about speed boost with workhorse macro */
                     quietwarning=FALSE, /* suppress some warnings being printed to the log */
                     quietnotes=FALSE, /* suppress notes being printed to the log */
                     timer=FALSE, /* suppress notes being printed to the log */
                     forcer=FALSE, /* if true, will force re-install current version of all r packages called by the macro + dependencies  */
                     /*deprecated*/
                     getfoldrisks=,   /* report fold specific risks - too slow to use regularly */
                     predvar= ,
                     cv=,
                     risk=,
                     gfstrat=
) / MINOPERATOR MINDELIMITER=' ';
  
  * _SuperLearner macro: workhorse function that can be called by the user and contains finer control
    and less error checking than the SuperLearner macro;
  %PUT NOTE: Super learner started;
  %IF &speedup=TRUE %THEN %DO;
   *eventually there will be more here;
   OPTIONS COMPRESS=BINARY;
  %END;
  %IF &quietwarning=TRUE %THEN ODS SELECT NONE;;
  %IF &quietnotes=TRUE %THEN OPTIONS NONOTES;;
  %IF &timer=TRUE %THEN %DO;DATA __SLtime; start = time();%END;
  %GLOBAL SLseed;
  %IF &seed= %THEN %DO;
   DATA _NULL_;
    seed = ROUND(RAND('UNIFORM')*(2147483647));
    CALL SYMPUT("SLseed", PUT(seed, 18.0));
  %END;
  %ELSE %LET slseed=&seed;

  * check methods/dist specification;
  %IF &dist^= AND &method= %THEN %DO;
   %__SLwarning(%STR(No method specified, setting to default NNLS.));
   %LET method=NNLS;;
  %END;
  %IF NOT (&method IN(NNLOGLIK CCLOGLIK NNLS CCLS OLS LS NNLAE CCLAE LAE LOGLIK AUC ADAPTRF RIDGE CCRIDGE NNRIDGE 
                      BNNLOGLIK BCCLOGLIK BLOGLIK BNNLS BCCLS BOLS BLS BNNRIDGE BCCRIDGE BRIDGE BNNLASSO BCCLASSO BLASSO BNNLAE BCCLAE BLAE)) 
  %THEN %__badSLerror(%str(Method &method not recognized));
  %IF &method=LS %THEN %LET method=OLS;; *allow naming conventions to be followed strictly;
  %IF &method=BLS %THEN %LET method=BOLS;; *allow naming conventions to be followed strictly;
  * format to reverse outcome coding for some procs (e.g. probit);
  PROC FORMAT; VALUE SLrevf 1='0' 0='1';RUN; * by default models outcome = 0;
  %IF &runchecks=TRUE %THEN %DO;
    * startup message;
    %IF %SYMEXIST(SLShowOnce)=0 %THEN %DO; 
      %GLOBAL SLShowOnce;
      %__SLnote(%str(SuperLearner Macro: please report bugs to akeil@unc.edu));
      %LET SLShowOnce='shown';
    %END;
       
    *allow for some variation in how macro is called;
    %IF &trtstrat^= %THEN %LET trtstrat=%UPCASE(&trtstrat);
    %IF &risk^= %THEN   %LET risk   = %SYSFUNC(UPCASE(%SYSFUNC(DEQUOTE(&risk))));;
    %IF &method^= %THEN %LET method = %SYSFUNC(UPCASE(%SYSFUNC(DEQUOTE(&method))));;
    %IF &dist^= %THEN   %LET dist   = %SYSFUNC(UPCASE(%SYSFUNC(DEQUOTE(&dist))));;
    %IF &library^= %THEN   %LET library   = %SYSFUNC(LOWCASE(%SYSFUNC(DEQUOTE(&library))));;
    %IF &dist IN (BERN BIN BINARY B) %THEN %LET dist=BERNOULLI;
    %IF &dist IN (GAUSS NORM NORMAL G N) %THEN %LET dist=GAUSSIAN;
    
    *announce deprecations and set some parameters by default;
    %__deprecations();

    %IF (&x^= AND (&binary_predictors^= OR &ordinal_predictors^= OR &nominal_predictors^= OR &continuous_predictors^=)) %THEN %DO;
      %__SLWarning(%(Macro parameters X and one of: binary_predictors, ordinal_predictors, nominal_predictors, continuous_predictors are specified. Only one should be specified. Setting X to be empty));
      %LET x=;
    %END;
    %ELSE %IF &x^= %THEN %DO;
      %LET predictors = &X;
      %__SLNote(%STR(Macro parameter X is specified. All variables with num levels > .05*N assumed continuous, otherwise nominal or binary));
      PROC SQL NOPRINT; SELECT COUNT(&Y)/20 into :SLcutoff from &indata ;quit;
      %LET xidx=1;
      %DO %WHILE(%SCAN(&X, &xidx)^=);
          %__SLPNumlevels(&indata, %SCAN(&X, &xidx));
          * variable %SCAN(&X, &xidx) has at least &SLPNumLevels levels;
          %IF %TRIM(&SLPNumLevels)=2 %THEN %LET binary_predictors = &binary_predictors %SCAN(&X, &xidx);
          %ELSE %IF %SYSEVALF(%TRIM(&SLPNumLevels)<=&SLcutoff) %THEN %LET nominal_predictors = &nominal_predictors %SCAN(&X, &xidx);
          %ELSE %IF %SYSEVALF(%TRIM(&SLPNumLevels)>&SLcutoff) %THEN %LET continuous_predictors = &continuous_predictors %SCAN(&X, &xidx);
        %LET xidx=%EVAL(&xidx+1);
      %END;
    %END;
    %ELSE %DO;   
      %LET predictors = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
    %END;
    *install r packages if needed;
    %__installR();
    *or force install;
    %IF &forcer=TRUE %THEN %__forceinstallR();;
   
    %IF &predvar = AND &Y = %THEN %DO;
     %__badSLerror(must set 'Y' to the name of the variable you wish to predict);
     %RETURN;
    %END;
    %ELSE %__SLnote(Making predictions of &Y);
    %IF &predictors = %THEN %DO;
     %__badSLerror(Must have variables for at least one of: binary_predictors, ordinal_predictors, 
                nominal_predictors, continuous_predictors);
    %END;
    * check for any missing values in predictors, and fail if any;
    %__CheckMissing(&predictors, &indata);
    *collect some information;
    DATA __sltm0017_; SET &indata; /*IF _N_<300*/; RUN; *todo: refactor so less expensive and less error prone;
    %__SLPBinary(__sltm0017_, &Y); *check whether or not predicting binary variable (assumed continuous otherwise);
    *catch some common errors (some will stop the macro, some will result in automatic corrections);
    %__commonerrors(); 
    %__checklibrary(&library); 
    
  %END; *runchecks;
  %IF %__TrueCheck(&trtstrat) %THEN %__intspeccheck();
  %IF &preddata = %THEN %DO;
    *predictions based on sample data;
    %LET preddata = &indata;
    %LET insample = true;
    %__SLnote(Making in-sample SL predictions for "&Y" in dataset "&indata");
  %END;
  %ELSE %DO;
    *predictions based on external data;
    %LET insample = false;;
    PROC SQL NOPRINT; SELECT COUNT(%SCAN(&x &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors, 1)) into :pSLSampSize from &preddata ;quit;
   %__SLnote(Making SL predictions for "&Y" in dataset "&preddata" and "&indata");
  %END;
  *define some fcmp functions;
  %__MKFUNCS();
  *prepare interaction terms;
  %__makeintx(bins = &binary_predictors,  others = &ordinal_predictors &nominal_predictors &continuous_predictors);
/*
_main: the absolute barebones super learner macro (not to be called on its own)
*/
  %MACRO _main(indata, y, id, folds, insample, preddata, library, risk, method, dist, outdata, outslcoefs, outslrisks);
    * the bulk of the superlearner functions go in here;
    %GLOBAL SLSampSize;
    %IF &id = %THEN %DO; 
      PROC SQL NOPRINT; SELECT COUNT(&Y) into :SLSampSize from &indata  ;quit;
    %END;
    %IF &id ^= %THEN %DO; 
      PROC SQL NOPRINT; SELECT COUNT(UNIQUE &ID) into :SLSampSize from &indata  ;quit;
    %END;
    *create AUC methods;
    %IF &method=AUC %THEN %_mkmethods();;
    %__SLnote(total observations/IDs in training data: %TRIM(&SLSampSize).);
    *cross validation estimation of superlearner coefficients for prediction;
    %__SLnote(Using cross validation with &folds fold);
    %__SLnote(Approximately %EVAL(&SLSampSize/&folds) per fold);
    *prepare data for cross validation (split by training/validation sets);
    %_cvsetup(Y=&Y, id=&id, indata=&indata, outdata=__sltm0013_, folds=&folds);
    * set up data for possible interventions (1 or 0 only);
    %_pred_setup(Y=&Y, intvars=&intvars, indata=__sltm0013_, outdata=__sltm001_, preddata=&preddata, insample=&insample); 
    * get cross validated predictions from each learner;
    OPTIONS NOQUOTELENMAX;
    %_getcvpreds&dist(Y=&Y, indata=__sltm001_, outdata=__sltm002_, library=&library, weight=&weight, id=&id, folds=&folds, seed=&slseed);;
    *get (cross-validated) risk estimates for each fold and superlearner coefficients for overall fit;
    %_sl_cvrisk(indata=__sltm002_, outdata=__sltm002_, library=&library, outcoef=&outslcoefs, risk=&risk, method=&method, outcvrisks=&outslrisks, seed=&slseed); 
    OPTIONS QUOTELENMAX;
    *restrict to valid predictions (non missing);
    %IF %__TrueCheck(&checkvalid) %THEN %LET library = &validlib; 
    %ELSE %LET droplib=none;
    *final predictions from super-learner;
    %_SLPredict(indata=__sltm002_, outdata=&outdata, library=&library, incoef=&outslcoefs, inrisk=&outslrisks); 
    *write cross validated risk (loss function) to the log;
    %IF %__TrueCheck(&logreport) %THEN %_cvriskreport(indata=&outdata, library=&library);; 
  %MEND _main;
  %IF &by ^= %THEN %DO;
    %LOCAL byj bylevs;
    %__CLEANUP(%str(&outdata, &outslcoefs, &outslrisks));
    %IF %SCAN(&by, 2)^= %THEN %__badSLerror(%str("by" statement only supports one by variable));
    PROC SQL NOPRINT; SELECT COUNT(DISTINCT &by) INTO :bylevs FROM &indata; QUIT;
    
    *start by loop;
    %LET byj=1;
    %DO %WHILE(%EVAL(&byj <= &bylevs));
      * find current value of by variable;
      * count all levels of by variable (this table gets deleted repeatedly) - todo: refactor;
      PROC FREQ DATA = &indata NOPRINT;
       TABLE &by / OUT=__sltm0018(KEEP=&by);
      RUN;
      DATA _NULL_;
       SET __sltm0018;
       IF _n_ = &byj THEN CALL SYMPUT('currbyval', PUT(&by, BEST9.));
      RUN;
      *restrict dataset to current level of by variable;
      DATA __sltm0000; SET &indata; WHERE &by = &currbyval; RUN;
      %IF &preddata ^= %THEN %DO; DATA __sltm1000; SET &preddata; WHERE &by = &currbyval; RUN; %END;
      *run super learner;
      %PUT By processing &byj of %trim(&bylevs);
      /**/
      %_main(__sltm0000, &Y, &id, &folds, &insample, __sltm1000, &library, &risk, &method, &dist, __sltm0100, __sltm0101, __sltm0102);
      /**/
      DATA __sltm0101; SET __sltm0101; &by=&currbyval;
      DATA __sltm0102; SET __sltm0102; &by=&currbyval;
      *append data;
      PROC APPEND DATA = __sltm0100 BASE = &OUTDATA FORCE;
      PROC APPEND DATA = __sltm0101 BASE = &outslcoefs FORCE;
      PROC APPEND DATA = __sltm0102 BASE = &outslrisks FORCE; RUN;
      PROC SQL NOPRINT; DROP TABLE __sltm0100, __sltm0101, __sltm0102, __sltm0000, __sltm1000; QUIT;
      *end by loop;
      %LET byj=%EVAL(&byj+1);
    %END; 
    *end if by;
  %END;
  %IF &by = %THEN %DO;
    /**/
    %_main(&indata, &Y, &id, &folds, &insample, &preddata, &library, &risk, &method, &dist, &outdata, &outslcoefs, &outslrisks);
    /**/
  %END;
  PROC SORT DATA = &outdata; BY &BY __seqid__ __cvid__ __int; RUN;
  %IF %__TrueCheck(&cleanup) %THEN %DO;
    * delete some temporary datasets, fcmp functions;
    %__FUNCLEANUP;
    %__CLEANUP(%str(__sltm001_, __sltm001_0, __sltm001_1, __sltm002_, __sltm003_, __sltm004_, __sltm005_, __sltm006_, __sltm007_, __sltm008_, 
                   __sltm009_, __sltm0010_, __sltm0011_, __sltm0012_, __sltm0013_, __sltm0014_, __sltm0015_, __sltm0016_, __sltm0017_, _namedat));
  %END;
  ODS SELECT ALL;
  %IF %__TrueCheck(&printres) %THEN %__printsummary(Y=&Y, 
     predictors=&binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors, 
     library=&library, folds=&folds, method=&method, dist=&dist, shuffle=&shuffle, preddata=&preddata, indata=&indata,
     outcoef=&outslcoefs,outcvrisk=&outslrisks,outresults=&outresults, n=&SLSampSize);;
  %IF %__FalseCheck(&printres) %THEN %__noprintsummary(Y=&Y, 
     predictors=&binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors, 
     library=&library, folds=&folds, method=&method, dist=&dist, shuffle=&shuffle, preddata=&preddata, indata=&indata,
     outcoef=&outslcoefs,outcvrisk=&outslrisks,outresults=&outresults, n=&SLSampSize);;
  %IF %__TrueCheck(&timer) %THEN %DO;
    DATA __SLtime; SET __Sltime;
      end = time();
      duration = (end-start)/60;
    DATA _NULL_; SET __Sltime; CALL SYMPUT("runtime", PUT(duration, 10.3));
    PROC SQL NOPRINT; DROP TABLE __SLTIME;
  %END;
  RUN; QUIT; RUN;
  OPTIONS NOTES;
  %PUT NOTE: Super learner completed, predictions available in dataset &outdata ;
  %IF %__TrueCheck(&timer) %THEN %PUT NOTE: %str(Super learner took %TRIM(&runtime) minutes to complete);
%MEND _SuperLearner;

%MACRO _CVSuperLearner(
                       Y=,
                       X=,
                       binary_predictors=  ,
                       ordinal_predictors=  ,
                       nominal_predictors=  ,
                       continuous_predictors= ,
                       id=,
                       weight= , 
                       indata= , 
                       dist= ,
                       library= , 
                       slfolds=10 , 
                       cvslfolds=10,
                       method=BNNLS,
                       outcvresults=cvsl_summary,
                       reportcvfolds=FALSE,
                       printfoldres=FALSE ,
                       printfolds=FALSE,  /*report fold of folds in log */
                       printlearner=FALSE, /* print learner to log each time it is used */
                       cleanup=TRUE ,
                       trimbound=0.001 ,
                       shuffle=TRUE,
                       seed=12345,
                       slridgepen=0.3, /* ridge regression penalty for methods: RIDGE, NNRIDGE, CCRIDGE */
                       /* kid gloves */
                       cvrunchecks=FALSE , 
                       cvcheckvalid=FALSE,
                       logreport=FALSE, 
                       verbose=FALSE,
                       speedup=FALSE,
                       simple=FALSE,
                       quietwarning=FALSE,
                       quietnotes=FALSE,
                       timer=TRUE);
  *todo: add in by group processing;
  OPTIONS NONOTES;
  %LOCAL CVSLV cvSLseed;
  %LET cvSLseed = %EVAL(&SEED);
  %IF &cvSLseed= %THEN %DO;
    DATA _NULL_;
      seed = ROUND(RAND('UNIFORM')*(2147483647));
      CALL SYMPUT("cvSLseed", PUT(seed, 18.0));
    RUN;
  %END;
  PROC SQL NOPRINT;
   CREATE TABLE __cvsltmp001__ AS SELECT *, RANUNI(&cvSLseed) AS __cvslsrt__
    FROM &indata ORDER BY __cvslsrt__;
  DATA __cvsltmp001__;
    SET __cvsltmp001__ END=eof;
    __cvslid__ = _N_;
    IF eof THEN CALL SYMPUT("CVSLsampsize", PUT(_N_, 12.0));
  DATA __cvsltmp001__;
    SET __cvsltmp001__;
    DO k = 1 TO &CVSLfolds;
      IF &CVSLsampsize/&CVSLfolds*(k-1) < __cvslid__ <= &CVSLsampsize/&CVSLfolds*k THEN __CVSLfold= k;
    END;
  DROP k;
  %__CleanUp(%STR(__cvsltmp006__)); QUIT;
  OPTIONS NOTES;
  %LET CVSLV = 1;
  %DO %WHILE (%EVAL(&CVSLV <= &CVSLfolds));
    OPTIONS NONOTES;
    DATA __cvsltmp002__; SET __cvsltmp001__(WHERE=(__CVSLfold^=&CVSLV));run;
    DATA __cvsltmp003__; SET __cvsltmp001__(WHERE=(__CVSLfold=&CVSLV));run;
    OPTIONS NOTES;
      %IF %__truecheck(&reportcvfolds) %THEN  %__SLnote(CVSuperLearner fold &CVSLV of &CVSLfolds);;
      %_SuperLearner(Y=&Y,
                     X=&X,
                     by=,
                     binary_predictors= &binary_predictors ,
                     ordinal_predictors= &ordinal_predictors ,
                     nominal_predictors= &nominal_predictors ,
                     continuous_predictors= &continuous_predictors ,
                     id=&id,
                     weight= &weight, 
                     indata=  __cvsltmp002__ , 
                     preddata=__cvsltmp003__, 
                     outdata= __cvsltmp004__ ,
                     dist=&dist ,
                     library=%str(&library) , 
                     intvars= , /* should be disabled here if you want CV risk */ 
                     trtstrat= FALSE, /* should be disabled here if you want CV risk */ 
                     folds=&slfolds , 
                     method=&method ,
                     outslrisks=cvsl_cvrisk&CVSLV ,
                     outslcoefs=cvsl_coefs&CVSLV ,
                     outresults=cvsl_summary&CVSLV,
                     printlearner=&printlearner ,
                     printres=&printfoldres ,
                     printfolds=&printfolds,
                     cleanup=&cleanup ,
                     trimbound=&trimbound ,
                     shuffle=TRUE,
                     slridgepen=&slridgepen, /* ridge regression penalty for methods: RIDGE, NNRIDGE, CCRIDGE */
                     seed=&cvSLseed,
                     /* kid gloves */
                     runchecks=  &cvrunchecks  , 
                     checkvalid= &cvcheckvalid,
                     logreport=&logreport, 
                     getfoldrisks=FALSE,
                     verbose=&verbose,
                     speedup=FALSE,
                     simple=FALSE,
                     quietwarning=&quietwarning,
                     quietnotes=&quietnotes,
                     timer=&timer
    );
    OPTIONS NONOTES;
    /**/
    %_get_slcvrisk(indata=__cvsltmp004__(WHERE=(__CVSLfold=&CVSLV)), Y=&y, library=&library, outrisk=__cvsltmp005__, weight=&weight, method=&METHOD, debug=FALSE)  
    /**/
    PROC APPEND DATA = __cvsltmp005__ BASE = __cvsltmp006__ FORCE; RUN;
    PROC SQL NOPRINT; DROP TABLE cvsl_summary&CVSLV, cvsl_coefs&CVSLV, cvsl_cvrisk&CVSLV; QUIT;
    %LET CVSLV = %EVAL(&CVSLV + 1);
    %END;
    PROC MEANS DATA = __cvsltmp006__ NOPRINT;
      CLASS Learner order;
        VAR CVrisk ;
      OUTPUT OUT = &outcvresults(WHERE=(Learner^="" AND order ^=.) DROP=_:) MEAN= STDERR= MIN= MAX=/ AUTONAME;
     RUN;
    PROC MEANS DATA = __cvsltmp006__ NOPRINT;
      CLASS Learner order;
        VAR Coefficient ;
      OUTPUT OUT = __cvsltmp007__(WHERE=(Learner^="" AND order ^=.) DROP=_:) MEAN=coef_mean;
     RUN;
    OPTIONS MERGENOBY = NOWARN;
    DATA &outcvresults;
      LENGTH Learner $39 coef_mean 8 CVrisk_mean 8 CVrisk_stderr 8 CVrisk_min 8 CVrisk_max 8;
      MERGE __cvsltmp007__ &outcvresults;
    RUN;
    PROC SORT DATA = &outcvresults;
      BY order;
    RUN;
    PROC PRINT DATA = &outcvresults(DROP=order) NOOBS;
    RUN;
    %IF %__TrueCheck(&CLEANUP) %THEN %DO;
      PROC SQL NOPRINT; DROP TABLE __cvsltmp001__, __cvsltmp002__, __cvsltmp003__, __cvsltmp004__, __cvsltmp005__, __cvsltmp006__, __cvsltmp007__, __cvsltmp008__, __cvsltmp009__; QUIT;
    %END;
    OPTIONS NOTES MERGENOBY = WARN;
    %__SLnote(CVSuperLearner finished);
%MEND;

********************************************************;
* Part 1: helper functions;
********************************************************;
%MACRO _mkmethods();
  %LOCAL ncutoffs;
  /* note: allowing for IDs completely broke AUC methods */
  %LET ncutoffs = 500; * number of cutoff points for approximate AUC calculation;
  PROC FCMP OUTLIB = work.__funcs.LOGFUNCS;
  FUNCTION AUC(coef[*], label[*], preds[*,*]) VARARGS;
    * implementing with fixed cutoffs, yielding approximate AUC;
    ARRAY __slp[&slsampsize] / NOSYMBOLS;
    CALL MULT(preds, coef, __slp);
    ARRAY sens[%EVAL(2+&ncutoffs)] / NOSYMBOLS;
    ARRAY fpr[%EVAL(2+&ncutoffs)] / NOSYMBOLS;
    __totp=0;
    __totn=0;
    DO i = 1 TO &slsampsize;
      __totp = __totp + label[i];
      __totn = __totn + (1-label[i]);
    END;
    auc = 0;
    sens[1]=1;
    fpr[1]=1;
    sens[%EVAL(2+&ncutoffs)]=0;
    fpr[%EVAL(2+&ncutoffs)]=0;
    DO j = 2 TO %EVAL(1+&ncutoffs);
      sens[j]=0;
      fpr[j]=0;
      DO i = 1 TO &slsampsize;
        sens[j] = sens[j] + label[i]*(__slp[i]>((j-1)/&ncutoffs))/__totp;
        fpr[j] = fpr[j] + (1-label[i])*(__slp[i]>((j-1)/&ncutoffs))/__totn;
      END;
    END;
    DO j = 2 TO %EVAL(1+&ncutoffs);
      auc = auc + (sens[j-1] - sens[j])*(1-fpr[j])/2 + (sens[j] - sens[j+1])*(1-fpr[j])/2; *trapezoidal sum;
    END;
    RETURN(auc);
  ENDSUB;
  FUNCTION AUCL(idx, coef[*], label[*], preds[*,*]) VARARGS;
    * stupid trick to please proc optmodel ;
  /* note: allowing for IDs completely broke AUC methods */
    ARRAY __slp[&slsampsize] / NOSYMBOLS;
    ARRAY ncoef[1] / NOSYMBOLS;
    DO i = 1 TO DIM(coef);
     CALL DYNAMIC_ARRAY(ncoef, i);
     IF i = idx THEN ncoef[i] = 1; ELSE ncoef[i] = 0;
    END;
    CALL MULT(preds, ncoef, __slp);
    ARRAY sens[%EVAL(2+&ncutoffs)] / NOSYMBOLS;
    ARRAY fpr[%EVAL(2+&ncutoffs)] / NOSYMBOLS;
    __totp=0;
    __totn=0;
    DO i = 1 TO &slsampsize;
      __totp = __totp + label[i];
      __totn = __totn + (1-label[i]);
    END;
    auc = 0;
    sens[1]=1;
    fpr[1]=1;
    sens[%EVAL(2+&ncutoffs)]=0;
    fpr[%EVAL(2+&ncutoffs)]=0;
    DO j = 2 TO %EVAL(1+&ncutoffs);
      sens[j]=0;
      fpr[j]=0;
      DO i = 1 TO &slsampsize;
        sens[j] = sens[j] + label[i]*(__slp[i]>((j-1)/&ncutoffs))/__totp;
        fpr[j] = fpr[j] + (1-label[i])*(__slp[i]>((j-1)/&ncutoffs))/__totn;
      END;
      auc = auc + (sens[j-1] - sens[j])*(1-fpr[j])/2 + (sens[j] - sens[j+1])*(1-fpr[j])/2; *trapezoidal sum;
    END;
    RETURN(auc);
  ENDSUB; 
  RUN;
%MEND _mkmethods;

%MACRO __MKFUNCS();
  OPTIONS CMPLIB = work.__funcs;
  PROC FCMP OUTLIB = work.__funcs.LOGFUNCS;
  FUNCTION expit(mu);
    mur = mu;
    IF mu<-700 THEN mur=-700;
    IF mu>700 THEN mur=700;
    lp = 1/(1+exp(-mur));
    RETURN(lp);
  ENDSUB;
  FUNCTION logit(p);
    pr = p;
    IF p <= 0 THEN pr = 1e-12;
    IF p >= 1 THEN pr = 1-(1e-12);
    lmu = LOG(pr/(1-pr));
    RETURN(lmu);
  ENDSUB;
  FUNCTION logitbound(p,l,h);
    pb=MIN(MAX(p,l),h);
    lmu = log(pb/(1-pb));
    RETURN(lmu);
  ENDSUB;
  FUNCTION logbound(p,l,h);
    pb=MIN(MAX(p,l),h);
    lp = log(pb);
    RETURN(lp);
  ENDSUB; 
RUN;
%MEND;
/* user-experience helper functions: error checking, custom messages, deprecation notices*/
%MACRO __TrueCheck(mvar);
  %TRIM(&MVAR)=true OR %TRIM(&MVAR)=TRUE OR %TRIM(&MVAR)=True OR %TRIM(&MVAR)="true" OR %TRIM(&MVAR)="TRUE" OR %TRIM(&MVAR)="True" OR %TRIM(&MVAR)="True" OR %TRIM(&MVAR)="T" OR %TRIM(&MVAR)=T OR %TRIM(&MVAR)="1" OR %TRIM(&MVAR)=1
%MEND __TrueCheck;

%MACRO __FalseCheck(mvar);
  %TRIM(&MVAR)=false OR %TRIM(&MVAR)=FALSE OR %TRIM(&MVAR)=False OR %TRIM(&MVAR)="false" OR %TRIM(&MVAR)="FALSE" OR %TRIM(&MVAR)="F" OR %TRIM(&MVAR)=F OR %TRIM(&MVAR)="0" OR %TRIM(&MVAR)=0
%MEND __FalseCheck;

%MACRO __SLwarning(msg);
  %PUT WARNING: Super learner non-fatal issue. %TRIM(&msg);
%MEND __SLwarning;

%MACRO __SLnote(msg);
  %PUT NOTE: Super learner %TRIM(&msg);
%MEND __SLnote;

%MACRO __SLerror(msg);
  %PUT ERROR: Super learner, possibly recoverable problem happened in the call to super learner. %TRIM(&msg);
  %RETURN;
%MEND __SLerror;

%MACRO __badSLerror(msg);
  *fail early: error to abort completely;
  %PUT ERROR: Super learner, unrecoverable problem happened in the call to super learner. %TRIM(&msg);
  ODS SELECT ALL; OPTIONS NOTES;
  %ABORT;
%MEND __badSLerror;

%MACRO __deprecations();
  %__SLnote(%str(__deprecations));
  %IF &predvar^= %THEN %DO;
       %__SLwarning(%STR('predvar' macro parameter (currently set to &predvar) will be deprecated in an upcoming version. Please use 'Y' instead. Setting macro parameter 'Y' to &Y.));;
       %LET Y = &Y;
  %END;
  
  %IF &cv^= %THEN 
       %__SLwarning(%STR('cv' macro parameter (currently set to &cv) will be deprecated in an upcoming version, CV is assumed so this parameter will be dropped.));;
  %IF &gfstrat^= %THEN %DO;
       %__SLwarning(%STR('gfstrat' macro parameter (currently set to &gfstrat) will be deprecated in an upcoming version, please use "trtstrat=TRUE/FALSE" in macro call instead.));
       %LET trtstrat = &gfstrat;
  %END;
  %IF &risk^= %THEN %DO;
    %IF &method^= %THEN %__badSLerror(%str('risk' is deprecated and is replaced by 'method' - both cannot be specified simultaneously));
    %__SLwarning(%STR('risk' macro parameter (currently set to &risk) will be deprecated in an upcoming version, please use "dist=gaussian" or "dist=bernoulli" in macro call instead.));
    %IF &risk=L2 %THEN %DO;
     %LET dist=GAUSSIAN;
     %LET method=NNLS;
    %END;
    %IF &risk=ENTROPY %THEN %DO;
      %LET dist=BERNOULLI;
      %LET method=CCLOGLIK;
    %END;
  %END;
%MEND __deprecations;

%MACRO __commonerrors(dummy=1) / MINOPERATOR MINDELIMITER=' ';
  %LOCAL l_l j_j _ic book;  
  %__SLnote(%str(Basic error checking));
  * missing parameter values;
  %IF &Y = AND &predvar =  %THEN %__badSLerror(must specify Y);
  %IF %SUBSTR(&indata, 1, 1)= %THEN %__badSLerror(must specify existing indata data set);
  %IF &outdata = %THEN %__badSLerror(must specify outdata data set name to write out results);
  %IF &library = %THEN %__badSLerror(must specify at least two members of the library);
  *not enough library members;
  %IF (%SCAN(&library, 2)=) %THEN %__SLwarning(Super learner has one library member.);
  %IF &folds= %THEN %DO;
    %__SLnote(Defaulting to 10-fold cross validation);
    %LET folds=10;
  %END;
  *check that stratified models are specified correctly;
  %IF %__TrueCheck(&trtstrat) %THEN %DO;
    %IF (&INTVARS=) %THEN %__badSLerror(Intervention variable (macro variable 'intvars') must be specified if trtstrat is TRUE);;
    %LET j_j=1;
    %LET _ic = 0;
    %DO %WHILE (%SCAN(&PREDICTORS, &j_j)^=);
      %IF %SCAN(&PREDICTORS, &j_j) IN &INTVARS %THEN %LET _ic = 1;
      %LET j_j=%EVAL(&j_j+1);
    %END;
    %IF &_ic = 0 %THEN %__badSLerror(Intervention variables must also be specified as predictors);;
  %END;
  * screw up binary/continuous specification;
  %IF %__TrueCheck(&SLPBinary) %THEN %DO;
    * y is binary;
    %__SLnote(%STR(&Y is assumed to be binary));
    %IF %TRIM(&dist)^=BERNOULLI %THEN %DO;
      * setting to bernoulli;
      %__SLwarning(%STR(dist function should be BERNOULLI for binary dependent variables, &Y appears to be non-binary. Setting dist to BERNOULLI.));
      %LET dist=BERNOULLI;
    %END;
    %__SLnote(%STR(assumed &dist distribution, using &method algorithm to estimate SL coefficients));
  %END;
  %IF %__FalseCheck(&SLPBinary) %THEN %DO;
    * y is not binary;
    %__SLnote(%STR(&Y is assumed to be continuous));
    %IF &risk = ENTROPY %THEN %__SLerror(%STR(risk function should be L2 for non-binary dependent variables, &Y appears to be continuous));;
    %IF %TRIM(&dist)^=GAUSSIAN %THEN %DO;
      * setting to gaussian;
      %__SLwarning(%STR(Dist function should be GAUSSIAN for continuous dependent variables, &Y appears to be non-continuous. Setting dist to GAUSSIAN.));
      %LET dist=GAUSSIAN;
    %END;   
    %__SLnote(%STR(assumed &dist distribution, using &method algorithm to estimate SL coefficients));
  %END;
  * unknown risk function;
  %IF (&risk ~=L2 AND &risk ~=ENTROPY AND &method= AND &dist=) %THEN %__badSLerror(Dist and Method must be set. Risk may also be set, but will soon be deprecated.);;
  * sas version checking;
  %GLOBAL SLsas94 SLsas93 SLsas92;
  %__SLnote(%STR(SAS version is &sysver));
  %LET SLsas94 = %EVAL(&sysver>9.3);
  %LET SLsas93 = %EVAL(&sysver>9.2);
  %LET SLsas92 = %EVAL(&sysver>9.1);
  %IF &SLsas94=0 %THEN %DO;
    __SLwarning(Using version of SAS < 9.4, be aware that some procs may not work as intended!);
    %LET l_l = 1;
    %DO %WHILE(%SCAN(&LIBRARY, &l_l)^=);
      %LET book=%SCAN(&LIBRARY, &l_l);
      %IF (&book=cart OR &book=cvcart OR &book=rf OR &book=rfoob OR &book=gampl OR &book=lasso) %THEN %DO;
        %IF &SLsas93=0 %THEN %__badSLerror(you are using one member of the library that does not work in this version of sas. Please respecify the library without rf, cart, or lasso.);
        %IF (&SLsas94=0 AND &book=lasso) %THEN %__badSLerror(Please respecify the library without lasso (it does not work in this version of sas).);
      %END;
    %LET l_l = %EVAL(&l_l + 1);
    %END; *scan l;
  %END;
%MEND;

%MACRO __Checklibrary(library);
  *check whether member of library exists; 
  %LOCAL l_l book;  
  %LET l_l = 1;
  %__SLnote(%str(Checking whether library (&library) is valid));
  %DO %WHILE(%SCAN(&LIBRARY, &l_l)^=);
    %LET book=%SCAN(&LIBRARY, &l_l);
      %IF (&dist=GAUSSIAN AND %SYSMACEXIST(&book._cn)=0) OR (&dist=BERNOULLI AND %SYSMACEXIST(&book._in)=0) %THEN
        %__badSLerror(Library member &book is not available for the &dist distribution. You might try "rf" "boost" "bagging" or "mars");
  %LET l_l = %EVAL(&l_l + 1);
  %END; *scan l;
%MEND __CheckLibrary;

%MACRO __CheckMissing(predictors, indata);
  *check for missing values;
  %LOCAL j_j _pred pmis;
  %LET j_j = 1;
  %DO %WHILE(%SCAN(&predictors, %EVAL(&j_j))^=);
    %LET _PRED = %SCAN(&predictors, &j_j);
    PROC SQL NOPRINT; 
     SELECT SUM((&_PRED<.z)) INTO :pmis FROM &INDATA;
    %IF %SYSEVALF(%TRIM(&pmis)>0) %THEN %__badSLerror(Missing values detected in &_pred.. Missing values in predictors are not yet handled in this macro. Please ensure that input data are free of missing values.);;
    %LET j_j = %EVAL(&j_j+1);
  %END;
  QUIT;
%MEND __CheckMissing;

%MACRO __CheckSLPredMissing(Y, indata);
  *check for missing values;
  %GLOBAL SLPredMiss;
  PROC SQL NOPRINT; 
    SELECT sum(&Y<=.z) INTO :SLPredMiss FROM &INDATA;
  QUIT;
  %IF %__FalseCheck(&quietwarning) %THEN %DO;
    %IF (%TRIM(&SLPredMiss) NE 0 AND %TRIM(&SLPredMiss) NE .) %THEN %__SLwarning(Missing values (%TRIM(&SLPredMiss)) detected in &Y.. Using bounded linear extrapolation to impute.);;
  %END;
%MEND __CheckSLPredMissing;

%MACRO __intspeccheck() / MINOPERATOR MINDELIMITER=' ';
  /*
   check that intvar is removed from predictor variables if trstrat is used
   allows identical specification of models for trstrat = true and false 
  */
  %LOCAL bp cp np op __p;
  %LET bp = ;
  %LET cp = ;
  %LET np = ;
  %LET op = ;
  %LET __p = 1;
  %DO %WHILE(%SCAN(&binary_predictors, &__p)^=);
      %IF NOT(%SCAN(&binary_predictors, &__p) IN (&intvars)) %THEN %LET bp = &bp %SCAN(&binary_predictors, &__p);
    %LET __p = %EVAL(&__P+1);
  %END;
  %LET __p = 1;
  %DO %WHILE(%SCAN(&continuous_predictors, &__p)^=);
      %IF NOT(%SCAN(&continuous_predictors, &__p) IN (&intvars)) %THEN %LET cp = &cp %SCAN(&continuous_predictors, &__p);
    %LET __p = %EVAL(&__P+1);
  %END;
  %LET __p = 1;
  %DO %WHILE(%SCAN(&nominal_predictors, &__p)^=);
      %IF NOT(%SCAN(&nominal_predictors, &__p) IN (&intvars)) %THEN %LET np = &np %SCAN(&nominal_predictors, &__p);
    %LET __p = %EVAL(&__P+1);
  %END;
  %LET __p = 1;
  %DO %WHILE(%SCAN(&ordinal_predictors, &__p)^=);
      %IF NOT(%SCAN(&ordinal_predictors, &__p) IN (&intvars)) %THEN %LET op = &op %SCAN(&ordinal_predictors, &__p);
    %LET __p = %EVAL(&__P+1);
  %END;
  %LET binary_predictors = &bp;
  %LET continuous_predictors = &cp;
  %LET nominal_predictors = &np;
  %LET ordinal_predictors = &op;
%MEND;

%MACRO __ValidLib(library, Y, indata);
  *check for missing values in model predictions;
  %__SLnote(__ValidLib);
  %SYMDEL validlib droplib / NOWARN;
  %GLOBAL validlib droplib;
  %LOCAL fullmiss cvmiss __j;
  %LET valdilib =; 
  %LET droplib =;
  %LET __j = 1;
  %DO %WHILE(%SCAN(&library, &__j)^=);
   %LET book = %SCAN(&library, &__j);
   %LET fullmiss = 0; 
   %LET cvmiss = 0;
   * may throw an error if column missing altogether, but should continue;
   PROC SQL NOPRINT; 
     SELECT SUM((p_&book._full<.z)) INTO :fullmiss  FROM &INDATA(KEEP=p_&book._full);
     SELECT SUM((p_&book._z<.z)) INTO :cvmiss  FROM &INDATA(WHERE=(__train=1) KEEP=p_&book._z __train);
   QUIT;
   %IF (%EVAL(&cvmiss.>0) OR %EVAL(&fullmiss.>0)) %THEN %DO;
     %LET droplib = &droplib %TRIM(&book);
     %__SLwarning(Dropping &book from library due to missing values - check to be sure you have specified the library member correctly.);
   %END;
   %ELSE %DO;
     %LET validlib = &validlib %TRIM(&book);
     %__SLnote(%str(Library member &book has no missing values. Keeping in library.));
   %END;
   %LET __j = %EVAL(&__j + 1);
  %END;
%MEND __ValidLib;

%MACRO __cleanup(ds);
  %LOCAL dcode nd ds cd;
  * remove temporary datasets: to be moved to end of macro;
  * first overwrite to prevent warning about table not existing in some cases;
  DATA __d; a=1; RUN;
  %LET dcode = ;
  %LET nd=1;
  %DO %WHILE(%SCAN(&ds, &nd, ',')^=);
    %LET cd = %SCAN(&ds, &nd, ',');
    %LET dcode = &dcode%str(;) CREATE TABLE &cd AS SELECT * FROM __D;
    %LET nd=%EVAL(&ND+1);
  %END;
  PROC SQL NOPRINT; &dcode; QUIT;
  PROC SQL NOPRINT; DROP table &ds, __d; QUIT;
%MEND __CLEANUP;
  
%MACRO __SLPNumlevels(ds, var);
  %GLOBAL SLPNumLevels;
  PROC SQL NOPRINT;  SELECT COUNT(DISTINCT &var) INTO :SLPNumLevels FROM &DS; QUIT;
     %__SLnote(levels of &var: at least %TRIM(&SLPNumLevels).);
%MEND __SLPNumlevels;
  

%MACRO __SLPBinary(ds, YVAR);
  * determine whether superlearner should run in binary or non-binary mode;
  %GLOBAL SLPBinary;
  %LOCAL ycount;
  PROC SQL NOPRINT;  SELECT COUNT(DISTINCT &YVAR) INTO :ycount FROM &DS; QUIT;
     %IF %SYSEVALF(%TRIM(&ycount)=2) %THEN %LET SLPBinary=TRUE;
     %ELSE %LET SLPBinary=FALSE;
     %__SLnote( levels of &yvar: at least %TRIM(&ycount). Am I binary? %TRIM(&SLPBinary));
%MEND __SLPBinary;

%MACRO __makeintx(bins = ,  others = );
  *make interaction terms
  %GLOBAL SLIXterms;
  %LOCAL j_j k_k p_p q_q allvars;
  %LET allvars = &bins &others;
  %LET SLIXterms = ;
  %LET j_j=1;
  %DO %WHILE (%SCAN(&bins, &j_j)^=);
    %LET k_k=%EVAL(&j_j+1);
    %LET p_p = %SCAN(&bins, &j_j);
    %DO %WHILE (%SCAN(&bins, &k_k)^=);
      %LET q_q = %SCAN(&bins, &k_k);
      %IF &p_p^=&q_q %THEN %LET SLIXterms = &SLIXterms &p_p*&q_q;
      %LET k_k=%EVAL(&k_k+1);
    %END;
   %LET j_j=%EVAL(&j_j+1);
  %END;
  %LET j_j=1;
  %DO %WHILE (%SCAN(&allvars, &j_j)^=);
    %LET k_k=1;
    %LET p_p = %SCAN(&allvars, &j_j);
    %DO %WHILE (%SCAN(&others, &k_k)^=);
      %LET q_q = %SCAN(&others, &k_k);
      %LET SLIXterms = &SLIXterms &p_p*&q_q;
      %LET k_k=%EVAL(&k_k+1);
    %END;
   %LET j_j=%EVAL(&j_j+1);
  %END;
%MEND;
*%__makeintx(bins = &binary_predictors,  others = &ordinal_predictors &nominal_predictors &continuous_predictors);

%MACRO __installR(package);
  %LOCAL _pkg __git;
  /* note: this function can be called directly to install an R package where sas will find it */
  %__SLnote(%STR(__installR: Installing R packages if necessary. ));
  %LET rinst=FALSE;
   FILENAME instcode TEMP; *rsubmit requires use of include statement with code from file;
   %LET rcodea = %STR(SUBMIT / r;);
   %LET rcodec = %STR(ENDSUBMIT;);
   %LET l_l = 1;
   %DO %WHILE(%SCAN(&LIBRARY, &l_l)^=);
     %LET book=%SCAN(&LIBRARY, &l_l);
     %IF %SUBSTR(&book, 1,2)=r_ %THEN %DO;
       %IF &rinst=FALSE %THEN %DO;
          %__SLwarning(%str(Please note that R learners are case sensitive, so check the case of your variable names if you get strange errors from PROC IML/R.));
          *need to use explicit quotes in the following or get warnings about unresolved symbolic references;
          %__SLnote(%nrstr('R needs to be installed and Rlang system option must be enabled in SAS. See http://documentation.sas.com/?docsetId=imlug&docsetTarget=imlug_r_sect003.htm&docsetVersion=14.3&locale=en for details.'));
       %END;
       %LET rinst=TRUE;
       %LET _pkg = &package;
       %LET __git=;
       %IF &_pkg= %THEN %DO;
         %IF &book=r_rf %THEN %LET _pkg=randomForest;;
         %IF &book=r_bart %THEN %LET _pkg=dbarts;;
         %IF &book=r_mars %THEN %LET _pkg=earth;;
         %IF &book=r_bagging %THEN %LET _pkg=ipred;;
         %IF &book=r_polymars %THEN %LET _pkg=polspline;;
         %IF &book=r_boost %THEN %LET _pkg=xgboost;;
         %IF &book=r_svm %THEN %LET _pkg=e1071;;
         %IF &book=r_dsa %THEN %LET _pkg=partDSA;;
         %IF &book=r_gam %THEN %LET _pkg=gam;;
         %IF &book=r_lasso %THEN %LET _pkg=glmnet;;
         %IF &book=r_enet %THEN %LET _pkg=glmnet;;
         %IF &book=r_ridge %THEN %LET _pkg=glmnet;;
         %IF &book=r_rpart %THEN %LET _pkg=rpart;;
         %IF &book=r_rpartprune %THEN %LET _pkg=rpart;;
         %IF &book=r_sl %THEN %LET _pkg=SuperLearner;;
         %IF &book=r_bkmr %THEN %LET _pkg=bkmr;;
         %IF &book=r_wqs %THEN %DO;
         	%LET _pkg=SLmix;;
         	%LET __git=alexpkeil1;
         %END;
         %IF &book=r_gwqs %THEN %DO;
         	%LET _pkg=SLmix;;
         	%LET __git=alexpkeil1;
         %END;
       %END;
       %IF &__git= %THEN %DO;
         %LET rcodeb = %STR(if(!is.element(%"&_pkg%", installed.packages())) install.packages(%"&_pkg%", repos = %"https://cran.mtu.edu%", dependencies=TRUE));
         %LET rcodebb = ;
       %END;
       %IF &__git^= %THEN %DO;
         %LET rcodeb = %STR(if(!is.element(%"devtools%", installed.packages())) install.packages(%"devtools%", repos = %"https://cran.mtu.edu%", dependencies=TRUE));
         %LET rcodebb = %STR(if(!is.element(%"&_pkg%", installed.packages())) devtools::install_github(%"&__git/&_pkg%", dependencies=TRUE));
       %END;
       DATA _null_;
        FILE instcode;
        PUT "&rcodea";PUT 'options("install.packages.compile.from.source"="always")'; PUT "&rcodeb";PUT "&rcodebb";PUT "&rcodec";
       RUN;
       PROC IML;
        %IF &_pkg^= %THEN %INCLUDE instcode;;
       QUIT;
     %END; *any r func;
    %LET l_l = %EVAL(&l_l + 1);
   %END; *scan l;
%MEND __installR;

%MACRO __forceinstallR(package);
  %LOCAL _pkg __git;
  /* note: this function can be called directly to install an R package where sas will find it */
  %__SLnote(%STR(__forceinstallR: Installing R packages if necessary. ));
  %LET rinst=FALSE;
   FILENAME instcode TEMP; *rsubmit requires use of include statement with code from file;
   %LET rcodea = %STR(SUBMIT / r;);
   %LET rcodec = %STR(ENDSUBMIT;);
   %LET l_l = 1;
   %DO %WHILE(%SCAN(&LIBRARY, &l_l)^=);
     %LET book=%SCAN(&LIBRARY, &l_l);
     %IF %SUBSTR(&book, 1,2)=r_ %THEN %DO;
       %IF &rinst=FALSE %THEN %DO;
          %__SLwarning(%str(Please note that R learners are case sensitive, so check the case of your variable names if you get strange errors from PROC IML/R.));
          %__SLnote(%nrstr('R needs to be installed and Rlang system option must be enabled in SAS. See http://documentation.sas.com/?docsetId=imlug&docsetTarget=imlug_r_sect003.htm&docsetVersion=14.3&locale=en for details.'));
       %END;
       %LET rinst=TRUE;
       %LET _pkg = &package;
       %LET __git=;
       %IF &_pkg= %THEN %DO;
         %IF &book=r_rf %THEN %LET _pkg=randomForest;;
         %IF &book=r_bart %THEN %LET _pkg=dbarts;;
         %IF &book=r_mars %THEN %LET _pkg=earth;;
         %IF &book=r_bagging %THEN %LET _pkg=ipred;;
         %IF &book=r_polymars %THEN %LET _pkg=polspline;;
         %IF &book=r_boost %THEN %LET _pkg=xgboost;;
         %IF &book=r_svm %THEN %LET _pkg=e1071;;
         %IF &book=r_dsa %THEN %LET _pkg=partDSA;;
         %IF &book=r_gam %THEN %LET _pkg=gam;;
         %IF &book=r_lasso %THEN %LET _pkg=glmnet;;
         %IF &book=r_enet %THEN %LET _pkg=glmnet;;
         %IF &book=r_ridge %THEN %LET _pkg=glmnet;;
         %IF &book=r_rpart %THEN %LET _pkg=rpart;;
         %IF &book=r_rpartprune %THEN %LET _pkg=rpart;;
         %IF &book=r_sl %THEN %LET _pkg=SuperLearner;;
         %IF &book=r_bkmr %THEN %LET _pkg=bkmr;;
         %IF &book=r_wqs %THEN %DO;
         	%LET _pkg=SLmix;;
         	%LET __git=alexpkeil1;
         %END;
         %IF &book=r_gwqs %THEN %DO;
         	%LET _pkg=SLmix;;
         	%LET __git=alexpkeil1;
         %END;
       %END;
       %IF &__git= %THEN %DO;
         %LET rcodeb = %STR(install.packages(%"&_pkg%", repos = %"https://cran.mtu.edu%", dependencies=TRUE));
         %LET rcodebb = ;
       %END;
       %IF &__git^= %THEN %DO;
         %LET rcodeb = %STR(install.packages(%"devtools%", repos = %"https://cran.mtu.edu%", dependencies=TRUE, force_deps=TRUE, upgrade_dependencies=TRUE));
         %LET rcodebb = %STR(devtools::install_github(%"&__git/&_pkg%", dependencies=TRUE, force_deps=TRUE, upgrade_dependencies=TRUE));
       %END;
       DATA _null_;
        FILE instcode;
        PUT "&rcodea";PUT 'options("install.packages.compile.from.source"="always")'; PUT "&rcodeb";PUT "&rcodebb";PUT "&rcodec";
       RUN;
       PROC IML;
        %IF &_pkg^= %THEN %INCLUDE instcode;;
       QUIT;
     %END; *any r func;
    %LET l_l = %EVAL(&l_l + 1);
   %END; *scan l;
%MEND __forceinstallR;

* special functions for gam;

%MACRO __gamspline(vars, degree);
  %LOCAL gami __gamv;
  %LET gamI = 1;
  %DO %WHILE (%SCAN(&vars, &gami)~=);
    %LET __gamv = %SCAN(&vars, &gami);
    /*%__SLnote(%str((GAM) Creating spline for &__gamv))*/
    SPLINE(&__gamV, DF=&DEGREE)
    %LET gamI = %EVAL(&gami + 1);
  %END;
%MEND;

%MACRO __gamdrop(vars);
  %LOCAL gami __gamv;
  DROP =
  %LET gamI = 1;
  %DO %WHILE (%SCAN(&vars, &gami)~=);
    %LET __gamv = %SCAN(&vars, &gami);
    p_&__gamV
    %LET gamI = %EVAL(&gami + 1);
  %END;
%MEND;

%MACRO __nndrop(vars);
  %LOCAL gami __gamv;
  DROP =
  %LET gamI = 1;
  %DO %WHILE (%SCAN(&vars, &gami)~=);
    %LET __gamv = %SCAN(&vars, &gami);
    S_&__gamV
    %LET gamI = %EVAL(&gami + 1);
  %END;
%MEND;

%MACRO __gamplspline(vars, degree=);
  %LOCAL gami __gamv;
  %LET gamI = 1;
  %DO %WHILE (%SCAN(&vars, &gami)~=);
    %LET __gamv = %SCAN(&vars, &gami);
    /*%__SLnote(%str((GAMPL) Creating spline for &__gamv))*/
     %IF &DEGREE^= %THEN SPLINE(&__gamV / DF=&degree);
     %ELSE %IF &DEGREE= %THEN SPLINE(&__gamV);
    %LET gamI = %EVAL(&gami + 1);
  %END;
%MEND;

%MACRO __PBSPLINE(vars, df);
  %LOCAL pbi __pbv;
  %LET pbI = 1;
  %DO %WHILE (%SCAN(&vars, &pbi)~=);
    %LET __pbv = %SCAN(&vars, &pbi);
    /*%__SLnote(%str((pb) Creating spline for &__pbv))*/
    PBSPLINE(&__pbV / DEGREE=&df)
    %LET pbI = %EVAL(&pbi + 1);
  %END;
%MEND __PBSPLINE;

%MACRO __SPLINE(vars, df);
  %LOCAL pbi __pbv;
  %LET pbI = 1;
  %DO %WHILE (%SCAN(&vars, &pbi)~=);
    %LET __pbv = %SCAN(&vars, &pbi);
    /*%__SLnote(%str((pb) Creating spline for &__pbv))*/
    SPLINE(&__pbV / DEGREE=&df)
    %LET pbI = %EVAL(&pbi + 1);
  %END;
%MEND __SPLINE;

%MACRO __IDENT(vars, df);
  %LOCAL pbi __pbv;
  %LET pbI = 1;
  %DO %WHILE (%SCAN(&vars, &pbi)~=);
    %LET __pbv = %SCAN(&vars, &pbi);
    /*%__SLnote(%str((pb) Creating identity for &__pbv))*/
    IDENTITY(&__pbV)
    %LET pbI = %EVAL(&pbi + 1);
  %END;
%MEND __IDENT;

%MACRO __RENAMEDESIGN(VARS);
  /* rename all features
     - by necessity these are very short names "_#", which is needed to allow
       as many terms as will fit.
  */
  %GLOBAL __SLhalvars;
  %LET __slhalvars = ;
  %__SLnote(__RENAMEDESIGN);
  %LOCAL l_l ;
  %LET l_l = 1;
  RENAME 
  %DO %WHILE(%SCAN(&vars, &l_l)^=);
    %LET __slhalvars = &__slhalvars _&l_l;
    %SCAN(&vars, &l_l) =  _&l_l
    %LET l_l = %EVAL(1+&l_l);
  %END;;
%MEND __RENAMEDESIGN;

%MACRO GetHALDesign(y, vars, indata, outdata, drop=TRUE, intdepthlimit=0);
  /*
   steps to create design matrix for HAL (highly adaptive lasso):
    0. preprocessing
    1. create indicator variables for I[i,j,m] = I(X[i,m] <= X[j,m]) for i = 1..N, j=1..N, m=1..P
      - this step is open to some optimization by checking for binary/nominal variables
    2. create all possible interactions of those indicators: e.g. I[i,j,m+1] = I[i,j,1]*I[i,j,2]
    3. remove duplicate columns from the design matrix
   *REQUIRED: training data should have non-missing Y, testing/validation data should have missing Y
    - this is satisfied by super learner macro defaults

  to do:
   1. Optimize selection of unique columns in design matrix (currently involves 2 expensive transpositions)
  */
  %LOCAL haln halnt __hidx  __halmains __nhalmains __HALBAR __hallimit;
  /*
    0. preprocessing
  */
  DATA __haltm0001_;
    SET &indata;
    %__RENAMEDESIGN(&vars);
  PROC SQL NOPRINT; SELECT COUNT(%SCAN(&__slhalvars, 1)) INTO :haln FROM __haltm0001_; QUIT;
  PROC SQL NOPRINT; SELECT COUNT(%SCAN(&__slhalvars, 1)) INTO :halnT FROM __haltm0001_(WHERE=(&Y>.z)); QUIT;
  %LET __hidx = 1;
  %LET __halbar = %SCAN(&__slhalvars, &__hidx) ;
  %DO %WHILE(%SCAN(&__slhalvars, &__hidx+1)^=);
    %LET __hidx = &__hidx+1;
    %LET __halbar = &__halbar | %SCAN(&__slhalvars, &__hidx);
  %END; 
  DATA fake;
    SET __haltm0001_ (OBS=1);
	WHERE &y>.z;
  * main terms only first;
  PROC GLMMOD DATA=fake OUTPARM=__halmains NOPRINT NAMELEN=200;
    MODEL &Y = &__slhalvars / NOINT ;
  PROC SQL NOPRINT;
    SELECT STRIP(EFFNAME) INTO :__halmains SEPARATED BY " " 
      FROM __halmains;
  DATA __halmains;
   SET __halmains END=EOF;
   IF eof THEN CALL SYMPUT("__nhalmains", PUT(_COLNUM_, 9.0));
  RUN;  
  * limiting the depth of interaction terms to speed up processing;
  %IF &intdepthlimit ^=0 %THEN %LET __hallimit =  &intdepthlimit;
  %ELSE %IF &intdepthlimit =0 %THEN %LET __hallimit = &__NHALMAINS;
  %IF %EVAL(&__hallimit < &__NHALMAINS) %THEN %PUT NOTE: HAL - depth of maximum product term limited by user to &__hallimit - design matrix may not be completely saturated;;
  * leverage glmmod for creating all possible interaction terms;
  PROC GLMMOD DATA=fake OUTPARM=__halterms  NOPRINT NAMELEN=200;
    MODEL &Y = &__halbar @&__hallimit / NOINT ;
  DATA __halterms;
   SET __halterms END=EOF;
   IF eof THEN CALL SYMPUT("__nhalterms", PUT(_COLNUM_, 9.0));
  RUN;
  *storing terms in file as code to get around macro length limit;
  FILENAME terms TEMP;
  DATA _NULL_;
    FILE terms;
    IF _N_=1 THEN DO;
	  PUT "*begin creation of full design matrix;";
      PUT "DO n = 1 TO %TRIM(&halnt);";
	END;
    SET __halterms END=eof;
	effname = STRIP(effname);
    t = 1;
	PUT '  __Hi[' _N_ ',n] = 1' @@;
	DO WHILE(SCAN(effname, t, '*')^='');
	  nm = STRIP(SCAN(effname, t, '*'));
      PUT '*(' nm ">= _" nm +(-1)'_[n])' @@;
      t=t+1;
	END;
	PUT ';';
    IF EOF THEN DO;
      PUT 'END;';
	  PUT '*end creation of full design matrix;';
	END;
  RUN;
  /*1. create indicator variables for I[i,j,m] = I(X[i,m] <= X[j,m]) for i = 1..N, j=1..N, m=1..P*/
  DATA __halmat;
	*this step should be done only in the training data!;
    SET __haltm0001_;
    WHERE &y > .z; 
    %LET __hidx = 1;
    %DO %WHILE(%SCAN(&__slhalvars, &__hidx, ' ')^=);
      %LET __x = %SCAN(&__halmains, &__hidx, ' ');
      ARRAY _&__x._[&halnt] ;
      %LET __hidx = %EVAL(&__hidx+1);
	  RETAIN _&__x._:;
	  KEEP _&__x._:;
    %END;
	*outer loop over variables, inner loop over sample;
    %LET __hidx = 1;
    %DO %WHILE(%SCAN(&__slhalvars, &__hidx, ' ')^=);
      DO i = 1 TO &halnt;
        IF i = _N_ THEN _%SCAN(&__slhalvars, &__hidx, ' ')_[i] = %SCAN(&__slhalvars, &__hidx, ' ');
      END;
      %LET __hidx = %EVAL(&__hidx+1);
    %END;
    IF _n_ = &halnt THEN OUTPUT;  
  RUN;
  /*2. create all possible interactions of those indicators: e.g. I[i,j,m+1] = I[i,j,1]*I[i,j,2]*/
  /*
  note: some speedup could be obtained by keeping (as main term) unmodified, all binary variables
  */
  DATA __designdupa(KEEP = __hi:);
  /* main computational slowdown */
    ARRAY __Hi[&__nhalterms, &halnt] ;
    LENGTH __Hi: 3;
    SET __haltm0001_;
    IF _n_=1 THEN SET __halmat;
    %LET __hidx = 1;
    %DO %WHILE(%SCAN(&__slhalvars, &__hidx, ' ')^=);
      %LET __x = %SCAN(&__halmains, &__hidx, ' ');
      ARRAY _&__x._[&halnt] ;
      %LET __hidx = %EVAL(&__hidx+1);
    %END;
    %INCLUDE terms;
  RUN;
  /*
  3. remove duplicate columns from the design matrix;
  */
  PROC TRANSPOSE DATA = __designdupa OUT=__designdup(DROP=_NAME_); 
  PROC SQL NOPRINT;
    DROP TABLE __designdupa;
    CREATE TABLE &outdata AS SELECT DISTINCT * FROM __designdup;
    %IF &DROP=TRUE %THEN DROP TABLE __designdup, __halmat, __halmains, __halterms, __haltm0001_;;
  QUIT;
  PROC TRANSPOSE DATA = &outdata OUT=&outdata(DROP=_NAME_) PREFIX=__hal_;
  RUN; QUIT; RUN;
%MEND GetHALDesign;

%MACRO __noprintsummary(Y=, predictors= , library=, folds=, 
                         method=, dist=, shuffle=, preddata=, indata=, outcoef=,outcvrisk=,outresults=,n=);
   *put some results and call summary in readable format;
   %__SLnote(%str(__printsummary: printing out summary results));
  %IF &BY= %THEN %DO; PROC TRANSPOSE DATA = &OUTCOEF OUT=&OUTCOEF(RENAME=(_NAME_=Learner col1=Coefficient));RUN; %END;
  %ELSE %DO; 
      PROC TRANSPOSE DATA = &OUTCOEF OUT=&OUTCOEF(RENAME=(_NAME_=Learner col1=Coefficient)); BY &by; RUN;
  %END;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outresults;
   LENGTH Learner $39;
   MERGE &outcoef &outcvrisk(DROP=j %IF (&method ^= ADAPTRF) %THEN rename=(riskl=CVrisk););
   Learner=SUBSTR(Learner, 10);
   IF Learner= '' THEN Learner = "Super learner (not cross-validated)";
  RUN;
  OPTIONS MERGENOBY=WARN;
%MEND __noprintsummary;

%MACRO __printsummary(Y=, predictors= , library=, folds=, 
                         method=, dist=, shuffle=, preddata=, indata=, outcoef=,outcvrisk=,outresults=,n=);
   *put some results and call summary in readable format;
   %__SLnote(%str(__printsummary: printing out summary results));
  %IF &BY= %THEN %DO; PROC TRANSPOSE DATA = &OUTCOEF OUT=&OUTCOEF(RENAME=(_NAME_=Learner col1=Coefficient));RUN; %END;
  %ELSE %DO; 
      PROC TRANSPOSE DATA = &OUTCOEF OUT=&OUTCOEF(RENAME=(_NAME_=Learner col1=Coefficient)); BY &by; RUN;
  %END;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outresults;
   LENGTH Learner $39;
   MERGE &outcoef &outcvrisk(DROP=j %IF (&method ^= ADAPTRF) %THEN rename=(riskl=CVrisk););
   Learner=SUBSTR(Learner, 10);
   IF Learner= '' THEN Learner = "Super learner (not cross-validated)";
  RUN;
  %IF %__FalseCheck(&checkvalid) %THEN %LET droplib=none;
  OPTIONS MERGENOBY=WARN;
  %IF %STR(&indata) = %STR(&preddata) %THEN %LET preddata=;
  OPTIONS LINESIZE = 109 PAGESIZE=80; *rudely set line size to my default;
  DATA _NULL_;
    SET &outresults END=eof;
    FILE PRINT;
    IF _N_=1 THEN DO;
      PUT "-----------------------------------------------------------------------------------------------";
      PUT "|                                                                                              |";
      PUT "|      Super learner summary                                                                   |";
      PUT "|                                                                                              |";
      PUT "-----------------------------------------------------------------------------------------------";
      PUT "                                                                                      ";
      PUT "  Super learner predictions 'p_SL_full' are in the dataset &outdata ";  
      PUT "    Making predictions of: &Y";  
      PUT "    Using predictors: %SYSFUNC(COMPBL(&predictors));                         ";
      PUT "    Training data: &indata (N=&n)";  
      %IF %STR(&indata) ^= %STR(&preddata) %THEN PUT "    Testing/validation data: &preddata";;
      PUT "                                                                                      ";
      PUT "  Super learner library: %SYSFUNC(COMPBL(&library))";  
      %IF &droplib^=none %THEN PUT "  Dropped library members (check SAS log): &droplib";;
      PUT "  Assumed distribution: &dist                                                      ";
      PUT "  Method: &method                                            ";
      PUT "  Cross validation folds: &folds                                            ";
      PUT "  Seed: &slseed                                            ";
      %IF &weight^= %THEN PUT "  Weights: &weight                                            ";;
      PUT "  Note: to use predictions from individual learners in the library  ";
      PUT "        please use the 'p_[learner]_full' variables in the dataset &outdata ";
      PUT "  Note: SAS Enterprise miner software must be installed to use certain learners   ";
      PUT "                                                                                      ";
      %IF %__TrueCheck(&simple) %THEN %DO;
        PUT "  For speed gains (and fewer error checks) and more options, use the %NRSTR(%_)SuperLearner macro: ";
        PUT "    Example: %NRSTR(%_)SuperLearner(Y=&Y, intvars=&intvars, binary_predictors=&binary_predictors,";
        PUT "             ordinal_predictors=&ordinal_predictors, nominal_predictors=&nominal_predictors, continuous_predictors=&continuous_predictors,";
        PUT "             indata=&indata, preddata=&preddata, outdata=&outdata, outresults=&outresults, ";
        PUT "             library=%str(&library), ";
        PUT "             folds=&folds, dist=&dist, method=&method, seed=&slseed,";
        PUT "             trtstrat=&trtstrat, slridgepen=&slridgepen,"  ;   
        PUT "             printres=TRUE, timer=TRUE, quietnotes=TRUE, quietwarning=TRUE)"  ;   
      %END;
      PUT "                                                                                      ";
      %IF &BY= %THEN %DO; 
        PUT "Super learner coefficients, &folds.-fold cross validated risk/expected loss";
        PUT "  ---------------------------------------------";
        PUT "    Learner      Coefficient   CV risk";
        PUT "  ---------------------------------------------";
      %END;
    END;
    PUT @5 Learner @17 coefficient 8.5 @31 cvrisk 8.5 ;
    IF eof THEN DO;
      PUT "  ---------------------------------------------";
      PUT "------------------------------------------------------------------------------------------------";
    END;
    RETURN;
    STOP;
  RUN;QUIT;RUN;
  
  %IF &BY^= %THEN %DO; 
    PROC PRINT DATA =  &outresults NOOBS;
     TITLE "Super learner coefficients, &folds.-fold cross validated risk/expected loss";
     VAR &BY Learner coefficient cvrisk;
    RUN;
  %END;

%MEND __printsummary;
/********************************************************;
* Part 2: learner functions;

* each has a standard call:

    %learner_in(Y,
             indata, 
             outdata, 
             binary_predictors, 
             ordinal_predictors, 
             nominal_predictors,  
             continuous_predictors,
             weight,
             suff,
             seed);

* Using this standard call, it is relatively straightforward
*  to add new learners, provided that the conventions
*  are followed.
* conventions:
*  1) each macro name must be structured like
      binary dep. vars:     %[library name]_in 
      non-binary dep. vars: %[library name]_cn
      where [library name] is the user defined name for a given learner. E.g. for a 
      random forest, [library name] is 'rf' (without quotes)
   2) macro call/parameters must follow exact naming conventions as shown above in '%learner_in' example
   3) the sample space of each predictor must be respected (e.g. &binary_predictors should
      be used where binary predictors are appropriate for the learner.) For example, 
      model statements in, PROC genmod will contain all &..._predictor macro variables, but 
      &nominal_predictors could be included in a CLASS statement, for example.
   4) outdata must contain: all variables from indata dataset (the data used in the learner)
      PLUS a variable that follows the naming convention: p_[library name]&SUFF
      that is either a) predicted probability (binary dep var) or b) predicted value (non-
      binary dep var)
   5) to include all interaction terms between predictors, the predictors must include
       &SLIXterms, which may be a mix of discrete and continuous variables
    
********************************************************/

%MACRO bayesnet_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Parent child Bayesian network with bivariate association based prescreening and subsequent variable selection
     max parents= 5 as of SAS HPEM 14.1 */
  
  &suppresswarn %__SLwarning(%str(This routine requires AT LEAST SAS 9.4 TS1M3 with high powered data mining procedures enabled));
  PROC HPBNET DATA = &indata  ;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weight possibly truncated to integer;
    TARGET &Y ; *binary only;
    %IF (&nominal_predictors~= OR &ordinal_predictors~= OR &binary_predictors~=) %THEN INPUT &ordinal_predictors &binary_predictors &nominal_predictors / LEVEL = nominal;;
    %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
    OUTPUT PRED=&outdata (drop = p_&Y.0 RENAME=(p_&Y.1 = p_bayesnet&SUFF));
    ID _ALL_;
  RUN;
%MEND bayesnet_in;

%MACRO nbayes_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Naive Bayes classification */
  
  &suppresswarn %__SLwarning(%str(This routine requires AT LEAST SAS 9.4 TS1M3 with high powered data mining procedures enabled));
  PROC HPBNET DATA = &indata  STRUCTURE=NAIVE MAXPARENTS=1 PRESCREENING=0 VARSELECT=0;
    FORMAT &Y;
    ODS SELECT NONE;
    TARGET &Y ; *binary only;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weight possibly truncated to integer;
    %IF (&nominal_predictors~= OR &ordinal_predictors~= OR &binary_predictors~=) %THEN INPUT &ordinal_predictors &binary_predictors &nominal_predictors / LEVEL = nominal;;
    %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
    OUTPUT PRED=&outdata (drop = p_&Y.0 RENAME=(p_&Y.1 = p_nbayes&SUFF));
    ID _ALL_;
  RUN;
%MEND nbayes_in;

%MACRO rf_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* RANDOM FOREST */
  &suppresswarn %__SLwarning(%str(This routine requires AT LEAST SAS 9.4 TS1M3 with high powered data mining procedures enabled));
  PROC HPFOREST DATA = &indata SEED=&seed  /*PRESELECT=BINNEDSEARCH SCOREPROLE=OOB*/ MAXTREES = 100 IMPORTANCE=NO;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weight possibly truncated to integer;
    TARGET &Y / LEVEL = binary;
    %IF (&binary_predictors~=) %THEN INPUT &binary_predictors / LEVEL = binary;;
    %IF (&ordinal_predictors~=) %THEN INPUT &ordinal_predictors / LEVEL = ordinal;;
    %IF (&nominal_predictors~=) %THEN INPUT &nominal_predictors / LEVEL = nominal;;
    %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
    SCORE out=&outdata (drop = _Warn_ f_&Y I_&Y p_&Y.0 RENAME=(p_&Y.1 = p_rf&SUFF));
    ID _ALL_;
  RUN;
%MEND rf_in;

%MACRO rf_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* RANDOM FOREST, continuous */
  
  &suppresswarn %__SLwarning(%str(This routine requires AT LEAST SAS 9.4 TS1M3 with high powered data mining procedures enabled));
  PROC HPFOREST DATA = &indata SEED=&seed  /*PRESELECT=BINNEDSEARCH SCOREPROLE=OOB*/  MAXTREES = 100  IMPORTANCE=NO;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weight possibly truncated to integer;
    TARGET &Y / LEVEL = interval;
    %IF (&binary_predictors~=) %THEN INPUT &binary_predictors / LEVEL = binary;;
    %IF (&ordinal_predictors~=) %THEN INPUT &ordinal_predictors / LEVEL = ordinal;;
    %IF (&nominal_predictors~=) %THEN INPUT &nominal_predictors / LEVEL = nominal;;
    %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
    SCORE out=&outdata (drop = _Warn_ R_&Y RENAME=(p_&Y = p_rf&SUFF));
    ID _ALL_;
  RUN;
%MEND rf_cn;

%MACRO rfoob_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* RANDOM FOREST, using out of bag estimates as predictions*/
  
  &suppresswarn %__SLwarning(%str(This routine requires AT LEAST SAS 9.4 TS1M3 with high powered data mining procedures enabled));
  PROC HPFOREST DATA = &indata SEED=&seed  /**/PRESELECT=BINNEDSEARCH SCOREPROLE=OOB MAXTREES = 100  IMPORTANCE=NO;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weight possibly truncated to integer;
    TARGET &Y / LEVEL = binary;
    %IF (&binary_predictors~=) %THEN INPUT &binary_predictors / LEVEL = binary;;
    %IF (&ordinal_predictors~=) %THEN INPUT &ordinal_predictors / LEVEL = ordinal;;
    %IF (&nominal_predictors~=) %THEN INPUT &nominal_predictors / LEVEL = nominal;;
    %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
    SCORE out=&outdata (drop = _Warn_ f_&Y I_&Y p_&Y.0 RENAME=(p_&Y.1 = p_rfoob&SUFF));
    ID _ALL_;
  RUN;
%MEND rfoob_in;

%MACRO rfoob_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* RANDOM FOREST, continuous, using out of bag estimates as predictions */
  
  &suppresswarn %__SLwarning(%str(This routine requires AT LEAST SAS 9.4 TS1M3 with high powered data mining procedures enabled));
  PROC HPFOREST DATA = &indata SEED=&seed  /**/PRESELECT=BINNEDSEARCH SCOREPROLE=OOB  MAXTREES = 100 IMPORTANCE=NO;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weight possibly truncated to integer;
    TARGET &Y / LEVEL = interval;
    %IF (&binary_predictors~=) %THEN INPUT &binary_predictors / LEVEL = binary;;
    %IF (&ordinal_predictors~=) %THEN INPUT &ordinal_predictors / LEVEL = ordinal;;
    %IF (&nominal_predictors~=) %THEN INPUT &nominal_predictors / LEVEL = nominal;;
    %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
    SCORE out=&outdata (drop = _Warn_ R_&Y RENAME=(p_&Y = p_rfoob&SUFF));
    ID _ALL_;
  RUN;
%MEND rfoob_cn;

%MACRO logit_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* logistic model */
  PROC LOGISTIC DATA = &indata NOPRINT DESCENDING;
    FORMAT &Y;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
    OUTPUT OUT = &OUTDATA(DROP=_level_) PRED=p_logit&SUFF;
  RUN;
%MEND logit_in;
*%logit_in( Y=y, indata=a,  outdata=LOGIT_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO logitint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* logistic model with interaction terms*/
  PROC LOGISTIC DATA = &indata NOPRINT DESCENDING;
    FORMAT &Y;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms;
    OUTPUT OUT = &OUTDATA(DROP=_level_) PRED=p_logitint&SUFF;
  RUN;
%MEND logitint_in;
*%logit_in( Y=y, indata=a,  outdata=LOGIT_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO glm_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /*wrapper for logit*/
 %logit_in(Y=&y, indata=&indata,  outdata=&outdata,  binary_predictors= &binary_predictors,  ordinal_predictors=&ordinal_predictors,  nominal_predictors=&nominal_predictors,   continuous_predictors=&continuous_predictors,weight=&weight, suff=&suff, seed=&seed);
 DATA &outdata; SET &outdata(RENAME=(p_logit&SUFF=p_glm&SUFF));RUN; 
%MEND glm_in;

%MACRO glmint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /*wrapper for logitint*/
 %logitint_in(Y=&y, indata=&indata,  outdata=&outdata,  binary_predictors= &binary_predictors,  ordinal_predictors=&ordinal_predictors,  nominal_predictors=&nominal_predictors,   continuous_predictors=&continuous_predictors,weight=&weight, suff=&suff, seed=&seed);
 DATA &outdata; SET &outdata(RENAME=(p_logitint&SUFF=p_glmint&SUFF));RUN;
%MEND glmint_in;

%MACRO mean_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* intercept only model */
  PROC GENMOD DATA = &indata DESCENDING;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = / LINK=LOGIT D=BINOMIAL;
    OUTPUT OUT = &OUTDATA PRED=p_mean&SUFF;
  RUN;
%MEND mean_in;

%MACRO mean_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* intercept only model */
  PROC GENMOD DATA = &indata;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = / LINK=ID D=NORMAL;
    OUTPUT OUT = &OUTDATA PRED=p_mean&SUFF;
  RUN;
%MEND mean_cn;

%MACRO linreg_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* linear model */
  PROC GENMOD DATA = &indata;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / LINK=ID D=NORMAL;
    OUTPUT OUT = &OUTDATA PRED=p_linreg&SUFF;
  RUN;
%MEND linreg_cn;
*%linreg_cn( Y=y, indata=a,  outdata=LOGIT_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO linregint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* linear model */
  PROC GENMOD DATA = &indata;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / LINK=ID D=NORMAL;
    OUTPUT OUT = &OUTDATA PRED=p_linregint&SUFF;
  RUN;
%MEND linregint_cn;
*%linregint_cn( Y=y, indata=a,  outdata=LOGIT_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO glm_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /*GLM: wrapper for linreg*/
 %linreg_cn(Y=&y, indata=&indata,  outdata=&outdata(RENAME=(p_linreg&SUFF=p_glm&SUFF)),  binary_predictors= &binary_predictors,  ordinal_predictors=&ordinal_predictors,  nominal_predictors=&nominal_predictors,   continuous_predictors=&continuous_predictors,weight=&weight, suff=&suff, seed=&seed)
%MEND glm_cn;

%MACRO glmint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /*wrapper for linregint*/
 %linregint_cn(Y=&y, indata=&indata,  outdata=&outdata(RENAME=(p_linregint&SUFF=p_glmint&SUFF)),  binary_predictors= &binary_predictors,  ordinal_predictors=&ordinal_predictors,  nominal_predictors=&nominal_predictors,   continuous_predictors=&continuous_predictors,weight=&weight, suff=&suff, seed=&seed)
%MEND glmint_cn;

%MACRO quantreg_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* quantile regression model */
  PROC QUANTREG DATA = &indata;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / QUANTILE=0.5;
    OUTPUT OUT = &OUTDATA(DROP=QUANTILE) PRED=p_quantreg&SUFF;
  RUN;
%MEND quantreg_cn;
*%quantreg_cn( Y=y, indata=a,  outdata=LOGIT_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO quantregint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* quantile regression model */
  PROC QUANTREG DATA = &indata ;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / QUANTILE=0.5;
    OUTPUT OUT = &OUTDATA(DROP=QUANTILE) PRED=p_quantregint&SUFF;
  RUN;
%MEND quantregint_cn;
*%quantregint_cn( Y=y, indata=a,  outdata=LOGIT_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO lasso_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Logit model with LASSO  */
  PROC HPGENSELECT DATA=&indata TECH=QUANEW NOSTDERR  NOSTDERR LASSORHO=0.8 LASSOSTEPS=50 NORMALIZE=YES;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y(EVENT='1') = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / DIST=BINARY LINK=LOGIT;
    SELECTION METHOD=lasso(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA p = p_lasso&SUFF; 
    ID _ALL_;
  RUN;;
%MEND lasso_in;
*%lasso_in( Y=y, indata=a,  outdata=lasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO back_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Logit model with backward selection  */
  PROC HPGENSELECT DATA=&indata TECH=QUANEW NOSTDERR;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y(EVENT='1') = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / DIST=BINARY LINK=LOGIT;
    SELECTION METHOD=BACKWARD(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA p = p_back&SUFF; 
    ID _ALL_;
  RUN;;
%MEND back_in;
*%back_in( Y=y, indata=a,  outdata=lasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO backint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Logit model with backward selection  */
  PROC HPGENSELECT DATA=&indata TECH=QUANEW NOSTDERR;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y(EVENT='1') = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / DIST=BINARY LINK=LOGIT;
    SELECTION METHOD=BACKWARD(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA p = p_backINT&SUFF; 
    ID _ALL_;
  RUN;;
%MEND backint_in;
*%backint_in( Y=y, indata=a,  outdata=lasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO lassob_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  %__SLwarning(%str(lassob does not resepect the 0/1 probability space and should be used with extreme caution));
  /* Logit model with LASSO  */
  PROC GLMSELECT DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / 
    SELECTION=LASSO;
    OUTPUT OUT = &OUTDATA PRED=p_lassob&SUFF;
  RUN;
%MEND lassob_in;

%MACRO swise_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Logit model with stepwise model selection  */
  PROC HPGENSELECT DATA=&indata TECH=QUANEW NOSTDERR;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y(EVENT='1') = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / DIST=BINARY LINK=LOGIT;
    SELECTION METHOD=STEPWISE(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA p = p_swise&SUFF; 
    ID _ALL_;
  RUN;;
%MEND swise_in;
*%swise_in( Y=y, indata=a,  outdata=lasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO lassoint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Logit model with LASSO - including interaction terms */
  PROC HPGENSELECT DATA=&indata  TECH=QUANEW NOSTDERR LASSORHO=0.8 LASSOSTEPS=100; 
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y(EVENT='1') = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms/ DIST=BINARY LINK=LOGIT;
    SELECTION METHOD=lasso;
    OUTPUT OUT = &OUTDATA p = p_lassoint&SUFF; 
    ID _ALL_;
  RUN;;
%MEND lassoint_in;
*%lassoint_in( Y=y, indata=a,  outdata=lasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO swiseint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Logit model with stepwise model selection  */
  PROC HPGENSELECT DATA=&indata TECH=QUANEW NOSTDERR;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y(EVENT='1') = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors  &SLIXterms/ DIST=BINARY LINK=LOGIT;
    SELECTION METHOD=STEPWISE(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA p = p_swiseint&SUFF; 
    ID _ALL_;
  RUN;;
%MEND swiseint_in;

%MACRO lassobint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  %__SLwarning(%str(lassoint2 does not resepect the 0/1 probability space and shoudld be used with extreme caution));
  /* Logit model with LASSO - including interaction terms */
  PROC GLMSELECT DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / 
    SELECTION=LASSO;
    OUTPUT OUT = &OUTDATA PRED=p_lassobint&SUFF;
  RUN;

%MEND lassobint_in;
*%lasso_in( Y=y, indata=a,  outdata=lasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO lasso_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* LASSO model, continuous */
  PROC HPGENSELECT DATA=&indata TECH=QUANEW NOSTDERR LASSORHO=0.8 LASSOSTEPS=100 NORMALIZE=YES;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / DIST=NORMAL LINK=IDENTITY;
    SELECTION METHOD=lasso(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA p = p_lasso&SUFF; 
    ID _ALL_;
  RUN;;
%MEND lasso_cn;
*%lasso_cn( Y=y, indata=a,  outdata=lasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO back_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* backward selection model, continuous */
  PROC HPGENSELECT DATA=&indata TECH=QUANEW NOSTDERR;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / DIST=NORMAL LINK=IDENTITY;
    SELECTION METHOD=BACKWARD(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA p = p_back&SUFF; 
    ID _ALL_;
  RUN;;
%MEND back_cn;
*%back_cn( Y=y, indata=a,  outdata=lasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO backint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* backward selection model, continuous */
  PROC HPGENSELECT DATA=&indata TECH=QUANEW NOSTDERR;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / DIST=NORMAL LINK=IDENTITY;
    SELECTION METHOD=BACKWARD(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA p = p_backint&SUFF; 
    ID _ALL_;
  RUN;;
%MEND backint_cn;
*%backint_cn( Y=y, indata=a,  outdata=lasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO lassob_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* linear model with LASSO  */
  PROC GLMSELECT DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / 
    SELECTION=LASSO(CHOOSE=AICC STEPS=100);
    OUTPUT OUT = &OUTDATA PRED=p_lassob&SUFF;
  RUN;

%MEND lassob_cn;
*%lasso_in( Y=y, indata=a,  outdata=lasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO ridge_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* ridge regression with linear model only */
  PROC REG DATA = &indata RIDGE=0 TO 10 by 0.05 OUTEST=__sltm0017_;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    p_ridge&SUFF: MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
  RUN;
  PROC SORT DATA = __sltm0017_(WHERE=(_TYPE_="RIDGE")); BY _rmse_; RUN;
  DATA __sltm0017_; SET __sltm0017_(OBS =1); run;   
  PROC SCORE DATA = &indata SCORE=__sltm0017_ OUT=&outdata TYPE=RIDGE;
    VAR &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
  RUN;
%MEND ridge_cn;
*%ridge_cn( Y=y, indata=a,  outdata=LOGIT_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO ridge_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* ridge regression with binary data */
  %__SLwarning(%str(ridge does not resepect the 0/1 probability space and should be used with extreme caution));
  PROC REG DATA = &indata RIDGE=0 TO 10 by 0.05 OUTEST=__sltm0017_;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    p_ridge&SUFF: MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
  RUN;
  PROC SORT DATA = __sltm0017_(WHERE=(_TYPE_="RIDGE")); BY _rmse_; RUN;
  DATA __sltm0017_; SET __sltm0017_(OBS =1); run;   
  PROC SCORE DATA = &indata SCORE=__sltm0017_ OUT=&outdata TYPE=RIDGE;
    VAR &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
  RUN;
%MEND ridge_in;
*%ridge_cn( Y=y, indata=a,  outdata=LOGIT_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO swise_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* linear model with stepwise model selection  */
  PROC HPGENSELECT DATA=&indata TECH=QUANEW NOSTDERR;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y(EVENT='1') = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / DIST=normal LINK=id;
    SELECTION METHOD=STEPWISE;
    OUTPUT OUT = &OUTDATA p = p_swise&SUFF; 
    ID _ALL_;
  RUN;;
%MEND swise_cn;

%MACRO swiseint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* linear model with stepwise model selection, interaction terms  */
  PROC HPGENSELECT DATA=&indata TECH=QUANEW NOSTDERR;
    FORMAT &Y;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y(EVENT='1') = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors  &SLIXterms/ DIST=normal LINK=id;
    SELECTION METHOD=STEPWISE;
    OUTPUT OUT = &OUTDATA p = p_swiseint&SUFF; 
    ID _ALL_;
  RUN;;
%MEND swiseint_cn;

%MACRO lassoint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* LASSO model, continuous, with interaction terms */
  PROC HPGENSELECT DATA=&indata TECH=QUANEW NOSTDERR NORMALIZE=YES;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors / SPLIT;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms/ DIST=NORMAL LINK=IDENTITY;
    SELECTION METHOD=lasso(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA p = p_lassoint&SUFF; 
    ID _ALL_;
  RUN;;
%MEND lassoint_cn;
*%lassoint_cn( Y=y, indata=a,  outdata=lasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO lassointb_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* linear model with LASSO  */
  PROC GLMSELECT DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors  &SLIXterms/ 
    SELECTION=LASSO(CHOOSE=AICC STEPS=100);
    OUTPUT OUT = &OUTDATA PRED=p_lassointb&SUFF;
  RUN;
%MEND lassointb_cn;

%MACRO cvlasso_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* LASSO model, selection by cross validation */
  PROC GLMSELECT DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / 
    SELECTION=LASSO(CHOOSE=CVEX STOP=NONE);
    OUTPUT OUT =&outdata(DROP=_CVINDEX:) PRED=p_cvlasso&SUFF;
  RUN;
%MEND cvlasso_cn;

%MACRO cvlassoint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* LASSO model, selection by cross validation */
  PROC GLMSELECT DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms/ 
    SELECTION=LASSO(CHOOSE=CVEX STOP=NONE);
    OUTPUT OUT =&outdata(DROP=_CVINDEX:) PRED=p_cvlassoint&SUFF;
  RUN;
%MEND cvlassoint_cn;

%MACRO cvlasso_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* LASSO model, selection by cross validation (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) */
  %cvlasso_cn(Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,
               nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight, suff=&suff, seed=&seed);
%MEND cvlasso_in;

%MACRO cvlassoint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* LASSO model, selection by cross validation (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) */  
  %cvlassoint_cn(Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,
               nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight ,suff=&suff, seed=&seed);
%MEND cvlassoint_in;

%MACRO lar_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* least angle regression model (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) */
  PROC GLMSELECT DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / 
    SELECTION=LAR;
    OUTPUT OUT = &OUTDATA PRED=p_lar&SUFF;
  RUN;
%MEND lar_in;
*%lar_in( Y=y, indata=a,  outdata=lar_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO larint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* least angle regression model (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) with interaction terms */
  PROC GLMSELECT DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms/ 
    SELECTION=LAR;
    OUTPUT OUT = &OUTDATA PRED=p_larint&SUFF;
  RUN;
%MEND larint_in;
*%lar_in( Y=y, indata=a,  outdata=lar_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO lar_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* least angle regression model, continuous - just a wrapper */

  %lar_in(Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors, weight=&weight ,suff=&suff, seed=&seed);
%MEND lar_cn;
*%lar_cn( Y=y, indata=a,  outdata=lar_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO larint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* least angle regression model, continuous, interaction terms - just a wrapper */
  %larint_in(Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors &SLIXterms,weight=&weight ,suff=&suff, seed=&seed);
%MEND larint_cn;
*%larint_cn( Y=y, indata=a,  outdata=lar_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO enet_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Elastic net model (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) */
  PROC GLMSELECT DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / 
    SELECTION=ELASTICNET;
    OUTPUT OUT = &OUTDATA PRED=p_enet&SUFF;
  RUN;
%MEND enet_in;
*%enet_in( Y=y, indata=a,  outdata=ENET_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO enetint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Elastic net model, interaction terms (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) */
  PROC GLMSELECT DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms/ 
    SELECTION=ELASTICNET;
    OUTPUT OUT = &OUTDATA PRED=p_enetint&SUFF;
  RUN;
%MEND enetint_in;
*%enet_in( Y=y, indata=a,  outdata=ENET_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO enet_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Elastic net model , continuous - just a wrapper */

  %enet_in(Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors, weight=&weight ,suff=&suff, seed=&seed);
%MEND enet_cn;
*%enet_cn( Y=y, indata=a,  outdata=lar_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO enetint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Elastic net model , continuous, interaction terms - just a wrapper */

  %enetint_in(Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors, weight=&weight ,suff=&suff, seed=&seed);
%MEND enetint_cn;
*%enetint_cn( Y=y, indata=a,  outdata=lar_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO cvcart_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* classification tree with cross validated pruning*/
  
  &suppresswarn %__SLwarning(%str(This function (CART) is untested below SAS 9.4 TS1M3));
  PROC HPSPLIT DATA = &indata SEED=&seed  ;
    FORMAT &Y;
    ODS SELECT NONE;
    PRUNE CC;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    TARGET &Y / LEVEL = ordinal;
    %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
        INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
    %IF (&continuous_predictors~=) %THEN 
         INPUT &continuous_predictors / LEVEL = interval;;
    ID _ALL_;
    OUTPUT out=&outdata (drop =  _node_ _leaf_ p_&Y.0 RENAME=(p_&Y.1 = p_cvcart&SUFF));
  RUN;
%MEND cvcart_in;

%MACRO cvcart_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* regression tree with cross validated pruning*/
  
  &suppresswarn %__SLwarning(%str(This function (CART) is untested below SAS 9.4 TS1M3));
  PROC HPSPLIT DATA = &indata SEED=&seed  ;
    FORMAT &Y;
    ODS SELECT NONE;
    PRUNE CC;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    TARGET &Y / LEVEL = interval;
    %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
         INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
    %IF (&continuous_predictors~=) %THEN 
          INPUT &continuous_predictors / LEVEL = interval;;
    ID _ALL_;
    OUTPUT out=&outdata (drop =  _node_ _leaf_ RENAME=(p_&Y = p_cvcart&SUFF));
  RUN;
%MEND cvcart_cn;

%MACRO cart_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* classification tree, no cross validation */
  
  &suppresswarn %__SLwarning(%str(This function (CART) is untested below SAS 9.4 TS1M3));
  PROC HPSPLIT DATA = &indata SEED=&seed  CVMETHOD=NONE;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    TARGET &Y / LEVEL = ordinal;
    %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
         INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
    %IF (&continuous_predictors~=) %THEN 
          INPUT &continuous_predictors / LEVEL = interval;;
    ID _ALL_;
    OUTPUT out=&outdata (drop =  _node_ _leaf_ p_&Y.0 RENAME=(p_&Y.1 = p_cart&SUFF));
  RUN;
%MEND cart_in;

%MACRO cart_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* regression tree, no cross validation */
  
  &suppresswarn %__SLwarning(%str(This function (CART) is untested below SAS 9.4 TS1M3));
  PROC HPSPLIT DATA = &indata SEED=&seed  CVMETHOD=NONE ;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    TARGET &Y / LEVEL = interval;
    %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
         INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
    %IF (&continuous_predictors~=) %THEN 
          INPUT &continuous_predictors / LEVEL = interval;;
    ID _ALL_;
    OUTPUT out=&outdata (drop =  _node_ _leaf_ RENAME=(p_&Y = p_cart&SUFF));
  RUN;
%MEND cart_cn;

%MACRO nn_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* neural network */
  PROC HPNEURAL DATA = &indata  ;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    TARGET &Y / LEVEL = NOM;
    %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
         INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = NOM;;
    %IF (&continuous_predictors~=) %THEN 
          INPUT &continuous_predictors / LEVEL = INT;;
    HIDDEN 5;
    TRAIN  MAXITER=200;
    SCORE out=&outdata (drop = I_&Y p_&Y.0 RENAME=(p_&Y.1 = p_nn&SUFF));
    ID _ALL_;
  RUN;
%MEND nn_in;

%MACRO nn_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* neural network regression*/
  PROC HPNEURAL DATA = &indata  ;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    TARGET &Y / LEVEL = INT;
    %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
         INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = NOM;;
    %IF (&continuous_predictors~=) %THEN 
          INPUT &continuous_predictors / LEVEL = INT;;
    HIDDEN 5;
    TRAIN OUTMODEL = __nnmod MAXITER=200;
  PROC HPNEURAL DATA = &indata;
    SCORE OUT=&outdata (DROP=_WARN_ RENAME=(p_&Y = p_nn&SUFF)) MODEL = __nnmod;
    ID _ALL_;
  RUN;
  PROC SQL NOPRINT; DROP TABLE __nnmod; QUIT;
%MEND nn_cn;

%MACRO gam_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* GENERALIZED ADDITIVE MODEL */
  %__SLnote(%str(GAMS use splines on all continuous variables, which may require a lot of computational power, user beware));;
  %IF (&continuous_predictors=) %THEN %__SLwarning(%str(GAMS with no continuous variables are equivalent to LOGIT, but slower));;
  %LET _pvar = p_gam&SUFF;
  PROC GAM DATA = &indata ;
    FORMAT &Y SLrevf.;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
      %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    MODEL &Y = %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=) OR (&binary_predictors~=)) %THEN PARAM(&binary_predictors &ordinal_predictors &nominal_predictors); %IF (&continuous_predictors~=) %THEN %__GAMSPLINE(&continuous_predictors, 3); / 
      DIST=BINOMIAL MAXITER=150 MAXITSCORE=300 ANODEV=NONE;
    OUTPUT OUT = &OUTDATA(RENAME=(P_&Y =  &_pvar) %IF (&continuous_predictors~=) %THEN %__gamdrop(&continuous_predictors);) PREDICTED;
  * gam leaves predictions missing if the predictors fall outside the range of the smooth surface;
  * temp solution is to do a linear extrapolation to fill in missing values;
  %__CheckSLPredMissing(Y= &_pvar, indata=&OUTDATA);
  %IF (&SLPredMiss NE 0 AND &SLPredMiss NE .) %THEN %DO;
    PROC GENMOD DATA = &OUTDATA;
      %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
      %IF &WEIGHT^= %THEN weight &weight;; 
      MODEL  &_pvar = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / LINK=ID D=NORMAL;
      OUTPUT OUT = &OUTDATA PRED=P_EXTRAPOLATE;
    DATA &outdata(DROP=p_extrapolate);
      SET &outdata;
      IF &_pvar = . THEN &_pvar = MAX(MIN(p_extrapolate, 1-&TRIMBOUND), &TRIMBOUND);
  %END;
  RUN;
%MEND gam_in;

%MACRO gamint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* GENERALIZED ADDITIVE MODEL */
  %__SLnote(%str(GAMS use splines on all continuous variables, which may require a lot of computational power, user beware));;
  %IF (&continuous_predictors=) %THEN %__SLwarning(%str(GAMS with no continuous variables are equivalent to LOGIT, but slower));;
  %LET _pvar = p_gamint&SUFF;
  PROC GAM DATA = &indata ;
    FORMAT &Y SLrevf.;
    ODS SELECT NONE;
      %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
     %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
    MODEL &Y = %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=) OR (&binary_predictors~=) OR (&SLIXterms~=)) %THEN PARAM(&binary_predictors &ordinal_predictors &nominal_predictors &SLIXterms); %IF (&continuous_predictors~=) %THEN %__GAMSPLINE(&continuous_predictors, 3); / 
      DIST=BINOMIAL MAXITER=150 MAXITSCORE=300 ANODEV=NONE;
    OUTPUT OUT = &OUTDATA(RENAME=(P_&Y =  &_pvar) %IF (&continuous_predictors~=) %THEN %__gamdrop(&continuous_predictors);) PREDICTED;
    * gam leaves predictions missing if the predictors fall outside the range of the smooth surface;
    * temp solution is to do a linear extrapolation to fill in missing values;
  %__CheckSLPredMissing(Y= &_pvar, indata=&OUTDATA);
  %IF (&SLPredMiss NE 0 AND &SLPredMiss NE .) %THEN %DO;
    PROC GENMOD DATA = &OUTDATA;
      %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
      %IF &WEIGHT^= %THEN weight &weight;; 
      MODEL  &_pvar = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / LINK=ID D=NORMAL;
      OUTPUT OUT = &OUTDATA PRED=P_EXTRAPOLATE;
    DATA &outdata(DROP=p_extrapolate);
      SET &outdata;
      IF &_pvar = . THEN &_pvar = MAX(MIN(p_extrapolate, 1-&TRIMBOUND), &TRIMBOUND);
  %END;
  RUN;
%MEND gamint_in;

%MACRO gam_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* GENERALIZED ADDITIVE MODEL for continuous variable (normal assumption)*/
  %__SLnote(%str(GAMS use splines on all continuous variables, which may require a lot of computational power, user beware));;
  %IF (&continuous_predictors=) %THEN %__SLwarning(%str(GAMS with no continuous variables are equivalent to PROC REG, but slower));;
  %LET _pvar = p_gam&SUFF;
  PROC GAM DATA = &indata ;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
        MODEL &Y = %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=) OR (&binary_predictors~=)) %THEN PARAM(&binary_predictors &ordinal_predictors &nominal_predictors); %IF (&continuous_predictors~=) %THEN %__GAMSPLINE(&continuous_predictors, 3); / 
     DIST=GAUSSIAN MAXITER=150 MAXITSCORE=300 ANODEV=NONE;
   OUTPUT OUT = &OUTDATA(RENAME=(P_&Y =  &_pvar) %IF (&continuous_predictors~=) %THEN %__gamdrop(&continuous_predictors);) PREDICTED;
  %__CheckSLPredMissing(Y= &_pvar, indata=&OUTDATA);
  %IF (&SLPredMiss NE 0 AND &SLPredMiss NE .) %THEN %DO;
      * gam leaves predictions missing if the predictors fall outside the range of the smooth surface;
    * temp solution is to do a linear extrapolation to fill in missing values;
    PROC GENMOD DATA = &OUTDATA;
      %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
      %IF &WEIGHT^= %THEN WEIGHT &weight;; *weights possibly truncated to integer values;
      MODEL  &_pvar = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors  / LINK=ID D=NORMAL;
      OUTPUT OUT = &OUTDATA PRED=P_EXTRAPOLATE;
    RUN;
    DATA &outdata(DROP=p_extrapolate);
     SET &outdata;
     IF  &_pvar = . THEN  &_pvar = p_extrapolate;
    RUN;
  %END;
%MEND gam_cn;

%MACRO gamint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* GENERALIZED ADDITIVE MODEL for continuous variable (normal assumption), interaction terms*/
  %__SLnote(%str(GAMS use splines on all continuous variables, which may require a lot of computational power, user beware));;
  %IF (&continuous_predictors=) %THEN %__SLwarning(%str(GAMS with no continuous variables are equivalent to PROC REG, but slower));;
  %LET _pvar = p_gamint&SUFF;
  PROC GAM DATA = &indata ;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
     MODEL &Y = %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=) OR (&binary_predictors~=) OR (&SLIXterms~=)) %THEN PARAM(&binary_predictors &ordinal_predictors &nominal_predictors &SLIXterms); %IF (&continuous_predictors~=) %THEN %__GAMSPLINE(&continuous_predictors, 3); / 
     DIST=GAUSSIAN MAXITER=150 MAXITSCORE=300 ANODEV=NONE;
    OUTPUT OUT = &OUTDATA(RENAME=(P_&Y =  &_pvar) %IF (&continuous_predictors~=) %THEN %__gamdrop(&continuous_predictors);) PREDICTED;
  %__CheckSLPredMissing(Y= &_pvar, indata=&OUTDATA);
  %IF (&SLPredMiss NE 0 AND &SLPredMiss NE .) %THEN %DO;
      * gam leaves predictions missing if the predictors fall outside the range of the smooth surface;
    * temp solution is to do a linear extrapolation to fill in missing values;
    PROC GENMOD DATA = &OUTDATA;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
     %IF &WEIGHT^= %THEN WEIGHT &weight;; *weights possibly truncated to integer values;
     MODEL  &_pvar = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / LINK=ID D=NORMAL;
     OUTPUT OUT = &OUTDATA PRED=P_EXTRAPOLATE;
    RUN;
    DATA &outdata(DROP=p_extrapolate);
     SET &outdata;
     IF  &_pvar = . THEN  &_pvar = p_extrapolate;
    RUN;
  %END;
%MEND gamint_cn;

%MACRO gampl_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* GENERALIZED ADDITIVE MODEL (using alternative sas proc) */
  %__SLnote(%str(GAMS use splines on all continuous variables, which may require a lot of computational power, user beware));;
  %IF (&continuous_predictors=) %THEN %__SLwarning(%str(GAMS with no continuous variables are equivalent to LOGIT, but slower));;
  %LET _pvar = p_gampl&SUFF;
  PROC GAMPL DATA = &indata PLIKEOPTIONS(TECH=QUANEW);
    FORMAT &Y SLrevf.;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
        MODEL &Y = %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=) OR (&binary_predictors~=)) %THEN PARAM(&binary_predictors &ordinal_predictors &nominal_predictors); %IF (&continuous_predictors~=) %THEN %__GAMPLSPLINE(&continuous_predictors); / 
     DIST=BINOMIAL;
    ID _all_;
    OUTPUT OUT = &OUTDATA(RENAME=(PRED = &_pvar)) PREDICTED;
  PROC DATASETS LIBRARY=WORK;MODIFY &OUTDATA; FORMAT &Y; QUIT;
  %__CheckSLPredMissing(Y= &_pvar, indata=&OUTDATA);
  %IF (&SLPredMiss NE 0 AND &SLPredMiss NE .) %THEN %DO;
    * gam leaves predictions missing if the predictors fall outside the range of the smooth surface;
    * temp solution is to do a linear extrapolation to fill in missing values;
    PROC GENMOD DATA = &OUTDATA;
     %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
     %IF &WEIGHT^= %THEN WEIGHT &weight;;
     MODEL  &_pvar = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors   / LINK=ID D=NORMAL;
     OUTPUT OUT = &OUTDATA PRED=P_EXTRAPOLATE;
    RUN;
    DATA &outdata(DROP=p_extrapolate);
     SET &outdata;
     IF &_pvar = . THEN &_pvar = MAX(MIN(p_extrapolate, 1-&TRIMBOUND), &TRIMBOUND);
    RUN;
  %END;
%MEND gampl_in;

%MACRO gamplint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* GENERALIZED ADDITIVE MODEL (using alternative sas proc), interaction terms */
  %__SLnote(%str(GAMS use splines on all continuous variables, which may require a lot of computational power, user beware));;
  %IF (&continuous_predictors=) %THEN %__SLwarning(%str(GAMS with no continuous variables are equivalent to LOGIT, but slower));;
  %LET _pvar = p_gamplint&SUFF.;
  PROC GAMPL DATA = &indata PLIKEOPTIONS(TECH=QUANEW);
    FORMAT &Y SLrevf.;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
        MODEL &Y = %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=) OR (&binary_predictors~=) OR (&SLIXterms~=)) %THEN PARAM(&binary_predictors &ordinal_predictors &nominal_predictors &SLIXterms); %IF (&continuous_predictors~=) %THEN %__GAMPLSPLINE(&continuous_predictors); / 
      DIST=BINOMIAL;
    ID _all_;
    OUTPUT OUT = &OUTDATA(RENAME=(PRED = &_pvar)) PREDICTED;
  PROC DATASETS LIBRARY=WORK;MODIFY &OUTDATA; FORMAT &Y; QUIT;
 %__CheckSLPredMissing(Y= &_pvar, indata=&OUTDATA);
  %IF (&SLPredMiss NE 0 AND &SLPredMiss NE .) %THEN %DO;
    * gam leaves predictions missing if the predictors fall outside the range of the smooth surface;
    * temp solution is to do a linear extrapolation to fill in missing values;
    PROC GENMOD DATA = &OUTDATA;
      %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
      %IF &WEIGHT^= %THEN WEIGHT &weight;;
      MODEL  &_pvar = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / LINK=ID D=NORMAL;
      OUTPUT OUT = &OUTDATA PRED=P_EXTRAPOLATE;
    RUN;
    DATA &outdata(DROP=p_extrapolate);
     SET &outdata;
     IF &_pvar = . THEN &_pvar = MAX(MIN(p_extrapolate, 1-&TRIMBOUND), &TRIMBOUND);
    RUN;
  %END;
%MEND gamplint_in;

%MACRO gampl_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* GENERALIZED ADDITIVE MODEL for continuous variable (using alternative sas proc) */
  %__SLnote(%str(GAMS use splines on all continuous variables, which may require a lot of computational power, user beware));;
  %IF (&continuous_predictors=) %THEN %__SLwarning(%str(GAMS with no continuous variables are equivalent to LINREG, but slower));;
  %LET _pvar = p_gampl&SUFF ;
  PROC GAMPL DATA = &indata PLIKEOPTIONS(TECH=QUANEW);
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=) OR (&binary_predictors~=)) %THEN PARAM(&binary_predictors &ordinal_predictors &nominal_predictors); %IF (&continuous_predictors~=) %THEN %__GAMplSPLINE(&continuous_predictors); / 
     DIST=GAUSSIAN;
   ID _all_;
   OUTPUT OUT = &OUTDATA(RENAME=(PRED = &_pvar)) PREDICTED;
  RUN;
  %__CheckSLPredMissing(Y= &_pvar, indata=&OUTDATA);
  %IF (&SLPredMiss NE 0 AND &SLPredMiss NE .) %THEN %DO;
      * gam leaves predictions missing if the predictors fall outside the range of the smooth surface;
    * temp solution is to do a linear extrapolation to fill in missing values;
    PROC GENMOD DATA = &OUTDATA;
      %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
      %IF &WEIGHT^= %THEN WEIGHT &weight;;
      MODEL  &_pvar = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / LINK=ID D=NORMAL;
      OUTPUT OUT = &OUTDATA PRED=P_EXTRAPOLATE;
    RUN;
    DATA &outdata(DROP=p_extrapolate);
      SET &outdata;
      IF &_pvar = . THEN  &_pvar = p_extrapolate;
    RUN;
  %END;
%MEND gampl_cn;

%MACRO gamplint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* GENERALIZED ADDITIVE MODEL for continuous variable (using alternative sas proc), interaction terms */
  %__SLnote(%str(GAMS use splines on all continuous variables, which may require a lot of computational power, user beware));;
  %IF (&continuous_predictors=) %THEN %__SLwarning(%str(GAMS with no continuous variables are equivalent to LINREGINT, but slower));;
  %LET _pvar = p_gamplint&SUFF;
  PROC GAMPL DATA = &indata PLIKEOPTIONS(TECH=QUANEW);
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=) OR (&binary_predictors~=) OR (&SLIXterms~=)) %THEN PARAM(&binary_predictors &ordinal_predictors &nominal_predictors &SLIXterms); %IF (&continuous_predictors~=) %THEN %__GAMplSPLINE(&continuous_predictors); / 
     DIST=GAUSSIAN;
   ID _all_;
   OUTPUT OUT = &OUTDATA(RENAME=(PRED = &_pvar)) PREDICTED;
  RUN;
  %__CheckSLPredMissing(Y=&_pvar, indata=&OUTDATA);
  %IF (&SLPredMiss NE 0 AND &SLPredMiss NE .) %THEN %DO;
    PROC GENMOD DATA = &OUTDATA;
     %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
     %IF &WEIGHT^= %THEN WEIGHT &weight;;
     MODEL &_pvar = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / LINK=ID D=NORMAL;
     OUTPUT OUT = &OUTDATA PRED=P_EXTRAPOLATE;
    RUN;
    DATA &outdata(DROP=p_extrapolate);
     SET &outdata;
     IF &_pvar = . THEN &_pvar = p_extrapolate;
    RUN;
  %END;
%MEND gamplint_cn;

%MACRO mars_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* multivariate adaptive regression splines */
  PROC ADAPTIVEREG DATA = &indata SEED=&seed;
    FORMAT &Y;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y.(DESCENDING) = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / LINK=LOGIT DIST=BINOMIAL DFPERBASIS=2;
    OUTPUT OUT = &OUTDATA PRED=p_mars&SUFF;
  RUN;
  DATA &outdata;
   SET &outdata;
   p_mars&SUFF = EXPIT(p_mars&SUFF);
%MEND mars_in;

%MACRO mars_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* multivariate adaptive regression splines, continuous */
  PROC ADAPTIVEREG DATA = &indata SEED=&seed;
    FORMAT &Y;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / LINK=ID DFPERBASIS=2 ;
    OUTPUT OUT = &OUTDATA PRED=p_mars&SUFF;
  RUN;
%MEND mars_cn;

%MACRO marsint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* multivariate adaptive regression splines, including interactions */
  PROC ADAPTIVEREG DATA = &indata SEED=&seed;
    FORMAT &Y;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y.(DESCENDING) = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / LINK=LOGIT DIST=BINOMIAL DFPERBASIS=2;
    OUTPUT OUT = &OUTDATA PRED=p_marsint&SUFF;
  RUN;
  DATA &outdata;
   SET &outdata;
   p_marsint&SUFF = EXPIT(p_marsint&SUFF);
  RUN;
%MEND marsint_in;

%MACRO marsint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* multivariate adaptive regression splines, continuous including interactions */
  PROC ADAPTIVEREG DATA = &indata SEED=&seed;
    FORMAT &Y;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / LINK=ID DFPERBASIS=2;
    OUTPUT OUT = &OUTDATA PRED=p_marsint&SUFF;
  RUN;
%MEND marsint_cn;

%MACRO loess_cn(      
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /* local regression*/ 
  PROC LOESS DATA = &indata;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
    OUTPUT OUT = &OUTDATA(DROP=smoothingparameter depvar obs) P=p_loess&SUFF; /*change predicted value name with p_[libraryname]&suff*/
  RUN;  
%MEND loess_cn; 

%MACRO loess_in(  
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
/* local regression*/
  PROC LOESS DATA = &indata;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
    OUTPUT OUT = &OUTDATA(DROP=smoothingparameter depvar obs) P=p_loess&SUFF; /*change predicted value name with p_[libraryname]&suff*/
  RUN;    
%MEND loess_in; /*optional: include macro name in mend statement with [libraryname]_cn*/

%MACRO probit_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* probit model */
  PROC PROBIT DATA = &indata;
    FORMAT &Y SLrevf.;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / D=NORMAL;
    OUTPUT OUT = &OUTDATA(DROP=_level_) P=p_probit&SUFF;
  RUN;
  PROC DATASETS LIBRARY=WORK;MODIFY &OUTDATA; FORMAT &Y; QUIT;
%MEND probit_in;
*%probit_in( Y=y, indata=a,  outdata=test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO probitint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* probit model */
  PROC PROBIT DATA = &indata;
    FORMAT &Y SLrevf.;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms/ D=NORMAL;
    OUTPUT OUT = &OUTDATA(DROP=_level_) P=p_probitint&SUFF;
  RUN;
  PROC DATASETS LIBRARY=WORK;MODIFY &OUTDATA; FORMAT &Y; QUIT;
%MEND probitint_in;
*%probitint_in( Y=y, indata=a,  outdata=test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO svm_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Support vector machine classification*/
  PROC HPSVM DATA = &indata;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
    TARGET &Y / LEVEL=binary ORDER=DESCENDING;
    %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
    ID _all_;
    OUTPUT OUT=&OUTDATA(DROP=_P_  p_&Y.0 I_&Y _Warn_ RENAME=(P_&Y.1 = p_svm&suff));
  RUN;
%MEND svm_in;

%MACRO svmrbf_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Support vector machine classification, rbf kernel*/
 PROC HPSVM DATA = &indata METHOD=ACTIVESET;
   FORMAT &Y;
   %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
   TARGET &Y / LEVEL=binary ORDER=DESCENDING;
   KERNEL RBF / K_PAR=1;
   %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
   %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
   ID _all_;
   OUTPUT OUT=&OUTDATA(DROP=_P_  p_&Y.0 I_&Y _Warn_ RENAME=(P_&Y.1 = p_svmrbf&suff));
 RUN;
%MEND svmrbf_in;

%MACRO boost_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* gradient boosting*/
  &suppresswarn %__SLwarning(%str(This function (BOOST) is untested below SAS 9.4 TS1M3));
  /*%LET modopts = %bquote(HUBER=NO Iterations=1000 TrainProportion = .60 SHRINKAGE=0.1 LeafFraction=0.1 MinCatsize=5 Maxbranch=2
        MAXDEPTH=4 );*/
  %LET modopts = %STR();
  PROC ARBOR PROC=TREEBOOST DATA = &indata SEED=&seed &modopts;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
    TARGET &Y / LEVEL=nominal;
      %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
      %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
    SCORE DATA=&indata OUT=__sltm0017_(RENAME = (p_&Y.1 = p_boost&SUFF) DROP = p_&Y.0 q_&Y.: r_&Y.: F_&Y U_&Y i_&Y _warn_);
  PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &outdata;
    CHANGE __sltm0017_=&outdata ;
   QUIT;
%MEND boost_in;

%MACRO boosting_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* gradient boosting*/
  &suppresswarn %__SLwarning(%str(This function (BOOST) is untested below SAS 9.4 TS1M3));
  /*%LET modopts = %bquote(HUBER=NO Iterations=1000 TrainProportion = .60 SHRINKAGE=0.1 LeafFraction=0.1 MinCatsize=5 Maxbranch=2
        MAXDEPTH=4 );*/
  %LET modopts = %STR();
  PROC ARBOR PROC=TREEBOOST DATA = &indata SEED=&seed &modopts;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
    TARGET &Y / LEVEL=nominal;
      %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
      %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
    SCORE DATA=&indata OUT=__sltm0017_(RENAME = (p_&Y.1 = p_boosting&SUFF) DROP = p_&Y.0 q_&Y.: r_&Y.: F_&Y U_&Y i_&Y _warn_);
  PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &outdata;
    CHANGE __sltm0017_=&outdata ;
   QUIT;
%MEND boosting_in;


%MACRO boost_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* gradient boosting*/
  &suppresswarn %__SLwarning(%str(This function (BOOST) is untested below SAS 9.4 TS1M3));
  /*%LET modopts = %bquote(HUBER=1 Iterations=1000 TrainProportion = .60 SHRINKAGE=0.1 LeafFraction=0.1 MinCatsize=5 Maxbranch=2
        MAXDEPTH=4 );*/
  %LET modopts = %STR();
  PROC ARBOR PROC=TREEBOOST DATA = &indata SEED=&seed &modopts;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
    TARGET &Y / LEVEL=INTERVAL;
     %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
     %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
     SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_boost&SUFF) DROP =  r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &outdata;
    CHANGE __sltm0017_=&outdata ;
   QUIT;
  RUN;
%MEND boost_cn;

%MACRO boosting_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* gradient boosting (same as boost_cn)*/
  &suppresswarn %__SLwarning(%str(This function (BOOST) is untested below SAS 9.4 TS1M3));
  /*%LET modopts = %bquote(HUBER=1 Iterations=1000 TrainProportion = .60 SHRINKAGE=0.1 LeafFraction=0.1 MinCatsize=5 Maxbranch=2
        MAXDEPTH=4 );*/
  %LET modopts = %STR();
  PROC ARBOR PROC=TREEBOOST DATA = &indata SEED=&seed &modopts;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
    TARGET &Y / LEVEL=INTERVAL;
     %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
     %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
     SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_boosting&SUFF) DROP =  r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &outdata;
    CHANGE __sltm0017_=&outdata ;
   QUIT;
  RUN;
%MEND boosting_cn;

%MACRO bagging_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* bootstrap aggregation*/
  &suppresswarn %__SLwarning(%str(This function (bagging) is experimental and untested below SAS 9.4 TS1M3));
  /*%LET modopts = %STR(SEED = 1232 MINCATSIZE=2 MAXTREES = 200 TrainProportion = .60 Criterion=Gini Minworth=0.0 SplitSize=20 
     Maxbranch=2 MAXDEPTH=30 MAXSURROGATES=0);*/
  %LET modopts = %STR();
  PROC ARBOR PROC=BAG DATA = &indata SEED=&seed &modopts;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
    TARGET &Y / LEVEL=nominal;
     %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
     %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
    /* perhaps go to vote based system?*/
   SCORE DATA=&indata OUT=__sltm0017_(RENAME = (p_&Y.1 = p_bagging&SUFF) DROP = iv_&Y.: pv_&Y.0 pv_&Y.1 p_&Y.0 q_&Y.: r_&Y.: F_&Y U_&Y i_&Y _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &outdata;
    CHANGE __sltm0017_=&outdata ;
   QUIT;
%MEND bagging_in;

%MACRO bagging_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* bootstrap aggregation*/
  &suppresswarn %__SLwarning(%str(This function (bagging) is experimental and untested below SAS 9.4 TS1M3));
  /*%LET modopts = %STR(SEED = 1232 MINCATSIZE=2 MAXTREES = 200 TrainProportion = .60 Criterion=Variance Minworth=0.0 SplitSize=20 
     Maxbranch=2 MAXDEPTH=30 MAXSURROGATES=0);*/
  %LET modopts = %STR();
  PROC ARBOR PROC=BAG DATA = &indata SEED=&seed &modopts;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
    TARGET &Y / LEVEL=INTERVAL;
      %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
      %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
     SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_bagging&SUFF) DROP = r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &outdata;
    CHANGE __sltm0017_=&outdata ;
   QUIT;
  RUN;
%MEND bagging_cn;

%MACRO sherwood_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Random forest with replacement*/
  &suppresswarn %__SLwarning(%str(This function (bagging) is experimental and untested below SAS 9.4 TS1M3));
  /*%LET modopts = %STR(SEED = 1232 MAXTREES=100 TrainProportion = .60 LeafFraction=0.1 MinCatsize=5 Maxbranch=2
        MAXDEPTH=30 WITHREP CRITERION=CHAID);*/
  %LET modopts = %STR(WITHREP);
  PROC ARBOR PROC=SHERWOOD DATA = &indata SEED=&seed &modopts;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
    TARGET &Y / LEVEL=nominal;
      %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
      %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
      /* perhaps go to vote based system?*/
     SCORE DATA=&indata OUT=__sltm0017_(RENAME = (p_&Y.1 = p_sherwood&SUFF) DROP = pv_&Y.0 pv_&Y.1 p_&Y.0 q_&Y.: r_&Y.: F_&Y U_&Y i_&Y _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &outdata;
    CHANGE __sltm0017_=&outdata ;
   QUIT;
%MEND sherwood_in;

%MACRO sherwood_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Random forest, with replacement*/
  &suppresswarn %__SLwarning(%str(This function (bagging) is experimental and untested below SAS 9.4 TS1M3));
  /*%LET modopts = %STR(SEED = 1232 MAXTREES=100 TrainProportion = .60 LeafFraction=0.1 MinCatsize=5 Maxbranch=2
        MAXDEPTH=30 WITHREP CRITERION=VARIANCE);*/
  %LET modopts = %STR(WITHREP);
  PROC ARBOR PROC=SHERWOOD DATA = &indata SEED=&seed &modopts;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
    TARGET &Y / LEVEL=INTERVAL;
      %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
      %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
     SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_sherwood&SUFF) DROP = r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &outdata;
    CHANGE __sltm0017_=&outdata ;
   QUIT;
  RUN;
%MEND sherwood_cn;

%MACRO knn_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  PROC DISCRIM DATA = &indata METHOD = npar KPROP=.01 /*K = 5*/ TESTDATA=&indata 
    TESTOUT = &outdata(DROP = _0 _into_ RENAME=(_1=p_knn&suff)) NOPRINT;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    CLASS &Y;
    VAR &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
  RUN;
%MEND knn_in;

%MACRO pbspline_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Penalized basis splines: not very useful*/
  %LET _pvar = p_pbspline&SUFF;
  PROC TRANSREG DATA = &indata MAXITER=100;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL IDENTITY(&Y) = %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS(&binary_predictors &ordinal_predictors &nominal_predictors);  %IF (&continuous_predictors~=) %THEN %__PBSPLINE(&continuous_predictors, 3);/ MAXITER=100;
    OUTPUT OUT = __sltm0018(KEEP = p&y RENAME=(p&y= p_pbspline&suff)) PREDICTED;  RUN;
  OPTIONS MERGENOBY = NOWARN;
  DATA &outdata; MERGE &indata __sltm0018;
  PROC SQL NOPRINT; DROP TABLE __sltm0018; QUIT;
  OPTIONS MERGENOBY = WARN;
%MEND pbspline_cn;

 %MACRO bspline_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* b-splines - minimizes squared error*/
  PROC TRANSREG DATA = &indata MAXITER=100;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL IDENTITY(&Y) = %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS(&binary_predictors &ordinal_predictors &nominal_predictors);  %IF (&continuous_predictors~=) %THEN %__SPLINE(&continuous_predictors, 2);/ MAXITER=100;
    OUTPUT OUT = __sltm0018(KEEP = p&y RENAME=(p&y= p_bspline&suff)) PREDICTED;  RUN;
  OPTIONS MERGENOBY = NOWARN;
  DATA &outdata; MERGE &indata __sltm0018;
  PROC SQL NOPRINT; DROP TABLE __sltm0018; QUIT;
  OPTIONS MERGENOBY = WARN;
%MEND bspline_cn;

 %MACRO boxcox_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* BOX COX non-linear transformation - minimizes squared error*/
  PROC TRANSREG DATA = &indata MAXITER=100;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL BOXCOX(&Y / LAMBDA=-3 to 3 by 0.1) = %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS(&binary_predictors &ordinal_predictors &nominal_predictors);%IF (&continuous_predictors~=) %THEN %__IDENT(&continuous_predictors); / MAXITER=100;
    OUTPUT OUT = __sltm0018(KEEP = p&y RENAME=(p&y= p_boxcox&suff)) PREDICTED;  RUN;
  OPTIONS MERGENOBY = NOWARN;
  DATA &outdata; MERGE &indata __sltm0018;
  PROC SQL NOPRINT; DROP TABLE __sltm0018; QUIT;
  OPTIONS MERGENOBY = WARN;
%MEND boxcox_cn;

* super learner library member 'deepnn';
%MACRO deepnn_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* 
  deep neural network regression
  */
  %LET nhl = 5; *number of hidden layers;
  %LET fpl = 50; *nodes per layer;
  %LET icom = ;
  %LET ncom = ;
  %IF (&continuous_predictors=) %THEN %LET icom = *;;
  %IF (&ordinal_predictors=) AND (&binary_predictors=) AND (&nominal_predictors=) %THEN %LET ncom=*;;
  /* neural network regression*/
  DATA __sltm0017_; SET &indata;

  PROC DMDB BATCH DATA=__sltm0017_(WHERE=(&Y>.z)) DMDBCAT=__dmdb ;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    &ncom CLASS &binary_predictors &ordinal_predictors &nominal_predictors;;
    VAR &Y &continuous_predictors;
    TARGET &Y;
  RUN; QUIT;
  
  PROC NEURAL DATA=__sltm0017_(WHERE=(&Y>.z)) RANDOM=&seed DMDBCAT=__dmdb random=&seed;
    FORMAT &Y;
    NLOPTIONS NOPRINT;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
    *performance alldetails noutilfile;
    NETOPTS DECAY=0;
    &icom INPUT &continuous_predictors / ID=__nnli LEVEL=INTERVAL ;;
    &ncom INPUT &binary_predictors &ordinal_predictors &nominal_predictors / ID=__nnln LEVEL=NOMINAL ;;
    TARGET &Y / ID = __nny LEVEL=INTERVAL BIAS;
    %LET _hl = 1;
    %DO %WHILE(%EVAL(&_hl<=&nhl));
      HIDDEN &fpl / ID=__nnl&_hl;
      %LET _hl = %EVAL(&_hl+1);
    %END;
    /* pretraining - multiple initial*/
    PRELIM 10 preiter=200 pretime=3600;
     /*initialize */
    TRAIN MAXITER=5 MAXTIME=14400;
    *pre-training hidden layer 1;
    %LET _hl = 2;
    %DO %WHILE(%EVAL(&_hl<=&nhl));
      FREEZE __nnl%EVAL(&_hl-1) -> __nnl&_hl;
      %LET _hl = %EVAL(&_hl+1);
    %END;
    TRAIN MAXITER=1000 MAXTIME=14400;
    %LET _hl = 2;
    %DO %WHILE(%EVAL(&_hl<=&nhl));
      %IF %EVAL(&_hl>2) %THEN THAW __nnl%EVAL(&_hl-2) -> __nnl%EVAL(&_hl-1);;
      %IF &_hl = 2 %THEN %DO; 
        &icom FREEZE __nnli->__nnl%EVAL(&_hl-1);
        &ncom FREEZE __nnln->__nnl%EVAL(&_hl-1);
      %END;
      %ELSE %DO;
          FREEZE __nnl%EVAL(&_hl-1)->__nnl&_hl;
      %END; 
      *pre-training layer &_hl;
      TRAIN MAXITER=2000 MAXTIME=14400;
      %LET _hl = %EVAL(&_hl+1);
    %END;
    %LET _hl = 2;
    %DO %WHILE(%EVAL(&_hl<=&nhl));
      %IF &_hl = 2 %THEN %DO; 
        &icom THAW __nnli->__nnl%EVAL(&_hl-1);
        &ncom THAW __nnln->__nnl%EVAL(&_hl-1);
      %END;
      THAW __nnl%EVAL(&_hl-1) -> __nnl&_hl;
      %LET _hl = %EVAL(&_hl+1);
    %END;
    *full training;
    TRAIN MAXITER=1000 MAXTIME=14400;
    *scoring;
    SCORE DATA=__sltm0017_ OUT=&outdata(DROP= R_&Y E_&Y __nnl: %IF &continuous_predictors^= %THEN %__nndrop(&continuous_predictors); RENAME=(P_&Y=p_deepnn&SUFF));
  RUN;
  %__CLEANUP(%STR(__sltm0017_, __dmdb));  
%MEND deepnn_cn;

%MACRO deepnn_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* 
  deep neural network classification
  */
  %LET nhl = 3; *number of hidden layers;
  %LET fpl = 50; *nodes per layer;
  %LET icom = ;
  %LET ncom = ;
  %IF (&continuous_predictors=) %THEN %LET icom = *;;
  %IF (&ordinal_predictors=) AND (&binary_predictors=) AND (&nominal_predictors=) %THEN %LET ncom=*;;
  /* neural network regression*/
  DATA __sltm0017_; SET &indata;

  PROC DMDB BATCH DATA=__sltm0017_(WHERE=(&Y>.z)) DMDBCAT=__dmdb ;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    CLASS &Y &binary_predictors &ordinal_predictors &nominal_predictors;;
    &icom VAR  &continuous_predictors;
    TARGET &Y;
  RUN; QUIT;  
  PROC NEURAL DATA=__sltm0017_(WHERE=(&Y>.z)) RANDOM=&seed DMDBCAT=__dmdb random=&seed;
    FORMAT &Y;
    NLOPTIONS NOPRINT;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
   *performance alldetails noutilfile;
    NETOPTS DECAY=0;
    &icom INPUT &continuous_predictors / ID=__nnli LEVEL=INTERVAL ;;
    &ncom INPUT &binary_predictors &ordinal_predictors &nominal_predictors / ID=__nnln LEVEL=NOMINAL ;;
    TARGET &Y / ID = __nny LEVEL=NOMINAL BIAS;
    %LET _hl = 1;
    %DO %WHILE(%EVAL(&_hl<=&nhl));
      HIDDEN &fpl / ID=__nnl&_hl;
      %LET _hl = %EVAL(&_hl+1);
    %END;
    /* initialize */
    /* pretraining */
    PRELIM 1 preiter=200 pretime=3600;
     /*initialize */
    TRAIN MAXITER=5 MAXTIME=14400;
    *pre-training hidden layer 1;
    %LET _hl = 2;
    %DO %WHILE(%EVAL(&_hl<=&nhl));
      FREEZE __nnl%EVAL(&_hl-1) -> __nnl&_hl;
      %LET _hl = %EVAL(&_hl+1);
    %END;
    TRAIN MAXITER=1000 MAXTIME=14400;
    %LET _hl = 2;
    %DO %WHILE(%EVAL(&_hl<=&nhl));
      %IF %EVAL(&_hl>2) %THEN THAW __nnl%EVAL(&_hl-2) -> __nnl%EVAL(&_hl-1);;
      %IF &_hl = 2 %THEN %DO; 
        &icom FREEZE __nnli->__nnl%EVAL(&_hl-1);
        &ncom FREEZE __nnln->__nnl%EVAL(&_hl-1);
      %END;
      %ELSE %DO;
          FREEZE __nnl%EVAL(&_hl-1)->__nnl&_hl;
      %END; 
      *pre-training layer &_hl;
      TRAIN MAXITER=2000 MAXTIME=14400;
      %LET _hl = %EVAL(&_hl+1);
    %END;
    %LET _hl = 2;
    %DO %WHILE(%EVAL(&_hl<=&nhl));
      %IF &_hl = 2 %THEN %DO; 
        &icom THAW __nnli->__nnl%EVAL(&_hl-1);
        &ncom THAW __nnln->__nnl%EVAL(&_hl-1);
      %END;
      THAW __nnl%EVAL(&_hl-1) -> __nnl&_hl;
      %LET _hl = %EVAL(&_hl+1);
    %END;
    *full training;
    TRAIN MAXITER=1000 MAXTIME=14400;
    *scoring;
    SCORE DATA=__sltm0017_ OUT=&outdata(DROP= P_&Y.0 R_&Y.0 R_&Y.1 E_&Y.0 E_&Y.1 __nnl: %IF &continuous_predictors^= %THEN %__nndrop(&continuous_predictors); RENAME=(P_&Y.1=p_deepnn&SUFF));
  RUN;
  %__CLEANUP(%STR(__sltm0017_, __dmdb));  
%MEND deepnn_in;

%MACRO hplogit_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* logistic model */
  PROC HPLOGISTIC DATA = &indata NOPRINT;
    FORMAT &Y;
    ID _all_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y (DESCENDING) = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
    OUTPUT OUT = &OUTDATA PRED=p_hplogit&SUFF;
  RUN;
%MEND hplogit_in;
*%hplogit_in( Y=y, indata=a,  outdata=LOGIT_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO hplogitint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* logistic model with interaction terms*/
  PROC HPLOGISTIC DATA = &indata NOPRINT ;
    FORMAT &Y;
    ID _all_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y (DESCENDING) = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms;
    OUTPUT OUT = &OUTDATA PRED=p_hplogitint&SUFF;
  RUN;
%MEND hplogitint_in;
*%hplogit_in( Y=y, indata=a,  outdata=LOGIT_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO hplinreg_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* linear regression model */
  PROC HPREG DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    ID _ALL_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors ;
    OUTPUT OUT = &OUTDATA PRED=p_hplinreg&SUFF;
  RUN;
%MEND hplinreg_cn;
*%hplinreg_in( Y=y, indata=a,  outdata=hplinreg_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO hplinregint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* linear regression model with interaction terms */
  PROC HPREG DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    ID _ALL_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms; 
    OUTPUT OUT = &OUTDATA PRED=p_hplinregint&SUFF;
  RUN;
%MEND hplinregint_cn;
*%hplinreg_cn( Y=y, indata=a,  outdata=hplinreg_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );


%MACRO hplasso_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* LASSO regression model (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) */
  PROC HPREG DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    ID _ALL_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors ;
    SELECTION METHOD=LASSO(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA PRED=p_hplasso&SUFF;
  RUN;
%MEND hplasso_cn;
*%hplasso_in( Y=y, indata=a,  outdata=hplasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO hplassoint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* LASSO regression model (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) with interaction terms */
  PROC HPREG DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    ID _ALL_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms; 
    SELECTION METHOD=LASSO(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA PRED=p_hplassoint&SUFF;
  RUN;
%MEND hplassoint_cn;
*%hplasso_cn( Y=y, indata=a,  outdata=hplasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO hplar_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* least angle regression model (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) */
  PROC HPREG DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    ID _ALL_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors ;
    SELECTION METHOD=LAR(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA PRED=p_hplar&SUFF;
  RUN;
%MEND hpLAR_cn;
*%hpLAR_in( Y=y, indata=a,  outdata=hpLAR_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO hplarint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* least angle regression model (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) with interaction terms */
  PROC HPREG DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    ID _ALL_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms; 
    SELECTION METHOD=LAR(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA PRED=p_hplarint&SUFF;
  RUN;
%MEND hplarint_cn;
*%hpLAR_cn( Y=y, indata=a,  outdata=hpLAR_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );
%MACRO hplasso_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* least angle regression model (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) */
  PROC HPREG DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    ID _ALL_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors ;
    SELECTION METHOD=LASSO(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA PRED=p_hplasso&SUFF;
  RUN;
%MEND hplasso_in;
*%hplasso_in( Y=y, indata=a,  outdata=hplasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO hplassoint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* least angle regression model (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) with interaction terms */
  PROC HPREG DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    ID _ALL_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms; 
    SELECTION METHOD=LASSO(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA PRED=p_hplassoint&SUFF;
  RUN;
%MEND hplassoint_in;
*%hplasso_in( Y=y, indata=a,  outdata=hplasso_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO hplar_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* least angle regression model (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) */
  PROC HPREG DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    ID _ALL_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors ;
    SELECTION METHOD=LAR(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA PRED=p_hplar&SUFF;
  RUN;
%MEND hpLAR_in;
*%hpLAR_in( Y=y, indata=a,  outdata=hpLAR_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO hplarint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* least angle regression model (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) with interaction terms */
  PROC HPREG DATA = &indata NOPRINT SEED=&seed;
    FORMAT &Y;
    ODS SELECT NONE;
    ID _ALL_;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms; 
    SELECTION METHOD=LAR(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = &OUTDATA PRED=p_hplarint&SUFF;
  RUN;
%MEND hpLARint_in;
*%hpLAR_in( Y=y, indata=a,  outdata=hpLAR_test,  binary_predictors= X l,  ordinal_predictors=,  nominal_predictors=,   continuous_predictors=, suff= );

%MACRO hpglm_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /*hpglm: wrapper for linreg*/
 %hplogit_cn(Y=&y, indata=&indata,  outdata=&outdata(RENAME=(p_hplogit&SUFF=p_hpglm&SUFF)),  binary_predictors= &binary_predictors,  ordinal_predictors=&ordinal_predictors,  nominal_predictors=&nominal_predictors,   continuous_predictors=&continuous_predictors,weight=&weight, suff=&suff, seed=&seed)
%MEND hpglm_in;

%MACRO hpglmint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /*wrapper for linregint*/
 %hplogitint_cn(Y=&y, indata=&indata,  outdata=&outdata(RENAME=(p_hplogitint&SUFF=p_hpglmint&SUFF)),  binary_predictors= &binary_predictors,  ordinal_predictors=&ordinal_predictors,  nominal_predictors=&nominal_predictors,   continuous_predictors=&continuous_predictors,weight=&weight, suff=&suff, seed=&seed)
%MEND hpglmint_in;

%MACRO hpglm_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /*hpglm: wrapper for linreg*/
 %hplinreg_cn(Y=&y, indata=&indata,  outdata=&outdata(RENAME=(p_hplinreg&SUFF=p_hpglm&SUFF)),  binary_predictors= &binary_predictors,  ordinal_predictors=&ordinal_predictors,  nominal_predictors=&nominal_predictors,   continuous_predictors=&continuous_predictors,weight=&weight, suff=&suff, seed=&seed)
%MEND hpglm_cn;

%MACRO hpglmint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /*wrapper for linregint*/
 %hplinregint_cn(Y=&y, indata=&indata,  outdata=&outdata(RENAME=(p_hplinregint&SUFF=p_hpglmint&SUFF)),  binary_predictors= &binary_predictors,  ordinal_predictors=&ordinal_predictors,  nominal_predictors=&nominal_predictors,   continuous_predictors=&continuous_predictors,weight=&weight, suff=&suff, seed=&seed)
%MEND hpglmint_cn;

%MACRO hal_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Highly adaptive LASSO model, selection by cross validation, minimizing CV residual sum of squares */
  %GetHALDesign(y=&y, vars=&binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors , 
                indata=&indata, outdata=__sltm0017_, drop=TRUE, intdepthlimit=0);
  OPTIONS MERGENOBY=NOWARN;
  DATA __sltm0016_;
   MERGE &indata(KEEP=&Y &weight) __sltm0017_;
  RUN;
  PROC GLMSELECT DATA = __sltm0016_ NOPRINT SEED=&seed;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    ODS SELECT NONE;
    MODEL &Y = __hal_: / SELECTION=LASSO(CHOOSE=CVEX STOP=NONE) CVMETHOD=RANDOM(10);
    OUTPUT OUT =__sltm0016_(KEEP=p_hal&SUFF) PRED=p_hal&SUFF;
  RUN;
  DATA &outdata;
   MERGE &indata __sltm0016_;
  RUN;
  OPTIONS MERGENOBY=WARN;
%MEND hal_cn;

%MACRO hal_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  %__SLwarning(%str(HAL does not resepect the 0/1 probability space and should be used with extreme caution (Try using the 'ahal' learner)));
  /* Highly adaptive LASSO model, selection by cross validation, minimizing CV residual sum of squares 
     (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) */
  %hal_cn(Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,
               nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight, suff=&suff, seed=&seed);
%MEND hal_in;

%MACRO ahal_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /*APPROXIMATE Highly adaptive LASSO model, selection by AICC, HPGENSELECT */
  %GetHALDesign(y=&y, vars=&binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors , 
                indata=&indata, outdata=__sltm0017_, drop=TRUE, intdepthlimit=0);
  OPTIONS MERGENOBY=NOWARN;
  DATA __sltm0016_;
   MERGE &indata(KEEP=&Y &weight) __sltm0017_;
  RUN;
  PROC HPGENSELECT DATA=__sltm0016_ TECH=QUANEW NOSTDERR LASSORHO=0.8 LASSOSTEPS=100 NORMALIZE=YES;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = __hal_: / DIST=GAUSSIAN LINK=ID;
    SELECTION METHOD=lasso(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = __sltm0016_(KEEP=p_ahal&SUFF) p = p_ahal&SUFF; 
  RUN;;
  DATA &outdata;
   MERGE &indata __sltm0016_;
  RUN;
  OPTIONS MERGENOBY=WARN;
%MEND ahal_cn;

%MACRO ahal_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /*APPROXIMATE Highly adaptive LASSO model, selection by AICC, HPGENSELECT*/
  %GetHALDesign(y=&y, vars=&binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors , 
                indata=&indata, outdata=__sltm0017_, drop=TRUE, intdepthlimit=0);
  OPTIONS MERGENOBY=NOWARN;
  DATA __sltm0016_;
   MERGE &indata(KEEP=&Y &weight) __sltm0017_;
  RUN;
  PROC HPGENSELECT DATA=__sltm0016_ TECH=QUANEW NOSTDERR LASSORHO=0.8 LASSOSTEPS=100 NORMALIZE=YES;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y(EVENT='1') = __hal_: / DIST=BINOMIAL LINK=LOGIT;
    SELECTION METHOD=lasso(CHOOSE=AICC STOP=AICC);
    OUTPUT OUT = __sltm0016_(KEEP=p_ahal&SUFF) p = p_ahal&SUFF; 
  RUN;;
  DATA &outdata;
   MERGE &indata __sltm0016_;
  RUN;
  OPTIONS MERGENOBY=WARN;
%MEND ahal_in;

%MACRO ahalb_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /*APPROXIMATE Highly adaptive LASSO model, selection by cross validation over non-exhaustive list of possible lasso parameters*/
  %GetHALDesign(y=&y, vars=&binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors , 
                indata=&indata, outdata=__sltm0017_, drop=FALSE);
  OPTIONS MERGENOBY=NOWARN;
  DATA __sltm0016_;
   MERGE &indata(KEEP=&Y &weight) __sltm0017_;
  RUN;
  PROC GLMSELECT DATA = __sltm0016_ NOPRINT SEED=&seed;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    ODS SELECT NONE;
    MODEL &Y = __hal_: / SELECTION=LASSO(CHOOSE=CVEX STEPS=100)  CVMETHOD=RANDOM(10);
    OUTPUT OUT =__sltm0016_(KEEP=p_ahalb&SUFF) PRED=p_ahalb&SUFF;
  RUN;
  DATA &outdata;
   MERGE &indata __sltm0016_;
  RUN;
  OPTIONS MERGENOBY=WARN;
%MEND ahalb_cn;

%MACRO ahalb_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  %__SLwarning(%str(aHALb does not resepect the 0/1 probability space and should be used with extreme caution (Try using the 'ahal' learner)));
  /*APPROXIMATE Highly adaptive LASSO model, selection by cross validation over non-exhaustive list of possible lasso parameters
     (NOTE THIS DOES NOT RESPECT THE 0,1 PARAMETER SPACE FOR A CLASSIFICATION PROBLEM!) */
  %ahalb_cn(Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,
               nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight, suff=&suff, seed=&seed);
%MEND ahalb_in;


/********************************************************;
* Part 2: learner functions that call R;
* TODO: re-write code in style of r_sl macros (clearer code)
********************************************************/

%MACRO r_rf_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'randomForest' must be installed));;
  *weights not implemented;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(set.seed(&seed));
  %LET rcodeb = %STR(rfmodf <- randomForest::randomForest%(y=mdata$&Y,x=mdata[-grep(%"&Y|&weight%", names(mdata))], ntree = 1000, nodesize=5, maxnodes=NULL, xtest=rdata[-grep(%"&Y|&weight%", names(rdata))], importance=FALSE, keep.forest = FALSE, na.action = na.omit%));
  %LET rcodec = %STR(p_r_rf&SUFF <- rfmodf$test$predicted);
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_rf&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_rf_cn; 
*%r_rf_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_rf_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'randomForest' must be installed));;
  *weights not implemented;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  /*%LET rcodei = %STR(#library%('randomForest'%));*/
  %LET rcodet = %STR(rdata$&Y = as.factor(rdata$&Y));
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(set.seed(123));
  %LET rcodeb = %STR(rfmodf <- randomForest::randomForest%(y=mdata$&Y,x=mdata[-grep(%"&Y.|&weight%", names(mdata))], ntree = 1000, nodesize=1, maxnodes=NULL, xtest=rdata[-grep(%"&Y|&weight%", names(rdata))], importance=FALSE, keep.forest = FALSE, na.action = na.omit%));
  %LET rcodec = %STR(p_r_rf&SUFF <- rfmodf$test$votes[,2]);
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodet";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_rf&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_rf_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_rf_in(Y=yb,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_mars_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'earth' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(set.seed(&seed));
  %LET rcodeb = %STR(emodf = earth::earth(y=mdata$&Y,x=mdata[,-grep(%"&Y.|&weight%", names(mdata))], nk=max(21, 2 * dim(mdata)[2]), degree=2, penalty=3,nfold=0,ncross=1,minspan=0,endspan=0, pmethod='backward', weights=mdata$&weight));
  %LET rcodec = %STR(p_r_mars&SUFF = as.numeric(predict(emodf, newdata=rdata[,-grep(%"&Y.|&weight%", names(rdata))], type='response')));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_mars&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_mars_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_mars_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_mars_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'earth' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodet = %STR(rdata$&Y = as.factor(rdata$&Y));
  %LET rcodei = %STR(set.seed(&seed));
  %LET rcodeb = %STR(emodf = earth::earth(y=mdata$&Y,x=mdata[,-grep(%"&Y.|&weight%", names(mdata))], glm= list(family=binomial), nk=max(21, 2 * dim(mdata)[2]), degree=2, penalty=3,nfold=0,ncross=1,minspan=0,endspan=0, pmethod='backward', weights=mdata$&weight));
  %LET rcodec = %STR(p_r_mars&SUFF = as.numeric(predict(emodf, newdata=rdata[,-grep(%"&Y.|&weight%", names(rdata))], type='response')));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_mars&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_mars_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_mars_in(Y=yb,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_bart_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'dbarts' must be installed));;
  %__SLnote(%str(This function will likely give a warning about a quoted string being too long. This warning should be safe to ignore.));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(set.seed(&seed));
  %LET rcodeb = %STR(rmod <- 
  dbarts::bart%(y.train=mdata$&Y,x.train=mdata[-grep(%"&Y.|&weight%", names(mdata))], x.test=rdata[-grep(%"&Y.|&weight%", names(rdata))], sigest = NA, sigdf = 3, 
    sigquant = 0.9, k = 2, power = 2, base = 0.95, binaryOffset = 0, 
    ntree = 200, ndpost = 1000, nskip = 100, printevery = 100, 
    keepevery = 1, keeptrainfits = T, usequants = F, numcut = 100, 
    printcutoffs = 0, nthread = 1, keepcall = T, verbose = F, weights=mdata$&weight%)
  );
  %LET rcodec = %STR(p_r_bart&SUFF <- rmod$yhat.test.mean);
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_bart&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_bart_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_bart_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_bart_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'dbarts' must be installed));;
  %__SLnote(%str(This function will likely give a warning about a quoted string being too long. This warning should be safe to ignore.));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(set.seed(&seed));
  %LET rcodeb = %STR(rmod <- 
  dbarts::bart%(y.train=mdata$&Y,x.train=mdata[-grep(%"&Y.|&weight%", names(mdata))], x.test=rdata[-grep(%"&Y.|&weight%", names(rdata))], sigest = NA, sigdf = 3, 
    sigquant = 0.9, k = 2, power = 2, base = 0.95, binaryOffset = 0, 
    ntree = 200, ndpost = 1000, nskip = 100, printevery = 100, 
    keepevery = 1, keeptrainfits = T, usequants = F, numcut = 100, 
    printcutoffs = 0, nthread = 1, keepcall = T, verbose = F, weights=mdata$&weight%)
  );
  %LET rcodec = %STR(p_r_bart&SUFF <- colMeans(stats::pnorm(rmod$yhat.test)));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_bart&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_bart_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_bart_in(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_bagging_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R packages 'ipred' and 'rpart'  must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(set.seed(&seed));
  %LET rcodeb = %STR(rmod <- 
  ipred::ipredbagg%(y=mdata$&Y,X=mdata[-grep(%"&Y.|&weight%", names(mdata))], 
    nbagg = 100, control = rpart::rpart.control(xval = 0, 
    maxsurrogate = 0, minsplit = 20, cp = 0.01, maxdepth = 30, weights=mdata$&weight%))
  );
  %LET rcodec = %STR(p_r_bagging&SUFF <- predict(rmod, newdata = rdata[-grep(%"&Y.|&weight%", names(rdata))], aggregation = %"average%"));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_bagging&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_bagging_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_bagging_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_bagging_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R packages 'ipred' and 'rpart'  must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(set.seed(&seed));
  %LET rcodeb = %STR(rmod <- 
  ipred::ipredbagg%(y=as.factor(mdata$&Y),X=mdata[-grep(%"&Y.|&weight%", names(mdata))], 
    nbagg = 100, control = rpart::rpart.control(xval = 0, 
    maxsurrogate = 0, minsplit = 20, cp = 0.01, maxdepth = 30, weights=mdata$&weight%))
  );
  %LET rcodec = %STR(p_r_bagging&SUFF <- predict(rmod, newdata = rdata[-grep(%"&Y.|&weight%", names(rdata))], type = %"prob%", aggregation = %"average%")[, 2]);
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_bagging&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_bagging_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_bagging_in(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_polymars_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'polspline' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(set.seed(&seed));
  %LET rcodeb = %STR(emodf = polspline::polymars(mdata$&Y,mdata[,-grep(%"&Y.|&weight%", names(mdata))], weights=mdata$&weight));
  %LET rcodec = %STR(p_r_polymars&SUFF = as.numeric(predict(emodf, x=rdata[,-grep(%"&Y.|&weight%", names(rdata))])));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_polymars&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_polymars_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_polymars_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_polymars_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'polspline' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodet = %STR(rdata$&Y = as.factor(rdata$&Y));
  %LET rcodei = %STR(set.seed(&seed));
  %LET rcodeb = %STR(emodf = polspline::polyclass(mdata$&Y,mdata[,-grep(%"&Y.|&weight%", names(mdata))], weight=mdata$&weight));
  %LET rcodec = %STR(p_r_polymars&SUFF = polspline::ppolyclass(cov = rdata[,-grep(%"&Y.|&weight%", names(rdata))], fit = emodf)[,2]);
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_polymars&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_polymars_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_polymars_in(Y=yb,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_boost_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R packages 'xgboost' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * put predictors into r formula;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(X = model.matrix(~. - 1, mdata[-grep(%"&Y.|&weight%", names(mdata))]));
  %LET rcodeib = %STR(newX = model.matrix(~. - 1, rdata[-grep(%"&Y.|&weight%", names(rdata))]));
  %LET rcodeic = %STR(xgmat = xgboost::xgb.DMatrix(data = X, label = mdata$&Y, weight=as.numeric(mdata$&weight)));
  %LET rcodeb = %STR(rmod <- xgboost::xgboost%(data=xgmat, objective = %"reg:linear%", nrounds = 1000,
         max_depth = 4, eta = 0.1, min_child_weight = 10, params = list(),  nthread = 1, verbose = 0, save_period = NULL));
  %LET rcodec = %STR(p_r_boost&SUFF <- predict(rmod, newdata = newX));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodem &rcodei &rcodeib &rcodeic &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeib";PUT "&rcodeic";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_boost&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_boost_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_boost_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_boost_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R packages 'xgboost' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(X = model.matrix(~. - 1, mdata[-grep(%"&Y.|&weight%", names(mdata))]));
  %LET rcodeib = %STR(newX = model.matrix(~. - 1, rdata[-grep(%"&Y.|&weight%", names(rdata))]));
  %LET rcodeic = %STR(xgmat = xgboost::xgb.DMatrix(data = X, label = mdata$&Y, weight=as.numeric(mdata$&weight)));
  %LET rcodeb = %STR(rmod <- xgboost::xgboost%(data=xgmat, objective = %"binary:logistic%", nrounds = 1000,
         max_depth = 4, eta = 0.1, min_child_weight = 10, params = list(),  nthread = 1, verbose = 0, save_period = NULL));
  %LET rcodec = %STR(p_r_boost&SUFF <- predict(rmod, newdata = newX));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodem &rcodei &rcodeib &rcodeic &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeib";PUT "&rcodeic";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_boost&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_boost_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_boost_in(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_svm_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'e1071' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(X = model.matrix(~. - 1, mdata[-grep(%"&Y.|&weight%", names(mdata))]));
  %LET rcodeib = %STR(newX = model.matrix(~. - 1, rdata[-grep(%"&Y.|&weight%", names(rdata))]));
  %LET rcodeb = %STR(rmod <- e1071::svm(y = mdata$&Y, x = X, nu = 0.5, type = %"nu-regression%", 
                    fitted = FALSE, kernel = %"radial%", degree = 3, cost = 1, coef0 = 0));
  %LET rcodec = %STR(p_r_svm&SUFF <- predict(rmod, newdata = rdata[-grep(%"&Y.|&weight%", names(rdata))]));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodem &rcodei &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_svm&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_svm_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_svm_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_svm_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'e1071' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(X = model.matrix(~. - 1, mdata[-grep(%"&Y.|&weight%", names(mdata))]));
  %LET rcodeib = %STR(newX = model.matrix(~. - 1, rdata[-grep(%"&Y.|&weight%", names(rdata))]));
  %LET rcodeb = %STR(rmod <- e1071::svm(y = as.factor(mdata$&Y), x = X, nu = 0.5, type = %"nu-classification%", 
                    fitted = FALSE, probability = TRUE, kernel = %"radial%", degree = 3, cost = 1, coef0 = 0));
  %LET rcodec = %STR(p_r_svm&SUFF <- attr(predict(rmod, newdata = rdata[-grep(%"&Y.|&weight%", names(rdata))], probability = TRUE), %"prob%")[, %"1%"]);
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodem &rcodei &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_svm&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_svm_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_svm_in(Y=x,indata=train, outdata=tdat, binary_predictors=l, ordinal_predictors= , nominal_predictors=,  continuous_predictors=c c2,suff=test);

%MACRO r_gam_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'gam' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET cts = 4;
  %LET deg = 2;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodep = %STR(suppressWarnings(suppressMessages(library(%"gam%"))));
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(set.seed(&seed));
  %LET rcodea0 = %STR(X=mdata[-grep(%"&Y.|&weight%", names(mdata))]);
  %LET rcodea1 = %STR(cts.x = apply(X, 2, function(x) (length(unique(x)) > &cts)));
  %LET rcodea2 = %STR(if (sum(!cts.x) > 0)  f = as.formula(paste(%"&Y~%", paste(paste0(%"gam::s(%", colnames(X[, cts.x, drop = FALSE]), %",%", &deg, %")%"), collapse = %"+%"),  %"+%", paste(colnames(X[, !cts.x, drop = FALSE]), collapse = %"+%"))));
  %LET rcodea3 = %STR(if (sum(!cts.x) == 0) f = as.formula(paste(%"&Y~%", paste(paste0(%"gam::s(%", colnames(X[, cts.x, drop = FALSE]), %",%", &deg, %")%"), collapse = %"+%"))));
  %LET rcodea4 = %STR(if (sum(!cts.x) == length(cts.x)) f = as.formula(paste0(%"&Y~%", paste(colnames(X), collapse = %"+%"))));
  %LET rcodeb = %STR(suppressWarnings(suppressMessages(gmod <- gam::gam(f, data = mdata, family = gaussian(), control = gam::gam.control(maxit = 50, bf.maxit = 50, weights=mdata$&weight)))));
  %LET rcodec = %STR(suppressWarnings(p_r_gam&SUFF <- gam::predict.Gam(gmod, newdata=rdata, type=%"response%")));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodep";PUT "&rcodem";PUT "&rcodei";PUT "&rcodea0";PUT "&rcodea1";PUT "&rcodea2";PUT "&rcodea3";PUT "&rcodea4";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_gam&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_gam_cn; 
*%r_gam_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_gam_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'gam' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET cts = 4;
  %LET deg = 2;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodep = %STR(suppressWarnings(suppressMessages(library(%"gam%"))));
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(set.seed(&seed));
  %LET rcodea0 = %STR(X=mdata[-grep(%"&Y.|&weight%", names(mdata))]);
  %LET rcodea1 = %STR(cts.x = apply(X, 2, function(x) (length(unique(x)) > &cts)));
  %LET rcodea2 = %STR(if (sum(!cts.x) > 0)  f = as.formula(paste(%"&Y~%", paste(paste0(%"gam::s(%", colnames(X[, cts.x, drop = FALSE]), %",%", &deg, %")%"), collapse = %"+%"),  %"+%", paste(colnames(X[, !cts.x, drop = FALSE]), collapse = %"+%"))));
  %LET rcodea3 = %STR(if (sum(!cts.x) == 0) f = as.formula(paste(%"&Y~%", paste(paste0(%"gam::s(%", colnames(X[, cts.x, drop = FALSE]), %",%", &deg, %")%"), collapse = %"+%"))));
  %LET rcodea4 = %STR(if (sum(!cts.x) == length(cts.x)) f = as.formula(paste0(%"&Y~%", paste(colnames(X), collapse = %"+%"))));
  %LET rcodeb = %STR(suppressWarnings(suppressMessages(gmod <- gam::gam(f, data = mdata, family = binomial(), control = gam::gam.control(maxit = 50, bf.maxit = 50, weights=mdata$&weight)))));
  %LET rcodec = %STR(suppressWarnings(p_r_gam&SUFF <- gam::predict.Gam(gmod, newdata=rdata, type=%"response%")));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodep";PUT "&rcodem";PUT "&rcodei";PUT "&rcodea0";PUT "&rcodea1";PUT "&rcodea2";PUT "&rcodea3";PUT "&rcodea4";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_gam&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_gam_in; 
*%r_gam_in(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_lasso_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R packages 'glmnet' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(X = model.matrix(~. - 1, mdata[-grep(%"&Y.|&weight%", names(mdata))]));
  %LET rcodeib = %STR(newX = model.matrix(~. - 1, rdata[-grep(%"&Y.|&weight%", names(rdata))]));
  %LET rcodeic = %STR(useMin=TRUE);
  %LET rcodeb = %STR(rmod <- glmnet::cv.glmnet(x=X, y=mdata$&Y, weight=as.numeric(mdata$&weight), lambda=NULL,
                     family=%"gaussian%", alpha=1, nlambda=100));
  %LET rcodec = %STR(p_r_lasso&SUFF <- as.numeric(predict(rmod, newx = newX, type = %"response%", s = ifelse(useMin, 
        %"lambda.min%", %"lambda.1se%"))));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodem &rcodei &rcodeib &rcodeic &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeib";PUT "&rcodeic";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_lasso&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_lasso_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_lasso_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_lasso_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R packages 'glmnet' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(X = model.matrix(~. - 1, mdata[-grep(%"&Y.|&weight%", names(mdata))]));
  %LET rcodeib = %STR(newX = model.matrix(~. - 1, rdata[-grep(%"&Y.|&weight%", names(rdata))]));
  %LET rcodeic = %STR(useMin=TRUE);
  %LET rcodeb = %STR(rmod <- glmnet::cv.glmnet(x=X, y=mdata$&Y, weight=as.numeric(mdata$&weight), lambda=NULL,
                     family=%"binomial%", alpha=1, nlambda=100));
  %LET rcodec = %STR(p_r_lasso&SUFF <- as.numeric(predict(rmod, newx = newX, type = %"response%", s = ifelse(useMin, 
        %"lambda.min%", %"lambda.1se%"))));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodem &rcodei &rcodeib &rcodeic &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeib";PUT "&rcodeic";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_lasso&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_lasso_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_lasso_in(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_enet_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R packages 'glmnet' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(X = model.matrix(~. - 1, mdata[-grep(%"&Y.|&weight%", names(mdata))]));
  %LET rcodeib = %STR(newX = model.matrix(~. - 1, rdata[-grep(%"&Y.|&weight%", names(rdata))]));
  %LET rcodeic = %STR(useMin=TRUE);
  %LET rcodeb = %STR(rmod <- glmnet::cv.glmnet(x=X, y=mdata$&Y, weight=as.numeric(mdata$&weight), lambda=NULL,
                     family=%"gaussian%", alpha=0.5, nlambda=100));
  %LET rcodec = %STR(p_r_enet&SUFF <- as.numeric(predict(rmod, newx = newX, type = %"response%", s = ifelse(useMin, 
        %"lambda.min%", %"lambda.1se%"))));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodem &rcodei &rcodeib &rcodeic &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeib";PUT "&rcodeic";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_enet&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_enet_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_enet_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_enet_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R packages 'glmnet' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(X = model.matrix(~. - 1, mdata[-grep(%"&Y.|&weight%", names(mdata))]));
  %LET rcodeib = %STR(newX = model.matrix(~. - 1, rdata[-grep(%"&Y.|&weight%", names(rdata))]));
  %LET rcodeic = %STR(useMin=TRUE);
  %LET rcodeb = %STR(rmod <- glmnet::cv.glmnet(x=X, y=mdata$&Y, weight=as.numeric(mdata$&weight), lambda=NULL,
                     family=%"binomial%", alpha=0.5, nlambda=100));
  %LET rcodec = %STR(p_r_enet&SUFF <- as.numeric(predict(rmod, newx = newX, type = %"response%", s = ifelse(useMin, 
        %"lambda.min%", %"lambda.1se%"))));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodem &rcodei &rcodeib &rcodeic &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeib";PUT "&rcodeic";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_enet&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_enet_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_enet_in(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_ridge_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R packages 'glmnet' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(X = model.matrix(~. - 1, mdata[-grep(%"&Y.|&weight%", names(mdata))]));
  %LET rcodeib = %STR(newX = model.matrix(~. - 1, rdata[-grep(%"&Y.|&weight%", names(rdata))]));
  %LET rcodeic = %STR(useMin=TRUE);
  %LET rcodeb = %STR(rmod <- glmnet::cv.glmnet(x=X, y=mdata$&Y, weight=as.numeric(mdata$&weight), lambda=NULL,
                     family=%"gaussian%", alpha=0, nlambda=100));
  %LET rcodec = %STR(p_r_ridge&SUFF <- as.numeric(predict(rmod, newx = newX, type = %"response%", s = ifelse(useMin, 
        %"lambda.min%", %"lambda.1se%"))));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodem &rcodei &rcodeib &rcodeic &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeib";PUT "&rcodeic";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_ridge&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_ridge_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_ridge_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_ridge_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R packages 'glmnet' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(X = model.matrix(~. - 1, mdata[-grep(%"&Y.|&weight%", names(mdata))]));
  %LET rcodeib = %STR(newX = model.matrix(~. - 1, rdata[-grep(%"&Y.|&weight%", names(rdata))]));
  %LET rcodeic = %STR(useMin=TRUE);
  %LET rcodeb = %STR(rmod <- glmnet::cv.glmnet(x=X, y=mdata$&Y, weight=as.numeric(mdata$&weight), lambda=NULL,
                     family=%"binomial%", alpha=0, nlambda=100));
  %LET rcodec = %STR(p_r_ridge&SUFF <- as.numeric(predict(rmod, newx = newX, type = %"response%", s = ifelse(useMin, 
        %"lambda.min%", %"lambda.1se%"))));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodem &rcodei &rcodeib &rcodeic &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeib";PUT "&rcodeic";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_ridge&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_ridge_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_ridge_in(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_rpart_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'rpart' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  DATA _null_;
   FILE rcode;
   PUT 'SUBMIT y w seed/ R;';
   PUT 'mdata = rdata[!is.na(rdata[, "&Y" ]),]';
   PUT 'set.seed(&seed)';
   PUT 'suppressWarnings(suppressMessages(library("rpart")))';
   PUT 'Y = mdata[,"&Y"]';
   PUT 'X = mdata[,-grep(paste0("&y", "|", "&w"), names(mdata))]';
   PUT 'Xfl = rdata[,-grep(paste0("&y", "|", "&w"), names(rdata))]';
   PUT 'W = mdata[,"&w"]';
   PUT 'suppressWarnings(suppressMessages(rmod <- rpart::rpart(Y ~ ., data = data.frame(Y, X), control = rpart::rpart.control(cp = 0.01, minsplit = 20, xval = 0L, maxdepth = 30, minbucket = round(minsplit/3)), method = "anova", weights = W)))';
   PUT 'p_r = predict(rmod, newdata = Xfl)';
   PUT 'ENDSUBMIT;';
  RUN;
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   y = "&y";
   w = "&weight";
   seed = "&seed";
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds(RENAME=(p_r = p_r_rpart&SUFF));
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_rpart_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_rpart_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_rpartprune_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'rpart' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  DATA _null_;
   FILE rcode;
   PUT 'SUBMIT y w seed/ R;';
   PUT 'mdata = rdata[!is.na(rdata[, "&Y" ]),]';
   PUT 'set.seed(&seed)';
   PUT 'suppressWarnings(suppressMessages(library("rpart")))';
   PUT 'Y = mdata[,"&Y"]';
   PUT 'X = mdata[,-grep(paste0("&y", "|", "&w"), names(mdata))]';
   PUT 'Xfl = rdata[,-grep(paste0("&y", "|", "&w"), names(rdata))]';
   PUT 'W = mdata[,"&w"]';
   PUT 'suppressWarnings(suppressMessages(rmod <- rpartprune::rpartprune(Y ~ ., data = data.frame(Y, X), control = rpartprune::rpartprune.control(cp = 0.001, minsplit = 20,  xval = 10, maxdepth = 20, minbucket = 5), method = "class", weights = W)))';
   PUT 'bcp <- rmod$cptable[which.min(rmod$cptable[, "xerror"]), "CP"]';
   PUT 'rmod2 <- rpart::prune(rmod, cp = bcp)';
   PUT 'p_r = predict(rmod2, newdata = Xfl)[,2]';
   PUT 'ENDSUBMIT;';
  RUN;
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   y = "&y";
   w = "&weight";
   seed = "&seed";
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds(RENAME=(p_r = p_r_rpartprune&SUFF));
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_rpartprune_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_rpartprune_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_rpartprune_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'rpart' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  DATA _null_;
   FILE rcode;
   PUT 'SUBMIT y w seed/ R;';
   PUT 'mdata = rdata[!is.na(rdata[, "&Y" ]),]';
   PUT 'set.seed(&seed)';
   PUT 'suppressWarnings(suppressMessages(library("rpart")))';
   PUT 'Y = mdata[,"&Y"]';
   PUT 'X = mdata[,-grep(paste0("&y", "|", "&w"), names(mdata))]';
   PUT 'Xfl = rdata[,-grep(paste0("&y", "|", "&w"), names(rdata))]';
   PUT 'W = mdata[,"&w"]';
   PUT 'suppressWarnings(suppressMessages(rmod <- rpartprune::rpartprune(Y ~ ., data = data.frame(Y, X), control = rpartprune::rpartprune.control(cp = 0.001, minsplit = 20, xval = 10, maxdepth = 20, minbucket = 5), method = "anova", weights = W)))';
   PUT 'bcp <- rmod$cptable[which.min(rmod$cptable[, "xerror"]), "CP"]';
   PUT 'rmod2 <- rpart::prune(rmod, cp = bcp)';
   PUT 'p_r = predict(rmod2, newdata = Xfl)';
   PUT 'ENDSUBMIT;';
  RUN;
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   y = "&y";
   w = "&weight";
   seed = "&seed";
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds(RENAME=(p_r = p_r_rpartprune&SUFF));
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_rpartprune_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_rpartprune_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_sl_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'SuperLearner' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  DATA _null_;
   FILE rcode;
   PUT 'SUBMIT y w seed/ R;';
   PUT 'mdata = rdata[!is.na(rdata[, "&Y" ]),]';
   PUT 'set.seed(&seed)';
   PUT 'suppressWarnings(suppressMessages(library("SuperLearner")))';
   PUT 'lib = c("SL.earth", "SL.glmnet", "SL.ranger", "SL.speedglm", "SL.dbarts")';
   PUT 'Y = mdata[,"&Y"]';
   PUT 'X = mdata[,-grep(paste0("&y", "|", "&w"), names(mdata))]';
   PUT 'Xfl = rdata[,-grep(paste0("&y", "|", "&w"), names(rdata))]';
   PUT 'W = mdata[,"&w"]';
   PUT 'suppressWarnings(suppressMessages(rmod <- SuperLearner(Y=Y, X=X, newX=Xfl, SL.library = lib, family=gaussian(), obsWeights = W)))';
   PUT 'p_r = predict(rmod)$pred[,1]';
   PUT 'ENDSUBMIT;';
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   y = "&y";
   w = "&weight";
   seed = "&seed";
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds(RENAME=(p_r = p_r_sl&SUFF));
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_sl_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_sl_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_sl_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'SuperLearner' must be installed));;
  DATA __sltm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  DATA _null_;
   FILE rcode;
   PUT 'SUBMIT y w seed/ R;';
   PUT 'mdata = rdata[!is.na(rdata[, "&Y" ]),]';
   PUT 'set.seed(&seed)';
   PUT 'suppressWarnings(suppressMessages(library("SuperLearner")))';
   PUT 'lib = c("SL.earth", "SL.glmnet", "SL.ranger", "SL.speedglm", "SL.dbarts")';
   PUT 'Y = mdata[,"&Y"]';
   PUT 'X = mdata[,-grep(paste0("&y", "|", "&w"), names(mdata))]';
   PUT 'Xfl = rdata[,-grep(paste0("&y", "|", "&w"), names(rdata))]';
   PUT 'W = mdata[,"&w"]';
   PUT 'suppressWarnings(suppressMessages(rmod <- SuperLearner(Y=Y, X=X, newX=Xfl, SL.library = lib, family=binomial(), obsWeights = W)))';
   PUT 'p_r = predict(rmod)$pred[,1]';
   PUT 'ENDSUBMIT;';
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   y = "&y";
   w = "&weight";
   seed = "&seed";
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds(RENAME=(p_r = p_r_sl&SUFF));
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_sl_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_sl_in(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_bkmr_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'bkmr' must be installed));;
  DATA __SLtm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  DATA _null_;
   FILE rcode;
   PUT 'SUBMIT y w seed/ R;';
   PUT 'mdata = rdata[!is.na(rdata[, "&Y" ]),]';
   PUT 'set.seed(&seed)';
   PUT 'suppressWarnings(suppressMessages(library("bkmr")))';
   PUT 'Y = mdata[,"&Y"]';
   PUT 'X = mdata[,-grep(paste0("&y", "|", "&w"), names(mdata))]';
   PUT 'Xfl = rdata[,-grep(paste0("&y", "|", "&w"), names(rdata))]';
   *PUT 'W = mdata[,"&w"]';
   PUT 'suppressWarnings(suppressMessages(rmod <- bkmr::kmbayes(y=Y,Z=X, iter = 1000, family = "gaussian", verbose = FALSE, )))';
   PUT 'pMat <- bkmr::SamplePred(rmod, Znew=Xfl, Xnew = cbind(0), type="response")';
   PUT 'p_r <- as.numeric(apply(pMat, 2, mean))';
   PUT 'ENDSUBMIT;';
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__SLtm0016_", "rdata");
   y = "&y";
   w = "&weight";
   seed = "&seed";
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds(RENAME=(p_r = p_r_bkmr&SUFF));
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_bkmr_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_bkmr_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_gwqs_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'SLmix' must be installed));;
  DATA __SLtm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  DATA _null_;
   FILE rcode;
   PUT 'SUBMIT y w seed/ R;';
   PUT 'mdata = rdata[!is.na(rdata[, "&Y" ]),]';
   PUT 'set.seed(&seed)';
   PUT 'suppressWarnings(suppressMessages(library("SLmix")))';
   PUT 'Y = mdata[,"&Y"]';
   PUT 'X = mdata[,-grep(paste0("&y", "|", "&w"), names(mdata))]';
   PUT 'nm = names(X)';
   PUT 'Xfl = rdata[,-grep(paste0("&y", "|", "&w"), names(rdata))]';
   PUT 'X$Y = Y';
   *PUT 'W = mdata[,"&w"]';
   PUT 'suppressWarnings(suppressMessages(rmod <- ml.gwqs(Y ~ NULL, mix_name=nm, data=X, q = 4, b=100, b1_pos=TRUE, family="gaussian")))';
   PUT 'p_r <- predict(fit=rmod, mix_name=nm, newdata=Xfl)';
   PUT 'ENDSUBMIT;';
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__SLtm0016_", "rdata");
   y = "&y";
   w = "&weight";
   seed = "&seed";
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds(RENAME=(p_r = p_r_gwqs&SUFF));
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_gwqs_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_gwqs_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_bkmr_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'bkmr' must be installed));;
  DATA __SLtm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  DATA _null_;
   FILE rcode;
   PUT 'SUBMIT y w seed/ R;';
   PUT 'mdata = rdata[!is.na(rdata[, "&Y" ]),]';
   PUT 'set.seed(&seed)';
   PUT 'suppressWarnings(suppressMessages(library("bkmr")))';
   PUT 'Y = mdata[,"&Y"]';
   PUT 'X = mdata[,-grep(paste0("&y", "|", "&w"), names(mdata))]';
   PUT 'Xfl = rdata[,-grep(paste0("&y", "|", "&w"), names(rdata))]';
   *PUT 'W = mdata[,"&w"]';
   PUT 'suppressWarnings(suppressMessages(rmod <- bkmr::kmbayes(y=Y,Z=X, iter = 1000, family = "binomial", verbose = FALSE, )))';
   PUT 'pMat <- bkmr::SamplePred(rmod, Znew=Xfl, Xnew = cbind(0), type="response")';
   PUT 'p_r <- as.numeric(apply(pMat, 2, mean))';
   PUT 'ENDSUBMIT;';
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__SLtm0016_", "rdata");
   y = "&y";
   w = "&weight";
   seed = "&seed";
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds(RENAME=(p_r = p_r_bkmr&SUFF));
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_bkmr_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_bkmr_in(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

%MACRO r_gwqs_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
  %__SLnote(%str(R package 'SLmix' must be installed));;
  DATA __SLtm0016_;
   SET &indata;
   FORMAT &Y;
   %IF &weight= %THEN %DO;
     %LET weight=wwwwww;
     wwwwww=1;
   %END;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &weight;
  RUN;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  DATA _null_;
   FILE rcode;
   PUT 'SUBMIT y w seed/ R;';
   PUT 'mdata = rdata[!is.na(rdata[, "&Y" ]),]';
   PUT 'set.seed(&seed)';
   PUT 'suppressWarnings(suppressMessages(library("SLmix")))';
   PUT 'Y = mdata[,"&Y"]';
   PUT 'X = mdata[,-grep(paste0("&y", "|", "&w"), names(mdata))]';
   PUT 'nm = names(X)';
   PUT 'Xfl = rdata[,-grep(paste0("&y", "|", "&w"), names(rdata))]';
   PUT 'X$Y = Y';
   *PUT 'W = mdata[,"&w"]';
   PUT 'suppressWarnings(suppressMessages(rmod <- ml.gwqs(Y ~ NULL, mix_name=nm, data=X, q = 4, b=100, b1_pos=TRUE, family="binomial")))';
   PUT 'p_r <- predict(fit=rmod, mix_name=nm, newdata=Xfl)';
   PUT 'ENDSUBMIT;';
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__SLtm0016_", "rdata");
   y = "&y";
   w = "&weight";
   seed = "&seed";
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds(RENAME=(p_r = p_r_gwqs&SUFF));
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_gwqs_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_gwqs_in(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);

********************************************************;
* Part 3: main functions;
********************************************************;

%MACRO _cvsetup(Y, id, indata, outdata, folds);
/*
 expand input dataset for cross validation
*/
%__SLnote(_cvsetup);
 DATA __sltm005_;
  SET &indata;
  __seqid__ = _n_;
 
 /*PROC SORT DATA = __sltm005_; BY __rnS; RUN;*/
  %IF %__TrueCheck(&shuffle) %THEN %DO;
    PROC SQL NOPRINT;
     CREATE TABLE &outdata(DROP=__rnS) AS SELECT *, RANUNI(&SLseed) AS __rnS FROM __sltm005_ ORDER BY __rnS;QUIT;
    %IF &ID ^= %THEN %DO;
    /* caution: untested */
     PROC SQL NOPRINT;
      CREATE TABLE &outdata(DROP=__rnS) AS SELECT *, MAX(RANUNI(&SLseed)) AS __rnS FROM __sltm005_ GROUP BY &id ORDER BY __rnS ;QUIT;
    %END;
  %END;
  %IF %__FalseCheck(&shuffle) %THEN %DO;
    PROC SQL NOPRINT; CREATE TABLE &outdata AS SELECT * FROM __sltm005_;QUIT;
  %END;
 DATA &outdata;
  SET &outdata;
  %IF &ID =  %THEN __cvid__ = _n_;;
  %IF &ID ^= %THEN %DO; 
    RETAIN __cvid__ __lid__;
    IF _n_=1 THEN __cvid__ = 0;
    IF &id^=__lid__ THEN __cvid__ = __cvid__ + 1;
    __lid__ = &id;
    DROP __lid__;
  %END;
  ARRAY __CV[&folds];
  ARRAY &y.__CV__[&folds];
  DO _k = 1 TO &FOLDS;
  /* untested: allow fold-maintenance of clusters identified by 'id' */
   IF &SLSampSize/&folds*(_k-1) < __cvid__ <= &SLSampSize/&folds*_k THEN __CV[_k] = 0;
   ELSE __CV[_k] = 1;
   IF __CV[_k] = 1 THEN &y.__CV__[_k] = &Y;
   IF __CV[_k] = 0 THEN __CVfold=_k;
   %IF %EVAL(&FOLDS=1) %THEN IF __CV[_k] = 0 THEN &y.__CV__[_k] = &Y;; * single fold will yield un-cross validated estimate;
  END;
  DROP _k;
%MEND _cvsetup;

%MACRO _pred_setup(Y, intvars, indata, outdata, preddata, insample);
  /* 
   a) combine training and testing data;
   b) expand input dataset to estimate counterfactual distributions
  */
  %__SLnote(_pred_setup);
  %LOCAL i_i __intvar __int __fullints;
  %IF %__TrueCheck(&insample) %THEN %DO;
    DATA &outdata;
      SET &indata;
      ARRAY __CV[&folds];
      __train = 1;
      __int=.o; *observed;
      OUTPUT;
      %IF %SCAN(&intvars,  %EVAL(1))~= %THEN %DO; 
        ARRAY &y.__CV__[&folds];
        *intervention variables are specified;
        %LET __int = 1;
        %LET __fullints = %str(0 1);
        %DO %WHILE(%SCAN(&__fullints, &__int)^=);
          *loop over interventions;
          __train = 0;
          __int=%SCAN(&__fullints, &__int);
          %LET i_i = 1;
          %DO %WHILE(%SCAN(&intvars,  %EVAL(&i_i))~=);
            %LET __intvar = %SCAN(&intvars,  %EVAL(&i_i));
            &__intvar = __int;
          %LET i_i = %EVAL(1+&i_i);
          %END;
          &Y = .; *set to missing so that this will not contribute to model fit;
          %IF %EVAL(&FOLDS>1) %THEN %DO;
            DO k = 1 TO &FOLDS;
              &y.__CV__[k] = .; *set to missing so that this will not contribute to model fit;
            END;       
          %END;
          DROP k;
          OUTPUT;
          %LET __int = %EVAL(&__int + 1);
        %END;
      %END;*intvars;
    RUN;
  %END;
  %IF %__FalseCheck(&insample) %THEN %DO;
    * making predictions in a test set;
    DATA __sltm0014_;
      SET &preddata;
      __cvid__ = _n_;
      _&Y=&Y; *save values for comparison, if available (will give a warning/note if this is not present);
      &Y = .;
    RUN;
    DATA &outdata;
      SET &indata (IN=ina) __sltm0014_(IN=inb);
      ARRAY &y.__CV__[&folds];
      IF ina THEN DO; 
          __int=.o; *observed;
          __train = 1;
          __intgroup = "Training set           ";
      END;
      IF inb THEN DO;
        __train = 0;
        __int=.t; *testing;
        __intgroup = "Testing/validation set ";
      END;
      OUTPUT;
      %IF %SCAN(&intvars,  %EVAL(1))~= %THEN %DO; 
        *intervention variables are specified;
        %LET __int = 1;
        %LET __fullints = %str(0 1);
        %DO %WHILE(%SCAN(&__fullints, &__int)^=);
          *loop over interventions;
          __train = 0;
          __int=%SCAN(&__fullints, &__int);
          %LET i_i = 1;
          %DO %WHILE(%SCAN(&intvars,  %EVAL(&i_i))~=);
            %LET __intvar = %SCAN(&intvars,  %EVAL(&i_i));
            *&intvar = __int;
            &__intvar = __int;
          %LET i_i = %EVAL(1+&i_i);
          %END;
          &Y = .; *set to missing so that this will not contribute to model fit;
          %IF %EVAL(&FOLDS>1) %THEN %DO;
            DO k = 1 TO &FOLDS;
              &y.__CV__[k] = .; *set to missing so that this will not contribute to model fit;
            END;       
          %END;
          DROP k;
          OUTPUT;
          %LET __int = %EVAL(&__int + 1);
        %END;
      %END;*intvars;
    RUN;
  %END;
%MEND _pred_setup;
*%LET folds = 5;
*%_pred_setup(Y=y, intvars=x1 x2, indata=__sltm0013_, outdata=__sltm001_, preddata=, insample=true);

%MACRO _selectlearnersBERNOULLI(
             library=,
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);

 %__SLnote(_selectlearnersBERNOULLI);
  %LOCAL l_l call;
  %LET l_l = 1;
  %DO %WHILE(%SCAN(&library, &l_l)~=);
    %LET call = %SCAN(&library, &l_l);
    %IF %__Truecheck(&printlearner) %THEN %PUT &call;
    %&call._in(Y=&Y,indata=&indata,outdata=&outdata,binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&SLseed);
    %IF %EVAL(&syserr>6) %THEN %DO; %PUT Errors occurred in super learner; DATA &outdata; SET &OUTDATA; p_&call&suff = .m; RUN;%END;
    %LET l_l = %EVAL(&l_l + 1);
  %END;

%MEND _selectlearnersBERNOULLI;

%MACRO _selectlearnersGAUSSIAN(
             library=,
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);

 %__SLnote(_selectlearnersGAUSSIAN);
  %LOCAL l_l call;
  %LET l_l = 1;
  %DO %WHILE(%SCAN(&library, &l_l)~=);
    %LET call = %SCAN(&library, &l_l);
    %IF %__Truecheck(&printlearner) %THEN %PUT &call;
    %&call._cn(Y=&Y,indata=&indata,outdata=&outdata,binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&SLseed);
    %IF %EVAL(&syserr>6) %THEN %DO; %PUT Errors occurred in super learner; DATA &outdata; SET &OUTDATA; p_&call&suff = .m; RUN;%END;
    %LET l_l = %EVAL(&l_l + 1);
  %END;

%MEND _selectlearnersGAUSSIAN;

%MACRO _selectlearnersstratBERNOULLI(
             library=,
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);

 %__SLnote(_selectlearnersstratBERNOULLI);
  %LOCAL l_l call;
  %LET l_l = 1;
  %DO %WHILE(%SCAN(&library, &l_l)~=);
    %LET call = %SCAN(&library, &l_l);
    %IF %__Truecheck(&printlearner) %THEN %PUT &call;
    %&call._in(Y=&Y,indata=&indata(WHERE=(%SCAN(&INTVARS, 1)=1)),outdata=&outdata.1,binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&SLseed);
    %IF %EVAL(&syserr>6) %THEN %DO; %PUT Errors occurred in super learner; DATA &outdata; SET &OUTDATA; p_&call&suff = .m; RUN;%END;
    %&call._in(Y=&Y,indata=&indata(WHERE=(%SCAN(&INTVARS, 1)=0)),outdata=&outdata.0,binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&SLseed);
    %IF %EVAL(&syserr>6) %THEN %DO; %PUT Errors occurred in super learner; DATA &outdata; SET &OUTDATA; p_&call&suff = .m; RUN;%END;
    DATA &outdata; SET &outdata.0 &outdata.1; RUN;
    %LET l_l = %EVAL(&l_l + 1);
  %END;
%MEND _selectlearnersstratBERNOULLI;

%MACRO _selectlearnersstratGAUSSIAN(
             library=,
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 
  %__SLnote(_selectlearnersstratGAUSSIAN);
  %LOCAL l_l call;
  %LET l_l = 1;
  %DO %WHILE(%SCAN(&library, &l_l)~=);
    %LET call = %SCAN(&library, &l_l);
    %IF %__Truecheck(&printlearner) %THEN %PUT &call;
    %&call._cn(Y=&Y,indata=&indata(WHERE=(%SCAN(&INTVARS, 1)=1)),outdata=&outdata.1,binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&SLseed);
    %IF %EVAL(&syserr>6) %THEN %DO; %PUT Errors occurred in super learner; DATA &outdata; SET &OUTDATA; p_&call&suff = .m; RUN;%END;
    %&call._cn(Y=&Y,indata=&indata(WHERE=(%SCAN(&INTVARS, 1)=0)),outdata=&outdata.0,binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&SLseed);
    %IF %EVAL(&syserr>6) %THEN %DO; %PUT Errors occurred in super learner; DATA &outdata; SET &OUTDATA; p_&call&suff = .m; RUN;%END;
    DATA &outdata; SET &outdata.0 &outdata.1; RUN;
    %LET l_l = %EVAL(&l_l + 1);
  %END;
%MEND _selectlearnersstratGAUSSIAN;

%MACRO _getcvpredsBERNOULLI(Y=, indata=, outdata=, library=, folds=, weight=, id=, seed=);
  /* create cross validated predictions using members of the super learner library*/
  %LOCAL k_k;
  %__SLnote(_getcvpreds: getting overall and cross-validated predictions of &Y);
  OPTIONS NOSYNTAXCHECK;
  *first get overall_fit;
  %IF %__TrueCheck(&trtstrat) %THEN %DO;
    %_selectlearnersstratBERNOULLI(
               library=&library,
               Y=&Y,
               indata=&indata, 
               outdata=&indata, 
               binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,
               seed=&seed,
               weight=&weight,
               id=&id,
               suff=_full
    );
  %END;
  %IF %__FalseCheck(&trtstrat) %THEN %DO;
    %_selectlearnersBERNOULLI(
               library=&library,
               Y=&Y,
               indata=&indata, 
               outdata=&indata, 
               binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,
               seed=&seed,
               weight=&weight,
               id=&id,
               suff=_full
    );
  %END;
  %IF %__TrueCheck(&timer) %THEN %DO;
    %LOCAL runtime expectime;
    DATA __SLinttime; SET __Sltime;
      end = time();
      duration = (end-start)/60;
      expectime = duration*&folds;
    DATA _NULL_; SET __SLinttime; CALL SYMPUT("runtime", PUT(duration, 10.3));CALL SYMPUT("expectime", PUT(expectime, 10.0));
    PROC SQL NOPRINT; DROP TABLE __SLinttime; QUIT;
    %IF %SYSEVALF(&expectime>1) %THEN %PUT %str(Time to fit all learners to training data: %TRIM(&runtime) minutes. Expected time remaining: %TRIM(&expectime) minutes);;
  %END;
  %__SLnote(Getting CV-fold specific predictions in full data from each learner); 
  %LET k_k=0;
  %DO %WHILE (&k_k < &folds);
    %LET k_k = %EVAL(&k_k + 1);
    %IF %__truecheck(&printfolds) %THEN %PUT Fold &k_k of &folds;;
    %IF %__TrueCheck(&trtstrat) %THEN %DO;
      %_selectlearnersstratBERNOULLI(
               library=&library,
               Y=&y.__CV__&k_k,
               indata=&indata, 
               outdata=&indata, 
               binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,
               seed=&seed,
               weight=&weight,
               id=&id,
               suff=&k_k      );
    %END;
    %IF %__FalseCheck(&trtstrat) %THEN %DO;
      %_selectlearnersBERNOULLI(
               library=&library,
               Y=&y.__CV__&k_k,
               indata=&indata, 
               outdata=&indata, 
               binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,
               seed=&seed,
               weight=&weight,
               id=&id,
               suff=&k_k
      );
    %END;
    OPTIONS SYNTAXCHECK;
  %END;
  %IF &OUTDATA ^= &indata %THEN %DO;
    DATA &outdata;
      SET &indata;
    RUN;
  %END;
%MEND _getcvpredsBERNOULLI;
*%LET binary_predictors = x l;
*%_getcvpredsBERNOULLI(Y=z,indata=__sltm001_, outdata=test_getcvpreds, library= logit rf, folds=3);

%MACRO _getcvpredsGAUSSIAN(Y=,indata=, outdata=, library=, folds=, weight=, id=, seed=);
  /* create cross validated predictions using members of the super learner library*/
  %LOCAL k_k;
  %__SLnote(_getcvpreds);
  *first get overall_fit- a convex weighted combination of the predicted values from these fits will be used for the superleaner predictions;
  %__SLnote(Getting predictions in full data from each learner);
  %IF %__TrueCheck(&trtstrat) %THEN %DO;
    %_selectlearnersstratGAUSSIAN(
               library=&library,
               Y=&Y,
               indata=&indata, 
               outdata=&indata, 
               binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,
               seed=&seed,
               weight=&weight,
               id=&id,
               suff=_full
    );
  %END;
  %IF %__FalseCheck(&trtstrat) %THEN %DO;
    %_selectlearnersGAUSSIAN(
               library=&library,
               Y=&Y,
               indata=&indata, 
               outdata=&indata, 
               binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,
               seed=&seed,
               weight=&weight,
               id=&id,
               suff=_full
    );
  %END;
  %IF %__TrueCheck(&timer) %THEN %DO;
    %LOCAL runtime expectime;
    DATA __SLinttime; SET __Sltime;
      end = time();
      duration = (end-start)/60;
      expectime = duration*&folds;
    DATA _NULL_; SET __SLinttime; CALL SYMPUT("runtime", PUT(duration, 10.3));CALL SYMPUT("expectime", PUT(expectime, 10.0));
    PROC SQL NOPRINT; DROP TABLE __SLinttime; QUIT;
    %IF %SYSEVALF(&expectime>1) %THEN %PUT %str(Time to fit all learners to training data: %TRIM(&runtime) minutes. Expected time remaining: %TRIM(&expectime) minutes);;
  %END;
  %__SLnote(Getting CV-fold specific predictions in full data from each learner); 
  %LET k_k=0;
  %DO %WHILE (&k_k < &folds);
    %LET k_k = %EVAL(&k_k + 1);
    %IF %__truecheck(&printfolds) %THEN %PUT Fold &k_k of &folds;;
    %IF %__TrueCheck(&trtstrat) %THEN %DO;
      %_selectlearnersstratGAUSSIAN(
               library=&library,
               Y=&y.__CV__&k_k,
               indata=&indata, 
               outdata=&indata, 
               binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,
               seed=&seed,
               weight=&weight,
               id=&id,
               suff=&k_k
      );
    %END;
    %IF %__FalseCheck(&trtstrat) %THEN %DO;
      %_selectlearnersGAUSSIAN(
               library=&library,
               Y=&y.__CV__&k_k,
               indata=&indata, 
               outdata=&indata, 
               binary_predictors=&binary_predictors,ordinal_predictors=&ordinal_predictors,nominal_predictors=&nominal_predictors,continuous_predictors=&continuous_predictors,
               seed=&seed,
               weight=&weight,
               id=&id,
               suff=&k_k
      );
    %END;
  %END;
  DATA &outdata;
   SET &indata;
  RUN;
%MEND _getcvpredsGAUSSIAN;
*%LET binary_predictors = x l;
*%_getcvpredsBERNOULLI(Y=z,indata=__sltm001_, outdata=test_getcvpreds, library= logit rf, folds=3);

%MACRO _libcount(library);
  %LOCAL l_l ;
  %LET l_l = 1;
 %DO %WHILE(%SCAN(&library,  %EVAL(&l_l))^=);
   %LET l_l = %EVAL(&l_l+1);
 %END;
 %LET l_l = %EVAL(&l_l-1);
 &l_l
%MEND _libcount;

%MACRO __RENAMEVARS(Y=, library=, suff=);
  /* give library specific predictions standard variable names
     to facilitate proc optmodel statements
  */
  %__SLnote(__RENAMEVARS);
  %LOCAL l_l ;
  %LET l_l = 1;
  RENAME 
  %DO %WHILE(%SCAN(&library, &l_l)^=);
    p_%SCAN(&library, &l_l)&SUFF =  __v&l_l
    %LET l_l = %EVAL(1+&l_l);
  %END;;
%MEND __RENAMEVARS;

%MACRO __unRENAMEVARS(Y=, library=, suff=);
  /* reverses __renamevars macro
  */
  %__SLnote(__unRENAMEVARS);
  %LOCAL l_l ;
  %LET l_l = 1;
  RENAME 
  %DO %WHILE(%SCAN(&library, &l_l)^=);
    __v&l_l = p_%SCAN(&library, &l_l)&SUFF
    %LET l_l = %EVAL(1+&l_l);
  %END;;
%MEND __unRENAMEVARS;

%MACRO __RENAMEcoefs(library=, suff=);
 /* give library specific predictions standard variable names
    to facilitate proc optmodel statements
 */
%__SLnote(__RENAMEcoefs);
 %LOCAL l_l return;
 %LET l_l = 1;
 %LET return = ;
 RENAME
 %DO %WHILE(%SCAN(&library, &l_l)^=);
    __slcoef_&l_l = __slcoef_%SCAN(&library, &l_l)&SUFF
  %LET l_l = %EVAL(1+&l_l);
 %END;;
%MEND __RENAMEcoefs;

%MACRO __RENAMEADAPTcoefs(library=, suff=);
 /* give library specific predictions standard variable names
    to facilitate proc optmodel statements
 */
%__SLnote(__RENAMEADAPTcoefs);
  %LOCAL l_l ;
  %LET l_l = 1;
  %DO %WHILE(%SCAN(&library, &l_l)^=);
     IF UPCASE(learner) = "__V&l_l" THEN learner = "__slcoef_%SCAN(&library, &l_l)&SUFF";
   %LET l_l = %EVAL(1+&l_l);
  %END;
%MEND __RENAMEADAPTcoefs;

%MACRO _get_coef(indata=, Y=, library=, outcoef=, outrisk=, suff=, weight=, method=CCLS, debug=FALSE, seed=) / MINOPERATOR MINDELIMITER=' ';
 /*
  Get super learner coefficients
  * getting superlearner coefficients from (POSSIBLY)constrained optimization; (&outcoef)
  * optmodel can constrain individual coefficieints to [0,1] as well as the overall sum to [1];
  * want the weighted combination of the predictors in the library that produces the lowest overall loss function value (risk)
  * this step will calculate overall expected loss for each learner in the library, as well (&outrisk)
 */
 %__SLnote(_get_coef);
  *temporarily rename variables for OPTMODEL;
  DATA __sltm004_; 
   SET &inDATa (WHERE =(__int=.o AND &Y > .z AND __train=1));
   %__RENAMEVARS(Y=&Y,library=&library,suff=_z);
  RUN;
  DATA _NULL_; SET __sltm004_ END=__eof; IF __eof THEN CALL SYMPUT('SLNumObs', PUT(_N_, BEST9.));RUN;
  %__SLnote(total observations/IDs used to calculate risk: %TRIM(&SLNumObs).);
  
  %LET libcount =  %_LIBCOUNT(library=&library);
  %IF %__TrueCheck(&verbose) %THEN %DO;  ODS SELECT ALL;%END;
  %IF (&method IN( NNLOGLIK CCLOGLIK LOGLIK NNLS CCLS OLS NNRIDGE CCRIDGE RIDGE NNLASSO CCLASSO LASSO NNLAE CCLAE LAE)) %THEN %DO;
    *optimization using proc optmodel -good general purpose for obs < 500k;
    PROC OPTMODEL;
      %IF %__TrueCheck(&verbose) %THEN TITLE "OPTMODEL procedure: SL coefficient estimation";;
      SET OBS;
      SET LIB = 1..&LIBCOUNT;
      NUMBER __Y{OBS};
      %IF &weight= %THEN NUMBER __weight{OBS} = 1;;
      %IF &weight^= %THEN %DO;
        NUMBER __weight{OBS};;
      READ DATA __sltm004_(KEEP=&weight) INTO OBS=[_N_] __weight=COL("&weight");
      %END;
      NUMBER LIBMEM{OBS,LIB};
      READ DATA __sltm004_(KEEP=&Y) INTO OBS=[_N_] __y=COL("&Y");
      READ DATA __sltm004_(KEEP=__V:) INTO OBS=[_N_] {b in LIB} < libmem[_N_, b]=COL("__v"||b) >;
      *method &method;
      %IF (&method IN(CCLS NNLS NNLOGLIK CCLOGLIK NNLAE CCLAE CCRIDGE NNRIDGE AUC)) %THEN %DO;
        *positively bounded coefficients;
        VAR coef{LIB} >= 0 INIT %EVAL(1/&LIBCOUNT);;
      %END;
      %IF (&method IN(OLS LOGLIK LAE RIDGE)) %THEN %DO;
        *unbounded coefficients;
        VAR coef{LIB} INIT %EVAL(1/&LIBCOUNT);;
      %END;
      %IF (&method IN (CCLS CCLOGLIK CCLAE CCRIDGE AUC)) %THEN %DO;
        *convexity constraint;
        CON t: SUM{i in LIB } coef[i] = 1.0;; 
      %END;
      %IF (&method IN (NNLAE CCLAE LAE)) %THEN %DO;
        *l1 loss function;
        *%__SLWarning(%STR(Method &method - L1 Loss function- is experimental. Use caution.));
        IMPVAR sl_pred{i IN OBS} = SUM{j in LIB} coef[j]*libmem[i,j] ;
        * get risk for each algorithm;
        IMPVAR riskl{j in LIB} = 1/&SLNumObs * SUM{i in OBS}  ABS(__y[i] - libmem[i,j]);
        * minimize the cross validated risk ;
        VAR rabs{OBS} >=0;
        CON rup{i IN OBS}:   rabs[i] >=  (__y[i] - sl_pred[i])*__weight[i];
        CON rdown{i IN OBS}: rabs[i] >= -(__y[i] - sl_pred[i])*__weight[i];
        MIN risk = 1/&SLNumObs * SUM{i IN OBS} rabs[i];
        SOLVE WITH nlp;
      %END;
      %IF (&method IN (NNLS CCLS OLS RIDGE CCRIDGE NNRIDGE)) %THEN %DO;
        *l2 loss function;
        IMPVAR sl_pred{i IN OBS} = SUM{j in LIB} coef[j]*libmem[i,j] ;
        * get risk for each algorithm;
        IMPVAR riskl{j in LIB} = 1/&SLNumObs * SUM{i in OBS}  __weight[i]*(__y[i] - libmem[i,j])**2;
        * minimize the cross validated risk ;
        MIN risk = %IF (&METHOD IN (RIDGE CCRIDGE NNRIDGE)) %THEN &slridgepen *1/(&SLSampSize)*(SUM{j in LIB} coef[j]**2) + ; 1/&SLSampSize * SUM{i IN OBS} __weight[i]*(__y[i] - sl_pred[i])**2 ;
        SOLVE WITH qp;
      %END;
      %IF (&method IN(NNLOGLIK CCLOGLIK LOGLIK)) %THEN %DO;
        *negative of the binomial likelihood;
        IMPVAR sl_pred{i IN OBS} = EXPIT(SUM{j in LIB} coef[j]*LOGITBOUND(libmem[i,j], &TRIMBOUND, 1-&TRIMBOUND)) ; *v 0.31+;
        * get risk for each algorithm;
        IMPVAR riskl{j in LIB} = -1/&SLNumObs * SUM{i in OBS} __weight[i]*((__y[i]*LOGBOUND(libmem[i,j], &TRIMBOUND, 1-&TRIMBOUND) + 
                                              (1-__y[i])*LOGBOUND(1-libmem[i,j], &TRIMBOUND, 1-&TRIMBOUND)));
        * minimize the cross validated risk ;
        MIN risk = -1/&SLNumObs * SUM{i IN OBS} __weight[i]*((__y[i]*LOGBOUND(sl_pred[i], &TRIMBOUND, 1-&TRIMBOUND) + 
                                                (1-__y[i])*LOGBOUND(1-sl_pred[i], &TRIMBOUND, 1-&TRIMBOUND)));
        SOLVE WITH nlp;
      %END;
      *discrete super learner;
      NUMBER idx;
      idx = 1;
      DO WHILE(riskl[idx]^=(MIN{j IN LIB} riskl[j])); idx = idx+1; END;
      IMPVAR dsl_pred {i in OBS} = libmem[i,idx];
     
      %IF (&method IN(AUC)) %THEN %DO;
        *rank loss function (maximizing the area under the curve);
        IMPVAR sl_pred{i IN OBS} = SUM{j in LIB} coef[j]*libmem[i,j] ;
        IMPVAR riskl{j in LIB} =  1-AUCL(j, coef, __y, libmem);
        MIN risk = 1-AUC(coef, __y, libmem);
        SOLVE WITH NLP / MULTISTART MSNUMSTARTS=20 HESSTYPE=PRODUCT SEED=&SEED;
      %END;
      *output sl coefficients to file;
      %IF (&method IN(CCLS OLS CCLOGLIK LOGLIK CCLAE LAE AUC RIDGE CCRIDGE)) %THEN %DO;
        *unstandardized coefficients;
         CREATE DATA &OUTCOEF FROM {j in lib} <COL('__slcoef_'||j) = coef[j]>;
        %IF %__TrueCheck(&verbose) %THEN PRINT coef;;
        %IF %__TrueCheck(&verbose) %THEN PRINT riskl;;
      %END;
      %IF (&method IN(NNLS NNLOGLIK NNLAE NNRIDGE)) %THEN %DO;
        *Standardized coefficients;
        IMPVAR stdcoef{j in LIB} = coef[j]/SUM{k in LIB} coef[k];
        CREATE DATA &OUTCOEF FROM {j in lib} <COL('__slcoef_'||j) = stdcoef[j]>; *(flat file);
        %IF %__TrueCheck(&verbose) %THEN PRINT coef;;
        %IF %__TrueCheck(&verbose) %THEN PRINT stdcoef;;
        %IF %__TrueCheck(&verbose) %THEN PRINT riskl;;
      %END;
      CREATE DATA __sltm0011_ FROM risk; *output sl RISK to file;
      CREATE DATA &outrisk FROM [j] riskl; *output sl library specific risks to file (long file);
      %IF %__TrueCheck(&debug) %THEN %DO;
        CREATE DATA optmodel_impvar FROM [i] sl_pred=sl_pred dsl_pred=dsl_pred &Y=__y;
        CREATE DATA testing FROM libmem[1,1];
      %END;
    QUIT;
    *end proc optmodel statements;
  %END;
  %IF (&method IN( BNNLOGLIK BCCLOGLIK BLOGLIK BNNLS BCCLS BOLS BNNRIDGE BCCRIDGE BRIDGE BNNLASSO BCCLASSO BLASSO BNNLAE BCCLAE BLAE)) %THEN %DO;
    *super learner fitting with hpnlmod - capable handling more data than optmodel, but less well tested;
    * NOTE: these methods may become default in future versions;
    %LET wt =;
    %IF &weight^= %THEN %LET wt= &weight *;;
    ODS EXCLUDE ALL; ODS NORESULTS;
    PROC HPNLMOD DATA=__sltm004_  ABSGCONV=1E-16 
      %IF (&method IN( BNNLOGLIK BCCLOGLIK BLOGLIK BNNLS BCCLS BOLS BNNRIDGE BCCRIDGE BRIDGE BNNLASSO BCCLASSO BLASSO BNNLAE BCCLAE BLAE )) %THEN TECH=QUANEW; 
      %ELSE %IF (&method IN( BNNLOGLIK )) %THEN TECH=TRUREG;  
      %ELSE /*TECH=LEVMAR*/;;
      %IF %__TrueCheck(&verbose) %THEN TITLE "HPNLMOD procedure: SL coefficient estimation";;
      PARMS 
        %LET l_l = 1; 
        %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); __slcoef_&l_l =%SYSEVALF(1/&LIBCOUNT)  %LET l_l = %EVAL(&l_l +1); %END;;
      %IF (&method IN(BCCLS BCCLOGLIK BCCRIDGE BCCLAE BCCLASSO)) %THEN %DO;
        * convexity part 1;
        BOUNDS 0 <= __slcoef_1-__slcoef_%EVAL(&l_l -1) <= 1;
      %END;
      % IF (&method IN(BNNLOGLIK BCCLOGLIK BLOGLIK)) %THEN %DO;
         *loglik methods;
        %LET l_l = 1;
        __slp = 1/(1+EXP(-( 0
          %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); + __slcoef_&l_l * (LOG(MIN(MAX(__v&l_l, &TRIMBOUND), 1-&TRIMBOUND))-LOG(MIN(MAX(1-__v&l_l, &TRIMBOUND), 1-&TRIMBOUND)))  %LET l_l = %EVAL(&l_l +1); %END;
          )));
         r =  (&y*LOG(MIN(MAX(__slp, &TRIMBOUND), 1-&TRIMBOUND)) + (1-&y)*LOG(MIN(MAX(1-__slp, &TRIMBOUND), 1-&TRIMBOUND)));
         dummy=0;
        MODEL dummy ~ GENERAL(&WT r);
      %END;
      %IF (&method IN(BNNLS BCCLS BOLS)) %THEN %DO;
        * ls methods;
        %LET l_l = 1;
        f =  &WT ( 0
          %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); + __slcoef_&l_l * __v&l_l  %LET l_l = %EVAL(&l_l +1); %END;
          );
        MODEL &y ~ NORMAL( f, sig2);
      %END;
      %IF (&method IN(BNNRIDGE BCCRIDGE BRIDGE)) %THEN %DO;
         * ridge methods, penalization by offset;
        %LET l_l = 1;
        f = (&Y-( 0
          %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); + __slcoef_&l_l * __v&l_l  %LET l_l = %EVAL(&l_l +1); %END;
          ))**2
          ;
         pen = (&slridgepen/&SLNumObs)*(0
          %LET l_l = 1;
          %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); + __slcoef_&l_l**2   %LET l_l = %EVAL(&l_l +1); %END;
          );
         dummy=0;
        MODEL dummy ~ GENERAL(-&WT f - pen);
      %END;
      %IF (&method IN(BNNLASSO BCCLASSO BLASSO)) %THEN %DO;
         * LASSO methods, penalization by offset;
        %LET l_l = 1;
        f = (&Y-( 0
          %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); + __slcoef_&l_l * __v&l_l  %LET l_l = %EVAL(&l_l +1); %END;
          ))**2
          ;
         pen = (&slridgepen/&SLNumObs)*(0
          %LET l_l = 1;
          %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); + ABS(__slcoef_&l_l)   %LET l_l = %EVAL(&l_l +1); %END;
          );
         dummy=0;
        MODEL dummy ~ GENERAL(-&WT f - pen);
      %END;
      %IF (&method IN(BNNLAE BCCLAE BLAE)) %THEN %DO;
         *least absolute error methods: useful for targeting median of predictive distribution;
         *NOTE: BNNLAE seems to be failing due to ridging errors;
        %LET l_l = 1;
        f =  ABS(&y-( 0
          %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); + __slcoef_&l_l * __v&l_l  %LET l_l = %EVAL(&l_l +1); %END;
          ))
          ;
         dummy=0;
        MODEL dummy ~ GENERAL(-&WT f);
      %END;
      %IF (&method IN(BCCLS BCCLOGLIK BCCLAE BCCRIDGE BCCLASSO)) %THEN %DO;
        * convexity part 2;
        %LET l_l = 1;
        RESTRICT  0  
          %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); + __slcoef_&l_l  %LET l_l = %EVAL(&l_l +1); %END;
          = 1.0;
      %END;
      %IF (&method IN(BNNLS BNNLOGLIK BNNRIDGE BNNLAE BNNLASSO)) %THEN %DO; 
        *non-negativity;
        %LET l_l = 1;
        %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); BOUNDS 0<= __slcoef_&l_l <=10;  %LET l_l = %EVAL(&l_l +1); %END; 
      %END;
      ODS OUTPUT ParameterEstimates=&outcoef(KEEP=parameter estimate RENAME=(estimate=Coef) WHERE=(parameter ^= "sig2"));
    RUN;  
    %IF (&method IN(BNNLS BNNLOGLIK BNNRIDGE BNNLAE BNNLASSO)) %THEN %DO;
      *renormalize coefficients for nn methods;
      PROC MEANS DATA = &OUTCOEF NOPRINT;
        VAR Coef;
        OUTPUT OUT=__slt0017_ SUM=/;
      %LOCAL _coefmean;
      DATA _NULL_;
        SET __slt0017_;
        CALL SYMPUT('_coefSUM', PUT(coef, 18.16));
      RUN;
      %IF %SYSEVALF(&_coefsum<.01) %THEN %__SLWarning(%STR(&method appears to be not working well for the current problem. Try BCCLS, BCCRIDGE, BCCLASSO, OR BCCLOGLIK (bernoulli only).));
      DATA &outcoef;
        SET &outcoef;
        Coef = Coef/&_coefsum;
      RUN;
    %END;
    *coefs to 1 obs;
    PROC TRANSPOSE DATA = &outcoef OUT=&outcoef(DROP=_NAME_); ID parameter;RUN;
    /* calculate risk */ 
    PROC SQL NOPRINT;
      CREATE TABLE &outrisk(DROP=TOSS) AS SELECT
      %LET l_l = 1;
      %IF (&method IN(BCCLS BNNLS BOLS BCCRIDGE BNNRIDGE BRIDGE BCCLASSO BNNLASSO BLASSO)) %THEN %DO;
       %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); MEAN(&WT (&Y-__v&l_l)**2) AS riskl&l_l,  %LET l_l = %EVAL(&l_l +1); %END;
      %END;
      %IF (&method IN(BCCLAE BNNLAE BLAE)) %THEN %DO;
       %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); MEAN(&WT ABS(&Y-__v&l_l)) AS riskl&l_l,  %LET l_l = %EVAL(&l_l +1); %END;
      %END;
      %IF (&method IN(BCCLOGLIK BNNLOGLIK BLOGLIK)) %THEN %DO;
       %DO %WHILE(%EVAL(&l_l<=&LIBCOUNT)); MEAN(-&WT (&Y*LOGBOUND(__v&l_l, &TRIMBOUND, 1-&TRIMBOUND)+(1-&Y)*LOGBOUND(1-__v&l_l, &TRIMBOUND, 1-&TRIMBOUND))) AS riskl&l_l,  %LET l_l = %EVAL(&l_l +1); %END;
      %END;
      SUM (1) AS toss
       FROM __sltm004_;
    QUIT;
    PROC TRANSPOSE DATA = &outrisk OUT=&outrisk ;RUN;
    DATA &outrisk;
      LENGTH j 8;
      SET &outrisk(KEEP=COL1);
      j=_n_;
      RENAME col1=riskl;
    RUN;
    ODS EXCLUDE NONE;ODS RESULTS;
    *end hpnlmod methods;
  %END;
  %IF (%__TrueCheck(&logreport) AND %__TrueCheck(&getfoldrisks)) %THEN %DO;
    * report coefficients to the log;
    %__SLnote(Learner specific risks: N=&SLNumObs);
    DATA _NULL_; 
      SET &outrisk;
      %LET l_l = 1;
      %DO %WHILE(%SCAN(&LIBRARY, &l_l)~=);
        IF j = &l_l THEN CALL SYMPUT("cvrisk&l_l", PUT(riskl, BEST9.));
        %LET l_l = %EVAL(1+&l_l);
      %END;;
    RUN;
    %LET l_l = 1;
    %DO %WHILE(%SCAN(&library, &l_l)~=);
      %__SLnote(Fold specific/overall %SCAN(&library, &l_l) risk: %TRIM(&&cvrisk&l_l).);
      %LET l_l = %EVAL(1+&l_l);
    %END;;
  %END; 
  %IF %__TrueCheck(&verbose) %THEN %DO; ODS SELECT NONE;%END;   
  DATA &OUTCOEF;
    SET &OUTCOEF;
    %__RENAMEcoefs(library=&LIBRARY); *give these a nice name;
  RUN;
%MEND _get_coef;
* %_get_coef(indata=__sltm002_, Y=zcv1, library=logit rf, outcoef=sl_coef_Test, outrisk=sl_risks, suff=1, debug=FALSE);

%MACRO _get_adaptive_coef(indata=, outdata=, Y=, library=, outcoef=, outrisk=, suff=, weight=, method=CCLS, debug=FALSE) / MINOPERATOR MINDELIMITER=' ';
  FILENAME adapt TEMP;
  /* RANDOM FOREST TO GET SUPER LEARNER FIT*/
  DATA __sltm004_;
    * training data; 
    SET &inDATa (WHERE =(__int=.o AND &Y > .z AND __train=1));
    %__RENAMEVARS(Y=&Y, library=&library,suff=_z);
  DATA __sltm005_; 
    * test data;
    SET &inDATa ;
    %__RENAMEVARS(Y=, library=&library,suff=_full);
  %IF &method = ADAPTRF %THEN %DO;
    PROC HPFOREST DATA = __sltm004_ seed=&SLseed  /*PRESELECT=BINNEDSEARCH SCOREPROLE=OOB MAXTREES = 100*/ ;
      ODS SELECT NONE;
      FORMAT &Y;
      %IF &WEIGHT^= %THEN FREQ &weight;; *weight possibly truncated to integer;
      TARGET &Y / LEVEL = %IF &DIST=BERNOULLI %THEN binary ;%ELSE interval;;
      INPUT __V: / LEVEL = interval;
      SAVE FILE=adapt;
      ODS OUTPUT VariableImportance=&outcoef;
    PROC hp4score DATA = __sltm005_;
     ID _ALL_;
     %IF &DIST=BERNOULLI %THEN SCORE FILE = adapt OUT = &outdata  (DROP = _Warn_  I_&Y p_&Y.0 RENAME=(p_&Y.1 = p_SL_full));;
     %IF &DIST=GAUSSIAN %THEN SCORE FILE = adapt OUT = &outdata (DROP = _Warn_  RENAME=(p_&Y = p_SL_full));;
  %END;
  DATA &outdata;
    SET &outdata;
    %__unRENAMEVARS(Y=, library=&library,suff=_full);
  %LET wt =;
  %IF &weight^= %THEN %LET wt= &weight *;;
  DATA __sltm009_(KEEP = j Learner CVrisk);
    LENGTH learner $39;
    SET &outdata;
    %LET l_l = 1;
    %DO %WHILE(%SCAN(&LIBRARY, &l_l)^=);
     %LET book = %SCAN(&LIBRARY, &l_l);
       Learner = "&book";
       j = &l_l; 
       CVrisk = &wt (&Y - p_&book._full)**2;
       OUTPUT;
     %LET l_l = %EVAL(&l_l + 1);
    %END; *scan l;
  PROC SORT DATA = __sltm009_; BY j learner;
  PROC MEANS DATA = __sltm009_ NOPRINT;
    BY j Learner;
    VAR CVrisk ;
    OUTPUT OUT = &outrisk(KEEP=j CVrisk) MEAN=;
  RUN;
  DATA &outcoef(KEEP= J Learner col1);
    LENGTH Learner $39;
    SET &outcoef;
      %LET l_l = 1;
      %DO %WHILE(%SCAN(&LIBRARY, &l_l)^=);
        %LET book = %SCAN(&LIBRARY, &l_l);
        IF TRIM(variable) = "__v&l_l" THEN DO;
          Learner = "__slcoef_&book";
          j = &l_l;
          %IF &DIST=BERNOULLI %THEN col1 = MarginOOB;;      
          %IF &DIST=GAUSSIAN %THEN col1 = MSEOOB;;      
          OUTPUT;
        END;
        %LET l_l = %EVAL(&l_l + 1);
      %END; *scan l_l;
  RUN;
  PROC SORT DATA = &OUTCOEF; BY j; RUN;
  PROC TRANSPOSE DATA = &outcoef(DROP=j) OUT=&outcoef; ID learner;RUN;
%MEND _get_adaptive_coef;

%MACRO _sl_cvrisk(indata, outdata, library, outcoef, risk, method, outcvrisks,seed)  / MINOPERATOR MINDELIMITER=' ';
  /*
  Cross validated risk estimates for each algorithm;
  */
  %__SLnote(_sl_cvrisk: calculate cross validated risk for each algorithm and minimize cross validate risk to estimate coefficients);
  DATA &indata;
    SET &indata;
    %LET k_k=0;
    %DO %WHILE (&k_k < &folds);
      %LET k_k = %EVAL(&k_k + 1);
      %LET l_l = 1;
      %DO %WHILE(%SCAN(&LIBRARY, &l_l)^=);
        %LET book = %SCAN(&LIBRARY, &l_l);
        p_&book._z = SUM(p_&book._z, (1-__cv&k_k)*p_&book&k_k); * compiling learner specific cross validated predictions;
        DROP p_&book&k_k ;
        %LET l_l = %EVAL(&l_l + 1);
      %END; *scan l;
      DROP &y.__CV__&k_k;
    %END; *k_k;
  RUN;
   * get fold specific coefficients (this step is unnecessary and may be cut out, but will yield fold specific risks);
  %IF %__TrueCheck(&getfoldrisks) %THEN %DO;
    %__SLwarning(%str(option getfoldrisks has been deprecated));
  %END;
  %IF %__TrueCheck(&checkvalid) %THEN %DO;
    * check for valid estimates in all learners, drop from library if missing;
    * somewhat expensive, so disabled in _superlearner, but enabled in superlearner;
    %__ValidLib(&library, &Y, &indata);
    %LET library = &validlib;
  %END;
  * now get overall superlearner coefficients (for SL predictions); 
  * step 7 in figure 3.2 of targeted learning book;
  %IF &method=AUC %THEN %__SLWarning(%str(AUC implementation is slow and extremely fragile on this platform. Take care!));
  %IF (&method IN(NNLOGLIK CCLOGLIK LOGLIK NNLS CCLS OLS NNLAE CCLAE LAE AUC RIDGE CCRIDGE NNRIDGE BNNLOGLIK BCCLOGLIK BLOGLIK BNNLS BCCLS BOLS BNNRIDGE BCCRIDGE BRIDGE BNNLASSO BCCLASSO BLASSO BNNLAE BCCLAE BLAE)) %THEN
    %_get_coef(indata=&indata, Y=&Y, library=&library, outcoef=&outcoef, outrisk=&outcvrisks, weight=&weight, suff=, method=&method, debug=false,seed=&seed);;
  %IF (&method IN(ADAPTRF)) %THEN
    %_get_adaptive_coef(indata=&indata, outdata=&outdata, Y=&Y, library=&library, outcoef=&outcoef, outrisk=&outcvrisks, weight=&weight, suff=, method=&method, debug=FALSE);;
%MEND _sl_cvrisk;
*%_sl_cvrisk(indata=__sltm002_, outdata=__sltm002_, library=&library, incoef=sl_coef, risk=&risk); *get (cross-validated) risk predictions for each fold;;

%MACRO _SLPredict(indata, outdata, library, incoef, inrisk)  / MINOPERATOR MINDELIMITER=' ';
  /*
  Get final superlearner predictions, including under interventions
  */
  %__SLnote(_SLPredict: get final superlearner predictions);
  PROC SQL NOPRINT; CREATE TABLE &outdata AS SELECT * FROM &indata ORDER BY __seqid__;
  DATA __sltm0017_;
    SET &inrisk END = eof;
    RETAIN minrisk 1e16 idx 1;
    IF minrisk > riskl THEN DO; minrisk = riskl; idx = _n_;END;
    IF eof THEN OUTPUT;
  DATA _NULL_;
    SET __sltm0017_;
    CALL SYMPUT("SL_dslidx", PUT(idx, 3.0));
  DATA &outdata;
    SET &outdata;
    IF _N_ = 1 THEN SET &incoef;
    %IF %__FalseCheck(&insample) %THEN %DO;
       IF __train=0 THEN &Y = _&Y;
    %END;
    %IF (&method IN(NNLOGLIK CCLOGLIK LOGLIK NNLS CCLS OLS NNLAE CCLAE LAE ADAPTRF AUC RIDGE CCRIDGE NNRIDGE BNNLOGLIK BCCLOGLIK BLOGLIK BNNLS BCCLS BOLS BNNLAE BCCLAE BLAE BRIDGE BCCRIDGE BNNRIDGE BLASSO BCCLASSO BNNLASSO)) %THEN %DO;
      %LET l_l = 1;
      %DO %WHILE(%SCAN(&LIBRARY, &l_l)^=);
        %LET book = %SCAN(&LIBRARY, &l_l);
        %IF %EVAL(&SL_dslidx=&l_l) %THEN p_dSL_full = p_&book._full;;
        LABEL p_&book._full = "&book prediction";
        LABEL p_&book._z = "&book prediction (fold specific)";
        %IF (&method IN (NNLS CCLS OLS NNLAE CCLAE LAE AUC RIDGE CCRIDGE NNRIDGE BNNLS BCCLS BOLS BNNLAE BCCLAE BLAE BRIDGE BCCRIDGE BNNRIDGE BLASSO BCCLASSO BNNLASSO)) %THEN %DO;
             p_SL_full  =   SUM(p_SL_full, __slcoef_&book*p_&book._full); *overall superlearner estimate with cross validated coefficients;
        %END;
        %IF (&method IN (NNLOGLIK CCLOGLIK LOGLIK BNNLOGLIK BCCLOGLIK BLOGLIK)) %THEN %DO;
          *only gives the logit probabilities;
          p_lslcv  = (SUM(p_lslcv, __slcoef_&book*LOGITBOUND(p_&book._full, &TRIMBOUND, 1-&TRIMBOUND))); *overall superlearner estimate with cross validated coefficients;
        %END;
        %LET l_l = %EVAL(&l_l + 1);
      %END; *scan l;
      %IF (&method IN (NNLOGLIK CCLOGLIK LOGLIK BNNLOGLIK BCCLOGLIK BLOGLIK)) %THEN %DO;
        p_SL_full = EXPIT(p_lslcv);
        DROP p_lslcv;
      %END;
    %END;
    %IF (&method IN(ADAPTRF)) %THEN %DO;
    %END;
    LABEL p_SL_full = "Super learner prediction";
    LABEL p_dSL_full = "Discrete super learner prediction";
    DROP __cv1-__cv&folds;
  RUN;
%MEND _SLPredict;

%MACRO _cvriskreport(indata, library) / MINOPERATOR MINDELIMITER=' ';
  /*
  Write out the cross-validated loss function values for library members and Super Learner
  */
  %__SLnote(_cvriskreport);
  DATA _NULL_; SET &INDATA(WHERE=(__int=.o)) END=__eof; IF __eof THEN CALL SYMPUT('SLNumObs', PUT(_N_, BEST9.));RUN;
  DATA __sltm003_(KEEP=risk: );
    SET &indata(WHERE=(__int=.o)) END = __eof;
    %IF (&method IN (NNLAE CCLAE LAE BNNLAE BCCLAE BLAE)) %THEN %DO;
      %LET l_l = 1;
      %DO %WHILE(%SCAN(&LIBRARY, &l_l)~=);
        %LET book = %SCAN(&LIBRARY, &l_l);
        RETAIN risk_&book 0 ;
        risk_&book = risk_&book + (ABS(&Y - p_&book._z))/&SLNumObs ;
        %LET l_l = %EVAL(&l_l + 1);
      %END;
    %END;
    %IF (&method IN (NNLS CCLS OLS ADAPTRF RIDGE CCRIDGE NNRIDGE BNNLS BCCLS BOLS BRIDGE BCCRIDGE BNNRIDGE BLASSO BCCLASSO BNNLASSO)) %THEN %DO;
      %LET l_l = 1;
      %DO %WHILE(%SCAN(&LIBRARY, &l_l)~=);
        %LET book = %SCAN(&LIBRARY, &l_l);
        RETAIN risk_&book 0 ;
        risk_&book = risk_&book + ((&Y - p_&book._z)**2)/&SLNumObs ;
        %LET l_l = %EVAL(&l_l + 1);
      %END;
    %END;
    %IF (&method IN(NNLOGLIK CCLOGLIK LOGLIK BNNLOGLIK BCCLOGLIK BLOGLIK)) %THEN %DO;
      %LET l_l = 1;
      %DO %WHILE(%SCAN(&LIBRARY, &l_l)~=);
        %LET book = %SCAN(&LIBRARY, &l_l);
        RETAIN risk_&book 0;
        risk_&book = risk_&book + (&Y*LOG(MAX(MIN(p_&book._z, 1-&TRIMBOUND), &TRIMBOUND)) + (1-&Y)*LOG(1-MAX(MIN(p_&book._z, 1-&TRIMBOUND), &TRIMBOUND)))/&SLNumObs ;
        %LET l_l = %EVAL(&l_l + 1);
      %END;
    %END;
    IF __eof THEN OUTPUT;
  DATA _NULL_; 
    SET __sltm003_;
      %LET l_l = 1;
      %DO %WHILE(%SCAN(&LIBRARY, &l_l)~=);
        %LET book = %SCAN(&LIBRARY, &l_l);
        CALL SYMPUT ("r&l_l", PUT(risk_&book, BEST9.));
        %LET l_l = %EVAL(&l_l + 1);
      %END;
  RUN;
  %__SLnote(Cross validated Super Learner risk: (unavailable without further cross-validation)); 
  %LET l_l = 1;
  %DO %WHILE(%SCAN(&LIBRARY, &l_l)~=);
     %LET book = %SCAN(&LIBRARY, &l_l);
     %__SLnote(Cross validated %SCAN(&library, &l_l) risk: %TRIM(&&r&l_l));
    %LET l_l = %EVAL(&l_l + 1);
  %END;
%MEND _cvriskreport;
*%LET Y= y;
*%_cvriskreport(indata=Sl_testdata, library=logit rf lasso gam);

%MACRO __FUNCLEANUP();
  PROC FCMP OUTLIB=work.__funcs.LOGFUNCS;
    DELETEFUNC expit;
    DELETEFUNC logit;
    DELETEFUNC logitbound;
    DELETEFUNC logbound;
    %IF &METHOD = AUC %THEN %DO;
      DELETEFUNC AUC;
      DELETEFUNC AUCL;
    %END;
  RUN;;
  OPTIONS CMPLIB=_null_;
%MEND;

%MACRO _get_slcvrisk(indata=, Y=, library=, outrisk=, weight=, method=CCLS, debug=FALSE) / MINOPERATOR MINDELIMITER=' ';
  /*
   Get cross validated risk estimates
  */
  %__MKFUNCS();
  *%LET denom  = %EVAL(&CVSLsampsize/&CVSLfolds);
  %__SLnote(_get_slcvrisk);
  %LET wt =;
  %IF &weight^= %THEN %LET wt= &weight *;;

  DATA __cvsltmp008__(KEEP = order learner CVrisk Coefficient);
    LENGTH learner $39;
    SET &indata;
    Coefficient = .;
    %IF (&method IN (NNLAE CCLAE LAE BNNLAE BCCLAE BLAE)) %THEN %DO;
      CVrisk = &wt ABS(&Y - p_SL_full);
      learner = "super learner";
      order = 1; 
      OUTPUT;
      CVrisk = &wt ABS(&Y - p_dSL_full);
      learner = "discrete super learner";
      order = 2; 
      OUTPUT;
    %END;
    %ELSE %IF (&method IN (NNLS CCLS OLS ADAPTRF RIDGE CCRIDGE NNRIDGE BNNLS BCCLS BOLS BRIDGE BCCRIDGE BNNRIDGE BLASSO BCCLASSO BNNLASSO)) %THEN %DO;
      CVrisk = &wt (&Y - p_SL_full)**2;
      learner = "super learner";
      order = 1; 
      OUTPUT;
      CVrisk = &wt (&Y - p_dSL_full)**2;
      learner = "discrete super learner";
      order = 2; 
      OUTPUT;
    %END;
    %ELSE %IF (&method IN(NNLOGLIK CCLOGLIK LOGLIK BNNLOGLIK BCCLOGLIK BLOGLIK)) %THEN %DO;
      CVrisk = &wt -(&Y * LOGBOUND(p_SL_full, &TRIMBOUND, 1-&TRIMBOUND) + (1-&Y) * LOGBOUND(1-p_SL_full, &TRIMBOUND, 1-&TRIMBOUND));
      learner = "super learner";
      order = 1; 
      OUTPUT;
      CVrisk = &wt -(&Y * LOGBOUND(p_dSL_full, &TRIMBOUND, 1-&TRIMBOUND) + (1-&Y) * LOGBOUND(1-p_dSL_full, &TRIMBOUND, 1-&TRIMBOUND));  
      learner = "discrete super learner";
      order = 2; 
      OUTPUT;
    %END;
    %LET l_l = 1;
    %DO %WHILE(%SCAN(&LIBRARY, &l_l)^=);
     %LET book = %SCAN(&LIBRARY, &l_l);
       Coefficient = __slcoef_&book;
       learner = "&book";
       order = &l_l+2;      
       %IF (&method IN (NNLAE CCLAE LAE NNLAE CCLAE LAE BNNLAE BCCLAE BLAE)) %THEN %DO;
         CVrisk = &wt ABS(&Y - p_&book._full);
         OUTPUT;
       %END;
       %ELSE %IF (&method IN (NNLS CCLS OLS ADAPTRF NNRIDGE CCRIDGE RIDGE BNNLS BCCLS BOLS BRIDGE BCCRIDGE BNNRIDGE BLASSO BCCLASSO BNNLASSO)) %THEN %DO;
         CVrisk = &wt (&Y - p_&book._full)**2;
         OUTPUT;
       %END;
       %ELSE %IF (&method IN (NNLOGLIK CCLOGLIK LOGLIK BNNLOGLIK BCCLOGLIK BLOGLIK)) %THEN %DO;
         CVrisk = &wt -(&Y * LOGBOUND(p_&book._full, &TRIMBOUND, 1-&TRIMBOUND) + (1-&Y) * LOGBOUND(1-p_&book._full, &TRIMBOUND, 1-&TRIMBOUND));
         OUTPUT;
       %END;
     %LET l_l = %EVAL(&l_l + 1);
    %END; *scan l;
  RUN;
  PROC SQL NOPRINT;
    CREATE TABLE __cvsltmp009__ AS SELECT * FROM __cvsltmp008__ ORDER BY order;
  QUIT;
  PROC MEANS DATA = __cvsltmp009__ NOPRINT;
    BY order learner;
    VAR CVrisk Coefficient;
    OUTPUT OUT = &outrisk MEAN=;
  RUN;
  %IF %__TrueCheck(&verbose) %THEN ODS SELECT NONE;;
  %__FUNCLEANUP;
%MEND _get_slcvrisk;

/********************************************************
* Part 4: testing;
Below are several macros with examples of using super learner
  test_bernoulli_int: simple confounding problem - predicting potential outcomes
  test_gaussian_int: example with continuous variable
  test_slnewlearner: example demonstrating how to introduce a new/custom learner
  test_slexternalpreds: example demonstrating how make predictions in a validation dataset
  test_cvsl: example demonstrating estimation of cross-validated super learner risk
********************************************************/

%MACRO test_bernoulli_int(n=300, trueRD = .1);
  *0) simulate data, including 5-fold cross validation sets;
  DATA A ;
    LENGTH id x l 3;
    CALL STREAMINIT(1192887);
    *observed data;
    DO id = 1 TO &N;
      py0_true = RAND("uniform")*0.1 + 0.4;  
      l = RAND("bernoulli", 1/(1+exp(-1 + py0_true)));
      c = RAND("normal", py0_true, 1);
      c2 = RAND("normal", py0_true, .3);
      x = RAND("bernoulli", 1/(1+exp(-1.5 + 2*l + c + c2)));
      py = py0_true + &trueRD*(x); *true risk difference per unit exposure;
      py1_true = py0_true + &trueRD;
      rd_true = &truerd;
      y = RAND("bernoulli", py);
      OUTPUT;
    END;
  RUN;
  
  %SuperLearner(Y=y,
                intvars=x,
                binary_predictors= x l,
                ordinal_predictors=,
                nominal_predictors=,
                continuous_predictors=c c2,
                indata=a, 
                outdata=sl_testdata,
                library= logit rf lasso nn gampl,
                  trtstrat=true, 
                folds=5, 
                method=NNLOGLIK, 
                dist=BERNOULLI 
  );
  PROC MEANS DATA = sl_testdata FW=5;
   TITLE 'Predicted outcomes';
   TITLE2 'no intervention (int=-1), never treatment (int=0), always treat (int=1)';
   VAR p_: py0_: py1_: py y;
   CLASS __int;
  RUN;
%MEND test_bernoulli_int;

%MACRO test_gaussian_int(n=300, trueMEANDIFF = 1);
  *0) simulate data, including 5-fold cross validation sets;
  DATA A ;
    LENGTH id x l 3;
    CALL STREAMINIT(1192887);
    *observed data;
     DO id = 1 TO &N;
       py0_true = RAND("uniform")*0.1 + 0.4;  
       l = RAND("bernoulli", 1/(1+exp(-1 + py0_true)));
       c = RAND("normal", py0_true, 1);
       c2 = RAND("normal", py0_true, .3);
       x = RAND("bernoulli", 1/(1+exp(-1.5 + 2*l + c + c2)));
       py = py0_true + &trueMEANDIFF*(x); *true risk difference per unit exposure;
       py1_true = py0_true + &trueMEANDIFF;
       meandiff_true = &trueMEANDIFF;
       y = RAND("NORMAL", py, 1);
       OUTPUT;
    END;
  RUN;
  
  %SuperLearner(Y=y,
                intvars=x,
                binary_predictors= x l,
                continuous_predictors=c c2,
                indata=a, 
                outdata=sl_testdata,
                library= linreg lasso gampl,
                  trtstrat=true, 
                folds=5, 
                method=CCLS, 
                dist=GAUSSIAN /*GAUSSIAN OR BERNOULLI*/
  );
  PROC MEANS DATA = sl_testdata FW=5;
   TITLE 'Predicted outcomes';
   TITLE2 'no intervention (__int=.o), never treatment (__int=0), always treat (__int=1)';
   VAR p_: py0_: py1_: py y;
   CLASS __int;
  RUN;
%MEND test_gaussian_int;

%MACRO test_slnewlearner(n=300, trueMEANDIFF = 1);
  /* template for adding in a custom learner*/
  *0) simulate data, including 5-fold cross validation sets;
  DATA A ;
    LENGTH id x l 3;
    CALL STREAMINIT(1192887);
    *observed data;
    DO id = 1 TO &N;
      py0_true = 10+RAND("uniform")*0.1 + 0.4;  
      l = RAND("bernoulli", 1/(1+exp(-1 + py0_true)));
      c = RAND("normal", py0_true, 1);
      c2 = RAND("normal", py0_true, .3);
      x = RAND("bernoulli", 1/(1+exp(-1.5 + 2*l + c + c2)));
      py = py0_true + &trueMEANDIFF*(x); *true risk difference per unit exposure;
      py1_true = py0_true + &trueMEANDIFF;
      meandiff_true = &trueMEANDIFF;
      y = RAND("NORMAL", py, 1);
      OUTPUT;
    END;
  RUN;
  
  
  *adding in a custom learner (custom_cn for 'continuous' and custom_in for 'binary');
  * example: new link function with gamma distribution;
  %MACRO custom_cn(/*change macro name with [libraryname]_cn*/
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
  );
    /* gamma model */
    PROC GENMOD DATA = &indata;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
     MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / LINK=LOG D=GAMMA;
     OUTPUT OUT = &OUTDATA PRED=p_custom&SUFF; /*change predicted value name with p_[libraryname]&suff*/
    RUN;
  %MEND custom_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
  
  %SuperLearner(Y=y,
                intvars=x,
                binary_predictors= x l,
                continuous_predictors=c c2,
                indata=a, 
                outdata=sl_testdata,
                library= linreg custom, /* note how new learner is used*/
                trtstrat=true, 
                folds=5, 
                method=CCLS, /*L2 ENTROPY*/
                dist=GAUSSIAN /*GAUSSIAN OR BERNOULLI*/
  );
  PROC MEANS DATA = sl_testdata FW=5;
   TITLE 'Predicted outcomes';
   TITLE2 'no intervention (int=-1), never treatment (int=0), always treat (int=1)';
   VAR p_: py0_: py1_: py y;
   CLASS __int;
  RUN;
%MEND test_slnewlearner;

%MACRO test_slexternalpreds(ntrain=300,nvalid=1000);
  *0) simulate data, including 5-fold cross validation sets;
  DATA train valid ;
    LENGTH id x l 3;
    CALL STREAMINIT(1192887);
    *observed data;
    DO id = 1 TO %EVAL(&ntrain+&nvalid);
      py0_true = RAND("uniform")*0.1 + 0.4;  
      l = RAND("bernoulli", 1/(1+exp(-1 + py0_true)));
      c = RAND("normal", py0_true, 1);
      c2 = RAND("normal", py0_true, .3);
      x = RAND("bernoulli", 1/(1+exp(-1.5 + 2*l + c + c2)));
      py = py0_true + 1*(x); *true risk difference per unit exposure;
      y = RAND("NORMAL", py, 0.5);
      KEEP x l c c2 y;
      IF id <= &ntrain THEN OUTPUT train;
      ELSE OUTPUT valid;
    END;
  RUN;
  TITLE "Super learner predictions in validation data";
  %SuperLearner(Y=y,
                X=x l c c2,
                indata=train, 
                preddata=valid, 
                outdata=sl_testdata,
                library= linreg lasso gampl,
                folds=10, 
                method=NNLS, 
                dist=GAUSSIAN /*GAUSSIAN OR BERNOULLI*/
  );
  PROC MEANS DATA = sl_testdata FW=5;
    TITLE 'Predicted outcomes in training/validation data';
    VAR p: y;
    CLASS __train;
  RUN;
  DATA mse(KEEP=__train squarederror:);
    SET sl_testdata;
    squarederror_sl = (y - p_SL_full)**2;
    squarederror_linreg = (y - p_linreg_full)**2;
    squarederror_lasso = (y - p_lasso_full)**2;
    squarederror_gampl = (y - p_gampl_full)**2;
  PROC MEANS DATA = mse FW=5 MEAN;
    TITLE 'Mean squared error of predictions in training/validation data';
    VAR squarederror:;
    CLASS __train;
  RUN;
%MEND test_slexternalpreds;

%MACRO test_cvsl(n=300);
  *0) simulate data;
  DATA A ;
    LENGTH id x l 3;
    CALL STREAMINIT(1192887);
    *observed data;
    DO id = 1 TO &N;
      py0_true = RAND("uniform")*0.1 + 0.4;  
      l = RAND("bernoulli", 1/(1+exp(-1 + py0_true)));
      c = RAND("normal", py0_true + 0.1*py0_true**2, 1);
      c2 = RAND("normal", py0_true - 0.1*py0_true**2, .3);
      x = RAND("bernoulli", 1/(1+exp(-1.5 + 2*l + c + c2)));
      py = py0_true + 1*(x) + .3*c*x - .3*c2*x + .3*c*c - .3*c2*c2; *true risk difference per unit exposure;
      y = RAND("NORMAL", py, 1);
      OUTPUT;
    END;
  RUN;
  
  %_SuperLearner(Y=y,
                 binary_predictors= x l,
                 continuous_predictors= c c2,
                 indata= a , 
                 outdata= sl_cvout ,
                 library=linreg lassoint gampl , 
                 folds= 10, 
                 dist= GAUSSIAN,
                 method=CCLS, 
                 printres=TRUE
                 );
  %_CVSuperLearner(Y=y,
                   binary_predictors=  x l,
                   continuous_predictors=  c c2,
                   indata= a , 
                   outdata= sl_cvout ,
                   library=linreg lassoint gampl , 
                   slfolds= 10, 
                   cvslfolds=10,
                   dist= GAUSSIAN,
                   method=CCLS,
                   cleanup=TRUE,
                   printfoldres=FALSE,
                   quietnotes=TRUE,
                   logreport=FALSE
                   );
%MEND test_cvsl;
OPTIONS NOMPRINT;

* uncomment any of these to show examples;
*%test_bernoulli_int(n=300, trueRD = .1);
*%test_gaussian_int(n=300, trueMEANDIFF = 1);
*%test_slnewlearner(n=300, trueMEANDIFF = 1);
*%test_slexternalpreds(ntrain=300, nvalid=1000);
*%test_cvsl(n=300);
/**********************************************************************************************************************
* MINOR UPDATES
* 13-AUG-2018 Bug with BLASSO, BRIDGE methods (hard coded outcome value). 
              Added nominal support for clustering (only in CV selection).
              Minor change with cvlasso, cvlassoint learners
              Added highly adaptive lasso learner (Experimental)
*  18-SEPT-2018 Added processing by ID for cross-validation
*  23-SEPT-2018 Added Bayesian kernel machine regression (R) and generalized weighted 
              quantile sums (R)
**********************************************************************************************************************/
