
libname sldat 'F:\Users\hinashah\SASFiles\SLData';

ods pdf file='F:\Users\hinashah\SASFiles\SLData\Report_Table2.pdf';

%let sl_table = sldat.c;

*Look at output;
*proc contents data = &sl_table.;
proc corr data = &sl_table.;
    var ga_edd;
    with p_sl_full p_gam_full p_lasso_full p_rf_full p_nn_full;

*MSE;
data &sl_table.;
    set &sl_table.;
    slse = (ga_edd - p_sl_full)**2;
    diffsl = p_sl_full - ga_edd;
    diffhadlock = hadlock_ga - ga_edd;
    diffintergrowth = intergrowth_ga - ga_edd;
    absdiffsl = abs(diffsl);
    hadlockse = diffhadlock**2;
    intergrowthse = diffintergrowth**2;
proc means data = &sl_table. mean std median q1 q3;
    var ga_edd p_sl_full slse diffsl diffhadlock diffintergrowth;
run;

*Plots;
ods graphics/reset imagename="SL plot 3 (GA vs SL)" border=off imagefmt=png height=5in width=5in;
proc sgplot data = &sl_table. noautolegend noborder;
    title1; title2;
    scatter x = ga_edd y = diffsl / markerattrs = (color = green);
    yaxis label="Superlearner Difference" values=(100 to -300 by 50) offsetmin=0 offsetmax=0 grid;
    xaxis label="True value" values=(0 to 400 by 50) offsetmin=0 offsetmax=0 grid;
    refline 0 / axis=y lineattrs=(color=black thickness=2);
run;

ods graphics/reset imagename="SL plot 3 (GA vs Hadlock)" border=off imagefmt=png height=5in width=5in;
proc sgplot data = &sl_table. noautolegend noborder;
    title1; title2;
    scatter x = ga_edd y = diffhadlock / markerattrs = (color = green);
    yaxis label="Hadlock Difference" values=(100 to -300 by 50) offsetmin=0 offsetmax=0 grid;
    xaxis label="True value" values=(0 to 400 by 50) offsetmin=0 offsetmax=0 grid;
    refline 0 / axis=y lineattrs=(color=black thickness=2);
run;

ods graphics/reset imagename="SL plot 4 (GA vs Intergrowth)" border=off imagefmt=png height=5in width=5in;
proc sgplot data = &sl_table. noautolegend noborder;
    title1; title2;
    scatter x = ga_edd y = diffintergrowth / markerattrs = (color = green);
    yaxis label="Intergrowth Difference" values=(100 to -300 by 50) offsetmin=0 offsetmax=0 grid;
    xaxis label="True value" values=(0 to 400 by 50) offsetmin=0 offsetmax=0 grid;
    refline 0 / axis=y lineattrs=(color=black thickness=2);
run;

ods graphics/reset imagename="SL plot 6 (SL Diff Boxplot)" border=off imagefmt=png height=5in width=5in;
proc sgplot data=&sl_table.;
    vbox diffsl / fillattrs=(color=CXCAD5E5) name='Box';
    xaxis fitpolicy=splitrotate;
    yaxis grid;
run;
ods graphics/reset imagename="SL plot 7 (Hadlock Diff Boxplot)" border=off imagefmt=png height=5in width=5in;
proc sgplot data=&sl_table.;
    vbox diffhadlock / fillattrs=(color=CXCAD5E5) name='Box';
    xaxis fitpolicy=splitrotate;
    yaxis grid;
run;
ods graphics/reset imagename="SL plot 8 (Intergrowth Diff Boxplot)" border=off imagefmt=png height=5in width=5in;
proc sgplot data=&sl_table.;
    vbox diffintergrowth / fillattrs=(color=CXCAD5E5) name='Box';
    xaxis fitpolicy=splitrotate;
    yaxis grid;
run;

ods pdf close;
