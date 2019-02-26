#!/bin/csh -f

# Set default variables
set fcmd = $0
set cmd = ${fcmd:t}
set display = ""
set engmode = ""

# Get the required arguments passed in
set function=$1
shift
set package=$1
shift
set mainclass="$1"
shift
set singleton=$1
shift
set scriptpre=$1
shift

#echo $mainclass

if ($function == "debug0" || \
    $function == "debug1" || \
    $function == "debug2" || \
    $function == "debug3" || \
    $function == "debug4" || \
    $function == "debug5") then
    set function = "start"
endif

# Decide what to do based on the specified function
switch ($function)
    case start:
	if ($singleton != 0) then
	    if ($scriptpre == "none") then
		set procs=`/bin/ps auxww | grep "$mainclass" | egrep -v grep | egrep -v kcwi_scripts.csh | egrep -v .csh | cut -c9-14`
	    else
		set procs=`/bin/ps auxww | grep "$mainclass" | grep $scriptpre | egrep -v grep | egrep -v kcwi_scripts.csh | egrep -v .csh | cut -c9-14`
	    endif
	    set numprocs=`echo $procs | wc -w`
	    if ( $numprocs > 0 ) then
		echo $package is already running.  Only one instance allowed.
		echo 
		if ($scriptpre == "none") then 
		    /bin/ps auxww | grep "$mainclass" | egrep -v grep | egrep -v kcwi_scripts.csh
		else
		    /bin/ps auxww | grep "$mainclass" | grep $scriptpre | egrep -v grep | egrep -v kcwi_scripts.csh
		endif
		echo
		breaksw
	    endif
	endif
	echo "${cmd}: Starting $package"

	# Get any optional arguments
	while ($#argv != 0)
	    switch ($1)
		case -D:
		    set display = $2
		    shift
		    breaksw
		case -T:
                    set terminal = $2
                    shift
                    breaksw
		default:
		    echo "${cmd}: Unknown flag <${1}> specified - script"\
			"aborted."
		    # set error code for error with command line input
		    exit 3
		    breaksw
	    endsw
	    shift
	end

	# Set the display if one was specified
	if ($display != "") then
	    echo "${cmd}: Setting display to ${display}"
	    setenv DISPLAY $display

	    # Check that it is a valid display
	    set junk = `xdpyinfo -display ${display}`
	    set error = $status
	    if ($error != 0) then
		echo "${cmd}: Error setting display - script aborted."
		exit 1
	    endif
	endif	    

	echo $mainclass
	$mainclass &

    breaksw

    case stop:
	set sig = "-15"
	if ($scriptpre == "none") then
	    set procs=`/bin/ps auxww | grep "$mainclass" | egrep -v grep | egrep -v stop | egrep -v kcwi_scripts.csh | cut -c9-14`
	else
	    set procs=`/bin/ps auxww | grep "$mainclass" | grep $scriptpre | egrep -v grep | egrep -v stop | egrep -v kcwi_scripts.csh | cut -c9-14`
	endif
	set numprocs=`echo $procs | wc -w`
	if ( $numprocs < 1 ) then
	    echo Aborting: $package is not running.
	    breaksw
	else if ($numprocs > 1 && $package != "keygrabber") then 
	    echo Warning: Multiple instances of $package are running. 
            echo This will kill all instances of $package':'
	    echo
	    if ($scriptpre == "none") then
		/bin/ps auxww | grep "$mainclass" | egrep -v grep | egrep -v stop | egrep -v kcwi_scripts.csh
	    else
		/bin/ps auxww | grep "$mainclass" | grep $sriptpre | egrep -v grep | egrep -v stop | egrep -v kcwi_scripts.csh
	    endif
	    echo
	    echo -n "Do you wish to continue? [Y/N]: "
	    set answer=$<
	    if ($answer != "Y" && $answer != "y") then
		echo Aborting kill of $package.
		breaksw
	    endif
	else if ($numprocs > 1 && $package == "keygrabber") then
	    set sig = "-9"
	    if ($scriptpre == "none") then
		/bin/ps auxww | grep "$mainclass" | egrep -v grep | egrep -v stop | egrep -v kcwi_scripts.csh
	    else
		/bin/ps auxww | grep "$mainclass" | grep $sriptpre | egrep -v grep | egrep -v stop | egrep -v kcwi_scripts.csh
	    endif
	endif
	echo Killing $mainclass
	echo kill $sig $procs
	kill $sig $procs
    breaksw
    case status:
	if ($scriptpre == "none") then 
	    set procs=`/bin/ps auxww | grep "$mainclass" | egrep -v grep | egrep -v kcwi_scripts.csh` 
	else
	    set procs=`/bin/ps auxww | grep "$mainclass" | grep $scriptpre | egrep -v grep | egrep -v kcwi_scripts.csh` 
	endif
	echo $procs
    breaksw

    case killrpc:
        echo killrpc does not apply to scripts.  Skipping.
    breaksw

    default:
	echo ""
	echo "${cmd}: Do not understand the function <$function>."
	echo ""
	exit 1
    breaksw

endsw
