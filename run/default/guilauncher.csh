#!/bin/csh -f

# Get the required arguments passed in
set function = $1

# Set variables for this package
set package=guilauncher
set mainclass=edu/ucla/astro/irlab/util/gui/builder/GUILauncher

shift
set otherargs=""
set type=""
# Get any other optional arguments passed in
while ($#argv != 0)
    if ($1 == -C) then
	set type = $2
	shift
    else
	set otherargs="${otherargs} $1"
    endif
    shift
end

set layout=$RELDIR/data/${type}_layout.xml
set props=$RELDIR/data/kcwiProperties.xml
set server="server=kcwi"

set otherargs="${otherargs} ${layout} ${props} ${server}"

# Call the next script
kcwi_guis.csh $function $package $mainclass ${otherargs}
