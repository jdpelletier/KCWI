#! /kroot/rel/default/bin/kpython

from KCWI import PowerInit, Calibration
#from KCWI.Util import sleepdots
import kcwiInit
import ktl
import os
import sys
import time
import subprocess
import argparse


def sleepdots(seconds):
    i = 0
    while i < seconds:
        i += 1
        sys.stdout.write(".")
        sys.stdout.flush()
        time.sleep(1)

    sys.stdout.write('\n')


separator = "----------------------------------------"
#####TODO delete this if we get rid of message file stuff
#mf = open('message_file', 'w')

# parse flags...

description = "Start KCWI"
parser = argparse.ArgumentParser(description=description)
parser.add_argument('-no_init', required=False, default=False, action='store_true', help='Run without init script')
parser.add_argument('-eng',required=False, default=False, action='store_true', help='Run in engineering mode')
parser.add_argument('-oa',required=False, default=False, action='store_true', help='Run in OA mode')

args = parser.parse_args()


# -------------------------------------------------------------------
# check for daemons...NOTE that we do NOT check on watchfcs, watchrot,
# and watchslew processes because these run as user 'mosfire' rather
# than under the numbered account and hence their existence does NOT
# present a conflict.
# -------------------------------------------------------------------



running_daemons = []
for daemon in (autodisplay, ds9):
    i = subprocess.Popen("get_kcwi_pid kcwidisplayb", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)
    if i != "":
        running_daemons.append(daemon)

if len(running_daemons) != 0:
    print("Can't start KCWI software because these daemons are already running:\n%s\nSee output below. You must stop these conflicting daemons to launch KCWI software!" % running_daemons)
######TODO delete this or add it in
#    ct = subprocess.Popen("ct", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True) 
#    (output, err) = ctx.communicate()
#    mf.write(output)
#    tkmessage -type error < $message_file
#    os.remove("message_file")
    sys.exit(1)

# -------------------------------------------------------------------
# Warn observer if other rpc tasks are currently running and under
# what accounts.
# -------------------------------------------------------------------

######TODO Delete this or add it in
#ctx = subprocess.Popen("ctx", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)
#(output, err) = ctx.communicate()
#if err > 0:
#    mf.write("\nCan't start KCWI software. There is something wrong with the software running on kcwiserver.\n\nPlease check output below and inform the Support Astronomer.")
#    mf.write(output)
#    tkmessage -type error < $message_file
#    os.remove("message_file")
#    sys.exit(1)


# -------------------------------------------------------------------
# define display layout appropriate for number of screens on host...
# -------------------------------------------------------------------

if os.environ.get("DISPLAY") is None:
    print("ERROR: must set DISPLAY before running this program")
    sys.exit(1)

# set display variables...
#TODO turn this into for loop using a list, not sure how intereaction with later shell will work
    disp = subprocess.Popen("uidisp 0", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)
    (output, err) = disp.communicate()
    uidisp0 = output
    disp = subprocess.Popen("uidisp 1", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)
    (output, err) = disp.communicate()
    uidisp1 = output
    disp = subprocess.Popen("uidisp 2", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)
    (output, err) = disp.communicate()
    uidisp2 = output
    disp = subprocess.Popen("uidisp 3", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)
    (output, err) = disp.communicate()
    uidisp3 = output

sleepdots(3)

# ---------------------------------------------------------------
# allow numbered user to restore default settings if desired...
# ---------------------------------------------------------------
if do_init == 1:
    subprocess.call('clear')
    kcwiInit()
    if status > 0:
    print("Can't start KCWI software. Some of the mechanisms are locked.\nPlease inform the Support Astronomer.")
#####TODO figure out with other message file stuff
#    tkmessage -type error < $message_file
#    \rm $message_file
    sys.exit(1)


# ---------------------------------------------------------------
# Start the kcwi DS9 Display utility and CSU audio widgets
# ---------------------------------------------------------------
#setenv DISPLAY $uidisp1
# Start KCWI's display software (ds9) and python relay

###TODO adding dictionary
#
#start = {}
#start['Help'] = ['Starting Blue image display software DS9', 'Starting focal plane display software DS9',
#                 'Starting Magiq display software DS9', 'Starting Eventsound', 'Starting KCWI Configuration Manager Backend',
#                 'Starting eventsounds\n**** OVERRIDE: Not ready yet ****', 
#                 'Starting Program Interface Gui\n**** OVERRIDE: Not ready yet ****',
#                 'Starting KCWI desktop', 'Starting TkLogger on $DISPLAY\n**** OVERRIDE: Not ready yet ****',
#                 'Starting Tkrose on $DISPLAY\n**** OVERRIDE: Not ready yet ****', 'Starting KCWIServerXterm on $DISPLAY',
#                 'Re-arranging GUIs', 'Starting KCWI Calibration GUI', 'Starting KCWI Exposure GUI', 'Starting KCWI Status GUI',
#                 'Starting KCWI Offset GUI']
#                  
#start['tool'] = ['kcwidisplayb', 'kfcdisplay', 'magiqdisplay', 'eventsounds', 'kcwiConfManager', 'kdesktop_eng', 'kdesktop_oa',
#                 'kdesktop', 'kcwiArrangeGuis', 'kcwiCalibrationGui', 'kcwiExposureGui', 'kcwiStatusGui', 'kcwiOffsetGui']
#
#start['display'] = ['uidisp0','uidisp1', 'uidisp2', 'uidisp3']

print(separator +
'''
Starting Blue image display software DS9
'''
+ separator)

subprocess.Popen("kcwi start kcwidisplayb -D $uidisp1", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)


print(separator +
'''
Starting focal plane display software DS9
'''
+ separator)

subprocess.Popen("kcwi start kfcdisplay -D $uidisp1", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)

print(separator +
'''
Starting Magiq display software DS9
'''
+ separator)


subprocess.Popen("kcwi start magiqdisplay -D $uidisp2", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)

print(separator +
'''
Starting Eventsound
'''
+ separator)

subprocess.Popen("kcwi start eventsounds -D $uidisp2", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)

print(separator +
'''
Starting KCWI Configuration Manager Backend
'''
+ separator)

subprocess.Popen("kcwi start kcwiConfManager", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)

# start eventsounds
print(separator +
'''
Starting eventsounds
**** OVERRIDE: Not ready yet ****
'''
+ separator)

print(separator +
'''
Starting Program Interface Gui
**** OVERRIDE: Not ready yet ****
'''
+ separator)

# ---------------------------------------------------------------
# Start the KCWI Desktop
# ---------------------------------------------------------------
print(separator +
'''
Starting KCWI desktop
'''
+ separator)

if eng == 1:
    subprocess.Popen("kcwi start kdesktop_eng -D $uidisp0", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)
elif oa == 1:
    subprocess.Popen("kcwi start kdesktop_oa -D $uidisp0", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)
else:
    subprocess.Popen("kcwi start kdesktop -D $uidisp0", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)

# ----------------------------------------------------------------------
# launch tklogger error checker...
# ----------------------------------------------------------------------
os.environ("DISPLAY") = uidisp2

print(separator +
'''
Starting TkLogger on %s
**** OVERRIDE: Not ready yet
'''
% os.getenv("DISPLAY") + separator)

#if ( $atWMKO == 1 ) then
#    kcwiStartTklogger
#endif

# ---------------------------------------------------------------
# Start the compass rose
# ---------------------------------------------------------------
os.environ("DISPLAY") = uidisp2

print(separator
'''
Starting Tkrose on %s
**** OVERRIDE: Not read yet
'''
% os.getenv("DISPLAY") + separator)

#if ( $atWMKO == 1 ) then
#    start_tkrose $uidisp2
#endif

# ---------------------------------------------------------------
# Start xterm on control2
# ---------------------------------------------------------------
os.environ("DISPLAY") = uidisp2

print(separator +
'''
Starting KCWIServerXterm on %s
'''
% os.getenv("DISPLAY") + separator)

#    ssh -X -l $USER ${kcwihost} xterm -title KCWIServerXterm -name Summit &

# ----------------------------------------------------------------------
# Arrange Guis on the desktops
# ----------------------------------------------------------------------
print(separator +
'''
Re-arranging GUIs
'''
+ separator)

time.sleep(10)

#TODO rewrite arrange guis in python
subprocess.Popen("kcwiArrangeGuis", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)

print(separator +
'''
Starting KCWI Calibration GUI
'''
+ separator)

subprocess.Popen("kcwi start kcwiCalibrationGui -D $uidisp2", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)


print(separator +
'''
Starting KCWI Exposure GUI
'''
+ separator)

subprocess.Popen("kcwi start kcwiExposureGui -D $uidisp1", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)

print(separator +
'''
Starting KCWI Status GUI
'''
+ separator)

subprocess.Popen("kcwi start kcwiStatusGui -D $uidisp1", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)

print(separator +
'''
Starting KCWI Offset GUI
'''
+ separator)

subprocess.Popen("kcwi start kcwiOffsetGui -D $uidisp2", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)


# power on hatch
PowerInit.kcwiPower(1, 7, "on")

#hatch open
Calibration.hatch("open")
#hatch close
Calibration.hatch("close")

# print completion message....

print(
'''
      ----------------------------------------------------------
                KDESKTOP might take a while to appear
      ----------------------------------------------------------
                       KCWI startup complete!
      ----------------------------------------------------------
''')

response = raw_input("Press <Enter> to exit...")

sys.exit(0)
