libname famdat 'F:\Users\hinashah\SASFiles';
libname epic 'F:\Users\hinashah\SASFiles\epic';

/********** PNDB **************/
* Extract gestational age information from the PNDB database;
proc sql;
	create table famdat.b1_ga_table_pndb as
	select Mom_EpicMRN as PatientID,
			M_PDT0101 as LMP,
			M_PDT0102 as EDC_LMP,
			M_PDT0103 as US_DATE,
			M_PDT0105 as US_EDC,
			M_PDT0106 as BEST_EDC,
			M_PDT0107 as Delivery_date
	from famdat.pndb_famli_records
	where not missing(Mom_EpicMRN);

data famdat.b1_ga_table_pndb (drop= gaus galmp eddlmp diffedds);
set famdat.b1_ga_table_pndb;
	if missing(BEST_EDC) then do;
		if not missing(US_DATE) and not missing(US_EDC) and not missing(LMP) then
		do;
			gaus = 280 - (US_EDC - US_DATE);
			galmp = US_DATE - LMP;
			eddlmp = lmp + 280;
			BEST_EDC = eddlmp;
			diffedds = abs(eddlmp - US_EDC);
			if (galmp < 62 and diffedds > 5) |
			(galmp < 111 and diffedds > 7) |
			(galmp < 153 and diffedds > 10) | 
			(galmp < 168 and diffedds >14) | 
			(galmp >= 169 and diffedds > 21)
			then
				BEST_EDC = US_EDC;
		end;
	end;
run;

/********** EPIC **************/

*Cleanup the ob dating data to have unique rows;
*study_id (in the download that I created) creates duplicates for each episode, dropping;
data ob_dating_epic_temp(drop=study_id);
	set epic.ob_dating;
run;
*remove any duplicates;
proc sql;
	create table ob_dating_epic as
	select distinct *
		from ob_dating_epic_temp;

proc sql;
*Count the number of times an episode (with line numbers) shows up in the table;
*make sure each episode shows up once;
	create table episode_counts as
	select pat_mrn_id, episode_id, count(*) as count
	from
	(
		select *
		from ob_dating_epic where line=1
	)
	group by pat_mrn_id, episode_id;

proc sql;
	select "count" label="Count of episodes",
		min(count) label="Minimum count",
		max(count) label="Maximum count" from episode_counts;
quit;

proc sql;
	select count(*) label='Count of all episodes' from
		(select distinct pat_mrn_id, episode_id from ob_dating_epic);
quit;

********** Last menstrual period table from epic;
proc sql;
	create table famdat.b1_epic_lmps as
	select pat_mrn_id, episode_id, line, ob_dating_event,
		sys_entered_date, user_entered_date,
		episode_working_edd
	from ob_dating_epic
	where ob_dating_event='LAST MENSTRUAL PERIOD';

	select count(*) label = 'Count of episodes with an LMP'
	from
	(
		select distinct pat_mrn_id, episode_id
		from famdat.b1_epic_lmps
	);

	*Select lmps with just the last lmp;
	create table famdat.b1_epic_lmps_last_entry as
	select a.pat_mrn_id, a.episode_id,
			a.user_entered_date as lmp format mmddyy10. label='Last Menstrual Period'
	from
		famdat.b1_epic_lmps as a
		inner join
		(
			select pat_mrn_id, episode_id, max(line) as max_line
			from famdat.b1_epic_lmps
			group by pat_mrn_id, episode_id
		) as b
		on a.pat_mrn_id = b.pat_mrn_id and a.episode_id = b.episode_id and a.line = max_line;

	select count(*) label = 'Count of episodes with an LMP at maxline'
	from
	(
		select distinct pat_mrn_id, episode_id
		from famdat.b1_epic_lmps_last_entry
	);

*********** embryo transfer edd table from epic;
proc sql;
	create table famdat.b1_epic_emb_trans as
	select pat_mrn_id, episode_id, line, ob_dating_event,
		sys_entered_date, user_entered_date, sys_estimated_edd, user_estimated_edd,
		episode_working_edd
	from ob_dating_epic
	where ob_dating_event='EMBRYO TRANSFER';

	select count(*) label = 'Count of episodes with an Embryo Transfer'
	from
	(
		select distinct pat_mrn_id, episode_id
		from famdat.b1_epic_emb_trans
	);

	*Select lmps with just the last lmp;
	create table famdat.b1_epic_emb_trans_last_entry as
	select a.pat_mrn_id, a.episode_id,
	coalesce(a.user_estimated_edd, a.sys_estimated_edd) as embryo_transfer_edd format mmddyy10. label='EDD based on Embryo Transfer'
	from
		famdat.b1_epic_emb_trans as a
		inner join
		(
			select pat_mrn_id, episode_id, max(line) as max_line
			from famdat.b1_epic_emb_trans
			group by pat_mrn_id, episode_id
		) as b
		on a.pat_mrn_id = b.pat_mrn_id and a.episode_id = b.episode_id and a.line = max_line;

	select count(*) label = 'Count of episodes with an Embryo Transfer'
	from
	(
		select distinct pat_mrn_id, episode_id
		from famdat.b1_epic_emb_trans_last_entry
	);

*********** Get unique ultrasounds;
proc sql;
	create table famdat.b1_epic_ultrasounds as
	select distinct pat_mrn_id, episode_id,
		coalesce(user_entered_date, sys_entered_date) as us_date format mmddyy10. label='Date of the ultrasound',
		coalesce(user_estimated_edd, sys_estimated_edd) as us_edd format mmddyy10. label='EDD based on the ultrasound',
		user_entered_ga_days as us_ga_days label='GA on date of ultrasound',
		line
	from ob_dating_epic
	where ob_dating_event='ULTRASOUND' and not(missing(user_estimated_edd) and missing(sys_estimated_edd));

	*Get the records for each episode at max line, but include the date when looking for max's;
	select count(*) label = 'Count of Ultrasounds'
	from
	(
		select distinct pat_mrn_id, episode_id, us_date
		from famdat.b1_epic_ultrasounds
	);

	create table famdat.b1_epic_ultrasounds_last_entry as
	select a.pat_mrn_id, a.episode_id, a.us_date, a.us_edd, a.us_ga_days
	from
		famdat.b1_epic_ultrasounds as a
		inner join
		(
			select pat_mrn_id, episode_id, us_date, max(line) as max_line
			from famdat.b1_epic_ultrasounds
			group by pat_mrn_id, episode_id, us_date
		) as b
		on a.pat_mrn_id = b.pat_mrn_id and a.episode_id = b.episode_id and a.line = max_line;

	select count(*) label = 'Count of Ultrasounds'
	from
	(
		select distinct pat_mrn_id, episode_id, us_date
		from famdat.b1_epic_ultrasounds_last_entry
	);

*Convert each ultrasound to a separate column. (transpose table?);
proc sort data= famdat.b1_epic_ultrasounds_last_entry out=WORK.SORTTempTableSorted;
	by pat_mrn_id episode_id;
run;

proc transpose data=WORK.SORTTempTableSorted prefix=us_edd_
		out=work.tempusdates(drop=_name_ _label_);
	var us_edd;
	by pat_mrn_id episode_id;
run;

proc sql noprint;
	select name into :us_edd_names separated by ', '
	from dictionary.columns
	where libname = 'WORK' and memname='TEMPUSDATES' and name contains 'us_edd_';

proc transpose data=WORK.SORTTempTableSorted prefix=us_ga_days_
		out=work.tempusga(drop=_name_ _label_);
	var us_ga_days;
	by pat_mrn_id episode_id;
run;

proc sql noprint;
	select name into :us_ga_days_names separated by ', '
	from dictionary.columns
	where libname = 'WORK' and memname='TEMPUSGA' and name contains 'us_ga_days_';


proc sql;
	create table famdat.b1_epic_ultrasounds as
	select coalesce(a.pat_mrn_id, b.pat_mrn_id) as pat_mrn_id,
		coalesce(a.episode_id, b.episode_id) as episode_id,
		&us_edd_names., &us_ga_days_names.
	from
		work.tempusdates as a
		full join
		work.tempusga as b
	on a.pat_mrn_id = b.pat_mrn_id and a.episode_id = b.episode_id;


************ Get final working edd, and it's method of determination;
proc sql;
	create table famdat.b1_epic_final_working_edd  as
	select distinct pat_mrn_id, episode_id, episode_working_edd
	from ob_dating_epic;

	create table b1_working_edd_methods as
	select distinct pat_mrn_id, episode_id, ob_dating_event as method_for_working_edd,
			episode_working_edd, line, entry_comment
	from ob_dating_epic
	where working_edd='Y';

	select count(*) label = 'Count of Episodes with a final edd method'
	from
	(
		select distinct pat_mrn_id, episode_id
		from b1_working_edd_methods
	);

	create table b1_epic_final_edd_last_entry as
	select a.pat_mrn_id,
			a.episode_id,
			a.method_for_working_edd label='Method of EDD determination',
			a.episode_working_edd,
			a.entry_comment label= 'Comment for the method of edd determinating event'
	from
		b1_working_edd_methods  as a
		inner join
		(
			select pat_mrn_id, episode_id, max(line) as max_line
			from b1_working_edd_methods
			group by pat_mrn_id, episode_id
		) as b
		on a.pat_mrn_id = b.pat_mrn_id and a.episode_id = b.episode_id and a.line = max_line;

	select count(*) label = 'Count of episodes with a final edd method'
	from
	(
		select distinct pat_mrn_id, episode_id
		from b1_epic_final_edd_last_entry
	);

	create table famdat.b1_epic_working_edd_methods as
	select coalesce(a.pat_mrn_id, b.pat_mrn_id) as pat_mrn_id,
			coalesce(a.episode_id, b.episode_id) as episode_id,
			a.episode_working_edd,
			b.method_for_working_edd,
			b.entry_comment
	from
		famdat.b1_epic_final_working_edd as a
		left join
		b1_epic_final_edd_last_entry as b
	on a.pat_mrn_id = b.pat_mrn_id and a.episode_id = b.episode_id;

*Combine everything together : this needs to be an inner join, but once the us is unified to have a row per study;
%macro mergedatasets(set1=, set2=, outset=);
	%let sortvars = pat_mrn_id episode_id;
	proc sort data=famdat.&set1 out=work._tmpsort1_;
		by &sortvars;
	run;
	proc sort data=famdat.&set2 out=work._tmpsort2_;
		by &sortvars;
	run;
	data famdat.&outset;
		merge _tmpsort1_ _tmpsort2_;
		by &sortvars;
	run;
	proc delete data=work._tmpsort1_ work._tmpsort2_;
	run;
%mend;

* macro to just set one dataset;
%macro setdataset(setin=, setout=);
	data famdat.&setout.;
	set famdat.&setin.;
	run;
%mend;

%let outputtable = b1_ga_table_epic;
data tablenames;
length tablename $ 40;
input tablename $;
datalines;
b1_epic_working_edd_methods
b1_epic_lmps_last_entry
b1_epic_emb_trans_last_entry
b1_epic_ultrasounds
;
run;

data _null_;
set tablenames;
if _n_=1 then
	call execute( catt('%setdataset(setin=', tablename, ', setout=', '&outputtable.', ');'));
else
	call execute( catt('%mergedatasets(set1=', '&outputtable.', ', set2=', tablename, ', outset=', '&outputtable.', ');'));
run;

/********** SRs **************/
data famdat.b1_ga_table_sr(keep=PatientID filename studydate ga ga_type edd);
	set famdat.b1_biom;
	ga = coalesce(ga_edd, ga_lmp, ga_doc);
	if not missing(ga_edd) then ga_type = 'EDD/Ultrasound';
	if not missing(ga_lmp) then ga_type = 'LMP';
	if not missing(ga_doc) then ga_type = 'DOC';
	if not missing(ga) then output;
run;

* Group the data by PatientID and sort by studydate ;
proc sql;
create table _tmp_sorted_sr_gas as 
	select * from famdat.b1_ga_table_sr 
	order by PatientID, studydate;

proc transpose data=_tmp_sorted_sr_gas prefix=us_date_ 
		out=work.tempusdates(drop=_name_);
	var studydate;
	by PatientID;
run;

proc sql noprint;
	select name into :us_date_names separated by ', ' 
	from dictionary.columns
	where libname = 'WORK' and memname='TEMPUSDATES' and name contains 'us_date_';

proc transpose data=_tmp_sorted_sr_gas prefix=us_ga_days_
		out=work.tempusga(drop=_name_);
	var ga;
	by PatientID;
run;

proc sql noprint;
	select name into :us_ga_days_names separated by ', ' 
	from dictionary.columns
	where libname = 'WORK' and memname='TEMPUSGA' and name contains 'us_ga_days_';


proc sql;
	create table sr_us_gas as 
	select coalesce(a.PatientID, b.PatientID) as PatientID,
		&us_date_names., &us_ga_days_names.
	from 
		work.tempusdates as a 
		full join 
		work.tempusga as b 
	on a.PatientID = b.PatientID;

data _null_;
set sr_us_gas(obs=1);
    array usd us_date_:;
    call symput('n_dts',trim(left(put(dim(usd),8.))));
run;

data sr_us_gas_edds (drop=i j new_preg_ind edd_set prev_ga prev_sd diff_ga diff_days);
set sr_us_gas;
	array usd us_date_:;
	array gas us_ga_days_:;
	array edd(&n_dts.);
	format edd1-edd&n_dts. mmddyy10.;
	array js(&n_dts.);
	
	new_preg_ind = 1;
	edd_set = 0;
	j=1;
	prev_ga = 0;
	prev_sd = -1;
	do i=1 to dim(usd); 
		if missing(usd{i}) then leave; * NO more ultrasounds, leave;
		
		if gas{i} > prev_ga then do;
			if edd_set = 0 and gas{i} >= 42 then do;
				edd{j} = usd{i} - gas{i} + 280;
				edd_set = 1;
				j = j+1;
			end;
			else if edd_set = 1 and gas{i} >= 42 then do;
				 * case when the ga is higher but from a different pregnancy ;
				 diff_ga = gas{i} - prev_ga;
				 diff_days = usd{i} - prev_sd;
				 if abs(diff_ga - diff_days) > 21  then do;
				 	* new pregnancy here ; 
				 	edd{j} = usd{i} - gas{i} + 280;
					edd_set = 1;
					 j = j+1;
				 end;
			end;
		end;
		else if gas{i} <= prev_ga and (usd{i} - prev_sd) > 30 then do;
			if edd_set = 1 then do; * Starting a new pregnancy;
				edd_set = 0;
				new_preg_ind = i;
			end;
			else do; * New pregnancy started, note down the edd for pregnancies whose us have ga < 42;
				edd{j} = usd{new_preg_ind} - gas{new_preg_ind} + 280;
				new_preg_ind = i;
				j = j+1;
			end;
		end;
		prev_ga = gas{i};
		prev_sd = usd{i};
		if edd_set = 1 then js{i} = j-1;
		else js{i} = j;

	end;
	
	if edd_set = 0 then do;
		if prev_ga < 42 then edd{j} = usd{new_preg_ind} - gas{new_preg_ind} + 280;
		else edd{j} = usd{i-1} - gas{i-1} + 280;
		js{i-1} = j;
	end;
run;

data famdat.b1_ga_table_sr_edds (keep=PatientID studydate ga edd) ;
set sr_us_gas_edds;
	array usd us_date_:;
	array gas us_ga_days_:;
	array edds edd:;
	array jind js:;
	do i=1 to dim(usd);
		if missing(usd{i}) then leave; * NO more ultrasounds, leave;
		studydate = usd{i};
		format studydate mmddyy10.;
		ga = gas{i};
		edd = edds{jind{i}};
		format edd mmddyy10.;
		output;
	end;
run;

/************ R4 ************/
%let r4_table = unc_famli_r4data20190820;
proc sql;
	create table famdat.b1_ga_table_r4 as
	select distinct medicalrecordnumber, put(input(medicalrecordnumber,12.),z12.)  as PatientID,
			EDD, NameofFile, egadays, ExamDate, studydate
	from famdat.&r4_table.
	where not missing(egadays);
