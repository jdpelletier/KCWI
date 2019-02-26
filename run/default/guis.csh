#!/bin/csh -f

# Get the required arguments passed in
set function=$1

# Get any other optional arguments passed in
set otherargs = "${argv[2-]}"

# Call the next script
kcwi $function kdesktop $otherargs
