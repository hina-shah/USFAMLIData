/*
 * Get delivery dates and gestational ages and baby weight at birth from epic
 */

/******************* BIRTH WEIGHT AND GA AT BIRTH ******************/
proc sql;
select 'Number of deliveries in EPIC', count(*) from epic.delivery;
select 'Number of deliveries in EPIC where ga at birth is missing', count(*) from epic.delivery where missing(ga_days);
create table ts as select *, count(*) as num_f from epic.delivery group by pat_mrn_id, datepart(delivery_dttm_utc);
select 'Number of multifetal deliveries in EPIC:', count(*) from ts where num_f > 1;


proc sql;
*gather birth weight and ga days -> assumes that the study patients also delivered here.;
create table epic_maternal_info as
    select distinct a.*, 
        b.birth_wt_ounces*28.34952 as birth_wt_gms, 
        b.ga_days as birth_ga_days,
        datepart(b.delivery_dttm_utc) as delivery_date format mmddyy10.
    from
        epic_maternal_info as a 
        left join
        epic.delivery as b 
    on
        (a.PatientID = b.pat_mrn_id) and 
		a.studydate <= datepart(b.delivery_dttm_utc) and
		a.studydate >= datepart(b.delivery_dttm_utc) - b.ga_days and
		not missing(b.ga_days) and
        not missing(b.delivery_dttm_utc);
quit;

proc sql;
select count(*) from epic_maternal_info where missing(birth_wt_gms);
select count(*) from epic_maternal_info where missing(birth_ga_days);
select count(*) from epic_maternal_info where missing(delivery_date);
