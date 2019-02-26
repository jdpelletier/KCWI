#!/bin/csh -f

# Get the required arguments passed in
set function = $1

# Set variables for this package
set package="watchslew"
set mainclass=$RELDIR/bin/kcwiSetupNextTarget.pyc
set singleton=1  # allow only one instance

# Get any other optional arguments passed in
set otherargs = "${argv[2-]}"

# Call the next script
kcwi_python.csh $function $package $mainclass $singleton $otherargs
