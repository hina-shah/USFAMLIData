%let serverpath = P:/Users/hinashah;
%let lib_path = &serverpath./SASFiles/SLData_New;

%INCLUDE "&serverpath.\SASFiles\USFAMLIData\Superlearner\SLFigures.sas";

ods listing gpath="&lib_path/" image_dpi=200;
libname sldat "&lib_path.";

%let datsuff = _cat;
%let indata = sldat.sl_out&datsuff.;

%create_panels(indata= &indata., suff=&datsuff.);

ods pdf file="&lib_path.\SplitOutputAnalysis.pdf" startpage=no;

* Separate out hte 2nd and 3rd trimester data.;
data out_2tr_sub out_3tr_sub;
set &indata.;
if trimester = 0 then output out_2tr_sub;
else output out_3tr_sub;
run;

proc means data = out_2tr_sub mean std;
    title1 "Stats on the training set 2nd trim";
    where __train=1;
    var diffsl diffhadlock diffintergrowth diffnichd
                absdiffsl absdiffhadlock absdiffintergrowth absdiffnichd
                sesl sehadlock seintergrowth senichd;
run;

proc means data = out_2tr_sub mean std;
    title1 "Stats on the test set 2nd trim"; 
    where __train=0;
    var diffsl diffhadlock diffintergrowth diffnichd
                absdiffsl absdiffhadlock absdiffintergrowth absdiffnichd
                sesl sehadlock seintergrowth senichd;
run;

proc means data = out_3tr_sub mean std;
    title1 "Stats on the training set 3rd trim";
    where __train=1;
    var diffsl diffhadlock diffintergrowth diffnichd
                absdiffsl absdiffhadlock absdiffintergrowth absdiffnichd
                sesl sehadlock seintergrowth senichd;
run;

proc means data = out_3tr_sub mean std;
    title1 "Stats on the test set 3rd trim"; 
    where __train=0;
    var diffsl diffhadlock diffintergrowth diffnichd
                absdiffsl absdiffhadlock absdiffintergrowth absdiffnichd
                sesl sehadlock seintergrowth senichd;
run;

%create_panels(indata= out_2tr_sub, suff=_2trsub);
%create_panels(indata= out_3tr_sub, suff=_3trsub);

ods pdf close;
