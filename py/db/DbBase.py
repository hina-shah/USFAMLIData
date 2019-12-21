import pandas as pd
import numpy as np
import logging
from pathlib import Path

class DbBase:
    def __init__(self, path):
        self._dbfile_path = Path(path)
        self._db = None
        self._num_obs = 0
        self._num_vars = 0
        self._reqd_tags = None
        self.initDB()

    def isValid(self):
        return self._db is not None

    def initDB(self):
        if not self._dbfile_path.exists():
            logging.error('Path: {} does not exist, returning'.format(str(self._dbfile_path)))
            return;
        
        try:
            logging.info('Format is: {}'.format(self._dbfile_path.suffix))
            if self._dbfile_path.suffix == '.csv':
                self._db = pd.read_csv(self._dbfile_path, low_memory=False)
            elif self._dbfile_path.suffix == '.sas7bdat':
                self._db = pd.read_sas(self._dbfile_path)
            else: 
                logging.error('This type of database not yet supported!')
                return;

            logging.info('Read {}'.format(self._dbfile_path))
            self._num_obs = len(self._db)
            self._num_vars = len(self._db.columns)
            logging.info('*** Number of observations: {}'.format(self._num_obs))
            logging.info('*** Number of variables: {}'.format(self._num_vars))
        except:
            logging.error('Error reading database from: {}'.format(self._dbfile_path))
            return;

    def checkNeededVariables(self):
        if not self.isValid():
            logging.error('Database not valid, returning')
            return False

        if self._reqd_tags is not None:       
            varnames_list = self._db.columns.to_list()
            tags_exist = [l in varnames_list for l in self._reqd_tags]
            if tags_exist.count(False) > 0:
                missing_tags = self._reqd_tags[tags_exist == False]
                logging.error('Database is missing required tags: {}'.format(missing_tags))
                return False
        
        return True

    def printTypes(self):
        if self.isValid():
            logging.info(self._db.dtypes)
    
    # Return a subset from the database with selected var names and 
    # conditions that w
    def getSubsetAt(self, selVarNames, whereVarNames, whereValValues):
        if not self.isValid():
            logging.error('Database still not set, returning')
            return None
        try:
            cond_table = None
            if len(whereValValues) != len(whereVarNames):
                logging.error('Variable name value pair mismatch')
                return None
            for ind in range(len(whereVarNames)):
                t = self._db[whereVarNames[ind]] == whereValValues[ind]
                cond_table = t if cond_table is None else cond_table & t
            subset = self._db[selVarNames][cond_table]
            return subset
        except:
            logging.error('Error reading subset')
            return None

    def getPreviousRow(self, index):
        if not self.isValid():
            logging.info('Database still not set, returning')
            return None
        
        if index<1 or index > self._num_obs-1:
            logging.error('Index out of bounds')
            return None
        
        try:
            subset = self._db[index-1:index]
            return subset
        except:
            logging.error('Error reading previous row')
            return None

    def getNextRow(self, index):
        if not self.isValid():
            logging.info('Database still not set, returning')
            return None
        
        if index<0 or index > self._num_obs-2:
            logging.error('Index out of bounds')
            return None

        try:
            subset = self._db[index+1:index+2]
            return subset
        except:
            logging.error('Error reading previous row')
            return None

    def getFirstRow(self):
        if not self.isValid():
            logging.info('Database still not set, returning')
            return None
        
        try:
            subset = self._db[0:1]
            return subset
        except:
            logging.error('Error reading First Row')
            return None
    
    def getRowAt(self, index):
        if not self.isValid():
            logging.info('Database still not set, returning')
            return None
        if index<0 or index > self._num_obs-1:
            logging.error('Index out of bounds')
            return None
        try:
            subset = self._db[index:index+1]
            return subset
        except:
            logging.error('Error reading row at {}'.format(index))
            return None

    def getVariables(self, varlist):
        if not self.isValid():
            logging.info('Databse still not set, returning')
            return None

        try:
            subset = self._db[varlist]
            return subset
        except:
            logging.error('ERror reading the Variables')
            return None

    def getTable(self):
        return self._db
