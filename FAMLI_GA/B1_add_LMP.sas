/*
Code to extract and integrate the LMPs into the final GA table.
*/

* PNDB ;
proc sql;
create table lmps_pndb as 
 select distinct a.*, b.LMP 
 from
    famdat.&ga_final_table. as a 
    left join
    famdat.&pndb_ga_table. as b
 on 
    a.PatientID = b.PatientID 
    and 
    a.episode_edd = b.BEST_EDC
;
    
* EPIC ;
proc sql;
create table lmps_pndb_epic as
 select distinct a.filename, a.PatientID, a.studydate, a.episode_edd, a.edd_source, a.ga_edd,
        coalesce(a.LMP, b.lmp) as lmp format mmddyy10.
 from
    lmps_pndb as a 
    left join
    famdat.&epic_ga_table. as b
 on
    a.PatientID = b.pat_mrn_id
    and
    a.episode_edd = b.episode_working_edd 
    and
    not missing(b.lmp)
    and
    b.lmp > a.episode_edd - &max_ga_cycle
;   

proc sql;
create table counts as 
    select distinct filename, count(*) as file_count
    from 
        lmps_pndb_epic
    group by filename;

/*
create table inconsistency_filenames as 
    select distinct a.filename 
    from 
        lmps_pndb_epic as a
        inner join
        famdat.epic_inconsistencies as b
    on
        a.PatientID = b.pat_mrn_id and
        a.episode_edd = b.episode_working_edd 
; */

update lmps_pndb_epic 
    set lmp = . 
    where filename in 
        (
            select filename 
            from counts 
            where file_count > 1
        )
;

* SR ;
proc sql;
create table lmps_from_us as 
 select a.*, a.studydate - a.ga as LMP format mmddyy10.
 from
    (
        /* Get patient ID and studydate for the first ultrasound in a pregnancy */
        select PatientID, episode_edd, us_date_1 as studydate, ga_1 as ga
        from famdat.b1_pregnancies_with_us
    ) as a
    inner join 
    famdat.&sr_ga_table. as b
 on  /* Inner join with the GA type where GA type is LMP */
    a.PatientID = b.PatientID
    and
    a.studydate = b.studydate
    and
    prxmatch('/LMP/', ga_type) > 0
;

* integrate back into the lmps table along with ga;
proc sql;
create table famdat.&ga_final_table. as
    select distinct a.filename, a.PatientID, a.studydate, a.episode_edd, a.edd_source, a.ga_edd,
            coalesce(a.lmp, b.LMP) as lmp format mmddyy10.
    from
        lmps_pndb_epic as a 
        left join
        lmps_from_us as b
    on
        a.PatientID = b.PatientID
        and
        a.studydate = b.studydate
;
