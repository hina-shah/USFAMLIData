import pandas as pd
import numpy as np
import logging
from .DbBase import DbBase

# This class is for processing sas datasets (or derivatives of)
# that have been generated from dicom sr. 
class EpicDb(DbBase):

    def __init__(self, path):
        super().__init__(path)
        self._reqd_tags = ['pat_mrn_id']


# This class is for processing sas datasets (or derivatives of)
# that have been generated from dicom sr. 
class EpicDbProcessor():

    def __init__(self, path):
        self._dir_path = path
        self._format = '.sas7bdat'
        self._delivery_table = None
        self._diagnosis_table = None
        self._labs_table = None
        self._ob_dating_table = None
        self._ob_history_table = None
        self._vitals_table = None

    def initDeliveryTable(self):
        self._delivery_table = EpicDb(self._dir_path/('delivery' + self._format))

    def initDiagnosisTable(self):
         self._diagnosis_table = EpicDb(self._dir_path/('diagnosis' + self._format))

    def initLabstable(self):
        self._labs_table = EpicDb(self._dir_path/('labs' + self._format))

    def initObDatingTable(self):
        self._ob_dating_table = EpicDb(self._dir_path/('ob_dating' + self._format))
    
    def initObHistoryTable(self):
        self._ob_history_table = EpicDb(self._dir_path/('ob_history' + self._format))

    def initVitalsTable(self):
        self._vitals_table = EpicDb(self._dir_path/('vitals' + self._format))

    def delDeliveryTable(self):
        del self._delivery_table
        self._delivery_table = None

    def delDiagnosisTable(self):
        del self._diagnosis_table
        self._diagnosis_table = None

    def delLabstable(self):
        del self._labs_table
        self._labs_table = None

    def delObDatingTable(self):
        del self._ob_dating_table
        self._ob_dating_table = None

    def delObHistoryTable(self):
        del self._ob_history_table
        self._ob_history_table = None

    def delVitalsTable(self):
        del self._vitals_table
        self._vitals_table = None

    def isValid(self):
        isvalid = self._delivery_table.isValid() if self._delivery_table is not None else True
        valid = isvalid
        isvalid = self._diagnosis_table.isValid() if self._diagnosis_table is not None else True
        valid &= isvalid
        isvalid = self._labs_table.isValid() if self._labs_table is not None else True
        valid &= isvalid
        isvalid = self._ob_dating_table.isValid() if self._ob_dating_table is not None else True
        valid &= isvalid
        isvalid = self._ob_history_table.isValid() if self._ob_history_table is not None else True
        valid &= isvalid
        isvalid = self._vitals_table.isValid() if self._vitals_table is not None else True
        valid &= isvalid
        return valid

    def getGAForStudyID(self, patientID, studyDate):
        if self._ob_dating_table is None:
            self.initObDatingTable()

        if not self.isValid():
           logging.error('Database not valid, returning')
           return None, None
        logging.debug('Processing patient: {} on studydate {}'.format(patientID, studyDate))
        ga_cycle = 300

        selectvars = ['user_entered_date', 'sys_estimated_edd']
        bptid = bytes(patientID) if type(patientID) is not bytes else patientID
        pat_us_table = self._ob_dating_table.getSubsetAt(selectvars, 
                                    ['ob_dating_event', 'pat_mrn_id'],
                                    [b'ULTRASOUND', bptid])
        
        if len(pat_us_table) == 0:
            logging.info('No ultrasounds found for patient {}'.format(patientID))
            return None, None

        # Get ultrasounds with user enetered date before studyDate
        minidx = self._ob_dating_table._num_obs
        date_cutoff = None # Using EDD as the
        first_us_date = studyDate

        for idx, entry in pat_us_table.iterrows():
            if date_cutoff is None:
                # The edd was not specified as input to the function. 
                # Try to see if the input ultrasound date is part of this entry's episode 
                # using the episode's (sys_entered_edd). If it is, set the date_cutoff 
                # based on the entry's sys_enteterd_edd
                tmp_date_cutoff = entry.sys_estimated_edd - (pd.to_timedelta(ga_cycle, unit='d'))
                date_cutoff = tmp_date_cutoff if studyDate > tmp_date_cutoff else None

            if date_cutoff is not None:
                # Find the first ultrasound in the series for this patient
                if entry.user_entered_date > date_cutoff and entry.user_entered_date <= first_us_date:
                    first_us_date = entry.user_entered_date
                    minidx = idx

        if minidx == self._ob_dating_table._num_obs:
            logging.info("Couldn't find US for the combination of: {}, {}".format(patientID, studyDate))
            return None, None
        
        final_ga = None
        final_ga_type = None
        # Get the row prior to the Ultrasound one
        prevrow = self._ob_dating_table.getPreviousRow(minidx)
        # Make sure the previous row still has the same patient info, else we don't have a previous row for the same patient
        if prevrow.iloc[0]['pat_mrn_id'] == patientID:
            # Note EDD from LMP if previous row is an LMP
            if prevrow.iloc[0]['ob_dating_event'] == b'LAST MENSTRUAL PERIOD':
                # Differ EDDs and keep GA per logic!
                us_row = self._ob_dating_table.getRowAt(minidx)
                lmp_edd = prevrow.sys_estimated_edd
                us_edd = us_row.sys_estimated_edd
                days_diff = (lmp_edd.iloc[0] - us_edd.iloc[0]).days
                logging.debug('Found a diff of {} days'.format(days_diff))
                us_ga = us_row.user_entered_ga_days.iloc[0]
                keep_ultrasound = False
                if (us_ga < 62 and days_diff > 5) or \
                   (us_ga < 111 and days_diff > 7) or \
                   (us_ga < 153 and days_diff > 10) or \
                   (us_ga < 168 and days_diff > 14) or \
                   (us_ga >= 169 and days_diff > 21) :
                    keep_ultrasound = True

                if keep_ultrasound:
                    final_ga = 280- ( (us_edd.iloc[0]).date() - studyDate).days
                    final_ga_type = 'ga_edd'
                else:
                    # Calculate ga frm 
                    final_ga = (studyDate - (lmp_edd.iloc[0]).date()).days
                    final_ga_type = 'ga_lmp'
            #TODO: THere are other dating events in the previous row as well.
            # Sometimes it can be ultrasounds, sometimes an updated LMP is seen AFTER
            # the Ultrasound rows -> coding should change or added for those?
        else:
            logging.debug("Patient information changed in previous row")

        return final_ga, final_ga_type
