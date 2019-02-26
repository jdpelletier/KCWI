#!/bin/csh -f

# Get the required arguments passed in
#set function=$1
set process=$1

# Set variables for this server
#set localport=""
#set tnetport=""

# Get any other optional arguments passed in
set otherargs = "${argv[2-]}"

# Call the stop script
kcwi stop $process $otherargs

set LIMIT = 0
set MAXLIMIT = 4

while ($LIMIT < $MAXLIMIT)
    set checkprocess = `ct | grep "\- $process" | head -1`
#    set checkprocess = `ct | grep ASDF | head -1`
    if ("${checkprocess}" == "") then
	echo "$process has been Stopped\!"
	break
    else
       @ LIMIT = $LIMIT + 1
       sleep 1
    endif
end

if ($LIMIT == $MAXLIMIT) then
    echo "$process did not stop in $LIMIT seconds, ABORTING...."
    exit
endif

sleep 5

# Call the start script
echo "Restarting $process..."
kcwi start $process $otherargs

exit
