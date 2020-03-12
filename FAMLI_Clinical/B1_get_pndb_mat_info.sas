*Script to create the pndb records for maternal vitals.;
*IMPORTANT: To import data correctly please make sure that the NULL strings are replaced
with empty cells in the original excel file;

*libname famdat '/folders/myfolders/';
/*libname famdat "F:\Users\hinashah\SASFiles";
%let b1_biom_table = b1_biom;
%let pndb_table = pndb_famli_records;
*/

*preprocess the pndb dataset;
data pndb_preprocess (keep= HospNum Mom_EpicMRN MRN
							A_APP0701 A_APP0702 A_APP0703 A_APP0704 A_APP0705 A_APP0706 A_CLD0401 A_CLD0402 A_CLD0403
							B_APP0803 B_APP0804 B_APP0809 B_APP0811 B_APP0801 B_APP0802 B_APP0810
							G_APP0510 F_PMH1515
							M_PDT0101 M_PDT0103 M_PDT0105 M_PDT0106 M_PDT0107 N_PDT0108 N_PDT0109
							L_APP0108 S_INF0112 D_Mom_DOB
							PregIndHTN PrevDiab GestDiab CalcEdd EddsEqual MomAgeEDD GABirth diff bestedd
							);
set famdat.&pndb_table (keep= HospNum Mom_EpicMRN
							A_APP0701 A_APP0702 A_APP0703 A_APP0704 A_APP0705 A_APP0706 A_CLD0401 A_CLD0402 A_CLD0403
							B_APP0803 B_APP0804 B_APP0809 B_APP0811 B_APP0801 B_APP0802 B_APP0810
							G_APP0510 F_PMH1515
							M_PDT0101 M_PDT0103 M_PDT0105 M_PDT0106 M_PDT0107 N_PDT0108 N_PDT0109
							L_APP0108 S_INF0112 D_Mom_DOB);

if not missing(Mom_EpicMRN) then
	MRN = put(input(Mom_EpicMRN, best12.), z12.);

PregIndHTN = A_APP0702 | A_APP0703 | A_APP0704 | A_APP0705 | A_APP0706 | A_CLD0401 | A_CLD0402 | A_CLD0403;
PrevDiab =  B_APP0803 | B_APP0804 | B_APP0809 | B_APP0811;
GestDiab = B_APP0801 | B_APP0802 | B_APP0810;

if not missing(M_PDT0103) and not missing(M_PDT0105) and not missing(M_PDT0101) then
do;
	usdate = M_PDT0103;
	usedd = M_PDT0105;
	lmp = M_PDT0101;
	gaus = &ga_cycle. - (usedd - usdate);
	galmp = usdate - lmp;
	eddlmp = lmp + &ga_cycle.;
	CalcEdd = eddlmp;
	diffedds = abs(eddlmp - usedd);
	if (galmp < 62 and diffedds > 5) |
	(galmp < 111 and diffedds > 7) |
	(galmp < 153 and diffedds > 10) |
	(galmp < 168 and diffedds >14) |
	(galmp >= 169 and diffedds > 21)
	then
		CalcEdd = usedd;
	format CalcEdd mmddyy10.;
	format eddlmp mmddyy10.;
end;

if not missing(M_PDT0106) and CalcEdd=M_PDT0106 then
	EddsEqual = 1;
else EddsEqual = 0;

if not missing(M_PDT0106) then
	bestedd = M_PDT0106;
else if not missing(CalcEdd) then
	bestedd = CalcEdd;

if not missing(bestedd) and not missing(D_Mom_DOB) then
do;
	MomAgeEDD = yrdif(D_Mom_DOB, bestedd, 'AGE');
	format MomAgeEDD 3.2;
end;

if not missing(bestedd) then
do;
	diff = bestedd - M_PDT0107;
	GABirth = &ga_cycle. - (bestedd - M_PDT0107);
end;

run;

* Find common pids in both the tables;
proc sql;
create table common_mrns as
	select distinct PatientID 
	from famdat.&ga_table. 
	where PatientID in
	(
		select MRN 
		from pndb_preprocess 
		where not missing(Mom_EpicMRN) 
	)
;


* Find similar entries from the pndb database using mrns;
create table studies_and_deliveries as
	select a.filename, a.PatientID, a.studydate, a.ga_edd as ga, b.* 
	from
		famdat.&ga_table. as a
		inner join
		(
			select MRN,
			bestedd - &ga_cycle. as DOC format mmddyy10.,
			bestedd as episode_working_edd format mmddyy10.,
			D_Mom_DOB as mom_birth_date format mmddyy10.,
			MomAgeEDD as mom_age_edd format 3.2,
			M_PDT0107 as delivery_date format mmddyy10.,
			L_APP0108 as fetal_growth_restriction,
			N_PDT0108*16 as mom_weight_oz,
			N_PDT0109 as mom_height_in,
			S_INF0112 as birth_wt_gms,
			GABirth as birth_ga_days,
			G_APP0510 as hiv,
			case 
				when F_PMH1515 > 0 then 'CURRENT SMOKER (PNDB)' 
			end as tobacco_use,
			F_PMH1515 as tobacco_pak_per_day,
			A_APP0701 as chronic_htn,
			case 
				when PregIndHTN = 1 then .
				when PregIndHTN = 0 then 0
				else  .
			end as preg_induced_htn,
			PrevDiab as diabetes,
			case 
				when GestDiab= 1 then .
				when GestDiab= 0 then 0
				else  .
			end as gest_diabetes
			from pndb_preprocess 
			where not missing(Mom_EpicMRN)
		) as b
		on 
			a.PatientID = b.mrn and
			a.episode_edd = b.episode_working_edd and 
			a.PatientID in 
			(
				select * from common_mrns
			)
;

* Select by pregnancy dates;
create table famdat.&mat_info_pndb_table.(drop=MRN) as
	select * 
	from studies_and_deliveries
	where 
		delivery_date > studydate and
		delivery_date < studydate + (&max_ga_cycle.-ga)
;
