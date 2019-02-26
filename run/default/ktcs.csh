#!/bin/csh -f

#local0.debug             /usr/local/var/log/mechanisms.log
#local1.debug             /usr/local/var/log/kcwi.terminal.servers
#local3.debug             /usr/local/var/log/detectors.log
#local7.debug             /usr/local/var/log/environmental.log

# set log facility to 7
setenv LOG_FACILITY 7

# Get the required arguments passed in
set function=$1

# Get any other optional arguments passed in
set otherargs = "${argv[2-]}"

# Call the next script
kcwi_servers.csh $function ktcs ktcs $otherargs
