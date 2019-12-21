from DbBase import DbBase
import logging
from SrDb import SrDb
#import SrDb

loglevel =  logging.INFO
logging.basicConfig(format='%(levelname)s:%(asctime)s:%(message)s', datefmt='%m/%d/%Y %I:%M:%S',
                         level=loglevel)

mydb = SrDb('/Users/hinashah/UNCFAMLI/Data/StructuredReports/SASUniversityEdition/myfolders/famli_c1_dicom_sr.sas7bdat')
mydb.printTypes()
lst = ['pid', 'indexdate']
subset = mydb.getSubsetAt(lst, 'study_id', b'FAM-025-0004-1')
logging.info(subset)
