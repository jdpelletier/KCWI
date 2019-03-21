#! /kroot/rel/default/bin/kpython

from KCWI import PowerInit, Calibration
from KCWI.Util import sleepdots
import kcwiInit
import ktl
import sys
import time
import subprocess
import argparse

separator = "----------------------------------------"

# additional defaults
#do_init = 1         # run init
#eng = 0 
#oa = 0 
# parse flags...
#with argparser

description = "Start KCWI"
parser = argparse.ArgumentParser(description=description)
parser.add_argument('-no_init', required=False, default=False, action='store_true', help='Run without init script')
parser.add_argument('-eng',required=False, default=False, action='store_true', help='Run in engineering mode')
parser.add_argument('-oa',required=False, default=False, action='store_true', help='Run in OA mode')

args = parser.parse_args()

###
#old way arguments
#while len(sys.argv) > 1:
#
#  # check for -no_init flag...
#  if sys.argv[1] == "-no_init":
#    do_init = 0
#    del sys.argv[1]
#    continue
#
#  # check for -eng flag...
#  if sys.argv[1] == "-eng":
#    eng = 1
#    del sys.argv[1]
#    continue
#
#  # check for -oa flag...
#  if  sys.argv[1] == "-oa":
#    oa = 1
#    del sys.argv[1]
#    continue
#
#  # exit flag check if no flags remain...
#  break
#
#
## validate arguments...
#if len(sys.argv) > 1:
#    echo "Usage: python3 kcwiStart.py [-no_init] [-eng] [-oa]"
#    exit


# -------------------------------------------------------------------
# check for daemons...NOTE that we do NOT check on watchfcs, watchrot,
# and watchslew processes because these run as user 'mosfire' rather
# than under the numbered account and hence their existence does NOT
# present a conflict.
# -------------------------------------------------------------------
set running_daemons = ()
foreach daemon ( autodisplay ds9 )
    set i = `get_kcwi_pid kcwidisplayb`
    if ( "$i" != "" ) then
        set running_daemons = ($running_daemons $daemon)
    endif
end

if ( $#running_daemons != 0 ) then
    set message_file = /tmp/$cmd.$$
    cat >! $message_file  <<EOF
Can't start KCWI software because these daemons are already running:

    $running_daemons

See output below.  You must stop these conflicting daemons to launch
KCWI software!

EOF
    ct >> $message_file
    tkmessage -type error < $message_file
    \rm $message_file
    exit 1
endif

