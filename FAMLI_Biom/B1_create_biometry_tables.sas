* Program to create the biometry table from B1 dataset structured reports table;

*libname famdat '/folders/myfolders/';

* Read the subset table;
%let famli_table = famdat.famli_b1_subset;

%macro createTable(biometry=, biomvname=, shortname=);
	* read the biometry tags;
	proc sql;
	create table temp_&biomvname (drop=Derivation Equation) as
	select filename, PatientID, studydttm, tagname, tagcontent, Derivation, Equation
	from &famli_table
	where missing(Derivation) and tagname = "&biometry";

	* Remove duplicate tag contents;
	create table WORK.temp_&biomvname._unique as
	select distinct(tagcontent), filename, PatientID, studydttm
	from temp_&biomvname
	group by filename
	order by filename;

	* delete not needed tables;
	proc delete data=temp_&biomvname;
	run;
	
	* Convert data to numerical values, and convert mms to cms;
	data WORK.temp_&biomvname._unique (drop=pos posmm tagcontent) ;
	set WORK.temp_&biomvname._unique;
	if not missing(tagcontent) then
		do;
			pos = find(tagcontent, 'cm', 'it') + find(tagcontent, 'centimeter', 'it');
			if pos = 0 then
			do;
				posmm = find(tagcontent, 'mm', 'it') + find(tagcontent, 'millimeter', 'it');
				if posmm > 0 then
				do;
				    put tagcontent;
				    tagcontent = compress(tagcontent,'','A')/10.0;
				end;
			end;
			else tagcontent = compress(tagcontent,'','A');
			num = input(tagcontent, 4.2);
		end;
	run;

	* Create columns for each biometry measurement;
	proc sort data= WORK.temp_&biomvname._unique out=WORK.SORTTempTableSorted;
		by PatientID studydttm filename;
	run;

	proc transpose data=WORK.SORTTempTableSorted prefix=&shortname
			out=WORK.&biomvname(drop=_Name_);
		var num;
		by PatientID studydttm filename;
	run;

	* Convert data to numerical values, and convert mms to cms;
	data famdat.&biomvname;
	set work.&biomvname;
	run;

	proc delete data=WORK.SORTTempTableSorted WORK.&biomvname WORK.temp_&biomvname._unique;
	run;

%mend;


data famdat.biomvar_details;
length tagname $ 27;
length varname $ 20;
length shortname $ 6;
infile datalines delimiter=',';
input tagname $ varname $ shortname $;
call execute( catt('%createTable(biometry=', tagname, ', biomvname=', varname, ', shortname=', shortname, ');'));
datalines;
Femur Length,biom_femur_length,fl_
Biparietal Diameter,biom_bip_diam,bp_
Head Circumference,biom_head_circ,hc_
Crown Rump Length,biom_crown_rump,crl_
Abdominal Circumference,biom_abd_circ,ac_
Trans Cerebellar Diameter,biom_trans_cer_diam,tcd_
AMNIOTIC FLUID INDEX LEN q1,afi_q1,afiq1_
AMNIOTIC FLUID INDEX LEN q2,afi_q2,afiq2_
AMNIOTIC FLUID INDEX LEN q3,afi_q3,afiq3_
AMNIOTIC FLUID INDEX LEN q4,afi_q4,afiq4_
Max Vertical Pocket,max_vp,mvp_
;
run;


