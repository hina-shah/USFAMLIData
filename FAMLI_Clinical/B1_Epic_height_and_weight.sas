
/*
* Script to extract maternal height and weight information before pregnancy from the Epic datasets.
* Assumes that the epic_maternal_info exists in the work library.
*/

/******************* HEIGHTS AND WEIGHT PREPROCESSING - create a date of conception table ******************/
proc sql;
create table DOCs as
select distinct PatientID, DOC from epic_maternal_info where not missing(DOC);

/******************* WEIGHTS ******************/
* Use maternal weight recorded either within the year before the pregnancy (most recent one), or
one recorded within the first 8 weeks of pregnancy;

* from the DOCs left join with weight using the date within one year prior to the pregnancy and
note the most recent one (back in time);
proc sql;
create table before as
	select distinct a.PatientID, a.DOC, b.weight_oz, b.recorded_time
	from
		DOCs as a 
		left join 
		epic.vitals as b 
	on
		a.PatientID = b.pat_mrn_id and
		b.recorded_time <= DHMS(a.DOC,11,59,59)
	where 
		not missing(b.weight_oz) and
		b.weight_oz >= &min_weight.*16 and
		b.weight_oz <= &max_weight.*16 and
		not missing(b.recorded_time)
	order by PatientID, DOC
;

create table maxbefore as
	select distinct a.PatientID, a.DOC, a.weight_oz, b.max_date
	from 
		before as a
		inner join
		(
			SELECT PatientID, DOC, MAX(recorded_time) as max_date
			from before
			GROUP BY PatientID, DOC
		) as b
	on 
		a.PatientID=b.PatientID and 
		a.DOC=b.DOC and 
		b.max_date = a.recorded_time and 
		b.max_date > DHMS(a.DOC-365, 0,0,0)
;

* from the DOCs left join with weight using the date within the pregnancy and
note the earliest one (forward in time);
create table after as
	select distinct a.PatientID, a.DOC, b.weight_oz, b.recorded_time
	from
		DOCs as a 
		left join 
		epic.vitals as b 
	on
		a.PatientID = b.pat_mrn_id and 
		b.recorded_time > DHMS(a.DOC,11,59,59)
	where 
		not missing(b.weight_oz) and 
		b.weight_oz >= &min_weight.*16 and
		b.weight_oz <= &max_weight.*16 and
		not missing(b.recorded_time)
	order by PatientID, DOC
;

create table minafter as
	select a.PatientID, a.DOC, a.weight_oz, b.min_date
	from 
		after as a
		inner join
		(
			SELECT PatientID, DOC, MIN(recorded_time) as min_date
			from after
			GROUP BY PatientID, DOC
		) as b
	on 
		a.PatientID=b.PatientID and 
		a.DOC=b.DOC and 
		b.min_date = a.recorded_time and 
		b.min_date < DHMS(a.DOC+&ga_cycle.,0,0,0)
;

* Combine the tables, and coalesce to use a weight recorded before the pregnancy when available;
proc sql;
create table weights as
	select coalesce(a.PatientID, b.PatientID) as PatientID, 
		coalesce(a.DOC, b.DOC) as DOC format mmddyy10.,
		coalesce(a.weight_oz, b.weight_oz) as mom_weight_oz
	from 
		maxbefore as a 
		full join 
		minafter as b
	on 
		a.PatientID = b.PatientID and 
		a.DOC=b.DOC
;

data weights;
set weights;
row = _n_;
run;

proc sql;
create table weights as
	select a.PatientID, a.DOC, a.mom_weight_oz
	from 
		weights as a 
		inner join 
		( 
			select PatientID, DOC, max(row) as max_line
			from weights
			group by PatientID, DOC
		) as b
	on 
		a.PatientID = b.PatientID and 
		a.DOC=b.DOC and
		a.row = b.max_line;

* Join with the maternal info dataset ;
create table epic_maternal_info as
	select distinct a.*, b.mom_weight_oz
	from
		epic_maternal_info as a 
		left join weights as b
	on
		a.PatientID=b.PatientID and 
		a.DOC=b.DOC;

/******************* HEIGHTS ******************/

* Use maternal height recorded either before the pregnancy (most recent one), or
one recorded after -> earliest one;
* Separting the most recent one and the earliest one to take into account that some
patients would be underage and height may change;

* from the DOCs left join with weight using the date within one year prior to the pregnancy and
note the most recent one (back in time);

proc sql;
create table before as
	select distinct a.PatientID, a.DOC, b.height_in, b.recorded_time
	from
		DOCs as a 
		left join 
		epic.vitals as b 
	on
		a.PatientID = b.pat_mrn_id and 
		b.recorded_time <= DHMS(a.DOC,11,59,59)
	where 
		not missing(b.height_in) and 
		b.height_in >= &min_height. and b.height_in <= &max_height. and
		not missing(b.recorded_time)
	order by PatientID, DOC;

create table maxbefore as
	select a.PatientID, a.DOC, a.height_in, b.max_date
	from 
		before as a
		inner join	
		(
			SELECT PatientID, DOC, MAX(recorded_time) as max_date
			from before
			GROUP BY PatientID, DOC
		) as b
	on 
		a.PatientID=b.PatientID and 
		a.DOC=b.DOC and 
		b.max_date = a.recorded_time;

create table after as
	select distinct a.PatientID, a.DOC, b.height_in, b.recorded_time
	from
		DOCs as a 
		left join 
		epic.vitals as b 
	on
		a.PatientID = b.pat_mrn_id and 
		b.recorded_time > DHMS(a.DOC,11,59,59)
	where 
		not missing(b.height_in) and 
		b.height_in >= &min_height. and b.height_in <= &max_height. and
		not missing(b.recorded_time)
	order by PatientID, DOC;

create table minafter as
	select a.PatientID, a.DOC, a.height_in, b.min_date
	from 
		after as a
		inner join
		(
			SELECT PatientID, DOC, MIN(recorded_time) as min_date
			from after
			GROUP BY PatientID, DOC
		) as b
	on 
		a.PatientID=b.PatientID and 
		a.DOC=b.DOC and
		b.min_date = a.recorded_time;

proc sql;
create table heights as
	select coalesce(a.PatientID, b.PatientID) as PatientID, 
		coalesce(a.DOC, b.DOC) as DOC format mmddyy10.,
		coalesce(a.height_in, b.height_in) as mom_height_in, 
		datepart(coalesce(a.max_date, b.min_date)) as ht_rec_date format mmddyy10.
	from 
		maxbefore as a 
		full join 
		minafter as b
	on
		a.PatientID = b.PatientID and 
		a.DOC=b.DOC;

data heights;
set heights;
row = _n_;
run;

proc sql;
create table heights as
	select a.PatientID, a.DOC, a.mom_height_in
	from 
		heights as a 
		inner join 
		( 
			select PatientID, DOC, max(row) as max_line
			from heights
			group by PatientID, DOC
		) as b
	on 
		a.PatientID = b.PatientID and 
		a.DOC=b.DOC and
		a.row = b.max_line
;

* Join with the maternal info dataset ;
create table epic_maternal_info as
	select distinct a.*, b.mom_height_in
	from
		epic_maternal_info as a 
		left join 
		heights as b
	on
		a.PatientID=b.PatientID and 
		a.DOC=b.DOC
;
