%macro create_panels(indata=,
					 suff=);

	data new_one (keep=category diff absdiff sqerr testtrain gt_week);
	set &indata.;
		label testtrain='Set';
		label category='Method';

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
	
	proc summary data=new_one nway;
		class testtrain category;
		var diff absdiff sqerr;
		output out=new_summary(drop=_:) mean=meandiff meanabsdiff meansqerr;
	run;

	data for_panel;
		set new_one new_summary;
	run;

	ods graphics/reset imagename="DiffBoxPlot&suff." border=off imagefmt=png;;
	proc sgpanel data=for_panel;
		panelby testtrain ;
		vbox diff/category=category nooutliers group=category datalabel transparency=0.3;
		scatter x=category y=meandiff / datalabel=meandiff markerattrs=(size=1px);
		rowaxis values= (-21 to 21 by 7) grid label='difference (days)';
		colaxis values = ('SuperLearner' 'Hadlock' 'Intergrowth' 'NICHD') label='learners';
		refline 0 / axis=Y lineattrs=(color=black thickness=1);
		colaxistable diff /X=category stat=mean label='mean' separator;
		title 'Difference from Ground Truth GA';
	run;

	ods graphics/reset imagename="AbsDiffBoxPlot&suff." border=off imagefmt=png;;
	proc sgpanel data=for_panel;
		panelby testtrain ;
		vbox absdiff/category=category nooutliers group=category datalabel transparency=0.3;
		scatter x=category y=meanabsdiff / datalabel=meanabsdiff markerattrs=(size=1px);
		rowaxis values= (0 to 21 by 7) grid label='absolute difference (days)';
		colaxis values = ('SuperLearner' 'Hadlock' 'Intergrowth' 'NICHD') label='learners';
		refline 0 / axis=Y lineattrs=(color=black thickness=1);
		colaxistable absdiff /X=category stat=mean label='mean' separator;
		title 'Absolute Difference from Ground Truth GA';
	run;
	
	ods graphics/reset imagename="SEBoxPlot&suff." border=off imagefmt=png;;
	proc sgpanel data=for_panel;
		panelby testtrain ;
		vbox sqerr/category=category nooutliers group=category datalabel transparency=0.3;
		scatter x=category y=meansqerr / datalabel=meansqerr markerattrs=(size=1px);
		rowaxis values= (0 to 150 by 7) grid label='squared difference of days';
		colaxis values = ('SuperLearner' 'Hadlock' 'Intergrowth' 'NICHD') label='learners';
		refline 0 / axis=Y lineattrs=(color=black thickness=1);
		colaxistable sqerr /X=category stat=mean label='mean' separator;
		title 'Squared Difference from Ground Truth GA';
	run;

	proc sql;
	select min(gt_week) into :minweek from new_one;
	select max(gt_week) into :maxweek from new_one;

	%if &maxweek < 28 %then %do;
		%let minweek=12;
		%let maxweek = 27;
	%end;
	%else %if &minweek >= 28 %then %do;
		%let minweek = 28;
		%let maxweek = 44;
	%end;
	%else %do;
		%let minweek = 12;
		%let maxweek = 44;
	%end;

	ods graphics/reset LOESSMAXOBS=50000 imagename="SL_GA_vs_Diff&suff." border=off imagefmt=png height=8in width=16in;;	
	proc sgpanel data=new_one ;
	panelby testtrain category / rows=2 columns=4 uniscale=all sort=data spacing=3 noborder novarname ;
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

%mend create_panels;
