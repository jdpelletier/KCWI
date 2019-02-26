#!/bin/sh
#+
# Mias.sh -- acquire telescope focus (Mira) 
#
# Purpose:
#	Provide an interface which allows the OA to take images 
#	to focus the telscope. 
#
# Usage:
#	kcwiMias.sh [-v] [-D] [dir]
# 
#
# Flags:
#	-v = VERBOSE mode (echo all commands)
#	-D = DEBUG mode (disables telescope moves, etc.)
#
# Arguments:
#	dir = name of the initial directory in which to run
#		[default = nightly directory]
# 
# Output:
#	Textual output is written to attached terminal session (STDOUT)
# 
# Side effects:
#	- Moves and restores Instrument settings
#	- Acquires images
#	- Moves the telescope
#	- Adjusts PMFM
# 
# Restrictions:
#	- Must be run from Instrument host
# 
# Exit values:
#	0 = normal completion
#	1 = interrupted
#
#-
# Modification history:
#       2011-Jan-21	MK	Original version based on NIRSPEC script
#	2012-May-05	MK/GDW	Removed sky differencing
#       2012-Sep-12     MK      modhead version on NUU was corrupting the image
#                               because PMFM is contained in object name 
#                               PMFM keyword is not needed in FITS header
#	2012-Sep-14	GDW	modhead exonerated & restored
#       2013-Nov-26     MK      Added mosfireWfMechs before preconfig:
#                               Script will wait for observer settings to
#                               complete before configuring for MIRA.
#	2014-May-08	GDW	Updated the takeImage routine to cut out
#				the image section using "fitscopy".  This
#				allows us to simply load the subsection
#				into the MIRA analysis tool and enables
#				OA to reload easily.  Eliminated routine
#				"createSubImage".
#	2014-Jun-04	GDW	Updated the initCheck routine to check
#				for extra-wide slits which could indicate
#				exoplanet configuration (in which case we
#				do not run MIRA).
#       2016-May-06     LR      Initial modifications for KCWI
#-----------------------------------------------------------------------
# 
# Checklist for new instrument
#
#- Edit mosfireConfig.inc
#- Define ITime. Default integration time for this instrument and Mira star.
#- Set NewPMFM to default PMFM value for this instrument.
#- Change ACSWaitTime, if required.
#
#- Commands required:
#	pmfm: 		reads and sets PMFM
#	markbase: 	remebers where the telescope is.
#	gotobase:	moves telescope back to marked position
#	beep:		makes a beep
#	save_state: saves the instrument settings
#	load_state: loads the instrument settings to a file
#
#- Subroutines to be completed
#	configureInstrument
#	configureDetector
#-----------------------------------------------------------------------
set -f		# Disable file name generation (i.e., no glob)

# *****************************************************************
# *****************************************************************
# Global variables

ITime=20
NumExp=1
NewPMFM=300
ACSWaitTime=35
TelescopeWaitTime=10
SavedITime='0'
Moved='0'

IsSimulation='0'
Count='9000'
PMFM='0'
ImageFile="_"
ImageFileBase="_"
Answer=""
SCRATCHDIR='/scratch'

export SavedITime

# go to the location of this program...
srcdir=`dirname $0`

# source the helper files...
. $srcdir/kcwiConfig.inc
. $srcdir/kcwiHelp.inc

# check for command-line flags...
while getopts Dv flag
do case "$flag" in
    D) DEBUG=1 ;;
    v) printf "VERBOSE mode enabled\n\a" && set -x ;;
    \?) printf "Usage: $0 [-D] [-v]\n\a" && exit 1;;
esac
done

# remove the options from the command line arg list...
shift `echo $OPTIND-1 | bc`

#-----------------------------------------------------------------------
# myError - report a fatal error via a popup and exit
# 
# Args:
#	* = lines of error message
# 
# Global variables:
#	None
#-----------------------------------------------------------------------
myError()
{

    # start the message...
    command='okMessage StaticText ("", 0, 0); SetBGColor (255, 0, 0); SetFont ("Dialog", 20); StaticText ("ERROR!", 0, 1);'

    # add additional lines from arguments...
    i="2"
    while [ $# -gt 0 ] ; do
	command=${command}' StaticText ("'$1'", 0, '$i');'
	i=`expr $i + 1`
	shift
    done

    # add final line and send command to MIRA...
    command=${command}' StaticText ("", 0, '$i');'
    beep
    myLog "$*"
    echo $command | $COMIRA $MIRAHOST $MIRAPORT

    exit 1
}

#------------------------------------------------------------------------
# okmessage - display a message via GUI
#------------------------------------------------------------------------
okMessage()
{
    # start the message...
    command='okMessage'
    command=${command}' SetFont ("Dialog", 20);'

    # add additional lines from arguments...
    i="1"
    while [ $# -gt 0 ] ; do
	command=${command}' StaticText ("'$1'", 0, '$i');'
	i=`expr $i + 1`
	shift
    done

    # add final line and send command to MIRA...
    command=${command}' StaticText ("To continue, press OK", 0, '$i'); '
    echo $command | $COMIRA $MIRAHOST $MIRAPORT
}

#------------------------------------------------------------------------
# mysleep - pause execution for N seconds
# 
# Args:
#	1 = number of seconds to sleep
# 
# Global variables:
#	DEBUG = flag indicating whether to suppress real action
#------------------------------------------------------------------------
mySleep()
{
    myEcho "Sleeping for $1 seconds..."
    CALL sleep $1
}

#------------------------------------------------------------------------
# waitForImage - pause whilst image is written to disk
# 
# Args:
#	None
# 
# Global variables:
#	None
#------------------------------------------------------------------------
waitForImage()
{
    n=5
    myEcho "Waiting $n seconds for image to be written..."
    sleep $n
}

#------------------------------------------------------------------------
# myLog - send message, plus timestamp and PID, to logfile.  
# Also send to terimnal if running in VERBOSE mode.
# 
# Args:
#	* = message to print to logfile
# 
# Global variables:
#	LOGFILE = name of the logfile
#	MIAS_PID = process ID number for this script
#------------------------------------------------------------------------
myLog()
{
    date=`/usr/bin/date -u "+%Y-%b-%d %H:%M:%S"`
    printf "[%5d] %s %s\n" "$MIAS_PID" "$date" "$*" >> $LOGFILE
    myEcho "$*"
}

#------------------------------------------------------------------------
# CALL - invoke a shell command
# 
# Args:
#	* = command to execute
# 
# Global variables:
#	DEBUG = flag indicating whether to suppress real action
#------------------------------------------------------------------------
CALL()
{
    if [ "$DEBUG" -eq "1" ]; then
	myEcho "[DEBUG] CALL $*"
    else
	$*
    fi
}


#-----------------------------------------------------------------------
# myEcho - print a message to the terminal window
# 
# Args:
#	* = text string to print
# 
# Global variables:
#	VERBOSE
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
myEcho()
{
    if [ $VERBOSE = "1" ]; then
	echo ">> $*"
    fi
}

#-----------------------------------------------------------------------
# setObject - define the object name
# 
# Args:
#	1 = new object name
# 
# Global variables:
#	None
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
setObject()
{
    echo "Setting object is disabled"
    #modify -s $INSTRUMENT object = "$1" $SILENT
}

#-----------------------------------------------------------------------
# setITime - change the integration time
# 
# Args:
#	1 = integration time [sec]
#	2 = Co adds
# 
# Global variables:
#	None
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
setITime()
{
    itime=$1
    myLog Setting integration time to $itime
    tintfc $itime
}

#-----------------------------------------------------------------------
# setACSPmfm - change the amount of focus mode in the primary mirror
# 
# Args:
#	1 = new focus mode value [nm]
# 
# Global variables:
#	None
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
setACSPmfm()
{
    PMFM=$1

    # return if PMFM is already set to this value...
    buf=`pmfm`
    pmfm_now=`printf "%.0f\n" $buf`
    if [ "$pmfm_now" -eq "$PMFM" ]; then 
	myEcho "No PMFM move required (already at $PMFM)"
	return
    fi	

    # change PMFM value...
    myLog Setting PMFM to $PMFM
    CALL pmfm $PMFM

    # wait for mirror to settle...
    mySleep $ACSWaitTime
}


#-----------------------------------------------------------------------
# initOnce - prepare telescope to acquire Mira images
# 
# Args:
#	None
# 
# Global variables:
#	None
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
initOnce()
{
    echo "Save old values is disabled"
    #saveOldValues
}

#-----------------------------------------------------------------------
# moveTel - place the star at the center of the readout window
# 
# Args:
#	None
# 
# Global variables:
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
moveTel()
{
    echo "Call poname KCWI is disabled"
    #CALL poname KCWI
    Moved='1'
}

#-----------------------------------------------------------------------
# unMoveTel - return the telescope to its original position
# 
# Args:
#	None
# 
# Global variables:
#	$Moved
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
unMoveTel()
{
    if [ "$Moved" = "1" ]; then

    # move star back to REF to prevent saturation...
	CALL poname REF
	Moved='0'
    fi
}

#-----------------------------------------------------------------------
# removeAll - deselect any selected images in the Mira analysis tool
# 
# Args:
#	None
# 
# Global variables:
#	None
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
removeAll()
{
    echo "removeAll" | $COMIRA $MIRAHOST $MIRAPORT
}

#-----------------------------------------------------------------------
# nextCount - increment the global Count variable by 1
# 
# Args:
#	None
# 
# Global variables:
#	Count
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
nextCount()
{
    Count=`expr $Count + 1`
}

#-----------------------------------------------------------------------
# miasLock - check whether any other instances of this script are running
# 
# Args:
#	None
# 
# Global variables:
#	SERIESFILE
#	LOCKFILE
#	COMIRA
#	MIRAHOST
#	MIRAPORT
#-----------------------------------------------------------------------
miasLock()
{
   # Use the SERIESFILE or another file.
   # The ln operation is an atomic operation.
   # If LOCKFILE exists, then the operation fails, 
   # meaning it is locked.
    myEcho "LOGFILE is $LOGFILE"
    myEcho "LOCKFILE is $LOCKFILE"
    myEcho "SERIESFILE is $SERIESFILE"
#   ln -s $SERIESFILE $LOCKFILE 2> /dev/null
    ln -s $SERIESFILE $LOCKFILE 
    if [ $? -ne '0' ]; then

	beep
	ANSWER=`echo 'yesNoMessage Title (title, "Warning !!!");  \
	    SetWindowPos (600, 300); \
	    Panel (p1, 0, 0) { \
	    SetFont ("Dialog", 35); \
	    SetFGColor (255, 0, 0); \
	    StaticText ("Warning !!!", 0, 0); } \
	    Panel (p1, 0, 1, 1, 1, BOTH, NORTHWEST, 1, 1, 10, 10, 10, 10) { \
	    SetBGColor (255, 0, 0); \
	    SetFGColor (255, 255, 255); \
	    SetFont ("Dialog", 25); \
	    StaticText ("Application is locked!", 0, 1); \
	    StaticText ("Another script may be running! ", 0, 2); \
	    StaticText ("To continue anyways, press Yes", 0, 3); \
	    StaticText ("To abort, press No", 0, 4); } \
	    ' | $COMIRA $MIRAHOST $MIRAPORT`

	if [ "$ANSWER" != "Yes" ]; then
	    return 1
	fi
    fi
    return 0
}

#-----------------------------------------------------------------------
# miasUnlock - remove previously allocated lockfile
# 
# Args:
#	None
# 
# Global variables:
#	LOCKFILE
#-----------------------------------------------------------------------
miasUnlock()
{
    rm -f $LOCKFILE
}

#-----------------------------------------------------------------------
# greeting - print start message and verify host computer
# 
# Args:
#	None
# 
# Global variables:
#	VERSION
#	REVDATE
#	AUTHORS
#	HOSTNAME
#	INSTRUMENTHOST
#-----------------------------------------------------------------------
greeting()
{
    myEcho 
    myEcho "Welcome to the $INSTRUMENT Mira image acquisition script"
    myEcho "Version $VERSION - $REVDATE by $AUTHORS"
    myEcho
    myEcho

    if [ "$HOSTNAME" != "$INSTRUMENTHOST" ]; then
	myEcho "This script can only be run on $INSTRUMENTHOST !!!"
	myEcho "Exiting ..."
	exit 1
    fi
}

#-----------------------------------------------------------------------
# initCheck - check initial state of instrument and software
# 
# Args:
#	None
# 
# Global variables:
#	DEBUG
#	DCS
#	COMIRA
#	MIRAHOST
#	MIRAPORT
#	IMAGEDIR
#-----------------------------------------------------------------------
initCheck()
{
    # feedback...
    myLog "Entering initCheck"

    # warn if in test mode...
    if [ "$DEBUG" = "1" ]; then
	myEcho
	myEcho 'WARNING - DEBUG MODE ENABLED!'
	myEcho 'Certain functions are disabled -- test mode only'
	beep 2
    fi

    # warn if DCS in simulate mode...
    IsSimulation=`show -s $DCS -terse SIMULATE`
    if [ "$IsSimulation" = "true" ]
    then
	myEcho
	myEcho 'WARNING - DCS in simulation mode!'
	beep
    fi

    # enable secondary moves...
    CALL modify -s $DCS secreqt = true

    # create output directory and go there...
    mkdir -p $IMAGEDIR2
    myLog "Changing Mira directory to $IMAGEDIR2"
    echo chdir "$IMAGEDIR2" | $COMIRA $MIRAHOST $MIRAPORT

    # feedback...
    myLog "Exiting initCheck"
    return 0
}

#-----------------------------------------------------------------------
# getSeriesNumber - return the number of the next Mira series
# 
# Args:
#	None
# 
# Global variables:
#	SERIESFILE
# 
# Side effects:
#	Increments the value stores in SERIESFILE
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
getSeriesNumber()
{
    TMPNR=`head -1 $SERIESFILE`
    if [ $? -ne "0" ] ; then
	SERIESNR="0"
    else
	SERIESNR=`expr $TMPNR + 1`
    fi
    echo $SERIESNR > $SERIESFILE
    Count="9000"
}

saveOldValues()
{
    myLog "Entering saveOldValues"

    # save original instrument state.  Note that for MOSFIRE this will
    # NOT save CSU parameters.  We don't want those to be restored at
    # the end (takes too much time if the OA needs to repeat the 
    # observations.
    save_state $STATE_FILE_PRE
    STAT=$?

    # verify success...
    while [ $STAT -ne "0" ] ; do

	beep
	ANSWER=`echo 'yesNoMessage Title (title, "Warning !!!");  \
	    SetWindowPos (600, 300); \
	    Panel (p1, 0, 0) { \
	    SetFont ("Dialog", 35); \
	    SetFGColor (255, 0, 0); \
	    StaticText ("Warning !!!", 0, 0); } \
	    Panel (p1, 0, 1, 1, 1, BOTH, NORTHWEST, 1, 1, 10, 10, 10, 10) { \
	    SetBGColor (255, 0, 0); \
	    SetFGColor (255, 255, 255); \
	    SetFont ("Dialog", 25); \
	    StaticText ("An error occurred while I was trying to save instrument settings!", 0, 1); \
	    StaticText ("If you continue, you will overwrite the existing settings.", 0, 2); \
	    StaticText ("This is OK to do, as long as you are sure", 0, 3); \
	    StaticText ("that the instrument is currently configured for observing,", 0, 4); \
	    StaticText ("rather than for Mira.", 0, 5); \
	    StaticText ("To overwrite, press Yes", 0, 6); \
	    StaticText ("To abort, press No", 0, 7); } \
	    ' | $COMIRA $MIRAHOST $MIRAPORT`

	if [ "$ANSWER" != "Yes" ]; then
	    myLog "User opts NOT to re-try save_state"
	    return 1
	fi

	myLog "Re-trying save_state with CLOBBER enabled"
        save_state -clobber $STATE_FILE_PRE
	STAT=$?
    done
    myLog "Exiting saveOldValues"
    return 0
} 

#-----------------------------------------------------------------------
# requestParameters - query Mira parameters from operator via GUI
# 
# Args:
#	None
# 
# Global variables:
#	None
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
requestParameters()
{
    TEMP=`echo \
	'form \
	Title (title, "Acquisition Parameters");\
        Panel (P1, 0, 0) {\
            SetFont (Dialog, 36);\
            SetBGColor (100, 100, 100);\
            SetFGColor (255, 255, 255);\
            StaticText ("", 0, 0); \
            StaticText ("'$INSTRUMENT'", 1, 0);\
        }\
        Panel (P2, 0, 1) {\
            StaticText ("Integration Time [sec] : ", 0, 1);\
            TextField (ITime, 20, "'$ITime'", 1, 1);\
            StaticText ("Num of Exposures : ", 0, 2);\
            TextField (NumExp, 2, "'$NumExp'", 1, 3);\
            StaticText ("approx. 20/(2.5^(15-mag_of_star))", 2, 1, 2); \
            StaticText ("PMFM : " , 0, 3);\
            TextField (NewPMFM, 5, "'$NewPMFM'", 1, 4);\
        }\
        Panel (P3, 0, 3, 1, 1, VERTICAL, NORTHWEST) {\
            CheckboxGroup (ManySide, 0, 1);\
            StaticText ("Single/Double side : ", 0, 2);\
            Radiobox ("Single", ManySide, 1, 2);\
            Radiobox ("Double", ManySide, 2, 2);\
            SetRadiobox ("Double", true);\
        } \
	' | $COMIRA $MIRAHOST $MIRAPORT `

    # The result is of the form:
    # Accept&testme2="44"&testme="43"&
    ANSWER=`echo $TEMP | awk -F'&' '{print $1}'`
    myLog "Got answer=$ANSWER"
    if [ "$ANSWER" != "Accept" ]; then
	myEcho Terminated by user.
	exit 1
    fi

    TEMP1=`echo $TEMP | sed -e 's/&/ /g'`
    RUNTHIS=`echo $TEMP1 | sed -e "s/$ANSWER//"`
    eval $RUNTHIS

    myLog "User entered ITIME=$ITime"
    myLog "User entered PMFM=$NewPMFM"
    myLog "User entered NumExp=$NumExp"
    myLog "User entered Double=$Double"
}

#-----------------------------------------------------------------------
# takeImage - acquire an image
# 
# Args:
#	None
# 
# Global variables:
#	SERIESNR
#	ImageFile
# 
# Returned value:
#	None
# Modification history
#       2012-mar-12    MK   Modified to use new imarith command syntax
#-----------------------------------------------------------------------
takeImage()
{

    # capture pmfm...
    buf=`pmfm`
    pmfm_now=`printf '%.0f\n' $buf`
    myEcho "Current PMFM is $pmfm_now"

    # increment image counter...
    ImageCount=`expr $ImageCount + 1`
    myLog "Acquiring image $ImageCount of $NumExp at PMFM=$pmfm_now" 

    # set object name...
    #setObject "MIRA PMFM $pmfm_now"

    # acquire image...
    goifpc
    if [ $? -ne 0 ]; then
	myError "goi command failed"
    fi

    # get image name...
    sleep 1 # ensure that FITS extensions get written
    lastimage=`lastfilefpc`

    # verify that image was acquired...
    i=1
    imax=30
    while [ ! -f $lastimage ]; do
	myLog "waiting for image file $lastimage to appear (trial $i/$imax)"
	sleep 1
	i=`expr $i + 1`
	if [ $i -gt $imax ]; then
	    myError "File $lastmage did not appear in $imax sec"
	fi
    done

    # generate name of source image...
    countstr=`printf "%04d\n" $Count`
    SaveImageBase=${SERIESNR}_${countstr}.fits
    SaveImage=$IMAGEDIR2/${SERIESNR}_${countstr}.fits
    myEcho MIRA source image will be $SaveImage

    # define subimage...
    #subImage=${lastimage}"[768:1279,768:1279]"
    myLog "Acquired image $lastimage"
    #myEcho "SubImage is $subImage"

    #fitscopy $subImage $SaveImage
    cp $lastimage $SaveImage
    if [ $? -ne 0 ]; then
	myError "Failed to copy $subImage to $SaveImage"
    fi
    myLog "Copied $subImage to $SaveImage"

    # add PMFM...
    myEcho "Adding PMFM=$pmfm_now to $SaveImage"
    modhead $SaveImage PMFM $pmfm_now
    modhead $SaveImage OBJECT "MIRA PMFM $pmfm_now"
    #modhead $SaveImage INSTRUME "kcwi"

    # load subimage...
    myEcho "Loading image $SaveImage"
    echo load "$SaveImage" | $COMIRA $MIRAHOST $MIRAPORT

    # increment count number...
    nextCount
}

#-----------------------------------------------------------------------
# displayImage - load image into the Mira display
# 
# Args:
#	None
# 
# Global variables:
#	ImageFile
#	VERBOSE
#	COMIRA
#	MIRAHOST
#	MIRAPORT
# 
# Returned value:
#	None
#-----------------------------------------------------------------------

displayImage()
{
    if [ -r "$loadImage" ]
    then
	FSIZE=`ls -l $loadImage | awk '{print $5}'`
	if [ "$FSIZE" -gt 270000 ]
	then
	    myLog Displaying image $loadImage
	    echo load $loadImage | $COMIRA $MIRAHOST $MIRAPORT 
	else
	    myError "File $loadImage size is too small ($FSIZE)" "May be corrupted." "Please check fits header"
	fi
    else
	myError "File $loadImage not found"
    fi
}

#-----------------------------------------------------------------------
# analyze - run Mira analysis
# 
# Args:
#	None
# 
# Global variables:
#	COMIRA
#	MIRAHOST
#	MIRAPORT
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
analyze()
{
    echo analyze | $COMIRA $MIRAHOST $MIRAPORT 
} 

#-----------------------------------------------------------------------
# askuser - prompt user when first image is completed
# 
# Args:
#	None
# 
# Global variables:
#	ImageFile
#	PMFM
#	Itime
#	COMIRA
#	MIRAHOST
#	MIRAPORT
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
askUser()
{
    echo 'yesNoMessage StaticText ("The first image, '$ImageFileBase', is taken with PMFM='$PMFM'.", 0, 0);' \
	'StaticText ("Integration time is '$ITime'", 0, 1);' \
	'StaticText ("Please check the image quality.", 0, 2);' \
	'StaticText ("To continue with the current parameters, press Yes", 0, 3);' \
	'StaticText ("To change parameters or find another star, press No", 0, 4);' \
	| $COMIRA $MIRAHOST $MIRAPORT 
}

#-----------------------------------------------------------------------
# askUser2Continue - warn user when analysis fails
# 
# Args:
#	None
# 
# Global variables:
#	COMIRA
#	MIRAHOST
#	MIRAPORT
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
askUser2Continue()
{
    echo 'yesNoMessage StaticText ("", 0, 0);' \
	'SetWindowPos (700, 200); '\
   'SetFont ("Dialog", 20); '\
   'StaticText ("Warning!", 0, 1);' \
	'StaticText ("Analysis failed.", 0, 2);' \
	'StaticText ("Please perform manual analysis.", 0, 3);' \
	'StaticText ("After applying corrections, press Yes to continue.", 0, 4);' \
	'StaticText ("Press No to abort.", 0, 5);' \
	'StaticText ("", 0, 6); '\
   | $COMIRA $MIRAHOST $MIRAPORT
}

#-----------------------------------------------------------------------
# waitB4PostStack - Wait before taking post-stack image
# 
# Args:
#	None
# 
# Global variables:
#	COMIRA
#	MIRAHOST
#	MIRAPORT
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
waitB4PostStack()
{
    echo 'yesNoMessage ' \
	'SetWindowPos (700, 200); '\
   'SetFont ("Dialog", 20); '\
   'StaticText ("Do you want to take the post-stack image now?", 0, 0);' \
	'StaticText ("Press Yes to continue.", 0, 1);' \
	'StaticText ("Press No to skip.", 0, 2);' \
	| $COMIRA $MIRAHOST $MIRAPORT
}

#------------------------------------------------------------------------
# restoreValues - return instrument setings to original state
# 
# Args:
#	None
#
# Global variables:
#	STATE_FILE_PRE = name of state file
#------------------------------------------------------------------------
restoreValues()
{

    myLog "Setting $INSTRUMENT config with file $STATE_FILE_PRE"
    myEcho "Contents of state file:"
    myEcho "----------------------------------------"
    cat $STATE_FILE_PRE
    myEcho "----------------------------------------"

    # execute restore state to move stages...
    myLog "Restoring original motor settings"
    buf=`restore_state -verify $STATE_FILE_PRE`
    STAT=$?
    
    while [ $STAT -gt 0 ] ; do

	myLog "restore_state failed with stat=$STAT and output of $buf"
	myEcho STAT=$STAT
	beep
	ANSWER=`echo 'yesNoMessage Title (title, "Warning !!!");  \
	    SetWindowPos (600, 300); \
	    Panel (p1, 0, 0) { \
	    SetFont ("Dialog", 35); \
	    SetFGColor (255, 0, 0); \
	    StaticText ("Warning !!!", 0, 0); } \
	    Panel (p1, 0, 1, 1, 1, BOTH, NORTHWEST, 1, 1, 10, 10, 10, 10) { \
	    SetBGColor (255, 0, 0); \
	    SetFGColor (255, 255, 255); \
	    SetFont ("Dialog", 25); \
	    StaticText ("An error occurred while I was trying to restore instrument settings!", 0, 1); \
	    StaticText ("Please check the text window for additional details.", 0, 2); \
	    StaticText ("The most likely reason for the failure is that", 0, 3); \
	    StaticText ("a stage failed to move,", 0, 4); \
	    StaticText ("If it looks as if this is the case, please try again.", 0, 5); \
	    StaticText ("To try again, press Yes", 0, 6); \
	    StaticText ("To abort, press No", 0, 7); } \
	    ' | $COMIRA $MIRAHOST $MIRAPORT`
	
	if [ "$ANSWER" != "Yes" ]; then
	    myLog "User elected NOT to try again"
	    return 1
	fi

	myLog "re-trying restore_state"
	restore_state -verify $STATE_FILE_PRE
	STAT=$?
    done

    # don't execute restore state to restore CSU targets...

    # remove state files...
    /bin/rm $STATE_FILE_PRE 

    # if we got here, then things must have gone well...
    myLog "Exiting restoreValues"
    return 0
} 

#-----------------------------------------------------------------------
# cleanUp - reset telescope to original settings
# 
# Args:
#	None
# 
# Global variables:
#	None
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
cleanUp2()
{
    trap "" 0 1 2 9 15
    myLog "------------------ script done ------------------"
    echo "killScript " | $COMIRA $MIRAHOST $MIRAPORT
}

cleanUp()
{
    trap cleanUp2 0 1 2 9 15

    #myLog "Restoring original $INSTRUMENT config"
    #restoreValues

    myLog "Returning telescope to original position"
    unMoveTel &
    TelMovePid=$!

    myLog "Resetting PMFM to zero"
    setACSPmfm 0 &
    AcsMovePid=$!

    myLog "Waiting for telescope move to complete (pid=$TelMovePid)"
    wait $TelMovePid

    myLog "Waiting for ACS move to complete (pid=$AcsMovePid)"
    wait $AcsMovePid

    myLog "Sending final confirmation popup"
    miasUnlock 
    beep
    okMessage "Mira has restored the parameters." \
	"Please confirm with the observers that they are correct."
    exit 0
}

# ******************************************************
# ******************************************************
# main part
# Parameter 1: initital directory, optional
# 
# Retrieved images are stored under the directory IMAGEDIR.
# 
# ******************************************************
# ******************************************************
myLog "---------------- script starting ----------------"

# Make sure this is the only one script running.
# Perform locking before changing instrument configuration.
miasLock
if [ $? -ne 0 ]; then
    exit 1
fi

initOnce

trap cleanUp 0 1 2 9 15

cd $IMAGEDIR

if [ "$1" != "" -a -d "$1" ] ; then
    myEcho cd $1
fi

# preliminaries...
greeting

# save settings and check for problem...
initCheck
if [ $? -ne 0 ]; then
    exit 1
fi

# ask user to set exposure time and coadds...
myLog "Requesting params from user"
requestParameters

# configure the instrument and detector for imaging...
myLog "Setting $INSTRUMENT config to MIRA configuration"
configureInstrument

# check if focal plane camera is on, and if not, turn it on 
myLog "Checking if the focal place camera is on"
fpcamPower on

# reset the filename
myLog "Resetting outfile parameter for FPC"

modify -s kfcs outfile=`framerootfpc`


myLog "Moving telescope"
moveTel

#----------------------------------------
# Positive PMFM image
#----------------------------------------

# begin image acquisition loop for +PMFM side...
while :
do
    getSeriesNumber

    # erase all images currently in MIRA analysis tool memory...
    removeAll
    ImageCount=0

    # configure instrument and telescope...
    myLog "Setting ITime=$ITime"
    setITime $ITime

    # set PMFM...
    myLog "Setting PMFM to +$NewPMFM"
    setACSPmfm $NewPMFM &
    AcsMovePid=$!

    # pause to ensure that segments get spread out before 
    # we open the filter...
    myLog "Pausing to allow segments to open"
    sleep 5

    # wait for ACS move to complete...
    myLog "Waiting for ACS to settle"
    wait $AcsMovePid

    # acquire image...
    takeImage

    # check whether to continue...
    beep
    Answer=`askUser`
    myLog "Got answer=$Answer"
    if [ "$Answer" = "Yes" ]; then
	break
    fi

    # ask user to set exposure time and coadds...
    myLog "Requesting params from user"
    requestParameters

done

#----------------------------------------
# optional additional images at POSITIVE PMFM...
#----------------------------------------
numLeft=`expr $NumExp - 1`
while [ $numLeft -gt 0 ]; do

    # acquire image...
    takeImage

    # change counter...
    numLeft=`expr $numLeft - 1`

done

#----------------------------------------
# Negative PMFM image
#----------------------------------------

# Take single image at -PMFM...
if [ "$Double" = "true" ]; then

    # insert PMFM and take +PMFM image...
    setACSPmfm -"$NewPMFM"

    # reset image counter...
    ImageCount=0

    # acquire NumExp images...
    numLeft=$NumExp
    while [ $numLeft -gt 0 ]; do

        # acquire image...
	takeImage

        # change counter...
	numLeft=`expr $numLeft - 1`

    done

fi

# move telescope back to original position...
myLog "Returning telescope to original position"
unMoveTel

# remove PMFM...
setACSPmfm 0 &
AcsMovePid=$!

# turn off focal plane camera
fpcamPower off


# run analysis...
myLog "analysis starting"
ANALYZE=`analyze`
myLog "analysis done"

# wait for background jobs to finish...
myLog "waiting for mirror to settle"
wait $AcsMovePid

# print final message...
myLog "Starting cleanup"
#restoreValues
