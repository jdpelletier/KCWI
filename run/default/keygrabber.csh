#!/bin/csh -f

# Get the required arguments passed in
set function = $1

# Set variables for this package
set package="keygrabber"
#set mainclass="$RELDIR/bin/keygrabber -c $RELDIR/data/kcwi/keygrabber.conf"
set mainclass="$RELDIR/bin/keygrabber -c $RELDIR/data/kcwi/keyheaderd.conf -y $RELDIR/data/kcwi/keyheader.conf"
set singleton=1  # allow only one instance
set scriptpre="none"

# Get any other optional arguments passed in
set otherargs = "${argv[2-]}"

if ($function == "stop") then
	set mainclass="keygrabber"
endif

# Call the next script
kcwi_scripts.csh $function $package "$mainclass" $singleton $scriptpre $otherargs
