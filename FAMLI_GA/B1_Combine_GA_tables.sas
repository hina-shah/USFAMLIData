libname famdat'/folders/myfolders/';
libname epic '/folders/myfolders/epic';

proc sql;
create table all_US as
	select filename, PatientID, studydate, coalesce(ga_edd, ga_doc, ga_lmp, ga_unknown) as ga_prec
	from famdat.b1_biom;

proc sql;
create table all_US_pndb as  /*Fills 7460 ultrasounds out of 86051, and adds 5 records*/
	select a.*, b.BEST_EDC as episode_edd 
	from
		all_US as a 
		left join
		famdat.b1_ga_table_pndb as b
		on
		a.PatientID = b.PatientID and
		a.studydate <= b.BEST_EDC and
		a.studydate >= b.BEST_EDC - 280;

proc sql;
create table all_US_pndb_epic as /*1682 added, fills 52554 out of 87738*/
	select a.filename, a.PatientID, a.studydate, a.ga_prec, coalesce(a.episode_edd, b.episode_working_edd) as episode_edd
	from 
		all_US_pndb as a
		left join
		famdat.b1_ga_table_epic as b
		on
		a.PatientID = b.pat_mrn_id and
		not missing(b.episode_working_edd) and
		missing(a.episode_edd) and
		a.studydate <= b.episode_working_edd and
		a.studydate >= b.episode_working_edd - 280;

* SR ;
proc sql;
create table all_US_pndb_epic_sr as
	select a.filename, a.PatientID, a.studydate, a.ga_prec, coalesce(a.episode_edd, b.edd) as episode_edd
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
create table all_US_pndb_epic_sr_r4 as /*1682 added, fills 52554 out of 87738*/
	select a.filename, a.PatientID, a.studydate, a.ga_prec, coalesce(a.episode_edd, b.EDD) as episode_edd format mmddyy10.
	from 
		all_US_pndb_epic_sr as a
		left join
		famdat.b1_ga_table_r4 as b
		on
		a.PatientID = b.PatientID and
		not missing(b.EDD) and
		missing(a.episode_edd) and
		a.studydate = b.ExamDate;


proc sql;
create table lo_studies as
select filename, PatientID, studydate, ga_lmp, ga_edd, ga_doc, ga_unknown
from famdat.b1_biom where filename in
(select filename from all_US_pndb_epic_sr_r4 where missing(episode_edd));

* Double check the gestational ages by edd vs a given ga
	to remove studies that are incosistent against a DOC ;
data all_US_pndb_epic_sr_r4;
set all_US_pndb_epic_sr_r4;
if not missing(episode_edd) then do;
	ga_edd = 280 - (episode_edd - studydate);
	if not missing(ga_prec) then ga_diffs = abs(ga_edd - ga_prec);
end;
	
run;


* Remove all pregnancies with a max ga that is less that 42 
days or set ga as -1 for these so that these are 
marked so in the other datasets ;