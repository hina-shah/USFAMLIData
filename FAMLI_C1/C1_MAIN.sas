*libname famdat '/folders/myfolders/';
*libname epic '/folders/myfolders/epic_latest';

libname famdat  "F:\Users\hinashah\SASFiles";
libname epic "F:\Users\hinashah\SASFiles\epic";


* Get biometry measurements ;
%let MainPath = F:\Users\hinashah\SASFiles\USFAMLIData;
%let C1Path = &MainPath./FAMLI_C1;
%let gt_ga_table = b1_pregnancies;
%let c1_ga_table = c1_ga_table;
%let c1_pregnancies_table = c1_pregnancies;
%let c1_studies_table = c1_patmrn_studytm;
%let c1_studies_in_epic = c1_epic_pids_study_ids;
%let biom_final_output_table = c1_biom_ga_table;
%let famli_table = famdat.famli_c1_dicom_sr;
filename reffile 'F:\Users\hinashah\SASFiles\c1_study_details.csv';


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

proc sql;
create table famdat.&c1_studies_in_epic. as
    select pat_mrn_id, substr(study_id, 1, findc(study_id, '-', 'b')-1) as famli_id
    from c1_epic_pids_study_ids
;

* Try to get the edds for these;
proc sql;
create table famdat.&c1_pregnancies_table. as
    select a.*, b.famli_id 
    from
        famdat.&gt_ga_table. as a 
        inner join
        famdat.&c1_studies_in_epic. as b
    on
    a.PatientID = b.pat_mrn_id
;

select 'Number of patients with an EDD', count(*) 
    from
        (select distinct PatientID from famdat.&c1_pregnancies_table.)
;

* load a table that was created from server that has famli id, study id, and study date ;
PROC IMPORT DATAFILE=reffile DBMS=CSV replace OUT=famdat.&c1_studies_table.;
    guessingrows=1000;
    getnames=YES;
RUN;

proc sql;
select 'Number of OCR-processed patients in C1:', count(*) 
    from
        (select distinct pid from famdat.&c1_studies_table.)
;

* Create a gestational age table from the edds;
proc sql;
create table c1_ga_table as 
    select coalesce(a.pid, b.famli_id) as famli_id, a.study_id, a.study_id_studydate, a.study_date, b.episode_edd, b.PatientID
    from 
        famdat.&c1_studies_table. as a 
        left join
        famdat.&c1_pregnancies_table. as b
    on
        a.pid = b.famli_id
        and
        a.study_date <= b.episode_edd + 28
        and
        a.study_date >= b.episode_edd - 280
;

* If there are multiple edd's assigned then assign the later one;
proc sql;
create table famdat.&c1_ga_table. as
    select a.study_id_studydate, a.famli_id as pid, a.study_id as StudyID,  
        a.study_date, a.episode_edd, a.study_date - (a.episode_edd - 280) as ga_edd, a.PatientID
    from
        c1_ga_table as a
        inner join
        (
            select study_id, study_date, max(episode_edd) as max_episode_edd
            from c1_ga_table
            group by study_id, study_date
        ) as b
        on a.study_id = b.study_id and a.study_date = b.study_date and a.episode_edd = max_episode_edd
;

* Create biometries;
%include "&C1Path/C1_Biom.sas";

* Combine biometry measurements with the gestational ages;
%include "&C1Path/C1_Biom_merge_tables.sas";

* Export as csv;
%ds2csv (
   data=famdat.&biom_final_output_table., 
   runmode=b, 
   csvfile=F:\Users\hinashah\SASFiles\c1_biom_ga_table.csv
 );