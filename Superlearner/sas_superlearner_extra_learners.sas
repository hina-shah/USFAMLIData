%PUT extra_learners v1.1.7;
/**********************************************************************************************************************
* Author: Alex Keil
* Program: sas_superlearner_extra_learners.sas
* Date: 20180521
* Project: super learning in the sas system
* Description: coding of some extra learners used in the paper: 
    Keil, AP. Super Learning in the SAS system. ArXiv. 2018
* Released under the GNU General Public License: http://www.gnu.org/copyleft/gpl.html
**********************************************************************************************************************/




/******************************************************************************************
bootstrap aggregation of regression trees (in R):
 complexity  = 0.1, 0.01, 0.00
 min split = 5
******************************************************************************************/

%MACRO r_bagging010_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, 
nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
  
  %__SLnote(%str(R packages 'ipred' and 'rpart'  must be installed));;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(#set.seed(123));
  %LET rcodeb = %STR(rmod <- 
  ipred::ipredbagg%(y=mdata$&Y,X=mdata[-grep(%"&Y%", names(mdata))], 
    nbagg = 100, control = rpart::rpart.control(xval = 0, 
    maxsurrogate = 0, minsplit = 20, cp = 0.1, maxdepth = 30%))
  );
  %LET rcodec = %STR(p_r_bagging010&SUFF <- predict(rmod, newdata = rdata[-grep(%"&Y%", names(rdata))], aggregation = %"average%"));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  DATA __sltm0016_;
   SET &indata;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_bagging010&SUFF" );
  QUIT;
  DATA &outdata;
   MERGE &indata __rpreds;
  RUN;
  PROC SQL; DROP TABLE __rpreds; QUIT;
  %PUT r_bagging_cn created predictions in &outdata;
%MEND r_bagging010_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/


%MACRO r_bagging001_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, 
nominal_predictors=,  continuous_predictors=,suff=
);
  
  %__SLnote(%str(R packages 'ipred' and 'rpart'  must be installed));;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(#set.seed(123));
  %LET rcodeb = %STR(rmod <- 
  ipred::ipredbagg%(y=mdata$&Y,X=mdata[-grep(%"&Y%", names(mdata))], 
    nbagg = 100, control = rpart::rpart.control(xval = 0, 
    maxsurrogate = 0, minsplit = 20, cp = 0.01, maxdepth = 30%))
  );
  %LET rcodec = %STR(p_r_bagging001&SUFF <- predict(rmod, newdata = rdata[-grep(%"&Y%", names(rdata))], aggregation = %"average%"));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  DATA __sltm0016_;
   SET &indata;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_bagging001&SUFF" );
  QUIT;
  DATA &outdata;
   MERGE &indata __rpreds;
  RUN;
  PROC SQL; DROP TABLE __rpreds; QUIT;
  %PUT r_bagging_cn created predictions in &outdata;
%MEND r_bagging001_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/


%MACRO r_bagging000_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, 
nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
  
  %__SLnote(%str(R packages 'ipred' and 'rpart'  must be installed));;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(#set.seed(123));
  %LET rcodeb = %STR(rmod <- 
  ipred::ipredbagg%(y=mdata$&Y,X=mdata[-grep(%"&Y%", names(mdata))], 
    nbagg = 100, control = rpart::rpart.control(xval = 0, 
    maxsurrogate = 0, minsplit = 20, cp = 0.00, maxdepth = 30%))
  );
  %LET rcodec = %STR(p_r_bagging000&SUFF <- predict(rmod, newdata = rdata[-grep(%"&Y%", names(rdata))], aggregation = %"average%"));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  DATA __sltm0016_;
   SET &indata;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_bagging000&SUFF" );
  QUIT;
  DATA &outdata;
   MERGE &indata __rpreds;
  RUN;
  PROC SQL; DROP TABLE __rpreds; QUIT;
  %PUT r_bagging_cn created predictions in &outdata;
%MEND r_bagging000_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/

%MACRO r_baggingms5_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, 
nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
  
  %__SLnote(%str(R packages 'ipred' and 'rpart'  must be installed));;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(#set.seed(123));
  %LET rcodeb = %STR(rmod <- 
  ipred::ipredbagg%(y=mdata$&Y,X=mdata[-grep(%"&Y%", names(mdata))], 
    nbagg = 100, control = rpart::rpart.control(xval = 0, 
    maxsurrogate = 0, minsplit = 5, cp = 0.01, maxdepth = 30%))
  );
  %LET rcodec = %STR(p_r_baggingms5&SUFF <- predict(rmod, newdata = rdata[-grep(%"&Y%", names(rdata))], aggregation = %"average%"));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  DATA __sltm0016_;
   SET &indata;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_baggingms5&SUFF" );
  QUIT;
  DATA &outdata;
   MERGE &indata __rpreds;
  RUN;
  PROC SQL; DROP TABLE __rpreds; QUIT;
  %PUT r_bagging_cn created predictions in &outdata;
%MEND r_baggingms5_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/


/******************************************************************************************
generalized additive models: gampl procedure
 df = 3 to 8 (2 causes errors for some reason)
******************************************************************************************/
%MACRO gampltempl_cn(deg=,
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* GENERALIZED ADDITIVE MODEL for continuous variable (using alternative sas proc) */
  %__SLnote(%str(GAMS use splines on all continuous variables, which may require a lot of computational power, user beware));;
  %IF (&continuous_predictors=) %THEN %__SLwarning(%str(GAMS with no continuous variables are equivalent to LINREG, but slower));;
  %LET _pvar = p_gamPL&deg&SUFF ;
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
%MEND gampltempl_cn;



%MACRO gampl3_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gampltempl_cn(deg=3, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gampl3_cn;

%MACRO gampl4_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gampltempl_cn(deg=4, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gampl4_cn;

%MACRO gampl5_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gampltempl_cn(deg=5, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gampl5_cn;

%MACRO gampl6_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gampltempl_cn(deg=6, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gampl6_cn;

%MACRO gampl7_cn( Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gampltempl_cn(deg=7,Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gampl7_cn;

%MACRO gampl8_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gampltempl_cn(deg=8, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gampl8_cn;


/******************************************************************************************
generalized additive models (proc gam):
 df = 2 - 8 
******************************************************************************************/


%MACRO gamtempl_cn(deg=,
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* GENERALIZED ADDITIVE MODEL for continuous variable (normal assumption)*/
  %__SLnote(%str(GAMS use splines on all continuous variables, which may require a lot of computational power, user beware));;
  %IF (&continuous_predictors=) %THEN %__SLwarning(%str(GAMS with no continuous variables are equivalent to PROC REG, but slower));;
  %LET _pvar = p_gam&deg&SUFF;
  PROC GAM DATA = &indata ;
    FORMAT &Y;
    ODS SELECT NONE;
    %IF ((&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &ordinal_predictors &nominal_predictors;;
    %IF &WEIGHT^= %THEN FREQ &weight;; *weights possibly truncated to integer values;
   MODEL &Y = PARAM(&binary_predictors &ordinal_predictors &nominal_predictors ) %IF (&continuous_predictors~=) %THEN %__GAMSPLINE(&continuous_predictors, &deg); / 
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
%MEND gamtempl_cn;


%MACRO gam2_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gamtempl_cn(deg=2, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gam2_cn;

%MACRO gam3_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gamtempl_cn(deg=3, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gam3_cn;

%MACRO gam4_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gamtempl_cn(deg=4, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gam4_cn;

%MACRO gam5_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gamtempl_cn(deg=5, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gam5_cn;

%MACRO gam6_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gamtempl_cn(deg=6, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gam6_cn;

%MACRO gam7_cn( Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gamtempl_cn(deg=7,Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gam7_cn;

%MACRO gam8_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %gamtempl_cn(deg=8, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND gam8_cn;
/******************************************************************************************
neural network:
 size 2, 3, 4, 5 (number of units in hidden layer)
******************************************************************************************/
%MACRO nn2_cn(
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
   HIDDEN 2;
   TRAIN OUTMODEL = nnmod MAXITER=200;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (DROP=_WARN_ RENAME=(p_&Y = p_nn2&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn2_cn;


%MACRO nn3_cn(
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
   HIDDEN 3;
   TRAIN OUTMODEL = nnmod MAXITER=200;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (DROP=_WARN_ RENAME=(p_&Y = p_nn3&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn3_cn;

%MACRO nn4_cn(
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
   HIDDEN 4;
   TRAIN OUTMODEL = nnmod MAXITER=200;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (DROP=_WARN_ RENAME=(p_&Y = p_nn4&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn4_cn;

%MACRO nn5_cn(
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
   HIDDEN 5;
   TRAIN OUTMODEL = nnmod MAXITER=200;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (DROP=_WARN_ RENAME=(p_&Y = p_nn5&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn5_cn;

%MACRO nn15_cn(
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
   HIDDEN 15;
   TRAIN OUTMODEL = nnmod MAXITER=200;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (DROP=_WARN_ RENAME=(p_&Y = p_nn15&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn15_cn;

%MACRO nn15_2_cn(
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
   HIDDEN 15;
   HIDDEN 15;
   TRAIN OUTMODEL = nnmod MAXITER=2000;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (DROP=_WARN_ RENAME=(p_&Y = p_nn15_2&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn15_2_cn;


%MACRO nn5_5_cn(
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
   HIDDEN 5;
   HIDDEN 5;
   TRAIN OUTMODEL = nnmod MAXITER=200;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (DROP=_WARN_ RENAME=(p_&Y = p_nn5_5&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn5_5_cn;

%MACRO nn6_cn(
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
   HIDDEN 6;
   TRAIN OUTMODEL = nnmod;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (DROP=_WARN_ RENAME=(p_&Y = p_nn6&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn6_cn;


/******************************************************************************************
neural net classification
******************************************************************************************/


%MACRO nn15_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* neural network classification*/
  &suppresswarn %__SLwarning(%str(This functionality (neural networks) is still experimental));
  

  PROC HPNEURAL DATA = &indata  ;
   ODS SELECT NONE;
    TARGET &Y / LEVEL = NOM;
   %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
        INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = NOM;;
   %IF (&continuous_predictors~=) %THEN 
         INPUT &continuous_predictors / LEVEL = INT;;
   HIDDEN 15;
   TRAIN OUTMODEL = nnmod MAXITER=200;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (drop = I_&Y p_&Y.0 RENAME=(p_&Y.1 = p_nn15&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn15_in;

%MACRO nn15_2_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* neural network classification*/
  &suppresswarn %__SLwarning(%str(This functionality (neural networks) is still experimental));
  

  PROC HPNEURAL DATA = &indata  ;
   ODS SELECT NONE;
    TARGET &Y / LEVEL = NOM;
   %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
        INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = NOM;;
   %IF (&continuous_predictors~=) %THEN 
         INPUT &continuous_predictors / LEVEL = INT;;
   HIDDEN 15;
   HIDDEN 15;
   TRAIN OUTMODEL = nnmod MAXITER=2000;
  PROC HPNEURAL DATA = &indata;
   SCORE OUT=&outdata (drop = I_&Y p_&Y.0 RENAME=(p_&Y.1 = p_nn15_2&SUFF)) MODEL = nnmod;
   ID _ALL_;
  RUN;
  PROC SQL; DROP TABLE nnmod; QUIT;
%MEND nn15_2_in;

/******************************************************************************************
loess:
 smoothing: 0.75, 0.5, 0.25, 0.1
******************************************************************************************/
%MACRO loess75_cn(      
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /* local regression*/ 
PROC LOESS DATA = &indata;
 MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / SMOOTH=0.75;
 OUTPUT OUT = &OUTDATA(DROP=smoothingparameter depvar obs) P=p_loess75&SUFF; /*change predicted value name with p_[libraryname]&suff*/
RUN;  
%MEND loess75_cn; 

%MACRO loess50_cn(      
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /* local regression*/ 
PROC LOESS DATA = &indata;
 MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / SMOOTH=0.5;
 OUTPUT OUT = &OUTDATA(DROP=smoothingparameter depvar obs) P=p_loess50&SUFF; /*change predicted value name with p_[libraryname]&suff*/
RUN;  
%MEND loess50_cn; 

%MACRO loess25_cn(      
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /* local regression*/ 
PROC LOESS DATA = &indata;
 MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / SMOOTH=0.25;
 OUTPUT OUT = &OUTDATA(DROP=smoothingparameter depvar obs) P=p_loess25&SUFF; /*change predicted value name with p_[libraryname]&suff*/
RUN;  
%MEND loess25_cn; 

%MACRO loess10_cn(      
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
 /* local regression*/ 
PROC LOESS DATA = &indata;
 MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / SMOOTH=0.1;
 OUTPUT OUT = &OUTDATA(DROP=smoothingparameter depvar obs) P=p_loess10&SUFF; /*change predicted value name with p_[libraryname]&suff*/
RUN;  
%MEND loess10_cn; 




/******************************************************************************************
CART:
 cost complexity: max number of leaves
 ALL, 25, 10
 
******************************************************************************************/


%MACRO cartALL_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* regression tree, no cross validation */
  
  &suppresswarn %__SLwarning(%str(This function (CART) is untested below SAS 9.4 TS1M3));
  PROC HPSPLIT DATA=&indata SEED=&seed  CVMETHOD=NONE ;
   ODS SELECT NONE;
   TARGET &Y / LEVEL = interval;
   %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
        INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
   %IF (&continuous_predictors~=) %THEN 
         INPUT &continuous_predictors / LEVEL = interval;;
   ID _ALL_;
   PRUNE COSTCOMPLEXITY (LEAVES=ALL);
   OUTPUT out=&outdata (drop =  _node_ _leaf_ RENAME=(p_&Y = p_cartALL&SUFF));
  RUN;
%MEND cartALL_cn;

%MACRO cart25_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* regression tree, no cross validation */
  
  &suppresswarn %__SLwarning(%str(This function (CART) is untested below SAS 9.4 TS1M3));
  PROC HPSPLIT DATA=&indata SEED=&seed  CVMETHOD=NONE ;
   ODS SELECT NONE;
   TARGET &Y / LEVEL = interval;
   %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
        INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
   %IF (&continuous_predictors~=) %THEN 
         INPUT &continuous_predictors / LEVEL = interval;;
   ID _ALL_;
   PRUNE COSTCOMPLEXITY (LEAVES=25);
   OUTPUT out=&outdata (drop =  _node_ _leaf_ RENAME=(p_&Y = p_cart25&SUFF));
  RUN;
%MEND cart25_cn;


%MACRO cart10_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* regression tree, no cross validation */
  
  &suppresswarn %__SLwarning(%str(This function (CART) is untested below SAS 9.4 TS1M3));
  PROC HPSPLIT DATA=&indata SEED=&seed  CVMETHOD=NONE ;
   ODS SELECT NONE;
   TARGET &Y / LEVEL = interval;
   %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
        INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
   %IF (&continuous_predictors~=) %THEN 
         INPUT &continuous_predictors / LEVEL = interval;;
   ID _ALL_;
   PRUNE COSTCOMPLEXITY (LEAVES=10);
   OUTPUT out=&outdata (drop =  _node_ _leaf_ RENAME=(p_&Y = p_cart10&SUFF));
  RUN;
%MEND cart10_cn;


%MACRO cart05_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* regression tree, no cross validation */
  
  &suppresswarn %__SLwarning(%str(This function (CART) is untested below SAS 9.4 TS1M3));
  PROC HPSPLIT DATA=&indata SEED=&seed  CVMETHOD=NONE ;
   ODS SELECT NONE;
   TARGET &Y / LEVEL = interval;
   %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
        INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
   %IF (&continuous_predictors~=) %THEN 
         INPUT &continuous_predictors / LEVEL = interval;;
   ID _ALL_;
   PRUNE COSTCOMPLEXITY (LEAVES=5);
   OUTPUT out=&outdata (drop =  _node_ _leaf_ RENAME=(p_&Y = p_cart10&SUFF));
  RUN;
%MEND cart05_cn;

/******************************************************************************************
random forest:
 Prune fraction (obs avai
10, 25, 50
******************************************************************************************/


%MACRO rf10_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* RANDOM FOREST, continuous */
  
  &suppresswarn %__SLwarning(%str(This routine requires AT LEAST SAS 9.4 TS1M3 with high powered data mining procedures enabled));
  PROC HPFOREST DATA=&indata SEED=&seed  /*PRESELECT=BINNEDSEARCH SCOREPROLE=OOB*/  MAXTREES = 100 IMPORTANCE=NO INBAGFRACTION=0.6 PRUNEFRACTION=0.1;
   ODS SELECT NONE;
   TARGET &Y / LEVEL = interval;
   %IF (&binary_predictors~=) %THEN INPUT &binary_predictors / LEVEL = binary;;
   %IF (&ordinal_predictors~=) %THEN INPUT &ordinal_predictors / LEVEL = ordinal;;
   %IF (&nominal_predictors~=) %THEN INPUT &nominal_predictors / LEVEL = nominal;;
   %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
   SCORE out=&outdata (drop = _Warn_ R_&Y RENAME=(p_&Y = p_rf10&SUFF));
   ID _ALL_;
  RUN;
  /* to do: expand to out of data prediction using HP4score */
%MEND rf10_cn;

%MACRO rf25_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* RANDOM FOREST, continuous */
  
  &suppresswarn %__SLwarning(%str(This routine requires AT LEAST SAS 9.4 TS1M3 with high powered data mining procedures enabled));
  PROC HPFOREST DATA=&indata SEED=&seed  /*PRESELECT=BINNEDSEARCH SCOREPROLE=OOB*/  MAXTREES = 100 IMPORTANCE=NO INBAGFRACTION=0.6 PRUNEFRACTION=0.25;
   ODS SELECT NONE;
   TARGET &Y / LEVEL = interval;
   %IF (&binary_predictors~=) %THEN INPUT &binary_predictors / LEVEL = binary;;
   %IF (&ordinal_predictors~=) %THEN INPUT &ordinal_predictors / LEVEL = ordinal;;
   %IF (&nominal_predictors~=) %THEN INPUT &nominal_predictors / LEVEL = nominal;;
   %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
   SCORE out=&outdata (drop = _Warn_ R_&Y RENAME=(p_&Y = p_rf25&SUFF));
   ID _ALL_;
  RUN;
  /* to do: expand to out of data prediction using HP4score */
%MEND rf25_cn;

%MACRO rf50_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* RANDOM FOREST, continuous */
  
  &suppresswarn %__SLwarning(%str(This routine requires AT LEAST SAS 9.4 TS1M3 with high powered data mining procedures enabled));
  PROC HPFOREST DATA=&indata SEED=&seed  /*PRESELECT=BINNEDSEARCH SCOREPROLE=OOB*/  MAXTREES = 100 IMPORTANCE=NO INBAGFRACTION=0.6 PRUNEFRACTION=0.5;
   ODS SELECT NONE;
   TARGET &Y / LEVEL = interval;
   %IF (&binary_predictors~=) %THEN INPUT &binary_predictors / LEVEL = binary;;
   %IF (&ordinal_predictors~=) %THEN INPUT &ordinal_predictors / LEVEL = ordinal;;
   %IF (&nominal_predictors~=) %THEN INPUT &nominal_predictors / LEVEL = nominal;;
   %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
   SCORE out=&outdata (drop = _Warn_ R_&Y RENAME=(p_&Y = p_rf50&SUFF));
   ID _ALL_;
  RUN;
  /* to do: expand to out of data prediction using HP4score */
%MEND rf50_cn;

/******************************************************************************************
bootstrap aggregation of regression trees:
 complexity  = 0.1, 0.01, 0.00
 min split = 5
******************************************************************************************/
%MACRO bagging00_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* bootstrap aggregation*/
  &suppresswarn %__SLwarning(%str(This function (bagging) is experimental and untested below SAS 9.4 TS1M3));
  /*%LET modopts = %STR(SEED = 1232 MINCATSIZE=2 MAXTREES = 200 TrainProportion = .60 Criterion=Variance Minworth=0.00 SplitSize=5 
     Maxbranch=2 MAXDEPTH=30 MAXSURROGATES=0);*/
  %LET modopts = %STR(Criterion=Variance Minworth=0.00);
  PROC ARBOR PROC=BAG DATA = &indata &modopts;
   TARGET &Y / LEVEL=INTERVAL;
     %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
     %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
   SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_bagging00&SUFF) DROP = r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &indata;
    CHANGE __sltm0017_=&indata ;
   QUIT;
  RUN;
%MEND bagging00_cn;


%MACRO bagging01_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* bootstrap aggregation*/
  &suppresswarn %__SLwarning(%str(This function (bagging) is experimental and untested below SAS 9.4 TS1M3));
  /*%LET modopts = %STR(SEED = 1232 MINCATSIZE=2 MAXTREES = 200 TrainProportion = .60 Criterion=Variance Minworth=0.00 SplitSize=5 
     Maxbranch=2 MAXDEPTH=30 MAXSURROGATES=0);*/
  %LET modopts = %STR(Criterion=Variance Minworth=0.01);
  PROC ARBOR PROC=BAG DATA = &indata &modopts;
   TARGET &Y / LEVEL=INTERVAL;
     %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
     %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
   SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_bagging01&SUFF) DROP = r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &indata;
    CHANGE __sltm0017_=&indata ;
   QUIT;
  RUN;
%MEND bagging01_cn;

%MACRO bagging10_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* bootstrap aggregation*/
  &suppresswarn %__SLwarning(%str(This function (bagging) is experimental and untested below SAS 9.4 TS1M3));
  /*%LET modopts = %STR(SEED = 1232 MINCATSIZE=2 MAXTREES = 200 TrainProportion = .60 Criterion=Variance Minworth=0.00 SplitSize=5 
     Maxbranch=2 MAXDEPTH=30 MAXSURROGATES=0);*/
  %LET modopts = %STR(Criterion=Variance Minworth=0.10);
  PROC ARBOR PROC=BAG DATA = &indata &modopts;
   TARGET &Y / LEVEL=INTERVAL;
     %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
     %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
   SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_bagging10&SUFF) DROP = r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &indata;
    CHANGE __sltm0017_=&indata ;
   QUIT;
  RUN;
%MEND bagging10_cn;

%MACRO baggingms5_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* bootstrap aggregation*/
  &suppresswarn %__SLwarning(%str(This function (bagging) is experimental and untested below SAS 9.4 TS1M3));
  /*%LET modopts = %STR(SEED = 1232 MINCATSIZE=2 MAXTREES = 200 TrainProportion = .60 Criterion=Variance Minworth=0.00 SplitSize=5 
     Maxbranch=2 MAXDEPTH=30 MAXSURROGATES=0);*/
  %LET modopts = %STR(SplitSize=5);
  PROC ARBOR PROC=BAG DATA = &indata &modopts;
   TARGET &Y / LEVEL=INTERVAL;
     %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
     %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
   SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_baggingms5&SUFF) DROP = r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &indata;
    CHANGE __sltm0017_=&indata ;
   QUIT;
  RUN;
%MEND baggingms5_cn;




/******************************************************************************************
boosting of regression trees 
 max depth  = 2 4 (default) 10
******************************************************************************************/

%MACRO boost10_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* gradient boosting*/
  &suppresswarn %__SLwarning(%str(This function (BOOST) is untested below SAS 9.4 TS1M3));
  /*%LET modopts = %STR(HUBER=1 Iterations=1000 TrainProportion = .60 SHRINKAGE=0.1 LeafFraction=0.1 MinCatsize=2 Maxbranch=2
        MAXDEPTH=2);*/
  %LET modopts = %STR(SHRINKAGE=.10);
  PROC ARBOR PROC=TREEBOOST DATA = &indata &modopts;
   TARGET &Y / LEVEL=INTERVAL;
     %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
     %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
   SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_boost10&SUFF) DROP =  r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &indata;
    CHANGE __sltm0017_=&indata ;
   QUIT;
  RUN;
%MEND boost10_cn;


%MACRO boost20_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* gradient boosting*/
  &suppresswarn %__SLwarning(%str(This function (BOOST) is untested below SAS 9.4 TS1M3));
  /*%LET modopts = %STR(HUBER=1 Iterations=1000 TrainProportion = .60 SHRINKAGE=0.1 LeafFraction=0.1 MinCatsize=2 Maxbranch=2
        MAXDEPTH=2);*/
  %LET modopts = %STR(SHRINKAGE=.20);
  PROC ARBOR PROC=TREEBOOST DATA = &indata &modopts;
   TARGET &Y / LEVEL=INTERVAL;
     %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
     %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
   SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_boost20&SUFF) DROP =  r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &indata;
    CHANGE __sltm0017_=&indata ;
   QUIT;
  RUN;
%MEND boost20_cn;


%MACRO boost40_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* gradient boosting*/
  &suppresswarn %__SLwarning(%str(This function (BOOST) is untested below SAS 9.4 TS1M3));
  /*%LET modopts = %STR(HUBER=1 Iterations=1000 TrainProportion = .60 SHRINKAGE=0.1 LeafFraction=0.1 MinCatsize=2 Maxbranch=2
        MAXDEPTH=2);*/
  %LET modopts = %STR(SHRINKAGE=0.05);
  PROC ARBOR PROC=TREEBOOST DATA = &indata &modopts;
   TARGET &Y / LEVEL=INTERVAL;
     %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
     %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
   SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_boost40&SUFF) DROP =  r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &indata;
    CHANGE __sltm0017_=&indata ;
   QUIT;
  RUN;
%MEND boost40_cn;



/******************************************************************************************
sherwood 
 defaults
******************************************************************************************/

%MACRO sherwoodb_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Random forest, with replacement*/
  &suppresswarn %__SLwarning(%str(This function (bagging) is experimental and untested below SAS 9.4 TS1M3));
/*%LET modopts = %STR(SEED = 1232 MAXTREES=100 TrainProportion = .60 LeafFraction=0.1 MinCatsize=5 Maxbranch=2
        MAXDEPTH=30 WITHREP CRITERION=VARIANCE);*/
  %LET modopts = %STR(WITHREP);
  PROC ARBOR PROC=SHERWOOD DATA = &indata &modopts;
   TARGET &Y / LEVEL=INTERVAL;
     %IF (&ordinal_predictors~=) OR (&binary_predictors~=) OR (&nominal_predictors~=) %THEN 
          INPUT &binary_predictors &ordinal_predictors &nominal_predictors / LEVEL = nominal;;
     %IF (&continuous_predictors~=) %THEN 
           INPUT &continuous_predictors / LEVEL = interval;;
   SCORE DATA=&indata  OUT=__sltm0017_(RENAME=(p_&Y = p_sherwoodb&SUFF) DROP = r_&Y  _warn_);
   PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE &indata;
    CHANGE __sltm0017_=&indata ;
   QUIT;
  RUN;
%MEND sherwoodb_cn;

/******************************************************************************************
sine function with knots
******************************************************************************************/
%MACRO skntemp_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,suff=,k=3, f=2, nm=temp);
 PROC NLMIXED DATA = &indata;
   kn = %EVAL(&k-3);
   f = &f;
   i1 = (&continuous_predictors<kn);
   i2 = (&continuous_predictors>=kn);
   mu = i1*(b1+b2*x) + i2*(b3 + b4*SIN(f*constant('pi')*x));
   llik = -log(sqrt(2*constant('pi'))*sig)-((&Y-mu)**2)/(2*sig**2);
   MODEL &Y ~ general(llik);
   PREDICT mu OUT=&OUTDATA(DROP = stderrpred df tvalue probt alpha lower upper RENAME=(PRED=p_skn&nm.&suff));
 RUN;
%MEND skntemp_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/

%MACRO skn11_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=1,f=1,nm=11, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn12_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=1,f=2,nm=12, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn13_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=1,f=3,nm=13, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn14_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=1,f=4,nm=14, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn21_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=2,f=1,nm=21, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn22_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=2,f=2,nm=22, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn23_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=2,f=3,nm=23, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn24_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=2,f=4,nm=24, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn31_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=3,f=1,nm=31, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn32_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=3,f=2,nm=32, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn33_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=3,f=3,nm=33, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn34_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=3,f=4,nm=34, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn41_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=4,f=1,nm=41, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn42_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=4,f=2,nm=42, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn43_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=4,f=3,nm=43, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn44_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=4,f=4,nm=44, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn51_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=5,f=1,nm=51, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn52_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=5,f=2,nm=52, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn53_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=5,f=3,nm=53, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;
%MACRO skn54_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %skntemp_cn(k=5,f=4,nm=54, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;



/******************************************************************************************
default paarameterization of random forests in SAS and R
******************************************************************************************/
%MACRO rfdef_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* RANDOM FOREST, continuous */
  
  &suppresswarn %__SLwarning(%str(This routine requires AT LEAST SAS 9.4 TS1M3 with high powered data mining procedures enabled));
  PROC HPFOREST DATA=&indata SEED=&seed ;
   ODS SELECT NONE;
   TARGET &Y / LEVEL = interval;
   %IF (&binary_predictors~=) %THEN INPUT &binary_predictors / LEVEL = binary;;
   %IF (&ordinal_predictors~=) %THEN INPUT &ordinal_predictors / LEVEL = ordinal;;
   %IF (&nominal_predictors~=) %THEN INPUT &nominal_predictors / LEVEL = nominal;;
   %IF (&continuous_predictors~=) %THEN INPUT &continuous_predictors / LEVEL = interval;;
   SCORE out=&outdata (drop = _Warn_ R_&Y RENAME=(p_&Y = p_rdeff&SUFF));
   ID _ALL_;
  RUN;
%MEND rfdef_cn;


%MACRO r_rfdef_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  
  %__SLnote(%str(R package 'randomForest' must be installed));;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(#set.seed(123));
  %LET rcodeb = %STR(rfmodf <- randomForest::randomForest%(y=mdata$&Y,x=mdata[-grep(%"&Y%", names(mdata))], xtest=rdata[-grep(%"&Y%", names(rdata))]%));
  %LET rcodec = %STR(p_r_rfdef&SUFF <- rfmodf$test$predicted);
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  DATA __sltm0016_;
   SET &indata;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_rfdef&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_rfdef_cn; 


/******************************************************************************************
deep neural networks;
******************************************************************************************/

%MACRO deepnntempl_cn(
                Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=, nhl=, fpl=
);
  /* 
  deep neural network regression
  */
  %LET icom = ;
  %LET ncom = ;
  %IF (&continuous_predictors=) %THEN %LET icom = *;;
  %IF (&ordinal_predictors=) AND (&binary_predictors=) AND (&nominal_predictors=) %THEN %LET ncom=*;;
  /* neural network regression*/
  DATA __sltm0017_; SET &indata;

  PROC DMDB BATCH DATA=__sltm0017_(WHERE=(&Y>.z)) DMDBCAT=__dmdb ;
    &ncom CLASS &binary_predictors &ordinal_predictors &nominal_predictors;;
    VAR &Y &continuous_predictors;
    TARGET &Y;
  RUN; QUIT;
  
  PROC NEURAL DATA=__sltm0017_(WHERE=(&Y>.z)) DMDBCAT=__dmdb random=12345;
    NLOPTIONS NOPRINT;
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
    SCORE DATA=__sltm0017_ OUT=&outdata(DROP= R_&Y E_&Y __nnl: %IF &continuous_predictors^= %THEN %__nndrop(&continuous_predictors); RENAME=(P_&Y=p_deepnn_&nhl._&fpl.&SUFF));
  RUN;
  PROC DATASETS LIBRARY=work NOPRINT NODETAILS ;
    DELETE __sltm0017_;
    DELETE __dmdb;
  QUIT;
%MEND deepnntempl_cn;


%MACRO deepnn_1_50_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=1, fpl=50, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_2_50_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=2, fpl=50, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_3_50_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=3, fpl=50, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_4_50_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=4, fpl=50, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_1_10_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=1, fpl=10, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_2_10_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=2, fpl=10, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_3_10_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=3, fpl=10, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_4_10_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=4, fpl=10, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_1_80_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=1, fpl=80, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_2_40_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=2, fpl=40, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_3_27_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=3, fpl=27, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_4_20_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=4, fpl=20, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_5_16_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=5, fpl=16, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;

%MACRO deepnn_6_13_cn(Y=,indata=, outdata=,binary_predictors=,ordinal_predictors=,nominal_predictors=,continuous_predictors=,weight=,id=,suff=,seed=);;
   %deepnntempl_cn(nhl=6, fpl=13, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);;
%MEND;


/******************************************************************************************
DSA algorithm in R;
******************************************************************************************/
%MACRO r_dsa_cn(Y=,
             indata=, 
             outdata=, 
             binary_predictors=, 
             ordinal_predictors=, 
             nominal_predictors=,  
             continuous_predictors=,
             suff=,
             seed=);
  
  %__SLnote(%str(R package 'DSApart' must be installed));;
  FILENAME rcode TEMP; *rsubmit requires use of include statement with code from file;
  * write R statements to file;
  %LET rcodea = %STR(SUBMIT / r;);
  %LET rcodem = %STR(mdata = rdata[!is.na(rdata$&Y),]);
  %LET rcodei = %STR(#set.seed(123));
  %LET rcodeb = %STR(dsafit = partDSA::partDSA(x=mdata[,-grep(%"&Y%", names(mdata))], y=mdata$&Y, control=DSA.control(vfold=10)));
  %LET rcodec = %STR(p_r_dsa&SUFF = apply(predict(dsafit, newdata1 = newX), 1, mean));
  %LET rcoded = %STR(ENDSUBMIT;);
  %LET rcode = &rcodea &rcodei &rcodem &rcodeb &rcodec &rcoded;
  DATA _null_;
   FILE rcode;
   PUT "&rcodea";PUT "&rcodem";PUT "&rcodei";PUT "&rcodeb";PUT "&rcodec";PUT "&rcoded";
  RUN;
  * limit data to just predictors and outcome;
  DATA __sltm0016_;
   SET &indata;
   KEEP &Y &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors;
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__sltm0016_", "rdata");
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r_dsa&SUFF" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds;
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_dsa_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_dsa_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);


/******************************************************************************************
Highly adaptive LASSO (HAL);
hal1, hal2, hal3, hal4
ahal1, ahal2, ahal3, ahal4

These are versions of 'hal' and 'ahal' that control the depth of interactions of
the basis functions, which are otherwise only limited by the number of variables
supplied to hal. E.g. hal3 includes only main terms, and all 2 and 3 way interaction terms 
******************************************************************************************/
%MACRO haltemplate_cn(deg=0,
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Highly adaptive LASSO model, selection by cross validation, minimizing CV residual sum of squares */
  %GetHALDesign(y=&y, vars=&binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors , 
                indata=&indata, outdata=__sltm0017_, drop=TRUE, intdepthlimit=&deg);
  OPTIONS MERGENOBY=NOWARN;
  DATA __sltm0016_;
   MERGE &indata(KEEP=&Y &weight) __sltm0017_;
  RUN;
  PROC GLMSELECT DATA = __sltm0016_ NOPRINT SEED=&seed;
    FORMAT &Y;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    ODS SELECT NONE;
    MODEL &Y = __hal_: / SELECTION=LASSO(CHOOSE=CVEX STOP=NONE) CVMETHOD=RANDOM(10);
    OUTPUT OUT =__sltm0016_(KEEP=p_hal&deg&SUFF) PRED=p_hal&deg&SUFF;
  RUN;
  DATA &outdata;
   MERGE &indata __sltm0016_;
  RUN;
  OPTIONS MERGENOBY=WARN;
%MEND haltemplate_cn;

%MACRO ahaltemplate_cn(deg=0,
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Highly adaptive LASSO model, selection by cross validation, minimizing CV residual sum of squares */
  %GetHALDesign(y=&y, vars=&binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors , 
                indata=&indata, outdata=__sltm0017_, drop=TRUE, intdepthlimit=&deg);
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
    OUTPUT OUT = __sltm0016_(KEEP=p_ahal&deg&SUFF) p = p_ahal&deg&SUFF; 
  RUN;;
  DATA &outdata;
   MERGE &indata __sltm0016_;
  RUN;
  OPTIONS MERGENOBY=WARN;
%MEND ahaltemplate_cn;

%MACRO ahaltemplate_in(deg=0,
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* Highly adaptive LASSO model, selection by cross validation, minimizing CV residual sum of squares */
  %GetHALDesign(y=&y, vars=&binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors , 
                indata=&indata, outdata=__sltm0017_, drop=TRUE, intdepthlimit=&deg);
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
    OUTPUT OUT = __sltm0016_(KEEP=p_ahal&deg&SUFF) p = p_ahal&deg&SUFF; 
  RUN;;
  DATA &outdata;
   MERGE &indata __sltm0016_;
  RUN;
  OPTIONS MERGENOBY=WARN;
%MEND ahaltemplate_in;


/* Gaussian link */
%MACRO hal1_cn(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %haltemplate_cn(deg=1, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND hal1_cn;

%MACRO hal2_cn(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %haltemplate_cn(deg=2, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND hal2_cn;

%MACRO hal3_cn(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %haltemplate_cn(deg=3, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND hal3_cn;

%MACRO hal4_cn(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %haltemplate_cn(deg=4, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND hal4_cn;

%MACRO ahal1_cn(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %ahaltemplate_cn(deg=1, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND ahal1_cn;

%MACRO ahal2_cn(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %ahaltemplate_cn(deg=2, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND ahal2_cn;

%MACRO ahal3_cn(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %ahaltemplate_cn(deg=3, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND ahal3_cn;

%MACRO ahal4_cn(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %ahaltemplate_cn(deg=4, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND ahal4_cn;


/* bernoulli link: note this is just a wrapper for the continuous version and does not respect the sample space boundaries */
%MACRO hal1_in(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
  %__SLwarning(%str(HAL does not resepect the 0/1 probability space and should be used with extreme caution (Try using the 'ahal' learner)));
   %haltemplate_cn(deg=1, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND hal1_in;

%MACRO hal2_in(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
  %__SLwarning(%str(HAL does not resepect the 0/1 probability space and should be used with extreme caution (Try using the 'ahal' learner)));
   %haltemplate_cn(deg=2, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND hal2_in;

%MACRO hal3_in(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
  %__SLwarning(%str(HAL does not resepect the 0/1 probability space and should be used with extreme caution (Try using the 'ahal' learner)));
   %haltemplate_cn(deg=3, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND hal3_in;

%MACRO hal4_in(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
  %__SLwarning(%str(HAL does not resepect the 0/1 probability space and should be used with extreme caution (Try using the 'ahal' learner)));
   %haltemplate_cn(deg=4, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND hal4_in;


%MACRO ahal1_in(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %ahaltemplate_in(deg=1, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND ahal1_in;

%MACRO ahal2_in(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %ahaltemplate_in(deg=2, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND ahal2_in;

%MACRO ahal3_in(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %ahaltemplate_in(deg=3, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND ahal3_in;

%MACRO ahal4_in(Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
                );
   %ahaltemplate_in(deg=4, Y=&Y ,indata=&indata , outdata=&outdata , binary_predictors=&binary_predictors ,ordinal_predictors=&ordinal_predictors ,nominal_predictors=&nominal_predictors ,continuous_predictors=&continuous_predictors, weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND ahal4_in;


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


/******************************************************************************************
generalized weighte quantile sums regression;
r_gwqs3 r_gwqs10 r_gwqs20 r_gwqs50 

These are versions of 'r_gwqs' that control the number of bootstrap
iterations used in calculating the weights 
******************************************************************************************/


%MACRO r_gwqstempl_cn(b=100,
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
   PUT 'SUBMIT y w b seed/ R;';
   PUT 'mdata = rdata[!is.na(rdata[, "&Y" ]),]';
   PUT 'set.seed(&seed)';
   PUT 'suppressWarnings(suppressMessages(library("SLmix")))';
   PUT 'Y = mdata[,"&Y"]';
   PUT 'X = mdata[,-grep(paste0("&y", "|", "&w"), names(mdata))]';
   PUT 'nm = names(X)';
   PUT 'Xfl = rdata[,-grep(paste0("&y", "|", "&w"), names(rdata))]';
   PUT 'X$Y = Y';
   *PUT 'W = mdata[,"&w"]';
   PUT 'suppressWarnings(suppressMessages(rmod <- ml.gwqs(Y ~ NULL, mix_name=nm, data=X, q = 4, b=&b, b1_pos=TRUE, family="gaussian")))';
   PUT 'p_r <- predict(fit=rmod, mix_name=nm, newdata=Xfl)';
   PUT 'ENDSUBMIT;';
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__SLtm0016_", "rdata");
   y = "&y";
   w = "&weight";
   seed = "&seed";
   b="&b";
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds(RENAME=(p_r = p_r_gwqs&b&SUFF));
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_gwqstempl_cn; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_gwqstempl_cn(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);


%MACRO r_gwqstempl_in(b=100,
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
   PUT 'SUBMIT y w b seed/ R;';
   PUT 'mdata = rdata[!is.na(rdata[, "&Y" ]),]';
   PUT 'set.seed(&seed)';
   PUT 'suppressWarnings(suppressMessages(library("SLmix")))';
   PUT 'Y = mdata[,"&Y"]';
   PUT 'X = mdata[,-grep(paste0("&y", "|", "&w"), names(mdata))]';
   PUT 'nm = names(X)';
   PUT 'Xfl = rdata[,-grep(paste0("&y", "|", "&w"), names(rdata))]';
   PUT 'X$Y = Y';
   *PUT 'W = mdata[,"&w"]';
   PUT 'suppressWarnings(suppressMessages(rmod <- ml.gwqs(Y ~ NULL, mix_name=nm, data=X, q = 4, b=&b, b1_pos=TRUE, family="binomial")))';
   PUT 'p_r <- predict(fit=rmod, mix_name=nm, newdata=Xfl)';
   PUT 'ENDSUBMIT;';
  RUN;
  /*%PUT &rcode ;*/
  PROC IML;
   RUN ExportDataSetToR("Work.__SLtm0016_", "rdata");
   y = "&y";
   w = "&weight";
   seed = "&seed";
   b="&b";
   %INCLUDE rcode;
   CALL ImportDatasetFromR("work.__rpreds", "p_r" );
  QUIT;
  OPTIONS MERGENOBY=NOWARN;
  DATA &outdata;
    MERGE &indata __rpreds(RENAME=(p_r = p_r_gwqs&b&SUFF));
  RUN;
  OPTIONS MERGENOBY=WARN;
  PROC SQL NOPRINT; DROP TABLE __rpreds; QUIT;
%MEND r_gwqstempl_in; /*optional: include macro name in mend statement with [libraryname]_cn*/
*%r_gwqstempl_in(Y=y,indata=train, outdata=tdat, binary_predictors=a z2, ordinal_predictors=, nominal_predictors=,  continuous_predictors=z1 z3,suff=test);



%MACRO r_gwqs3_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %r_gwqstempl_cn(B=3, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND r_gwqs3_cn;

%MACRO r_gwqs10_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %r_gwqstempl_cn(B=10, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND r_gwqs10_cn;

%MACRO r_gwqs20_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %r_gwqstempl_cn(B=20, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND r_gwqs20_cn;

%MACRO r_gwqs50_cn(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %r_gwqstempl_cn(B=50, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND r_gwqs50_cn;



%MACRO r_gwqs3_in(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %r_gwqstempl_in(B=3, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND r_gwqs3_in;

%MACRO r_gwqs10_in(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %r_gwqstempl_in(B=10, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND r_gwqs10_in;

%MACRO r_gwqs20_in(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %r_gwqstempl_in(B=20, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND r_gwqs20_in;

%MACRO r_gwqs50_in(Y=,indata=, outdata=, binary_predictors=, ordinal_predictors=, nominal_predictors=,  continuous_predictors=,weight=,id=,suff=,seed=);
      %r_gwqstempl_in(B=50, Y=&Y,indata=&indata, outdata=&outdata, binary_predictors=&binary_predictors, ordinal_predictors=&ordinal_predictors, 
      nominal_predictors=&nominal_predictors,  continuous_predictors=&continuous_predictors,weight=&weight,id=&id,suff=&suff,seed=&seed);
%MEND r_gwqs50_in;


/******************************************************************************************
Fast mars
******************************************************************************************/


%MACRO fastmars_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* multivariate adaptive regression splines */
  PROC ADAPTIVEREG DATA = &indata SEED=&seed;
    FORMAT &Y;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y.(DESCENDING) = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / LINK=LOGIT DIST=BINOMIAL DFPERBASIS=2 FAST;
    OUTPUT OUT = &OUTDATA PRED=p_fastmars&SUFF;
  RUN;
  DATA &outdata;
   SET &outdata;
   p_fastmars&SUFF = EXPIT(p_fastmars&SUFF);
%MEND fastmars_in;

%MACRO fastmars_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* multivariate adaptive regression splines, continuous */
  PROC ADAPTIVEREG DATA = &indata SEED=&seed;
    FORMAT &Y;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors / LINK=ID DFPERBASIS=2  FAST;
    OUTPUT OUT = &OUTDATA PRED=p_fastmars&SUFF;
  RUN;
%MEND fastmars_cn;

%MACRO fastmarsint_in(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* multivariate adaptive regression splines, including interactions */
  PROC ADAPTIVEREG DATA = &indata SEED=&seed;
    FORMAT &Y;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y.(DESCENDING) = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / LINK=LOGIT DIST=BINOMIAL DFPERBASIS=2  FAST;
    OUTPUT OUT = &OUTDATA PRED=p_fastmarsint&SUFF;
  RUN;
  DATA &outdata;
   SET &outdata;
   p_fastmarsint&SUFF = EXPIT(p_fastmarsint&SUFF);
  RUN;
%MEND fastmarsint_in;

%MACRO fastmarsint_cn(
                Y=, indata=, outdata=, binary_predictors=, ordinal_predictors=, 
                nominal_predictors=,  continuous_predictors=, weight=, id=, suff=, seed=
);
  /* multivariate adaptive regression splines, continuous including interactions */
  PROC ADAPTIVEREG DATA = &indata SEED=&seed;
    FORMAT &Y;
    %IF ((&binary_predictors~=) OR (&ordinal_predictors~=) OR (&nominal_predictors~=)) %THEN CLASS &binary_predictors &ordinal_predictors &nominal_predictors ;;
    %IF &WEIGHT^= %THEN WEIGHT &weight;;
    MODEL &Y = &binary_predictors &ordinal_predictors &nominal_predictors &continuous_predictors &SLIXterms / LINK=ID DFPERBASIS=2  FAST;
    OUTPUT OUT = &OUTDATA PRED=p_fastmarsint&SUFF;
  RUN;
%MEND fastmarsint_cn;
