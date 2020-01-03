*Script to create the pndb records for maternal vitals.;
*IMPORTANT: To import data correctly please make sure that the NULL strings are replaced
with empty cells in the original excel file;

libname famdat '/folders/myfolders/';
%let b1_biom_table = b1_biom;
%let pndb_table = pndb_famli_records; 

*preprocess the pndb dataset;
data pndb_preprocess (keep= HospNum Mom_EpicMRN MRN 
							A_APP0701 A_APP0702 A_APP0703 A_APP0704 A_APP0705 A_APP0706 A_CLD0401 A_CLD0402 A_CLD0403
							B_APP0803 B_APP0804 B_APP0809 B_APP0811 B_APP0801 B_APP0802 B_APP0810
							G_APP0510 F_PMH1515 
							M_PDT0101 M_PDT0103 M_PDT0105 M_PDT0106 M_PDT0107 M_PDT0108 M_PDT0109
							L_APP0108 S_INF0112 D_Mom_DOB
							PregIndHTN PrevDiab GestDiab CalcEdd EddsEqual MomAgeEDD GABirth diff
							);
set famdat.&pndb_table (keep= HospNum Mom_EpicMRN 
							A_APP0701 A_APP0702 A_APP0703 A_APP0704 A_APP0705 A_APP0706 A_CLD0401 A_CLD0402 A_CLD0403
							B_APP0803 B_APP0804 B_APP0809 B_APP0811 B_APP0801 B_APP0802 B_APP0810
							G_APP0510 F_PMH1515 
							M_PDT0101 M_PDT0103 M_PDT0105 M_PDT0106 M_PDT0107 M_PDT0108 M_PDT0109
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
	gaus = 280 - (usedd - usdate);
	galmp = usdate - lmp;
	eddlmp = lmp + 280;
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
	GABirth = 280 - (bestedd - M_PDT0107);
end;

run;

data biom_with_startdate;
set famdat.&b1_biom_table;
if ga_lmp > 0 then
	ga = ga_lmp;
else if ga_edd > 0 then
	ga = ga_edd;
else if ga_doc > 0 then
	ga = ga_doc;
else if ga_unknown > 0 then
	ga = ga_unknown;
else if ga_extrap > 0 then
	ga = ga_extrap;
run;

* Find common pids in both the tables;
proc sql;
create table common_mrns as 
select distinct PatientID from biom_with_startdate where PatientID in
(select 
MRN from pndb_preprocess where not missing(Mom_EpicMRN) );


* Find similar entries from the pndb database using mrns;
create table studies_and_deliveries as
select a.filename, a.PatientID, a.studydttm, a.ga, b.* from 
biom_with_startdate as a 
left join 
(
select MRN, 
M_PDT0107 as DelDate format mmddyy10., 
L_APP0108 as FetGrowthRestr,
M_PDT0108 as MatWeightLbs,
M_PDT0109 as MatHeightIn, 
S_INF0112 as BirthWtLbs,
G_APP0510 as HIV_AIDS,
F_PMH1515 as Tobacco_Use,
A_APP0701 as ChronicHTN,
PregIndHTN, PrevDiab, GestDiab, 
MomAgeEDD, GABirth
from pndb_preprocess where not missing(Mom_EpicMRN)
) as b
on a.PatientID = b.mrn;

* Select by pregnancy dates;
create table famdat.b1_maternal_info (drop=MRN) as
select * from studies_and_deliveries
where PatientID in (select * from common_mrns) and 
DelDate > datepart(studydttm) and 
DelDate < datepart(studydttm) + (300-ga);
