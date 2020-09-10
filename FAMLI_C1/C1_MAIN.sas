*libname famdat '/folders/myfolders/';
*libname epic '/folders/myfolders/epic_latest';

%let ServerPath = H:\Users\hinashah\SASFiles;

libname famdat  "&ServerPath.\InputData";
libname epic "&ServerPath.\InputData\epic720";
libname uslib "&ServerPath.\InputData\Ultrasound";
libname outlib "&ServerPath.\C1Data";

*Paths;
%let MainPath = &ServerPath.\USFAMLIData;
%let C1Path = &MainPath.\FAMLI_C1;

* Inputs to the scripts;
%let dicom_sr = famdat.famli_c1_dicom_sr;
%let nondicom_sr = famdat.famli_c1_nondicom_sr;
* Outputs: will be created in outlib;
%let famli_table = outlib.c1_sr_all; /*This will have the SR table subset to C1 data*/
%let ga_table = outlib.c1_ga_table; /* This is the ga table*/
%let sr_ga_table = outlib.c1_sr_ga_table;
%let c1_pregnancies_table = outlib.c1_pregnancies;
%let c1_studies = outlib.c1_studies;
%let c1_studies_in_epic = outlib.c1_epic_studies;
%let c1_pats_epic = outlib.c1_epic_pids;

filename reffile "&ServerPath.\C1Data\c1_study_details.csv";


* Get as many Study IDs as possible, and corresponding PatientIDs from EPIC;
proc sql;
create table c1_epic_pids_study_ids as
    select pat_mrn_id, study_id from epic.vitals where not missing(study_id)
    UNION
        (select pat_mrn_id, study_id from epic.delivery where not missing(study_id)
        UNION
            (select pat_mrn_id, study_id from epic.diagnosis where not missing(study_id)
            UNION
                (select pat_mrn_id, study_id from epic.labs where not missing(study_id)
                UNION
                    (select pat_mrn_id, study_id from epic.ob_dating where not missing(study_id)
                    UNION
                        (select pat_mrn_id, study_id from epic.medications where not missing(study_id)
                        UNION
                            (select pat_mrn_id, study_id from epic.social_hx where not missing(study_id)
                            UNION
                                (select pat_mrn_id, study_id from epic.procedures where not missing(study_id)
                                UNION
                                    (select pat_mrn_id, study_id from epic.ob_history where not missing(study_id) 
))))))))
;

* Create the table of all studies based on instance tables;
proc sql;
create table &c1_studies. as 
select distinct PID, StudyID, datepart(study_dttm) as studydate format mmddyy10.
	from uslib.famli_c1_instancetable;
select 'Number of studies: ', count(*) from &c1_studies.;
select 'Number of patients: ', count(*) from (select distinct PID from &c1_studies.);
select 'Number of patients in EPIC: ', count(*) from c1_epic_pids_study_ids;

* Patients in epic;

/* 
studydates should always be taken from instancetable and not from SRs.
The content times can be inconsistent in the SR dicom headers.
*/
proc sql;
create table &c1_pats_epic. as
    select pat_mrn_id, study_id as famli_id
    from c1_epic_pids_study_ids
;

* Studies in EPIC;
create table &c1_studies_in_epic. as
select PID as famli_id, StudyID, studydate from &c1_studies where
	PID in (select famli_id from &c1_pats_epic);


proc sql;
select 'Number of studies in DICOM SR: ', count(*) from (select distinct StudyID from famdat.famli_c1_dicom_sr);
select 'Number of studies in NONDICOM SR: ', count(*) from (select distinct StudyID from famdat.famli_c1_nondicom_sr);

*Combine both tables together;
create table &famli_table. as
select filename, PID, StudyID, studydttm, tagname, tagcontent, numericvalue from &dicom_sr.
UNION
	(select filename, PID, StudyID, studydttm, tagname, tagcontent, numericvalue from &nondicom_sr.
	where missing(alert));

*Get EDDs from SRs;
%include "&MainPath./FAMLI_GA/C1_create_GA_tables_SR.sas";
%include "&C1Path./C1_Volumes.sas";

title 'Counts';
proc sql;
select 'Number of patients in DICOM: ', count(*) from (select distinct pid from &dicom_sr.);
select 'Number of studies in DICOM: ', count(*) from (select distinct StudyID from &dicom_sr.);
select 'Number of EPIC matches for patients found from DICOM', count(*) from 
(
	select a.pat_mrn_id, a.famli_id 
	from 
		&c1_pats_epic. as a
		inner join
		(select distinct pid from famdat.famli_c1_dicom_sr) as b
		on
		a.famli_id = b.pid
);


/* Preparing for collecting clinical data */
/*
GA table right now is only from SR.
Need actual PatientIDs (to match clinical data in Epic)
Need filenames from SR, since that is a key for a lot of stuff that I do while gathering clinical information
*/

* Create filenames table, make sure I get unique ones by taking ones with max studydttm (this one is different from famli_c1_l3eeDRGN instancetable);
proc sql; 
create table c1_filenames as 
select distinct a.filename, a.pid, a.StudyID
from &dicom_sr. as a
	inner join
	( select filename, pid, StudyID, max(studydttm) as ms
		from &dicom_sr.
		group by pid, StudyID
	) as b
	on
	a.pid = b.pid 
	and a.StudyID = b.StudyID
	and a.studydttm = b.ms
;

create table counts as 
select *, count(*) as sr_count
from c1_filenames
group by pid, StudyID;

select 'Number of studies with more than one sr on a day: ', count(*), max(sr_count) from counts where sr_count > 1;

proc sql;
/* Add filenames to the ga table*/
create table ga_filenames as
select b.filename, a.*
from &sr_ga_table. as a
	left join
	c1_filenames as b
	on
	a.StudyID = b.StudyID
;

proc sql;
create table &ga_table. as
select a.filename, b.pat_mrn_id as PatientID, a.PatientID as FamliID, a.StudyID, a.studydate, a.edd as episode_edd, 
		a.edd_source, a.ga as ga_edd
from ga_filenames as a 
	 left join
	 &c1_pats_epic. as b
on 
	a.PatientID = b.famli_id
; 
create table &ga_table. as
select * from &ga_table. where not missing(PatientID);

select 'Number of patients in the ga table: ', count(*) from (select distinct PatientID from &ga_table.);
select 'Number of patients in the ga table (studyid): ', count(*) from (select distinct StudyID from &ga_table.);
select 'Number of studies: ', count(*) from &ga_table.;
select 'Number of studies with missing GA: ', count(*) from &ga_table. where missing(ga_edd);
select 'Number of pregnancies: ', count(*) from (select distinct PatientID, episode_edd from &ga_table.);

%let ReportsOutputPath = &ServerPath.\C1Data;
%let ClinicalPath= &MainPath.\FAMLI_Clinical;

* Inputs ;
%let pndb_table = famdat.pndb_famli_records_with_matches; /*This has all the data from PNDB*/

****** Names of output tables to be generated by Clinical dataset *****;
%let mat_info_pndb_table = outlib.c1_maternal_info_pndb;
%let mat_info_epic_table = outlib.c1_maternal_info_epic;
%let mat_final_output_table = outlib.c1_maternal_info;

******* Define global values *******;
%let max_ga_cycle = 308;
%let ga_cycle = 280;
%let min_height = 40;
%let max_height = 90;
%let min_weight = 90; /* in lbs */
%let max_weight = 400; /* in lbs */

%include "&MainPath./FAMLI_Clinical/B1_MAIN_Create_Clinical.sas";

proc sql;
create table c1_maternal_info as 
select b.FamliID, b.StudyID, a.* 
from 
	&mat_final_output_table. as a
	left join
	&ga_table. as b
	on
	a.PatientID = b.PatientID
	and a.studydate = b.studydate
	;

data &mat_final_output_table. (drop=filename PatientID);
set c1_maternal_info;
run;

proc sql;
select count(*) from (select distinct FamliID from &mat_final_output_table.);
select count(*) from (select distinct StudyID from &mat_final_output_table.);
select count(*) from (select distinct FamliID, episode_working_edd from &mat_final_output_table.);

%ds2csv(
    data=&mat_final_output_table.,
    runmode=b,
    labels=N,
    csvfile=F:/Users/hinashah/SASFiles/FAMLI_UNC_Clinical.csv   
);

/*b.filename, a.PatientID, a.StudyID, a.studydate, a.edd as episode_edd, a.edd_source, a.ga as ga_edd*/
/*from*/
/*	( /* Add EPIC MRNs to the table */*/
/*		select c.PatientID as FamliID, s.StudyID, c.studydate, c.edd, c.edd_source, c.ga, d.pat_mrn_id as PatientID*/
/*		from*/
/*			&sr_ga_table. as c*/
/*			left join*/
/*			&c1_pats_epic. as d*/
/*			on*/
/*			c.PatientID = d.famli_id*/
/*	)as a*/
/*	left join*/
/*	c1_filenames as b*/
/*	on*/
/*	b.StudyID = a.StudyID; */


/* Not including the non-dicom srs here because the clinical data is not available for these studies in UNC/EPIC*/

/**/
/** Try to get the edds for these;*/
/*proc sql;*/
/*create table famdat.&c1_pregnancies_table. as*/
/*    select a.*, b.famli_id */
/*    from*/
/*        famdat.&gt_ga_table. as a */
/*        inner join*/
/*        famdat.&c1_studies_in_epic. as b*/
/*    on*/
/*    a.PatientID = b.pat_mrn_id*/
/*;*/
/**/
/*select 'Number of patients with an EDD', count(*) */
/*    from*/
/*        (select distinct PatientID from famdat.&c1_pregnancies_table.)*/
/*;*/
/**/
/** load a table that was created from server that has famli id, study id, and study date ;*/
/*PROC IMPORT DATAFILE=reffile DBMS=CSV replace OUT=famdat.&c1_studies_table.;*/
/*    guessingrows=1000;*/
/*    getnames=YES;*/
/*RUN;*/
/**/
/*proc sql;*/
/*select 'Number of OCR-processed patients in C1:', count(*) */
/*    from*/
/*        (select distinct pid from famdat.&c1_studies_table.)*/
/*;*/
/**/
/** Create a gestational age table from the edds;*/
/*proc sql;*/
/*create table c1_ga_table as */
/*    select coalesce(a.pid, b.famli_id) as famli_id, a.study_id, a.study_id_studydate, a.study_date, b.episode_edd, b.PatientID*/
/*    from */
/*        famdat.&c1_studies_table. as a */
/*        left join*/
/*        famdat.&c1_pregnancies_table. as b*/
/*    on*/
/*        a.pid = b.famli_id*/
/*        and*/
/*        a.study_date <= b.episode_edd + 28*/
/*        and*/
/*        a.study_date >= b.episode_edd - 280*/
/*;*/
/**/
/** If there are multiple edd's assigned then assign the later one;*/
/*proc sql;*/
/*create table famdat.&c1_ga_table. as*/
/*    select a.study_id_studydate, a.famli_id as pid, a.study_id as StudyID,  */
/*        a.study_date, a.episode_edd, a.study_date - (a.episode_edd - 280) as ga_edd, a.PatientID*/
/*    from*/
/*        c1_ga_table as a*/
/*        inner join*/
/*        (*/
/*            select study_id, study_date, max(episode_edd) as max_episode_edd*/
/*            from c1_ga_table*/
/*            group by study_id, study_date*/
/*        ) as b*/
/*        on a.study_id = b.study_id and a.study_date = b.study_date and a.episode_edd = max_episode_edd*/
/*;*/
/**/
/** Create biometries;*/
/*%include "&C1Path/C1_Biom.sas";*/
/**/
/** Combine biometry measurements with the gestational ages;*/
/*%include "&C1Path/C1_Biom_merge_tables.sas";*/
/**/
/** Export as csv;*/
/*%ds2csv (*/
/*   data=famdat.&biom_final_output_table., */
/*   runmode=b, */
/*   csvfile=F:\Users\hinashah\SASFiles\c1_biom_ga_table.csv*/
/* );*/
