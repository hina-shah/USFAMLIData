/* 
Code to combine all the gestational age tables into one
*/
proc sql;
create table all_US_pndb as  
    select distinct a.*, b.BEST_EDC as episode_edd format mmddyy10., b.edd_source
    from
        &famli_studies. as a
        left join
        famdat.&pndb_ga_table. as b
        on
        a.PatientID = b.PatientID and
        a.studydate <= b.BEST_EDC and
        a.studydate >= (b.BEST_EDC - &ga_cycle.);

proc sql;
create table all_US_pndb_epic as
    select distinct a.filename, a.PatientID, a.studydate, 
            coalesce(a.episode_edd, b.episode_working_edd) as episode_edd format mmddyy10.,
            coalesce(a.edd_source, b.edd_source) as edd_source
    from 
        all_US_pndb as a
        left join
        famdat.&epic_ga_table. as b
        on
        a.PatientID = b.pat_mrn_id and
        a.studydate <= b.episode_working_edd and
        a.studydate >= (b.episode_working_edd - &ga_cycle.) and
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
        famdat.&sr_ga_table._edds as b
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
        famdat.&r4_ga_table. as b
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

data famdat.&ga_final_table.;
set famdat.&ga_final_table.;
if not missing(episode_edd) then do;
    ga_edd = &ga_cycle. - (episode_edd - studydate);
end;
run;

* Remove non-singleton pregnancy records;
proc sql;
create table alerts as
    select distinct a.*, b.alert
    from
        famdat.&ga_final_table as a
        left join
        &famli_table. as b
    on
    a.filename = b.filename and a.PatientID = b.PatientID;

create table to_be_deleted_sr as
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

* Finding EPIC multifetals ; 
proc sql;
create table to_be_deleted_epic as 
    select distinct a.filename 
    from 
        famdat.&ga_final_table. as a 
        inner join
        (
            select * from 
            (
                select distinct pat_mrn_id, episode_id, episode_working_edd, count(*) as count_edd 
                from famdat.b1_ga_table_epic 
                group by pat_mrn_id, episode_id
            ) 
            where count_edd > 1
        ) as b
        on
            a.PatientID = b.pat_mrn_id and
            a.episode_edd = b.episode_working_edd
            and a.filename not in (select * from to_be_deleted_sr);
;

* Finding PNDB multifetals;
proc sql;
create table to_be_deleted_pndb as 
    select distinct a.filename 
    from 
        famdat.&ga_final_table. as a 
        inner join
        (
            select * from 
            (
                select distinct PatientID, BEST_EDC, count(*) as count_edd 
                from famdat.b1_ga_table_pndb 
                group by PatientID, BEST_EDC
            ) 
            where count_edd > 1
        ) as b
        on
            a.PatientID = b.PatientID and
            a.episode_edd = b.BEST_EDC
            and a.filename not in (select * from to_be_deleted_sr);
;

* Find ultrasounds with non-viable gas;
proc sql;
create table to_be_deleted_ga as
    select distinct filename, ga_edd
    from 
        famdat.&ga_final_table.
    where 
        not missing(ga_edd) and 
        (ga_edd < 42 or ga_edd > 308)
;

data to_be_deleted;
set to_be_deleted_sr to_be_deleted_epic to_be_deleted_pndb to_be_deleted_ga(drop=ga_edd);
run;

* Delete records ;
proc sql;
delete * from famdat.&ga_final_table. 
    where filename in (select * from to_be_deleted);
delete * from &famli_studies. 
    where filename in (select * from to_be_deleted);
delete * from &famli_table.
    where filename in (select * from to_be_deleted);

proc sql;
create table per_study_count as 
    select *, count(*) as count
    from famdat.&ga_final_table.
    group by filename, PatientID, studydate;
quit;


proc delete data=all_US_pndb all_US_pndb_epic all_US_pndb_epic_sr all_US_pndb_epic_sr_r4;
    run;
