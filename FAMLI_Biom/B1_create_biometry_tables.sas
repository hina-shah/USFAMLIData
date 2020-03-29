* Program to create the biometry table from B1 dataset structured reports table;

%macro createTable(biometry=, biomvname=, shortname=, pattern=);
    * read the biometry tags;
    proc sql;
    create table temp_&biomvname as
        select filename, PatientID, studydttm, tagcontent
        from &famli_table
        where 
            missing(Derivation) and 
            tagname = "&biometry" and
            prxmatch("/&pattern./",Container) > 0
        group by filename
        order by filename
    ;
    
    proc sql;
    create table temp_&biomvname._calc as
        select filename, PatientID, studydttm, tagcontent
        from &famli_table
        where
            Derivation='Calculated'
            and tagname = "&biometry"
            and prxmatch("/&pattern./",Container) > 0
            and filename not in (select filename from temp_&biomvname)
    ;
    
    * Remove duplicate tag contents;
    data WORK.temp_&biomvname._unique;
    set temp_&biomvname temp_&biomvname._calc;
    run;
 
     * delete not needed tables;
    proc delete data=temp_&biomvname. temp_&biomvname._calc;
    run;

    * Convert data to numerical values, and convert mms to cms;
    data WORK.temp_&biomvname._unique (drop=pos posmm tagcontent) ;
    set WORK.temp_&biomvname._unique;
    if not missing(tagcontent) then
        do;
            pos = find(tagcontent, 'cm', 'it') + find(tagcontent, 'centimeter', 'it');
            if pos = 0 then
            do;
                posmm = find(tagcontent, 'mm', 'it') + find(tagcontent, 'millimeter', 'it');
                if posmm > 0 then
                do;
                    put tagcontent;
                    tagcontent = compress(tagcontent,'','A')/10.0;
                end;
            end;
            else tagcontent = compress(tagcontent,'','A');
            num = input(tagcontent, 4.2);
        end;
    run;

    * Create columns for each biometry measurement;
    proc sort data= WORK.temp_&biomvname._unique out=WORK.SORTTempTableSorted;
        by PatientID studydttm filename;
    run;

    proc transpose data=WORK.SORTTempTableSorted prefix=&shortname
            out=WORK.&biomvname(drop=_Name_);
        var num;
        by PatientID studydttm filename;
    run;

    * Convert data to numerical values, and convert mms to cms;
    data famdat.&biomvname;
    set work.&biomvname;
    run;

    proc delete data=WORK.SORTTempTableSorted WORK.&biomvname WORK.temp_&biomvname._unique;
    run;

%mend;


data famdat.biomvar_details;
length tagname $ 27;
length varname $ 20;
length shortname $ 6;
length pattern $ 45;
infile datalines delimiter=',';
input tagname $ varname $ shortname $ pattern $;
call execute( catt('%createTable(biometry=', tagname, ', biomvname=', varname, ', shortname=', shortname, ', pattern=', pattern, ');'));
datalines;
Femur Length,biom_femur_length,fl_,Fetal Biometry: Biometry[ ]?Group
Biparietal Diameter,biom_bip_diam,bp_,Fetal Biometry: Biometry[ ]?Group
Head Circumference,biom_head_circ,hc_,Fetal Biometry: Biometry[ ]?Group
Crown Rump Length,biom_crown_rump,crl_,Early Gestation: Biometry[ ]?Group[s]?
Abdominal Circumference,biom_abd_circ,ac_,Fetal Biometry: Biometry[ ]?Group
Trans Cerebellar Diameter,biom_trans_cer_diam,tcd_,Fetal Biometry: Biometry[ ]?Group
AMNIOTIC FLUID INDEX LEN q1,afi_q1,afiq1_,Findings
AMNIOTIC FLUID INDEX LEN q2,afi_q2,afiq2_,Findings
AMNIOTIC FLUID INDEX LEN q3,afi_q3,afiq3_,Findings
AMNIOTIC FLUID INDEX LEN q4,afi_q4,afiq4_,Findings
Max Vertical Pocket,max_vp,mvp_,(MVP)|(Pelvis and Uterus: Biometry Group)
;
run;

