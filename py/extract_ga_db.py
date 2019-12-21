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
   
    # Setup the GA database
    srdb = db.SrDb(args.db_file)
    if not srdb.isValid():
        logging.error('Failed to read the structured report database file, exiting')
        return

    if not srdb.checkNeededVariables():
        logging.error('Failed to read the needed variables from the DB')
        return

    # Make a list of the directories
    studies = []
    for dirname, dirnames, __ in os.walk(str(data_folder)):
        if len(dirnames) == 0:
            studies.append(Path(dirname))

    logging.info('Found {} studies '.format(len(studies)))
    print('Found {} studies '.format(len(studies)))
    
    # In the output folder, find the tag folders and make a list of csv writers for those
    tag_folders=[]
    tags_csv={} # Dictionary with all the csv rows for a tag
    for dirname, dirnames, __ in os.walk(str(out_folder)):
        if len(dirnames) == 0:
            tag_folders.append(Path(dirname))
            tags_csv[Path(dirname).name] = []
    
    all_csv_rows = []
    got_ga_count = 0
    for study_path in studies:
         # For each study directory, extract the study date and study id
        study_name = study_path.name
        pos = study_name.find('_')
        if pos == -1:
            logging.warning("Study name in path {} not in the correct format for a valid study".format(study_path))
            continue

        study_id = study_name[:pos]
        study_date = study_name[pos+1:pos+9]
        # Query study date and study id for patient id, a GA, and the ground truth
        ga, ga_type = srdb.getGAForStudyID(study_id)
        if ga is None:
            logging.info("Couldn't find GA for study: {}".format(study_name))
            continue
        
        got_ga_count +=1
        ga_type = ga_type.decode() if type(ga_type) is bytes else ga_type

        all_csv_rows.append({'Idx': str(got_ga_count), 'Study': str(study_name), 'GA': str(ga), 'type': ga_type})

        # Find the info.csv and create/write ga to the tag folders in the output directory
        info_file = study_path/'info.csv'
        try:
            with open(info_file) as f:
                csv_reader = csv.DictReader(f)
                file_tag_pairs = [ (line['File'], line['tag']) for line in csv_reader if line['tag'] in tags_csv.keys() ]
        except (OSError) as e:
            logging.error('Error reading csv file: {}'.format(info_file))
            return

        for file, tag in file_tag_pairs:
            file_name = Path(file).name
            tags_csv[tag].append({'File':file_name, 'Study': str(study_name), 'GA': str(ga)})

    # Write out to a common csv file whihc keeps a list of studies with GA
    # and their ground truth type
    file_path = data_folder/'gestational_ages.csv'
    utils.writeCSVRows(file_path, all_csv_rows, ['Idx', 'Study', 'GA', 'type'])

    for tag in tags_csv.keys():
        file_path = out_folder/tag/'gestational_ages.csv'
        utils.writeCSVRows(file_path, tags_csv[tag], ['File', 'Study', 'GA'])
    
    logging.info('Found {} Gestational ages out of {} studies'.format(got_ga_count, len(studies)))

if __name__=="__main__":
    
    parser = ArgumentParser()
    parser.add_argument('--dir', type=str, help='Directory with subject subfolders that have info.csv generated.'
                'Every lowest level subfolder will be considered as a study')
    parser.add_argument('--out_dir', type=str, help='Output directory location.'
                'This will be the directory where the cines have been classified by their tags')
    parser.add_argument('--debug', action='store_true', help='Add debug info in log')
    parser.add_argument('--db_file', type=str, help='Path to the database that holds GA information')
    args = parser.parse_args()

    main(args)