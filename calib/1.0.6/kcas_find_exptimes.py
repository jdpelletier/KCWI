#! /kroot/rel/default/bin/kpython

import getopt
import sys
import os
import argparse
import inspect 
import numpy as np


try: 
    from KCWI.Blue import *
except:
    sys.stdout.write('Error importing KCWI.blue 0 Some functions might not be available')

from KCWI.Helper import say

description = "Return calibration exposure times given instrument parameters"
parser = argparse.ArgumentParser(description=description)
parser.add_argument('bgrating',help='grating')
parser.add_argument('cwaveb',help='central wavelength')

if __name__ == '__main__':
    
    args = parser.parse_args()
    bgrating = args.bgrating
    cwaveb = args.cwaveb

    print str(bgrating)+" "+str(cwaveb)

    bgrating=bgrating.upper()

    min_time = 0.05
    max_time=120.00


    try:
        grat = grating(bgrating)
    except:
        raise RuntimeError('Error: Invalid grating specified: '+str(bgrating)+'\n')

    reldat = os.environ['RELDIR'] + '/data/kcwi'

    fname=os.path.join(reldat,'kcwi_exptimes_'+(bgrating.lower()).strip()+'.dat')
    print fname
    print cwaveb
    print "Here."
#    if cwaveb < 3500. or cwaveb > 6000:
#        raise RuntimeError('Error: Invalid central wave: '+str(cwaveb)+'\n')


    waves,tcont,tfear,tthar,tdome=np.loadtxt(fname,comments="#",unpack=True)
    print "Here too"
    cwaveb=float(cwaveb)
    new_tthar=np.interp(cwaveb,waves,tthar)
    new_tfear=np.interp(cwaveb,waves,tfear)
    new_tcont=np.interp(cwaveb,waves,tcont)
    new_tdome=np.interp(cwaveb,waves,tdome)

    if new_tthar < min_time:
        new_tthar=min_time
    elif new_tthar > max_time:
        new_tthar=max_time


    if new_tfear < min_time:
        new_tfear = min_time
    elif new_tfear > max_time:
        new_tfear = max_time

    if new_tcont < min_time:
        new_tcont = min_time
    elif new_tcont > max_time:
        new_tcont = maxtime

    if new_tdome < min_time:
        new_tdome = min_time
    elif new_tdome > max_time:
        new_tdome = maxtime
        

    print 'EXPTIMES{0:8.2f}{1:8.2f}{2:8.2f}{3:8.2f}{4:8.1f}{5:8.1f}'.format(new_tcont, new_tfear, new_tthar, new_tdome,cwaveb,cwaveb)

# 
# 
