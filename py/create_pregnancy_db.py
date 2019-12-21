from pathlib import Path
import pandas as pd
import db


datadir = Path('/Users/hinashah/UNCFAMLI/Data/StrcturedReports/SASUniversityEdition/myfolders')
b1_biom_table_name = 'b1_biometry_20191218_133525.sas7bdat'

b1_biom = db.DbBase(datadir/b1_biom_table_name)
if not b1_biom.isValid():
    exit()

b1_biom_table = b1_biom.getTable()

pregnancies = {}
for index, entry in b1_biom_table.iterrows():
    if entry.ga_lmp > 0 or entry.ga_doc > 0 or entry.ga_doc > 0:
        # Exists a gestational age. Create a pregnancy entry
        if entry.PatientID not in pregnancies.keys():
            pregnancies[entry.PatientID] = []
        ga = 0
        if entry.ga_lmp > 0:
            ga = entry.ga_lmp.iloc[0]
        elif entry.ga_doc > 0:
            ga = entry.ga_dociloc[0]
        elif entry.ga_edd > 0:
            ga = entry.ga_eddiloc[0]

        startdate = (entry.studydttm.iloc[0]).date() - pd.to_timedelta(ga, unit='d')
        if startdate not in pregnancies[entry.PatientID]:
            pregnancies[entry.PatientID].append(startdate)