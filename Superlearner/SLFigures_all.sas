%let serverpath = H:/Users/hinashah;
%let lib_path = &serverpath./SASFiles/SLData_Del923;

libname sldat "&lib_path.";

%let indata=sldat.sl_out_cat3tr;
%let biomdata = sldat.sl_out_biom_cat3tr;
%let gendata = sldat.sl_out__cat3trg;
%let suff = all_together;

ods listing gpath="&lib_path/" image_dpi=150;


	data new_one (keep=category diff absdiff sqerr testtrain gt_week);
	set &indata.;
		label testtrain='Set';
		label category='Method';
		length category $25;
		category='SuperLearner';
		diff = diffsl;
		absdiff = absdiffsl;
		sqerr = sesl;
		gt_week = ga_edd_weeks;
		if __train = 1 then testtrain = 'Train'; else testtrain = 'Test';
		output;

		category='Hadlock';
		diff = diffhadlock;
		absdiff = absdiffhadlock;
		sqerr = sehadlock;
		gt_week = ga_edd_weeks;
		if __train = 1 then testtrain = 'Train'; else testtrain = 'Test';
		output;

		category='Intergrowth';
		diff = diffintergrowth;
		absdiff = absdiffintergrowth;
		sqerr = seintergrowth;
		gt_week = ga_edd_weeks;
		if __train = 1 then testtrain = 'Train'; else testtrain = 'Test';
		output;


		category='NICHD';
		diff = diffnichd;
		absdiff = absdiffnichd;
		sqerr = senichd;
		gt_week = ga_edd_weeks;
		if __train = 1 then testtrain = 'Train'; else testtrain = 'Test';
		output;
	run;
	

	data new_biom (keep=category diff absdiff sqerr testtrain gt_week);
	set &biomdata.;
		label testtrain='Set';
		label category='Method';
		length category $25;

		category='SuperLearner NoClinic';
		diff = diffsl;
		absdiff = absdiffsl;
		sqerr = sesl;
		gt_week = ga_edd_weeks;
		if __train = 1 then testtrain = 'Train'; else testtrain = 'Test';
		output;
	run;

	data new_gen (keep=category diff absdiff sqerr testtrain gt_week);
	set &gendata.;
		label testtrain='Set';
		label category='Method';
		length category $25;

		category='SuperLearner Gender';
		diff = diffsl;
		absdiff = absdiffsl;
		sqerr = sesl;
		gt_week = ga_edd_weeks;
		if __train = 1 then testtrain = 'Train'; else testtrain = 'Test';
		output;
	run;

	data new_one;
	set new_one new_biom new_gen;
	run;

	proc summary data=new_one nway;
		class testtrain category;
		var diff absdiff sqerr;
		output out=new_summary(drop=_:) mean=meandiff meanabsdiff meansqerr std=stddiff stdabsdiff stdsqerr;
	run;

	data for_panel;
		set new_one new_summary;
	run;

	data for_panel;
	set for_panel;
	rmse = sqrt(meansqerr);
	run;


	ods graphics/reset imagename="DiffBoxPlot&suff." border=off imagefmt=png;;
	proc sgpanel data=for_panel;
		panelby testtrain ;
		vbox diff/category=category nooutliers group=category datalabel transparency=0.3;
		scatter x=category y=meandiff / datalabel=meandiff markerattrs=(size=1px);
		rowaxis values= (-28 to 28 by 7) grid label='difference (days)';
		colaxis values = ('SuperLearner' 'SuperLearner NoClinic' 'SuperLearner Gender' 'Hadlock' 'Intergrowth' 'NICHD') label='learners';
		refline 0 / axis=Y lineattrs=(color=black thickness=1);
		colaxistable diff /X=category stat=mean label='mean' separator;
		title 'Difference from Ground Truth GA';
	run;

	ods graphics/reset imagename="AbsDiffBoxPlot&suff." border=off imagefmt=png;;
	proc sgpanel data=for_panel;
		panelby testtrain ;
		vbox absdiff/category=category nooutliers group=category datalabel transparency=0.3;
		scatter x=category y=meanabsdiff / datalabel=meanabsdiff markerattrs=(size=1px);
		rowaxis values= (0 to 35 by 7) grid label='absolute difference (days)';
		colaxis values = ('SuperLearner' 'SuperLearner NoClinic' 'SuperLearner Gender' 'Hadlock' 'Intergrowth' 'NICHD') label='learners';
		refline 0 / axis=Y lineattrs=(color=black thickness=1);
		colaxistable absdiff /X=category stat=mean label='mean' separator;
		title 'Absolute Difference from Ground Truth GA';
	run;
	
	ods graphics/reset imagename="SEBoxPlot&suff." border=off imagefmt=png;;
	proc sgpanel data=for_panel;
		panelby testtrain ;
		vbox sqerr/category=category nooutliers group=category datalabel transparency=0.3;
		scatter x=category y=meansqerr / datalabel=rmse markerattrs=(size=1px);
		rowaxis values= (0 to 280 by 7) grid label='squared difference of days';
		colaxis values = ('SuperLearner' 'SuperLearner NoClinic' 'SuperLearner Gender' 'Hadlock' 'Intergrowth' 'NICHD') label='learners';
		refline 0 / axis=Y lineattrs=(color=black thickness=1);
		colaxistable sqerr /X=category stat=mean label='mean' separator;
		title 'Squared Difference from Ground Truth GA';
	run;

	proc sql;
	select min(gt_week) into :minweek from new_one;
	select max(gt_week) into :maxweek from new_one;

/*	%if &maxweek < 28 %then %do;*/
/*		%let minweek=12;*/
/*		%let maxweek = 27;*/
/*	%end;*/
/*	%else %if &minweek >= 28 %then %do;*/
/*		%let minweek = 28;*/
/*		%let maxweek = 44;*/
/*	%end;*/
/*	%else %do;*/
/*		%let minweek = 12;*/
/*		%let maxweek = 44;*/
/*	%end;*/
/**/
/*	*/

	ods graphics/reset LOESSMAXOBS=50000 imagename="SL_GA_vs_Diff&suff." border=off imagefmt=png height=8in width=16in;;	
	proc sgpanel data=new_one ;
	panelby testtrain category / rows=2 columns=6 uniscale=all sort=data spacing=3 noborder novarname ;
	styleattrs datacontrastcolors=(red green orange yellow blue purple black azure cream);
	        scatter x = gt_week y = diff / markerattrs = (symbol=CircleFilled) transparency=0.7 group=testtrain ;
	        loess x = gt_week y = diff / nomarkers lineattrs=(thickness=3 color=blue) smooth=0.3;
	        ellipse x = gt_week y=diff / lineattrs = (color=purple);
	        rowaxis label="Difference (days)" values=(-35 to 35 by 5) offsetmin=0 offsetmax=0 grid;
	        colaxis label="Ground Truth GA (weeks)" values=(&minweek to &maxweek by 1) offsetmin=0 offsetmax=0 grid;
	        refline 0 / axis=y lineattrs=(color=black thickness=2);
	title 'Difference(Days) from the Ground Truth GA';
	run;
	ods graphics/reset;

	data sldat.new_summary;
	set new_summary;
	rmse = sqrt(meansqerr);
	run;

	%ds2csv(
    data= sldat.new_summary,
    runmode=b,
    labels=N,
    csvfile=&lib_path./Cat3TrimSumm.csv   
    );
