import matplotlib.mlab as mlab
import matplotlib.pyplot as plt 
from pathlib import Path
import csv
import logging

in_dir = Path('/Users/hinashah/famli/Users/hinashah/dataset_C1_cines')

ga_file_names = list( in_dir.glob('**/gestational_ages.csv') )
print('Found: {} files'.format(len(ga_file_names)))

all_gas = {}
for ga_file in ga_file_names:
    try:
        with open(ga_file) as f:
            csv_reader = csv.DictReader(f)
            for line in csv_reader:
                if line['Study'] not in all_gas.keys():
                     all_gas[ line['Study']  ] = int(float(line['GA']))
    except (OSError) as e:
        logging.error('Error reading csv file: {}'.format(ga_file))
        exit

num_studies = len(all_gas.keys())
print('Cines extracted have {} studies in all'.format(num_studies))

gas = all_gas.values()
num_bins = 40
n, bins, patches = plt.hist(gas, num_bins, facecolor='blue', alpha=0.5)
plt.xlabel('Gestational Age in days')
plt.ylabel('Frequency')
plt.title(r'Histogram of GAs in C1 extracted cines')
plt.show()


#log_file = Path('/Users/hinashah/UNCFAMLI/Data/us_tags_extract/log20191101-124356.txt')
log_file = Path('/Users/hinashah/famli/Users/hinashah/dataset_C1_cines/log20191101-191445.txt')
with open(log_file) as f:
    all_lines = [line.rstrip('\n') for line in f]

processing_lines = [line.find('PROCESSING:') for line in all_lines]
study_line_indices = [i for i,e in enumerate(processing_lines) if e>=0]

study_alo_cine = 0
study_list_alo_cine = []
for study_line_index in study_line_indices:
    # get the next line
    next_line = all_lines[study_line_index + 1]
    # if it says it found a cine,
    if next_line.find('Copying file:') >= 0:
        # Make sure there is a study name in the processing line:
        if all_lines[study_line_index].find('info.csv') >= 0:
            # extract the study name
            study_path = Path( all_lines[study_line_index].split()[-1])    
            folder_name = Path( study_path.parent ).name 
            study_list_alo_cine.append(folder_name)
            # increment the study counter
            study_alo_cine +=1

print('Number of studies with at least one cine: {}'.format(study_alo_cine))

study_list_no_ga = [study for study in study_list_alo_cine if study not in all_gas.keys()]
with open('/Users/hinashah/famli/Users/hinashah/dataset_c1_nogas.txt', 'w') as f:
    f.writelines("%s\n" % study for study in study_list_no_ga)
