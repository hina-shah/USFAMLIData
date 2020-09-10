

%macro processArray(bn=);
    data &biom_subset_measures.;
    set &biom_subset_measures.;
        array biomarr &bn.:;
        
        &bn.first_1 = biomarr{1};
        &bn.first_2 = biomarr{2};
        
        if missing(&bn._first_2) then &bn.firstMean = &bn.first_1;
        else &bn._firstMean = mean(&bn.first_1, &bn.first_2);
        
        do i=dim(biomarr) to 1 by -1;
            if not missing(biomarr{i}) then
            do;
                if i>1 then do;
                    &bn.last_1 = biomarr{i};
                    &bn.last_2 = biomarr{i-1};
                    &bn.lastMean = mean(&bn.last_1, &bn.last_2);
                end;
                else do;
                    &bn.last_1 = biomarr{i};
                    &bn.lastMean = biomarr{i};
                end;
                leave;
            end;
        end;
    run;
%mend;

data &biom_subset_measures.;
set &biom_final_output_table.;
run;

data _null_;
set outlib.biomvar_details;
call execute( catt('%processArray(bn=', shortname, ');'));
run;

/*Create a dataset that keeps first and last two measurements along with their means*/
data &biom_subset_measures. (keep = filename PatientID studydate ga_edd lmp 
                                           fl_first: fl_last: bp_first: bp_last: 
                                           hc_first: hc_last: ac_first: ac_last:
                                           crl_first: crl_last: tcd_first: tcd_last:
                                           afiq1_first: afiq1_last: afiq2_first: afiq2_last:
                                           afiq3_first: afiq3_last: afiq4_first: afiq4_last:
                                           mvp_first: mvp_last:);
set &biom_subset_measures.;
run;
