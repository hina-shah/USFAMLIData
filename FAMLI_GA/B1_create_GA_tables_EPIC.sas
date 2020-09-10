
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
 create table outlib.b1_epic_lmps as
 select pat_mrn_id, episode_id, line, ob_dating_event,
    sys_entered_date, user_entered_date,
    episode_working_edd
 from ob_dating_epic
 where ob_dating_event='LAST MENSTRUAL PERIOD' and 
 		(not missing(sys_entered_date) or not missing(user_entered_date));

 select count(*) label = 'Count of episodes with an LMP'
 from
 (
    select distinct pat_mrn_id, episode_id
    from outlib.b1_epic_lmps
 );

 *Select lmps with just the last lmp;
 create table outlib.b1_epic_lmps_last_entry as
 select a.pat_mrn_id, a.episode_id,
        a.user_entered_date as lmp format mmddyy10. label='Last Menstrual Period'
 from
    outlib.b1_epic_lmps as a
    inner join
    (
        select pat_mrn_id, episode_id, min(line) as min_line
        from outlib.b1_epic_lmps
        group by pat_mrn_id, episode_id
    ) as b
    on a.pat_mrn_id = b.pat_mrn_id and 
    	a.episode_id = b.episode_id and 
    	a.line = min_line and 
    	not missing(a.user_entered_date);

 select count(*) label = 'Count of episodes with an LMP at minline'
 from
 (
    select distinct pat_mrn_id, episode_id
    from outlib.b1_epic_lmps_last_entry
 );

* ********* Epic delivery dates ;
proc sql;
create table outlib.b1_epic_deliveries as
       select distinct pat_mrn_id, episode_id, datepart(delivery_dttm_utc) as delivery_date format mmddyy10.
       from epic.delivery;

*********** embryo transfer edd table from epic;
proc sql;
 create table outlib.b1_epic_emb_trans as
 select pat_mrn_id, episode_id, line, ob_dating_event,
    sys_entered_date, user_entered_date, sys_estimated_edd, user_estimated_edd,
    episode_working_edd
 from ob_dating_epic
 where 
    ob_dating_event='EMBRYO TRANSFER'
    or
    (
        prxmatch('/(ALTERNATE EDD ENTRY)|(OTHER BASIS)|(PATIENT REPORTED)/', ob_dating_event) > 0 and
        prxmatch('/IVF|embryo/', entry_comment) > 0 
    )
 ;

 select count(*) label = 'Count of episodes with an Embryo Transfer'
 from
 (
    select distinct pat_mrn_id, episode_id
    from outlib.b1_epic_emb_trans
 );

 *Select embryo transfer last date;
 proc sql;
 create table outlib.b1_epic_emb_trans_last_entry as
 select a.pat_mrn_id, a.episode_id,
 coalesce(a.user_estimated_edd, a.sys_estimated_edd) as embryo_transfer_edd format mmddyy10. label='EDD based on Embryo Transfer',
 a.episode_working_edd as embryo_episode_working_edd format mmddyy10. label = 'Episode working EDD'
 from
    outlib.b1_epic_emb_trans as a
    inner join
    (
        select pat_mrn_id, episode_id, max(line) as max_line
        from outlib.b1_epic_emb_trans
        group by pat_mrn_id, episode_id
    ) as b
    on a.pat_mrn_id = b.pat_mrn_id and a.episode_id = b.episode_id and a.line = max_line;

 select count(*) label = 'Count of episodes with an Embryo Transfer'
 from
 (
    select distinct pat_mrn_id, episode_id
    from outlib.b1_epic_emb_trans_last_entry
 );

*********** Get unique ultrasounds;
proc sql;
 create table outlib.b1_epic_ultrasounds as
 select distinct pat_mrn_id, episode_id,
    coalesce(user_entered_date, sys_entered_date) as us_date format mmddyy10. label='Date of the ultrasound',
    coalesce(user_estimated_edd, sys_estimated_edd) as us_edd format mmddyy10. label='EDD based on the ultrasound',
    asuser_entered_ga_days as us_ga_days label='GA on date of ultrasound',
    line
 from ob_dating_epic
 where ob_dating_event='ULTRASOUND' and not(missing(user_estimated_edd) and missing(sys_estimated_edd));

 *Get the records for each episode at max line, but include the date when looking for max's;
 select count(*) label = 'Count of Ultrasounds'
 from
 (
    select distinct pat_mrn_id, episode_id, us_date
    from outlib.b1_epic_ultrasounds
 );

 create table outlib.b1_epic_ultrasounds_last_entry as
 select a.pat_mrn_id, a.episode_id, a.us_date, a.us_edd, a.us_ga_days
 from
    outlib.b1_epic_ultrasounds as a
    inner join
    (
        select pat_mrn_id, episode_id, us_date, max(line) as max_line
        from outlib.b1_epic_ultrasounds
        group by pat_mrn_id, episode_id, us_date
    ) as b
    on a.pat_mrn_id = b.pat_mrn_id and a.episode_id = b.episode_id and a.line = max_line;

 select count(*) label = 'Count of Ultrasounds'
 from
 (
    select distinct pat_mrn_id, episode_id, us_date
    from outlib.b1_epic_ultrasounds_last_entry
 );

*Convert each ultrasound to a separate column. (transpose table?);
proc sort data= outlib.b1_epic_ultrasounds_last_entry out=WORK.SORTTempTableSorted;
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
 create table outlib.b1_epic_ultrasounds as
 select coalesce(a.pat_mrn_id, b.pat_mrn_id) as pat_mrn_id,
    coalesce(a.episode_id, b.episode_id) as episode_id,
    &us_edd_names., &us_ga_days_names.
 from
    work.tempusdates as a
    full join
    work.tempusga as b
 on a.pat_mrn_id = b.pat_mrn_id and a.episode_id = b.episode_id;

************ Create counts for the number of dating events *********;
proc sql;
create table dating_event as
select distinct pat_mrn_id, episode_id, ob_dating_event
from ob_dating_epic
;

create table dating_event_counts as 
select *, count(*) as count_events
from dating_event
group by pat_mrn_id, episode_id
;

create table lmps as
select pat_mrn_id, episode_id 
from dating_event_counts
where count_events=1 and ob_dating_event="LAST MENSTRUAL PERIOD";

************ Get final working edd, and it's method of determination;
proc sql;
 create table outlib.b1_epic_final_working_edd  as
 select distinct pat_mrn_id, episode_id, episode_working_edd
 from ob_dating_epic
 where not missing(episode_working_edd);
 

 create table b1_working_edd_methods as
 select distinct pat_mrn_id, episode_id, ob_dating_event as method_for_working_edd,
        episode_working_edd, line, entry_comment
 from ob_dating_epic
 where working_edd='Y' and not missing(episode_working_edd);

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
        where not missing(episode_working_edd)
        group by pat_mrn_id, episode_id
    ) as b
    on a.pat_mrn_id = b.pat_mrn_id and a.episode_id = b.episode_id and a.line = max_line;

 select count(*) label = 'Count of episodes with a final edd method'
 from
 (
    select distinct pat_mrn_id, episode_id
    from b1_epic_final_edd_last_entry
 );

 create table outlib.b1_epic_working_edd_methods_lmps as
 select coalesce(a.pat_mrn_id, b.pat_mrn_id) as pat_mrn_id,
        coalesce(a.episode_id, b.episode_id) as episode_id,
        a.episode_working_edd,
        b.method_for_working_edd,
        b.entry_comment
 from
    outlib.b1_epic_final_working_edd as a
    left join
    b1_epic_final_edd_last_entry as b
 on a.pat_mrn_id = b.pat_mrn_id and a.episode_id = b.episode_id;

* Remove the episodes that have only LMP as the dating event, to remove errors;
proc sql;
create table outlib.b1_epic_working_edd_methods as
select * from outlib.b1_epic_working_edd_methods_lmps
where episode_id not in (select episode_id from lmps)
;

*Combine everything together : this needs to be an inner join, but once the us is unified to have a row per study;
%macro mergedatasets(set1=, set2=, outset=);
 %let sortvars = pat_mrn_id episode_id;
 proc sort data=&set1 out=work._tmpsort1_;
    by &sortvars;
 run;
 proc sort data=&set2 out=work._tmpsort2_;
    by &sortvars;
 run;
 data &outset;
    merge _tmpsort1_ _tmpsort2_;
    by &sortvars;
 run;
 proc delete data=work._tmpsort1_ work._tmpsort2_;
 run;
%mend;

* macro to just set one dataset;
%macro setdataset(setin=, setout=);
 data &setout.;
 set &setin.;
 run;
%mend;

data tablenames;
length tablename $ 40;
input tablename $;
datalines;
b1_epic_working_edd_methods
b1_epic_lmps_last_entry
b1_epic_deliveries
b1_epic_emb_trans_last_entry
b1_epic_ultrasounds
;
run;

data _null_;
set tablenames;
if _n_=1 then
 call execute( catt('%setdataset(setin=outlib.', tablename, ', setout=', '&epic_ga_table.', ');'));
else
 call execute( catt('%mergedatasets(set1=', '&epic_ga_table.', ', set2=outlib.', tablename, ', outset=', '&epic_ga_table.', ');'));
run;

* remove entries that are only within delivery date when available;
proc sql;
create table deleting_epic_rows as
       select * 
       from &epic_ga_table.
       where 
            not missing(delivery_date) and
                not missing(episode_working_edd) and
                ( delivery_date < episode_working_edd - &ga_cycle. or delivery_date > episode_working_edd + 30)
;

proc sql;
delete * 
 from &epic_ga_table.
 where 
    not missing(delivery_date) and
                not missing(episode_working_edd) and
                ( delivery_date < episode_working_edd - &ga_cycle. or delivery_date > episode_working_edd + 30)
;

proc sql;
alter table &epic_ga_table. add edd_source char;
update &epic_ga_table. set edd_source='EPIC';

proc delete data=work.ob_dating_epic_temp work.episode_counts work.ob_dating_epic 
    work.tempusdates work.tempusga work.b1_working_edd_methods 
    work.b1_epic_final_edd_last_entry work.SORTTempTableSorted work.tablenames;
run;

proc sql;
create table outlib.epic_inconsistencies as
    select b.*, a.count_episodes
    from
        ( 
            select distinct pat_mrn_id, episode_working_edd, count(*) as count_episodes 
            from &epic_ga_table. 
            group by pat_mrn_id, episode_working_edd 
        ) as a
        inner join
        &epic_ga_table. as b
    on
        a.pat_mrn_id = b.pat_mrn_id and
        a.episode_working_edd = b.episode_working_edd and
        a.count_episodes > 1 and
        not missing(a.episode_working_edd)
    order by pat_mrn_id, episode_id   
;
