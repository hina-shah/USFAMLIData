import pandas as pd
import numpy as np
import logging
from .DbBase import DbBase

# This class is for processing sas datasets (or derivatives of)
# that have been generated from dicom sr. 
class SrDb(DbBase):
    
    def __init__(self, path):
        super().__init__(path)
        self._gatagnames = [b'Gestational Age by EDD', b'Gestational Age by LMP']
        self._reqd_tags = ['tagname', 'StudyID', 'pid', 'studydate', 'tagcontent', 'numericvalue']

    def getGAForStudyID(self, studyID):
        if not self.isValid():
           logging.error('Database not valid, returning')
           return None, None

        subset = self._db[ ['numericvalue', 'tagname' ]][ (self._db['tagname'].isin(self._gatagnames)) & 
                                      (self._db['StudyID'] == bytes(studyID, 'utf-8')) ]
        if subset.empty:
            subset = self._db[ 'numericvalue' ][ (self._db['StudyID'] == bytes(studyID, 'utf-8')) & 
                                                (self._db['tagname'] == b'Gestational Age') & 
                                                (self._db['Container'] == b'Summary') & 
                                                (self._db['Equation'].isnull())]
            if subset.empty:
                return None, None
            else:
                age = subset.iat[0]
                gatype = 'Gestational Age by Previous'
        else:
            age = subset.iat[0,0]
            gatype = subset.iat[0,1]

        return age, gatype
