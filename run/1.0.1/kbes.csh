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

# Call the next script
kcwi_servers.csh $function kbes kbes $otherargs

# wait for service to be available
set ii=0
set tries=10
set running=0
while ($ii < $tries) 
  set running=`kcwiCheckServer kbes`
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
    echo kbes is running.
    # check DMC code matches source
    set galilCheck=`kcwiCheckGalilProgram kbes bexgalil`
    if ($status == 0) then 
	if ($galilCheck == "0") then
	    echo "Galil program matches expected program listing."
	    echo "Unlocking mechanism moves."
	    modify -s kbes movelock=2468
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

