*libname famdat'/folders/myfolders/';
*libname epic '/folders/myfolders/epic';

*libname famdat 'F:\Users\hinashah\SASFiles';
*libname epic 'F:\Users\hinashah\SASFiles\epic';

proc sql;
create table all_US_pndb as  
	select distinct a.*, b.BEST_EDC as episode_edd format mmddyy10., b.edd_source
	from
		famdat.b1_patmrn_studytm as a
		left join
		famdat.b1_ga_table_pndb as b
		on
		a.PatientID = b.PatientID and
		a.studydate <= b.BEST_EDC and
		a.studydate >= (b.BEST_EDC - 280);

proc sql;
create table all_US_pndb_epic as
	select distinct a.filename, a.PatientID, a.studydate, 
			coalesce(a.episode_edd, b.episode_working_edd) as episode_edd format mmddyy10.,
			coalesce(a.edd_source, b.edd_source) as edd_source
	from 
		all_US_pndb as a
		left join
		famdat.b1_ga_table_epic as b
		on
		a.PatientID = b.pat_mrn_id and
		a.studydate <= b.episode_working_edd and
		a.studydate >= (b.episode_working_edd - 280) and
		missing(a.episode_edd) and
		not missing(b.episode_working_edd)
		;

* SR ;
proc sql;
create table all_US_pndb_epic_sr as
	select distinct a.filename, a.PatientID, a.studydate, 
			coalesce(a.episode_edd, b.edd) as episode_edd format mmddyy10.,
			coalesce(a.edd_source, b.edd_source) as edd_source
	from 
		all_US_pndb_epic as a
		left join
		famdat.b1_ga_table_sr_edds as b
		on
		a.PatientID = b.PatientID and
		a.studydate = b.studydate and
		missing(a.episode_edd);

* R4 ;
proc sql;
create table all_US_pndb_epic_sr_r4 as 
	select distinct a.filename, a.PatientID, a.studydate, 
			coalesce(a.episode_edd, b.EDD) as episode_edd format mmddyy10.,
			coalesce(a.edd_source, b.edd_source) as edd_source
	from 
		all_US_pndb_epic_sr as a
		left join
		famdat.b1_ga_table_r4 as b
		on
		a.PatientID = b.PatientID and
		missing(a.episode_edd) and
		a.studydate = b.ExamDate and
		not missing(b.EDD)
	order by PatientID, studydate;

* If there are multiple edd's assigned then assign the later one;
proc sql;
create table famdat.&ga_final_table. as
	select a.filename, a.PatientID, a.studydate, a.episode_edd, a.edd_source
	from
		all_US_pndb_epic_sr_r4 as a
		inner join
		(
			select filename, PatientID, studydate, max(episode_edd) as max_episode_edd
			from all_US_pndb_epic_sr_r4
			group by filename, PatientID, studydate
		) as b
		on a.filename = b.filename and a.PatientID = b.PatientID and a.episode_edd = max_episode_edd;

* Remove non-singleton pregnancy records;
proc sql;
create table alerts as
	select distinct a.*, b.alert
	from
		famdat.&ga_final_table as a
		left join
		famdat.famli_b1_subset as b
	on
	a.filename = b.filename and a.PatientID = b.PatientID;

create table to_be_deleted as
	select distinct filename 
	from 
		famdat.&ga_final_table. as a
		inner join
		(
			select PatientID, episode_edd, count(*) as ns_count
			from 
			alerts
			where prxmatch('/non-singleton/', alert) > 0
			group by PatientID, episode_edd
		) as b
		on a.PatientID = b.PatientID and a.episode_edd = b.episode_edd and b.ns_count > 0;

delete * from famdat.&ga_final_table. 
	where filename in (select * from to_be_deleted);
delete * from famdat.b1_patmrn_studytm 
	where filename in (select * from to_be_deleted);
delete * from &famli_table
	where filename in (select * from to_be_deleted);

* Create missing ga studies, and pregnancy list;
proc sql;
create table famdat.b1_missing_ga_studies as
	select filename, PatientID, studydate
	from famdat.b1_patmrn_studytm 
	where filename in
	(
		select filename 
		from all_US_pndb_epic_sr_r4 
		where missing(episode_edd)
	);


proc sql;
create table per_study_count as 
	select *, count(*) as count
	from famdat.&ga_final_table.
	group by filename, PatientID, studydate;
quit;

data famdat.&ga_final_table.;
set famdat.&ga_final_table.;
if not missing(episode_edd) then do;
	ga_edd = 280 - (episode_edd - studydate);
end;
run;

proc sql;
create table famdat.b1_pregnancies as
	select distinct PatientID, episode_edd, count(*) as us_counts label='Number of ultrasounds in that pregnancy' 
	from
	famdat.&ga_final_table.
	group by PatientID, episode_edd;


proc delete data=all_US_pndb all_US_pndb_epic all_US_pndb_epic_sr all_US_pndb_epic_sr_r4;
	run;