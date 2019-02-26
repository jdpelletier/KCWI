#!/bin/csh -f

#local0.debug             /usr/local/var/log/mechanisms.log
#local1.debug             /usr/local/var/log/kcwi.terminal.servers
#local3.debug             /usr/local/var/log/detectors.log
#local7.debug             /usr/local/var/log/environmental.log

# set log facility to 4
#setenv LOG_FACILITY 4

# Get the required arguments passed in
set function=$1

# Get any other optional arguments passed in
set otherargs = "${argv[2-]}"

if ($function == "stop" || $function == "start") then
    set fill = `show -s kbms -terse artfilling`
    if ($fill == 1) then
	echo KCWI is in fill position and the server cannot be shut down
	exit
    endif
endif



# Call the next script
kcwi_servers.csh $function kbms kbms $otherargs

# wait for service to be available
set ii=0
set tries=10
set running=0
while ($ii < $tries) 
  set running=`kcwiCheckServer kbms`
  set exitcode=$status
  if ($running == 1) then
    break
  else if ($exitcode != 255) then
    echo Error with kcwiCheckServer
    break
  endif
  sleep 1
  @ ii++
end

if ($running == 1) then
    echo kbms is running.
    # check DMC code matches source
    set galilCheck=`kcwiCheckGalilProgram kbms bmsgalil`
    if ($status == 0) then 
	if ($galilCheck == "0") then
	    echo "Galil program matches expected program listing."
	    echo "Unlocking mechanism moves."
	    modify -s kbms movelock=2468
	    exit
	else
	    echo "ERROR: Galil program DOES NOT match expected program listing."
	endif
    else
	echo "Error checking Galil program."
    endif
else 
    echo "Timeout waiting for server to become available."
endif
echo
echo "Mechanism moves will remain LOCKED."

