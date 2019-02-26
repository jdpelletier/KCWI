#!/bin/csh -f

# set log facility to 7
#setenv LOG_FACILITY 7

# Get the required arguments passed in
set function=$1

# Get any other optional arguments passed in
set otherargs = "${argv[2-]}"

# Call the next script
kcwi_servers.csh $function kpws kp1s $otherargs
