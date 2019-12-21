
from pathlib import Path
import pandas as pd 
import db

datadir = Path('/Users/hinashah/UNCFAMLI/Data/StructuredReports/SASUniversityEdition/myfolders')
b1_biom_table_name = 'b1_biometry_20191218_133525.sas7bdat'


b1_biom = db.DbBase(datadir/b1_biom_table_name)
if not b1_biom.isValid():
    exit()

b1_biom_table = b1_biom.getTable()

uniquePatients = b1_biom_table['PatientID'].unique()

missingga = b1_biom_table['ga_lmp'].isna() & b1_biom_table['ga_doc'].isna() & b1_biom_table['ga_edd'].isna()
notmissingga = pd.notna(b1_biom_table['ga_lmp']) | pd.notna(b1_biom_table['ga_doc']) | pd.notna(b1_biom_table['ga_edd'])

studiesalo = (b1_biom_table[notmissingga]).copy()
pidsalo = studiesalo['PatientID'].unique()
print("Studies with at least one: {}, patients with at least one: {} ".format(len(studiesalo), len(pidsalo)))
studiesmissing = b1_biom_table[missingga]
pidsmissin = studiesmissing['PatientID'].unique() 
print("Studies with missing: {}, patients with missing: {}".format(len(studiesmissing), len(pidsmissin)))

commonpids = studiesmissing['PatientID'][studiesmissing['PatientID'].isin(studiesalo['PatientID'])]
print("Studies with common pids: {}".format(len(commonpids)))

commonstudiesalo = (studiesalo[studiesalo['PatientID'].isin(commonpids)]).copy()
startdates = []
ga_type_arr = []
for idx, entry in commonstudiesalo.iterrows():
    if pd.notna(entry['ga_lmp']):
        ga = entry.ga_lmp
        ga_type = 'ga_lmp'
    elif pd.notna(entry['ga_doc']):
        ga = entry.ga_doc
        ga_type = 'ga_doc'
    else:
        ga = entry.ga_edd
        ga_type = 'ga_edd'
    startdates.append((entry.studydttm - pd.to_timedelta(ga, unit='d')).date())
    ga_type_arr.append(ga_type)

commonstudiesalo['startdate'] = startdates
commonstudiesalo['ga_type'] = ga_type_arr

commonstudiesmissing = (studiesmissing[studiesmissing['PatientID'].isin(commonpids)]).copy()
gasdict = {}
gasdict['ga_edd'] = [pd.NaT]*len(commonstudiesmissing)
gasdict['ga_lmp'] = [pd.NaT]*len(commonstudiesmissing)
gasdict['ga_doc'] = [pd.NaT]*len(commonstudiesmissing)
dictind = 0
for idx, entry in commonstudiesmissing.iterrows():
    studydate = (entry.studydttm).date()
    gas = studydate - commonstudiesalo['startdate']
    alo = commonstudiesalo[ (commonstudiesalo['PatientID'] == entry.PatientID) &  (gas > pd.Timedelta(0, unit='d')) & (gas < pd.Timedelta(280, unit='d'))]
    if len(alo) > 0:
        #Get the first row
        ga_type = alo.iloc[0].ga_type
        ga = (studydate - alo.iloc[0].startdate).days
        gasdict[ga_type][dictind] = ga
    dictind += 1 

commonstudiesmissing['ga_lmp'] = gasdict['ga_lmp']
commonstudiesmissing['ga_doc'] = gasdict['ga_doc']
commonstudiesmissing['ga_edd'] = gasdict['ga_edd']

print('--Updating---')
b1_biom_table.update(commonstudiesmissing)
b1_biom_table['filename'] = b1_biom_table['filename'].astype(str)
b1_biom_table['PatientID'] = b1_biom_table['PatientID'].astype(str)
b1_biom_table.to_csv(str(datadir/'b1_biometry_20191218_133525_extr.csv'))
print('--done---')

# libname famdat '/folders/myfolders/';
# %let b1_biom_table = b1_biometry_20191218_133525;

# * pids with at least one ga per study;
# proc sql;
# create table b1_all_patids as 
# select distinct(PatientID) from famdat.&b1_biom_table;

# create table b1_pid_alo as
# select distinct(PatientID) from famdat.&b1_biom_table 
# where not (missing(ga_lmp) and missing(ga_edd) and missing(ga_doc));

# * pids with no ga per study;
# create table b1_pids_mis as
# select distinct(PatientID) from famdat.&b1_biom_table
# where missing(ga_lmp) and missing(ga_edd) and missing(ga_doc);

# * Find pids that have missing dates, but also have some with a ga;
# create table common_pids as
# select a.PatientID from 
# b1_pids_mis as a inner join b1_pid_alo as b 
# on a.PatientID = b.PatientID;

# create table b1_alo_studies as
# select filename, PatientID, studydttm, ga_lmp, ga_edd, ga_doc from famdat.&b1_biom_table 
# where not (missing(ga_lmp) and missing(ga_edd) and missing(ga_doc));

# *Find studies that have missing gas, but also have another study with a ga;
# create table b1_common_studies as
# select filename, PatientID, studydttm, ga_lmp, ga_edd, ga_doc from famdat.&b1_biom_table
# where missing(ga_lmp) and missing(ga_edd) and missing(ga_doc) and PatientID in
# (select PatientID from common_pids);
# quit;

# data b1_alo_studies;
# set b1_alo_studies;
# if not missing(ga_lmp) then do;
# 	startdate = datepart(studydttm) - ga_lmp;
# 	ga_type = 'ga_lmp';
# 	end;
# else if not missing(ga_doc) then do;
# 	startdate = datepart(studydttm) - ga_doc;
# 	ga_type = 'ga_doc';
# 	end;
# else do;
# 	startdate = datepart(studydttm) - ga_edd;
# 	ga_type = 'ga_edd';
# 	end;
# run;


# %macro fillGA(pid=, studydttm=);

# 	proc sql;
# 	select * from b1_alo_studies
# 	where PatientiD='&pid' and studydttm = &studydttm and datepart(&studydttm) - startdate
	
# 	data withpid;
# 	set b1_alo_studies;
# 	where PatientID="&pid" and studydttm=&studydttm;
# 	*ga = datepart(&studydttm) - startdate;
# 	run;
# %mend;

# data b1_common_studies;
# set b1_common_studies (obs=1);
# call execute( catt('%fillGA(pid=', PatientID, ', studydttm=', studydttm, ');'));
# run;
