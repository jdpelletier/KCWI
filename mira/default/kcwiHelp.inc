#!/bin/sh
#-----------------------------------------------------------------------
# Help file included by Mias.sh
# This file should not be executed by itself.
#
# Author: Shui Hung Kwok
# Created: Nov 18, 2002
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# verifyInstrument - check whether instrument settings are appropriate
# 
# Args:
#	None
#
# Called by:
#	configureInstrument
# 
# Global variables:
# 
# Returned value:
#	None
#-----------------------------------------------------------------------
verifyInstrument()
{
    echo "Verifying settings"
}

#-----------------------------------------------------------------------
# configureMotors - called by configureInstrument
#
# Args:
#	$1 = obsmode [defaults to J-imaging]
#
# Modification history:
#	2012sep12	GDW	Added SETUPNAME
#	2012sep14       JLW     Removed SETUPNAME, put in mosfireConfigCSUMira.csh
#	2012oct09	GDW	Added check for failed restore_state
#-----------------------------------------------------------------------
configureMotors()
{

    myEcho "Check that FPC is on"
    result=`show -s kp1s pwstat1`
    if [ "$result" = "0" ]; then
	myEcho "Turning on FPCamera"
	fpcamPower on
    fi
    myEcho "Check that FPC is ready"
    result=`show -s kfcs status`
    if [ "$result" != "OK" ]; then
	myEcho "FP camera is not ready. Resetting..."
	fpcamPower on
    fi


       
    myEcho "Configuring motors"

    # remove existing state file...

    myLog "Setting $INSTRUMENT to file $STATE_FILE"
    myEcho "Contents of state file:"
    myEcho "----------------------------------------"
    cat $STATE_FILE
    myEcho "----------------------------------------"

    # enter restore state loop...
    while [ 1 ]; do

        # effect changes...
	myLog "Running restore_state" 
	buf=`restore_state -verify $STATE_FILE`
	stat=$?

	# check for success,,,
	if [ "$stat" = "0" ]; then
	    myLog "Completed restore_state successfully"
	    break
	fi

	# report failure...
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
	    myLog "User elected NOT to try again -- abort!"
	    exit 1
	fi

    done
}

#-----------------------------------------------------------------------
# configureInstrument - set instrument up for taking Mira data
# 
# Args:
#	None
# 
# Global variables:
#	
# Returned 
#	None
#-----------------------------------------------------------------------
configureInstrument()
{
    configureMotors
}

