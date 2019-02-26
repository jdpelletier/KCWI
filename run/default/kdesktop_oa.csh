#!/bin/csh -f

# Get the required arguments passed in
set function = $1

# Set variables for this package
set package=kdesktop
set mainclass=edu/caltech/srl/kcwi/kdesktop/KDesktop

# Get any other optional arguments passed in
set otherargs = "${argv[2-]}"

set config="-C kdesktop_cfg_oa.xml"

# Call the next script
kcwi_guis.csh $function $package $mainclass $config $otherargs
