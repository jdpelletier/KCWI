#!/bin/tcsh
#
# 170410
# Neill -- neill@caltech.edu
#
# The object of this script is to take one bar image

# process the parameters
# options:

# get current state
set sout = "/tmp/kcwicurstate$$.state"
set cout = "/tmp/kcwicurstate$$.cal"
save_state $sout

# generate cal file
kcas_make_calfile.sh $sout

# get the bars line
echo taking Bars bars image

set barsline = `grep Bars $cout`
eval set barsline=\($barsline:q\)
echo $barsline[1] $barsline[2] $barsline[3] 0 1 no >! $cout

set cur_ccdmode = `show -t -s kbds ccdmode`
modify -s kbds ccdmode=1

echo kcas_calib.sh -n -f $cout
kcas_calib.sh -n -f $cout

modify -s kbds ccdmode=$cur_ccdmode

\rm /tmp/kcwicurstate*
echo "Done."

