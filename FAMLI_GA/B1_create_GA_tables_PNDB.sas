
/********** PNDB **************/
* Extract gestational age information from the PNDB database;
proc sql;
	create table &pndb_ga_table. as
	select Mom_EpicMRN as PatientID,
			M_PDT0101 as LMP,
			M_PDT0102 as EDC_LMP,
			M_PDT0103 as US_DATE,
			M_PDT0105 as US_EDC,
			M_PDT0106 as BEST_EDC,
			M_PDT0107 as Delivery_date
	from &pndb_table.
	where not missing(Mom_EpicMRN);

data &pndb_ga_table. (drop= gaus galmp eddlmp diffedds);
set &pndb_ga_table.;
	if missing(BEST_EDC) then do;
		if not missing(US_DATE) and not missing(US_EDC) and not missing(LMP) then
		do;
			gaus = 280 - (US_EDC - US_DATE);
			galmp = US_DATE - LMP;
			eddlmp = lmp + 280;
			BEST_EDC = eddlmp;
			diffedds = abs(eddlmp - US_EDC);
			if (galmp < 62 and diffedds > 5) |
			(galmp < 111 and diffedds > 7) |
			(galmp < 153 and diffedds > 10) | 
			(galmp < 168 and diffedds >14) | 
			(galmp >= 169 and diffedds > 21)
			then
				BEST_EDC = US_EDC;
		end;
	end;
	edd_source = 'PNDB';
run;
