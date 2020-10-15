/* 
Code to combine all the gestational age tables into one
*/
proc sql;
create table all_US_pndb as  
    select distinct a.*, b.BEST_EDC as episode_edd format mmddyy10., b.edd_source
    from
        &famli_studies. as a
        left join
        &pndb_ga_table. as b
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
        &epic_ga_table. as b
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
        &sr_ga_table._edds as b
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
        &r4_ga_table. as b
        on
        a.PatientID = b.PatientID and
        missing(a.episode_edd) and
        a.studydate = b.ExamDate and
        not missing(b.EDD)
    order by PatientID, studydate;
   

* Extrapolate GAs when not available;
proc sql;
create table extrap_ga_attempt as 
    select a.*, b.episode_edd as episode_edd_extrap format mmddyy10.
    from
        all_US_pndb_epic_sr_r4 as a 
        left join
        ( 
            select distinct PatientID, episode_edd, edd_source
            from all_US_pndb_epic_sr_r4
            where not missing(episode_edd)
         ) as b
     on 
     a.PatientID = b.PatientID and
     a.studydate > b.episode_edd - &ga_cycle. and
     a.studydate <= b.episode_edd 
;

data extrap_ga_attempt_together (drop=episode_edd_extrap);
set extrap_ga_attempt;
if missing(episode_edd) and not missing(episode_edd_extrap) then
    do;
        episode_edd = episode_edd_extrap;
        edd_source = 'extrap';
    end;
run;

proc sql;
create table distinct_gas_extrap as
    select distinct * from extrap_ga_attempt_together
;

* If there are multiple edd's assigned then assign the later one;
proc sql;
create table &ga_final_table. as
    select a.filename, a.PatientID, a.studydate, a.episode_edd, a.edd_source
    from
        distinct_gas_extrap as a
        inner join
        (
            select filename, PatientID, studydate, max(episode_edd) as max_episode_edd
            from distinct_gas_extrap
            group by filename, PatientID, studydate
        ) as b
        on a.filename = b.filename and a.PatientID = b.PatientID and a.episode_edd = max_episode_edd;

data &ga_final_table.;
set &ga_final_table.;
if not missing(episode_edd) then do;
    ga_edd = &ga_cycle. - (episode_edd - studydate);
end;
run;

* Remove non-singleton pregnancy records;
proc sql;
create table alerts as
    select distinct a.*, b.alert
    from
        &ga_final_table. as a
        left join
        &famli_table. as b
    on
    a.filename = b.filename and a.PatientID = b.PatientID;

create table to_be_deleted_sr as
    select distinct filename 
    from 
        &ga_final_table. as a
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
        &ga_final_table. as a 
        inner join
        (
            select * from 
            (
                select distinct pat_mrn_id, episode_id, episode_working_edd, count(*) as count_edd 
                from &epic_ga_table. 
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
        &ga_final_table. as a 
        inner join
        (
            select * from 
            (
                select distinct PatientID, BEST_EDC, count(*) as count_edd 
                from &pndb_ga_table.
                group by PatientID, BEST_EDC
            ) 
            where count_edd > 1
        ) as b
        on
            a.PatientID = b.PatientID and
            a.episode_edd = b.BEST_EDC
            and a.filename not in (select * from to_be_deleted_sr);
;

* R4 multifetals ;
create table to_be_deleted_r4 as
	select distinct a.filename
	from
		&ga_final_table. as a 
		inner join
		(
			select distinct PatientID, NameOFFile
			from &r4_ga_table.
			where NumberOfFetuses NE '1'
		) as b
		on
			a.PatientID = b.PatientID and
			a.filename not in (select * from to_be_deleted_sr) and
			a.filename = b.NameOfFile
;

* Find ultrasounds with non-viable gas;
proc sql;
create table to_be_deleted_ga as
    select distinct filename, ga_edd
    from 
        &ga_final_table.
    where 
        not missing(ga_edd) and 
        (ga_edd < 42 or ga_edd > 308)
;


data to_be_deleted;
set to_be_deleted_sr to_be_deleted_epic to_be_deleted_pndb to_be_deleted_r4 to_be_deleted_ga(drop=ga_edd);
run;

proc sql;
create table outlib.b1_multifetals as
select filename from to_be_deleted_sr 
UNION 
select filename from to_be_deleted_epic 
UNION 
select filename from to_be_deleted_pndb
UNION
select filename from to_be_deleted_r4;
run;

proc sql;
select 'Number of multifetals', count(*) from outlib.b1_multifetals;

select 'Number of nonviable ga ultrasounds', count(*) from 
    (select filename 
        from to_be_deleted_ga 
        where filename not in 
            (select filename from  outlib.b1_multifetals)
   ); 



* Delete records ;
proc sql;
delete * from &ga_final_table. 
    where filename in (select * from to_be_deleted);
delete * from &famli_studies. 
    where filename in (select * from to_be_deleted);
delete * from &famli_table.
    where filename in (select * from to_be_deleted);

proc sql;
create table per_study_count as 
    select *, count(*) as count
    from &ga_final_table.
    group by filename, PatientID, studydate;
quit;


proc delete data=all_US_pndb all_US_pndb_epic all_US_pndb_epic_sr all_US_pndb_epic_sr_r4;
    run;
