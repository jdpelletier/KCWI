#!/bin/tcsh -f

# Set default variables
set fcmd = $0
set cmd = ${fcmd:t}
set localport = ""
set tnetport = ""
set termserv = "lantronix"
set force = 0
set terminal = /dev/null

# Get the required arguments passed in
set function = $1
shift
set libname = $1
shift
set service = $1
shift

# Get any optional arguments
while ($#argv != 0)
    switch ($1)
	case -localport:
	    set localport = $2
	    shift
	    breaksw
	case -tnetport:
	    set tnetport = $2
	    shift
	    breaksw
	case -termserv:
	    set termserv = $2
	    shift
	    breaksw
	case -T:
            set terminal = $2
            shift
            breaksw
    	case -F:
            set force = 1
	    shift
            breaksw
    	case -S:
            set simsrv = `echo $libname | tr "[a-z]" "[A-Z]"`
	    setenv ${simsrv}_SIMULATE 1
            breaksw
	default:
	    echo "${cmd}: Unknown flag <${1}> specified - script"\
		"aborted."
	    # set command line input error code
	    exit 3
	    breaksw
    endsw
    shift
end

echo -n "Performing $function on $service"
if ($localport != "") then
    echo -n " with localport=<$localport>"
#else
#    echo -n " (no tnet process)" 
endif

if ($tnetport != "") then
    echo -n ", tnetport=<$tnetport>, termserv=<$termserv>"
endif

echo



# Decide what to do based on the specified function
switch ($function)
    case start:
    case debug:
    case debug0:
    case debug1:
    case debug2:
    case debug3:
    case debug4:
    case debug5:
    case debug8:
	echo "${cmd}: Starting $service"

	# Check if the server is already running
	if (`kcwiCheckServer ${service}` == 1) then
	    echo "${cmd}: ${service} is already running - another instance"\
		"will not be started."
            echo "**********" > $terminal
	    echo "${service} is already running - another instance"\
		"will not be started." > $terminal
            echo "**********" > $terminal
	    exit 4
	endif

	# Check if there is an RPC registry entry to be removed
	set rpcuser = `kcwiCheckRPCInfo ${service}`
	if ("${rpcuser}" != "") then
	    echo "${cmd}: Detected entry in RPC registry by ${rpcuser}."
	    # If owned by current user or kcwi, remove the entry
	    if ("${rpcuser}" == "$USER") then
		kcwiKillRPCEntry $service
		set error = $status
		if ($error == 0) then
		    echo "${cmd}: Entry removed."
		else
		    echo "${cmd}: Unable to remove entry - aborting script."
		    exit 4
		endif
	    else if ("${rpcuser}" == "kcwi") then
		xterm -e ssh -l kcwi localhost kcwiKillRPCEntry $service
		set rpcuser = `kcwiCheckRPCInfo ${service}`
		if ("${rpcuser}" == "") then
#		set error = $status
#		if ($error == 0) then
		    echo "${cmd}: Entry removed."
		else
		    echo "${cmd}: Unable to remove entry - aborting script."
		    exit 4
		endif
	    else
		echo "${cmd}: Unable to remove entry - aborting script."
		exit 4
	    endif
	endif

	# if localport is defined, start tnet
	if ("${localport}" != "") then
	    echo -n "${cmd}: Checking to see if port is free..."
	    if (`/sbin/fuser $localport` == "") then
	        set tcmd = "tnet $localport $termserv $tnetport"
	        echo "${cmd}: The tnet command is:"
		echo "${cmd}:   ${tcmd}"
	        $tcmd &
	    else
	        echo "${cmd}: Port ${localport} is in use - unable to"\
		    "start tnet."
	        echo "${cmd}: Server ${service} not started."
	        exit 4
	    endif
	endif

	# log msg level
	switch ($function)
	case debug:
	case debug1:
	    set loglvl=256
	    breaksw
	case debug2:
	    set loglvl=2304
	    breaksw
	case debug3:
	    set loglvl=3840
	    breaksw
	case debug4:
	    set loglvl=3854
	    breaksw
	case debug5:
	    set loglvl=3998
	    breaksw
	case debug6:
	    set loglvl=4095
	    breaksw
	case debug8:
	    set loglvl=10000
	default:
	    set loglvl=0
	    breaksw
	endsw

	# command to start server
        set newcmd = "rpcKey_server -l ${libname}_service -s $service -v $loglvl"

        # echo info to user
        echo "${cmd}: The server command is:"
        echo "${cmd}:   ${newcmd}"
    
	# actually start the server

	# source the envvar file for this server
	echo "Check environment variables for this server"
	set uppercaseserver = `echo $service | tr "[a-z]" "[A-Z]"`
	set envhost = `env | grep ${uppercaseserver}_HOST`
	set envprognum = `env | grep ${uppercaseserver}_PROGNUM`
	set keywordconf = `env | grep ${uppercaseserver}_KEYWORD_CONFIG_FILE`
	set simulation_mode = `env | grep ${uppercaseserver}_SIMULATE`
	echo "HOST: ${envhost}"
	echo "PROGNUM: ${envprognum}"
	echo "KEYWORD_CONF_FILE: ${keywordconf}"
	echo "SIMULATE MODE: ${simulation_mode}"
	if ($envhost == "") then
	    echo "HOST environment variable is not defined for $service"
	    echo "Server will NOT be started"
	    echo "HOST environment variable is not defined for $service" > $terminal
	    echo "Server will NOT be started" > $terminal
	    exit 1
	endif
	if ($envprognum == "") then
	    echo "PROGNUM environment variable is not defined for $service"
	    echo "Server will NOT be started"
	    echo "PROGNUM environment variable is not defined for $service" >$terminal
	    echo "Server will NOT be started" >$terminal
	    exit 1
	endif
	if ($keywordconf == "") then
	    echo "KEYWORD_CONFIG_FILE  environment variable is not defined for $service"
	    echo "Server will NOT be started"
	    echo "KEYWORD_CONFIG_FILE  environment variable is not defined for $service" >$terminal
	    echo "Server will NOT be started" >$terminal
	    exit 1
	endif
	    

	# If the server to be started is the global server, then check and make
	# sure the other servers are running, or warn the user.
	if (($service == kcwid) && ($force == 0)) then
            set warning = `ctx -nokgswarn | grep "missing a required" | cat -n | tail -1 | cut -f 1`
            if ($warning > 0) then
		ctx -nokgswarn > $terminal
		echo "There are $warning warnings, do you want to continue to start the global server? (Y/y)" > $terminal
		echo -n "Alternately, input the wait time desired in seconds before starting: " > $terminal
		set input_char = "$<"
  
		set digits=`echo "$input_char" | egrep "^[0-9]"`
		set chars=`echo "$input_char" | egrep "^[a-zA-Z]"`

		if ($chars == "Y" || $chars == "y") then
		    $newcmd &
		else if ($digits > 0) then
		    sleep $input_char
		    $newcmd &
		    exit
		else
		    echo > $terminal
		    echo "Exiting... " > $terminal
		    echo > $terminal
		    exit
		endif
            else
		$newcmd &
	    endif
        else
	$newcmd &
	    ### NOTE: the ampersand is needed here. MB 2005/02/09
	echo " "
        endif
    breaksw

    case stop:
	echo Shutting down $service

	# set logging to 0
	echo Turning off logging...
	modify -s $service logging=0
	sleep 1

	# shutdown server using keyword
	echo Shutting down server...
	modify -s $service shutdown=1
	sleep 1

	if ($localport != "") then
	    # kill tnet
	    echo -n "Killing tnet... "
	    /sbin/fuser -k $localport
	endif
	# clean up remaining processes just in case
	kill -9 `/bin/ps auxww | grep rpcKey_server | grep "\-s $service" | cut -c9-14`
	# remove rpc entry
	echo Removing RPC entry for $service

	kcwiKillRPCEntry $service
	
    breaksw

    case status:
	/bin/ps auxww | grep rpcKey_server | grep "\-s $service"
	if ($localport != "") then
	   /bin/ps auxww | grep tnet | grep "$localport" | grep -v kcwi_servers.csh 
	endif

    breaksw
    
    case killrpc:
	echo Removing RPC entry for $service

	kcwiKillRPCEntry $service

    breaksw

    default:
	echo ""
	echo "${cmd}: Do not understand the function $function."
	echo ""
	exit 1
    breaksw

endsw
