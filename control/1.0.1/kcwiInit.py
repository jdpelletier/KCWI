from KCWI import PowerInit, Calibrations, Blue, Procs
from KCWI.Helper import say
from KCWI.Util import sleepdots
import ktl
import sys
import subprocess

# check arguments

if len(sys.argv) > 1:
    print("Usage: python kcwiInit.py")
    exit

# verify that the user really wants to run the script...
print(
'''
Welcome to the KCWI initialization script. You should ALWAYS run 
this script at the start of any observing nights of your run to 
undo any changes that the previous observer made to KCWI and to 
re-initialize hardware and software.
'''
)
response = str(input( "Do you want to continue running the setup script? (y/n) [y]: "))
if response in ['n', 'N']:
    exit

subprocess.Popen("kcwiUnlockAllServers", stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True)

# set the observer
observer_keyword = ktl.cache('kbds', 'observer')
observer = observer_keyword.read()

observer_input = input("Enter the name(s) of the observing team members [%s] " % observer)

if observer_input != "":
    observer_keyword.write(observer_input)

# reset the instrument and camera keywords for the blue detector

instrument = ktl.cache("kbds", "INSTRUMENT")
camera = ktl.cache("kbds", "CAMERA")
instrument.write("KCWI")
camera.write("BLUE")

# define the output directory...

outdirectory_keyword = ktl.cache("kbds", "outdir")
outdirectory = outdirectory_keyword.read()

print( "Output directory is currently set to [%s]" % outdirectory)

disklist = ktl.cache("kbds", "disklist")
disklist.write("/s/sdata1400")

default = y
yesno = str(input("Do you want to create a new data directory? (y/n) [%s]: " % default))

# no response ==> use default...
if yesno == "":
    yesno = default

# positive response ==> create new directory...
if yesno in ['y', 'Y']:
    #TODO find newdir
    newdir

# set the frame number; default is to use next number in sequence for
# current output directory...
#TODO check this Procs function with Luca
default = str(Procs.get_nextfile(channel='blue')
frameno = input("Enter starting blue image number [%s]: " % default)

if frameno == "":
    frameno = default

if frameno < 0:
    frameno = 0
#TODO check this too
#setframeb $frameno
Procs.set_nextframe(channel='blue',number=frameno)
frameroot = str(Procs.frameroot(channel='blue'))
print("Changing frameroot to %s " % frameroot)

outfile = ktl.cache("kbds", "outfile")
outfile.write(frameroot)

### FOCAL PLANE CAMERA
default = str(Procs.get_nextfile(channel='fpc'))
frameno = input("Enter starting focal plane camera image number [%s]: " % default)

if frameno == "":
    frameno = default

if frameno < 0:
    frameno = 0

#setframefpc $frameno
Procs.set_nextframe(channel='fpc',number=frameno)
#@ frameroot = `framerootfpc`

#JOHNEDIT
outfile = ktl.cache("kfcs", "outfile")
outfile.write(str(Procs.frameroot(channel='fpc')))

### CCD Power

ccdpower_keyword = ktl.cache("kbds", "ccdpower")
ccdpower = ccdpower_keyword.read()

if ccdpower == "1":
    print("The CCD power is already on")

else
    # reset detector...
    default = "y"
    yesno = str(input("Do you want to turn on power to the Blue CCD? (y/n) [%s]: " % default))

    # no response ==> use default...
    if yesno == "":
        yesno = default

    if yesno in ['y', 'Y']
        print("Turning on power to Blue CCD")

        #JOHNEDIT
        #modify -s kbds ccdpower = 1
        ccdpower = ktl.cache("kbds", "ccdpower")
        ccdpower.write(1)

        #JOHNEDIT added python script
        #sleepdots 5
        sleepdots(5)

### Blue CCD settings

default = "y"
yesno = str(input("Do you want to reset the Blue CCD to default settings ? (y/n) [%s]: " % default))

    # no response ==> use default...
if yesno == "":
    yesno = default

    # positive response ==> reset
if yesno in ['y', 'Y']
    print("Resetting detector parameters to their nominal values...")
    Blue.ampmodeb(ampmode=9)
    Blue.gainmulb(gainmul=10)
    Blue.ccdmodeb(ccdmode=0)
    Blue.binningb(binning='2,2')
    Blue.autoshutb(mode=1)
    print("Default detector parameters have been set")

### Magiq Guider

magiqPower_keyword = ktl.cache("kpls"," pwstat2")
magiqPower = magiqPower_keyword.read()

if magiqPower == "1":
    print("Magiq power is already on")
else
    default = "y"
    yesno = str(input("Do you want to turn on power to the Magiq Guider? (y/n) [%s]: " % default))

    # no response ==> use default...
    if yesno == "":
        yesno = default

    if yesno in ['y', 'Y']:
        print("Turning on power to Magiq Guider")

    PowerInit.kcwiPower(1, 2, "on")
    sleepdots(5)

print(
'''

------------------------------------------------------------------------
                    Instrument initialization completed
------------------------------------------------------------------------

'''
)
exit