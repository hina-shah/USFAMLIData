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
	create table temp_&biomvname._unique as
	select distinct(tagcontent), filename, PatientID, studydttm
	from temp_&biomvname
	group by filename
	order by filename;
	
	* delete not needed tables;
	proc delete data=temp_&biomvname;
	run;
	
	* Create columns for each biometry measurement;
	proc sort data= temp_&biomvname._unique out=WORK.SORTTempTableSorted;
		by PatientID studydttm filename;
	run;
	
	proc transpose data=WORK.SORTTempTableSorted prefix=&shortname 
			out=WORK.&biomvname(drop=_Name_);
		var tagcontent;
		by PatientID studydttm filename;
	run;
	
	* Convert data to numerical values, and convert mms to cms;
	data famdat.&biomvname (drop=i pos posmm);
	set work.&biomvname;
	array biomvars &shortname.:;
	do i=1 to dim(biomvars);
		if not missing(biomvars{i}) then
		do;
			pos = find(biomvars{i}, 'cm', 'it') + find(biomvars{i}, 'centimeter', 'it');
			if pos = 0 then 
			do;
				posmm = find(biomvars{i}, 'mm', 'it') + find(biomvars{i}, 'millimeter', 'it');
				if posmm > 0 then 
				do;
				    put biomvars{i};
					biomvars{i} = compress(biomvars{i},'','A')/10.0;
				end;
			end;
			else biomvars{i} = compress(biomvars{i},'','A');
		end; 
	end;
	run;

	proc delete data=WORK.SORTTempTableSorted WORK.&biomvname;
	run;


%mend;


data famdat.biomvar_details;
length tagname $ 25;
length varname $ 20;
length shortname $ 4;
infile datalines delimiter=','; 
input tagname $ varname $ shortname $;
call execute( catt('%createTable(biometry=', tagname, ', biomvname=', varname, ', shortname=', shortname, ');'));
datalines;
Femur Length,biom_femur_length,fl
Biparietal Diameter,biom_bip_diam,bp
Head Circumference,biom_head_circ,hc
Crown Rump Length,biom_crown_rump,crl
Abdominal Circumference,biom_abd_circ,ac
Trans Cerebellar Diameter,biom_trans_cer_diam,tcd
;
run;
