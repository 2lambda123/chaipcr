# load dependencies for 'amp.r' and 'meltcrv.r'


# load libraries
library(plyr)
#library(qpcR)
library(reshape2)
library(RMySQL)


# load dependencies from qpcR but not the whole package

library(MASS)
library(minpack.lm)
#library(rgl)
library(robustbase)
library(Matrix)
library(DBI)

#setwd(Sys.getenv('RWORKDIR')) # Xia Hong

dpds <- dir(pattern='\\.[Rr]$', recursive=TRUE)
dpds <- dpds[dpds != 'depend.r']
dummy <- lapply(dpds, source) # recursively load all the files that ends with '.R' or '.r'

load('qpcR/sysdata.rda')
load('k_list_bywell.RData') # load hard-coded deconvolution matrix


# set constants

num_wells <<- 16
scaling_factor <<- 9e5

# optical calibration (oc)
oc_water_step_id <<- 74 # used: 2, 74.
oc_signal_step_ids <<- list('1'=76, '2'=76) # names are channels (int in database) as characters. used: 4, list('1'=76, '2'=76).
# # for testing array output of get_amplification_data
# oc_water_step_id <<- 2
# oc_signal_step_id <<- 4

# color compensation / multi-channel deconvolution
dcv_target_step_ids <- list('1'=76, '2'=78) # the steps where target dye used for each channel


# function: connect to MySQL database; message about data selection
db_etc <- function(db_usr, db_pwd, db_host, db_port, db_name, # for connecting to MySQL database
                   exp_id, stage_id, calib_id # for selecting data to analyze
                   ) {
    
    message('db: ', db_name)
    db_conn <- dbConnect(RMySQL::MySQL(), 
                         user=db_usr, 
                         password=db_pwd, 
                         host=db_host, 
                         port=db_port, 
                         dbname=db_name)
    
    message('experiment_id: ', exp_id)
    message('stage_id: ', stage_id)
    message('calibration_id: ', calib_id)
    
    return(db_conn)
    }


