#!/bin/python
"""
160428
Matuszewski -- matmat@caltech.edu 

Purpose:
Given the centroid of a spot and reference pixel on the focal plane
camera (FPC), compute the offset of the X-Y stage needed to place the
spot at the reference pixel.

170224
Changed stepsizey to accommodate change in stepping

"""

import numpy as np
import sys

def kfcs_compute_kcas_offset(xcen, ycen, tol):
    """
    given x and y centroid coordinates, compute the necessary offset
    to put the spot at the reference point. 
    """
    # reference point
    # This reference point was determined on 161101
    # With instrument temperatures about 17C
    xref = 1674.0
    yref = 1277.0
    
    # maximum allowed shift
    maxmove = 2000.0

    # camera pixel size in microns (unbinned)
    xpixsize = 5.5
    ypixsize = 5.5
    
    # stage step size in microns
    xstepsize = 0.4961
    ystepsize = 0.4961 # *4.000
    
    # x-y distortion
    xdistortion = 0.985
    ydistortion = 0.985
    
    # encoder counts per microstep
    steptoenc = 1.25

    # relative rotation angle in radians
    theta = 0.000
    
    dpx = xref - xcen
    dpy = yref - ycen
    in_tol = 0

    dx = dpx/xdistortion
    dy = dpy/ydistortion

    du = dx * np.cos(theta) - dy * np.sin(theta)
    dv = dx * np.sin(theta) + dy * np.cos(theta)

    dsu = du*xpixsize/xstepsize*steptoenc
    dsv = dv*ypixsize/ystepsize*steptoenc

    if ( dsu > maxmove ):
        dsu = maxmove

    if ( dsu < -1*maxmove):
        dsu = -1*maxmove

    if ( dsv > maxmove ):
        dsv = maxmove

    if ( dsv < -1*maxmove ):
        dsv = -1*maxmove

    diff = np.sqrt(dsu*dsu+dsv*dsv)*xstepsize/steptoenc
    
    if ( diff <= tol ):
        in_tol = 1
    
    print "Offsets: {:f} {:f} {:f}".format(dsu,dsv,diff)
    print "INTOFFSETS {:d} {:d} {:d} {:f}".format(int(dsu),int(dsv),in_tol,diff)



if __name__ == "__main__":

    if ( len(sys.argv) != 4 ):
        print "Insufficient parameters."
        print "Usage: "
        print "   kfcs_compute_kcas_offset xcen ycen tol"
        exit(-1)

    xcen = float(sys.argv[1])
    ycen = float(sys.argv[2])
    tol = float(sys.argv[3])

    kfcs_compute_kcas_offset(xcen, ycen, tol)

    exit(0)

