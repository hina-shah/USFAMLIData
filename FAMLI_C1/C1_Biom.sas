* Program to create the biometry table from B1 dataset structured reports table;

%macro createTable(biometry=, biomvname=, shortname=, pattern=);
	* read the biometry tags;
	proc sql;
	create table temp_&biomvname (drop=Derivation Equation) as
		select distinct pid, StudyID, Container, tagname, tagcontent, Derivation, Equation
		from &famli_table
		where 
			Derivation='Mean' and 
			tagname = "&biometry" and
			prxmatch("/&pattern./",Container) > 0
	;
	
	select distinct Container 
	from temp_&biomvname;

	* Remove duplicate tag contents;
	create table WORK.temp_&biomvname._unique as
		select tagcontent, pid, StudyID
		from temp_&biomvname
		group by StudyID
		order by StudyID
	;

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
		by pid StudyID;
	run;

	proc transpose data=WORK.SORTTempTableSorted prefix=&shortname
			out=WORK.&biomvname(drop=_Name_);
		var num;
		by pid StudyID;
	run;

	* Convert data to numerical values, and convert mms to cms;
	data famdat.&biomvname.;
	set work.&biomvname;
	run;

	proc delete data=WORK.SORTTempTableSorted WORK.&biomvname WORK.temp_&biomvname._unique;
	run;

%mend;

data famdat.c1_biomvar_details;
length tagname $ 27;
length varname $ 20;
length shortname $ 6;
length pattern $ 45;
infile datalines delimiter=',';
input tagname $ varname $ shortname $ pattern $;
call execute( catt('%createTable(biometry=', tagname, ', biomvname=', varname, ', shortname=', shortname, ', pattern=', pattern, ');'));
datalines;
Femur Length,c1_biom_femur_length,fl_,Fetal Biometry: Biometry[ ]?Group
Biparietal Diameter,c1_biom_bip_diam,bp_,Fetal Biometry: Biometry[ ]?Group
Head Circumference,c1_biom_head_circ,hc_,Fetal Biometry: Biometry[ ]?Group
Abdominal Circumference,c1_biom_abd_circ,ac_,Fetal Biometry: Biometry[ ]?Group
Trans Cerebellar Diameter,c1_biom_trans_cer_diam,tcd_,Fetal Biometry: Biometry[ ]?Group
;
run;
