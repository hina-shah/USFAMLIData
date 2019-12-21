from argparse import ArgumentParser
from pathlib import Path
import logging
import os
import csv
import utils
import db

def main(args):
    data_folder = Path(args.dir)
    out_folder = Path(args.out_dir)
    
    utils.setupLogFile(out_folder, args.debug)
    
    ob_table_name = 'ob_dating.sas7bdat'

    # Setup the GA database
    missing_patids = db.DbBase(args.db_file)
    if not missing_patids.isValid():
        logging.error('Failed to read the Missing GA database file, exiting')
        return

    dating_info = db.EpicDbProcessor(data_folder)
    dating_info.initObDatingTable()
    if not dating_info.isValid():
        logging.error('Failed to read the OB Dating database file, exiting')
        return

    missinggas = missing_patids.getVariables(['PatientID','studydttm'])
    missinggas = missinggas[missinggas.PatientID.notnull()]
    gas_added = 0
    for index, missingga in missinggas.iterrows():
        # Call the epic db processor to get the GA.
        ga, ga_type = dating_info.getGAForStudyID(missingga.PatientID, (missingga.studydttm).date())
        if ga is not None:
            missinggas.at[index, ga_type] = ga
            gas_added += 1
    missinggas.to_csv(str(out_folder/'missinggas_epic_filled.csv'))
    print('Added {} missing gas'.format(gas_added))

if __name__=="__main__":
# /Users/hinashah/famli/Groups/Restricted_access_data/Clinical_Data/EPIC/Dataset_B
    parser = ArgumentParser()
    parser.add_argument('--dir', type=str, help='Directory with the EPIC database files')
    parser.add_argument('--out_dir', type=str, help='Output folder name')
    parser.add_argument('--db_file', type=str, help='Databse file with study information missing Gestational Ages')
    parser.add_argument('--debug', action='store_true', help='Add debug info in log')
    args = parser.parse_args()

    main(args)