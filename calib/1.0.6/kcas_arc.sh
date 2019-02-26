#!/bin/tcsh
#
# 170410
# Neill -- neill@caltech.edu
#
# The object of this script is to go through a *.cal file
# and take arc images

# process the parameters
# options:
set temp=(`getopt -s tcsh -o a:: --long arc:: -- $argv:q`)
if ( $? != 0 ) then
	echo "Invalid arguments." > /dev/stderr
	echo $temp
	exit -1
endif

set arc = "THAR"

if ( $1 == "" ) then
	set arc = "THAR"
else
	if ( $1 == "-a" || $1 == "--arc" ) then
		set arc=$2:q
	else
		echo "Invalid arguments." > /dev/stderr
		exit -1
	endif
endif

set arc = `echo $arc | tr "[a-z]" "[A-Z]"`

if ( $arc != "THAR" && $arc != "FEAR" ) then
	echo "Invalid arc specified, must be thar or fear." > /dev/stderr
endif

# get current state
set sout = "/tmp/kcwicurstate$$.state"
set cout = "/tmp/kcwicurstate$$.cal"
save_state $sout

# generate cal file
kcas_make_calfile.sh $sout

# get the arc line
echo taking $arc arc image

set arcline = `grep $arc $cout`
eval set arcline=\($arcline:q\)
echo $arcline[1] $arcline[2] $arcline[3] 0 1 no >! $cout

set cur_ccdmode = `show -t -s kbds ccdmode`
modify -s kbds ccdmode=1

echo kcas_calib.sh -n -f $cout
kcas_calib.sh -n -f $cout

modify -s kbds ccdmode=$cur_ccdmode

\rm /tmp/kcwicurstate*
echo "Done."

