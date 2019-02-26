#!/bin/csh -f

# Set default variables
set fcmd = $0
set cmd = ${fcmd:t}
set config = ""
set display = ""
set engmode = ""
set force = 0
set otherargs = ""

# Get the required arguments passed in
set function=$1
shift
set package=$1
shift
set mainclass=$1
shift

# Get any optional arguments
while ($#argv != 0)
    switch ($1)
	case -C:
	    set config = $2
	    shift
	    breaksw
	case -D:
	    set display = $2
	    shift
	    breaksw
	case -T:
	    set terminal = $2
	    shift
	    breaksw
	case -F:
	    set force = 1
	    breaksw
	default:
	    if ($package == guilauncher) then
		if ($config == "") then
		    # if the first arg, which should be the
		    # layout file, doesn't exist, assume
		    # the command is being run to give status
		    # or stop on all GUILauncher programs.
		    # set config such that the grep for
		    # those functions works, but doesn't 
		    # for start.
		    if (-e $1) then
		    
			# for guilauncher, set config
			# to layout filename, but cut off
			# extension, so it is not used as 
			# as config file on start up.  want
			# to set a config so it is grepped on
			# in the status and stop commands
			set config=`echo $1 | cut -f1 -d . `
		    else
			set config="GUILauncher"
		    endif
		endif
		set otherargs = "${otherargs} ${1}"
	    else
		echo "${cmd}: Unknown flag <${1}> specified - script"\
		    "aborted."
		# set error code for error with command line input
		exit 3
	    endif
	    breaksw
    endsw
    shift
end

if ($function == "debug0" || \
    $function == "debug1" || \
    $function == "debug2" || \
    $function == "debug3" || \
    $function == "debug4" || \
    $function == "debug5") then
    set function = "start"
endif

# If no config file was specified, try a default
if ($config == "") then
#    if ($package == "guilauncher") then
#	set config="$otherargs"
#    else
	set config = "${package}_cfg.xml"
	if ($function == "start") then
	    echo "${cmd}: No java config file specified, will try <${config}>."
	endif
#    endif
endif

# Decide what to do based on the specified function
switch ($function)
    case start:

	echo "${cmd}: Starting $package"

	# Set variables for java
	set jar_dir=$RELDIR/classes/
	set config_dir=$RELDIR/data/kcwi/
	set java_lib=$RELDIR/lib
	set cpath="${jar_dir}kdesktop.jar:${jar_dir}srlUtil.jar:${jar_dir}kcwiUtil.jar:${jar_dir}kecgui.jar:${jar_dir}kcfcgui.jar:${jar_dir}kcfsgui.jar:${jar_dir}irlabUtil.jar:${jar_dir}jdom.jar:${jar_dir}kjava.jar:${jar_dir}fits.jar:${jar_dir}jcommon.jar:${jar_dir}jfreechart.jar:${jar_dir}log4j.jar"
	set java_policy=$RELDIR/data/kcwi/kcwi.java.policy
	set java_options="-Dawt.useSystemAAFontSettings=on -Djava.security.policy=file://${java_policy} -Djava.library.path=${java_lib}"


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

	# Check if the gui should be in an engineering mode
	switch ($USER)
	    case kcwidev:
		breaksw
	    case kcwirun:
		breaksw
	    case kcwieng:
#		set engmode = "-eng"
		breaksw
	    default:
		# Do nothing
		breaksw
	endsw

	if ($force == 0) then

	    # Check to make sure the global server is started before starting
	    # mdesktop

	    if ($package == "kdesktop") then

		set warning = `ctx | grep "kcwi is missing" | cat -n | cut -f 1`
		
		#echo "Warning is: $warning"

		if ($warning == 1) then
		    echo > $terminal
		    echo "The kcwi global server is not started, so kdesktop will not be started" > $terminal
		    echo "Please start the global server, then start kdesktop:" > $terminal
		    echo "  kcwi $function kcwi" > $terminal
		    echo "  kcwi $function kcwi" > $terminal
		    echo > $terminal
		    exit
		endif
	    endif
	endif

	# Check if the config file exists and then start the gui
	# Look in the current directory, and a default location
	if (-e $config) then 
	    echo java $java_options -cp $cpath $mainclass cfg=$config $engmode $otherargs
	    java $java_options -cp $cpath $mainclass cfg=$config $engmode $otherargs &
	else if (-e $config_dir/$config) then 
	    echo java $java_options -cp $cpath $mainclass cfg=$config_dir/$config $engmode $otherargs
	    java $java_options -cp $cpath $mainclass cfg=$config_dir/$config $engmode $otherargs &
	else
	    echo "${cmd}: Java config file <${config}> not found, gui will"\
		 "be started without any config file."
	    echo java $java_options -cp $cpath $mainclass $engmode $otherargs
	    java $java_options -cp $cpath $mainclass $engmode $otherargs &
        endif
    breaksw

    case stop:
	set procs=`/bin/ps auxww | grep java | grep $mainclass | grep "$config" | cut -c9-14`
	set numprocs=`echo $procs | wc -w`
	if ( $numprocs < 1 ) then
	    echo Aborting: $package is not running.
	    breaksw
	else if ($numprocs > 1) then 
	    echo Warning: Multiple instances of $package are running. 
            echo This will kill all instances of $package':'
	    echo
	    /bin/ps auxww | grep java | grep $mainclass | grep "$config"
	    echo
	    echo -n "Do you wish to continue? [Y/N]: "
	    set answer=$<
	    if ($answer != "Y" && $answer != "y") then
		echo Aborting kill of $package.
		breaksw
	    endif
	endif
	echo Killing java $mainclass
	echo kill -9 $procs
	kill -9 $procs
    breaksw
    case status:
	echo test "$config"
	set procs=`/bin/ps auxww | grep java | grep $mainclass | grep "$config"`
	echo $procs
    breaksw
    case killrpc:
        echo killrpc does not apply to GUIs.  Skipping.
    breaksw

    default:
	echo ""
	echo "${cmd}: Do not understand the function <$function>."
	echo ""
	exit 1
    breaksw

endsw
