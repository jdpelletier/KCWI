#!/bin/csh -f

# Get the required arguments passed in
set function = $1

# Set variables for this package
set package="kcwiStatusGui"
set mainclass="$RELDIR/bin/KCWI_Status"
set singleton=1  # allow only one instance
set scriptpre="none"

# Get any other optional arguments passed in
set otherargs = "${argv[2-]}"

# Call the next script
kcwi_scripts.csh $function $package "$mainclass" $singleton $scriptpre $otherargs
