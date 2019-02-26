#!/bin/python
"""
160427
Matuszewski -- matmat@caltech.edu

kfcs_centroid.py
----------------
Program intended as a very basic centroiding tool for the KCWI
focal plane camera images. 

Parameters:
    filename: string
        fits filename to load the image from

Returns:
    centroid: array 

Procedure works roughly as follows:

1. Load file
2. Via median filter remove any cosmic rays 
3. Add all rows to generate a 1-D image, centroid the resultant PSF
4. Add all columns to generate a 1-D image, centroid the resultant PSF
5. Return the x,y values

"""

# import packages
import astropy.io.fits as fits
import numpy as np
import matplotlib.pyplot as plt
import scipy.signal as signal
from scipy.special import erfc as erfc
import os.path
import sys
from scipy.optimize import curve_fit as cfit
from scipy.ndimage.interpolation import rotate as imrotate


# confolution of a gaussian with a square box
def gaussbox(x,p0,p1,p2,p3,p4,p5):
    ''' Convolution of a gaussian with a top-hat
    p[0] -- center of box
    p[1] -- width of box
    p[2] -- left-sigma of gaussian
    p[3] -- right-sigma of gaussian
    p[4] -- max value 
    p[5] -- fixed offset
    '''
 
    p1=26.0#/2.0
    p1=20.0#/2.0
    first=erfc( (x-p0-p1/2.0)/(np.sqrt(2.0)*p2) )
    second=erfc( (x-p0+p1/2.0)/(np.sqrt(2.0)*p3) )
    return p5 + 0.5 * p4 * ( first - second )


def gaussian(x,p0,p1,p2,p3,p4 ,p5):
    ''' gaussian model
    p[0] -- scale factor
    p[1] -- centroid
    p[2] -- sigma
    p[3] -- offset
    p[4] -- slope
    '''
    u = (x - p1)/p2
    return p0*np.exp(-0.5*u*u) + p3 + p4*x + p5*x*x

def kfcs_centroid(image_filename,dark_filename="None",rotangle=0.0):

    # are we plotting?
    plotting = 0
    
    #binning
    binning = 1
    deviceysize = 2472
    devicexsize = 3296

    # size of the median filter (for unbinned pixels)
    medfilter = 33
    
    # border within which we use the coords of the max of the peak, rather
    # than a Gaussian fit (for unbinned pixels)
    border = 200
    
    # acceptable signal to noise for the peak 
    sigma = 5
    
    # these should be passed as parameters, but let it be this 
    # for now.
    spotimage, spothdr = fits.getdata(image_filename, 0, header=True)#, uint=True )

    if dark_filename != "None":
        darkimage, diffhdr  = fits.getdata(dark_filename, 0, header = True)#, uint=True )
    

    # extract size information. 
    ysize, xsize  = spotimage.shape
    # get binning from the file
    binning = spothdr['BINNING']
    
    # update medfilter
    medfilter = 1+8/binning
    # update border
    border = border/binning
    
    # will not need to write the difference image until later
    if dark_filename != "None":
        diffimage = spotimage-darkimage
#        fits.writeto('./data/diff.fits',diffimage, spothdr, clobber=True)
    else:
        diffimage = spotimage

    # Apply gains to diff image
    sh=diffimage.shape
    print sh
    diffimage[[0,sh[0]/2],[0,sh[1]/2]] = diffimage[[0,sh[0]/2],[0,sh[1]/2]]*1.255
    diffimage[[0,sh[0]/2],[sh[1]/2,sh[1]-1]] = diffimage[[0,sh[1]/2],[sh[0]/2,sh[0]-1]]*1.255
    diffimage[[sh[0]/2,sh[0]-1],[sh[1]/2,sh[1]-1]] = diffimage[[sh[0]/2,sh[0]-1],[sh[1]/2,sh[1]-1]]*1.237
    diffimage[[sh[0]/2,sh[0]-1],[0,sh[1]/2]] = diffimage[[sh[0]/2,sh[0]-1],[0,sh[1]/2]]*1.238
     
    if rotangle != 0.0:
        diffimage = imrotate(diffimage, rotangle)

    # get the x and y profiles
    xprofile = np.sum(diffimage,axis=0)
    xvals = np.arange(0, xprofile.shape[0], 1)
    print np.max(xvals)
    yprofile = np.sum(diffimage,axis=1)
    yvals = np.arange(0, yprofile.shape[0], 1)
    
    # median average the profiles, and find their median, and max values
    xprofilemed = signal.medfilt(xprofile, medfilter)
    yprofilemed = signal.medfilt(yprofile, medfilter)
    
    xmedian = np.median(xprofile)
    ymedian = np.median(yprofile)
    
    xmax = np.nanmax(xprofilemed)
    ymax = np.nanmax(yprofilemed)
    xmaxind = np.argmax(xprofilemed)
    ymaxind = np.argmax(yprofilemed)

#    print xprofile.size
#    print yprofile.size
#    yprofile = np.sum(diffimage[:,xmaxind-3:xmaxind+3],axis=1)
#    xprofile = np.sum(diffimage[ymaxind-3:ymaxind+3,:],axis=0)

#    print yprof.size
#    print 'yo'
    print xmaxind
    print ymaxind
    
    # find the stdev of the noise (i.e., profile - <median filtered profile>)
    xstdev = np.std(xprofile-xprofilemed)
    ystdev = np.std(yprofile-yprofilemed)
    
    print 'xmed= {:7.5f}, xmax= {:7.5f}, xstdv= {:7.5f}, x= {:7.5f}'.format(xmedian,xmax,xstdev, xmaxind)
    print 'ymed= {:7.5f}, ymax= {:7.5f}, ystdv= {:7.5f}, y= {:7.5f}'.format(ymedian,ymax,ystdev, ymaxind)
    
    if ( ((xmax - xmedian) > (sigma * xstdev)) and ((ymax - ymedian) > (sigma*ystdev)) ):
        peakok = 1 
        print "Peak is OK!"
        significance = (xmax-xmedian)/sigma
    else:
        peakok = 0 
        exit(-1)
        
        ###endif
    

    # find the X centroid.
    if ( xmaxind < border or xmaxind > (xsize-border-1)) :
        xcen = xmaxind
    else:
        print "Can centroid X better!"
        xsubvals = xvals[xmaxind-border:xmaxind+border]
        xsubprof = xprofile[xmaxind-border:xmaxind+border]
#        p_x = ( xmax, xmaxind, 40./binning, xmedian, 0.0, 0.0 )
#        pt, pv = cfit(gaussian,xsubvals, xsubprof, p0=(p_x[0], p_x[1], p_x[2], p_x[3], p_x[4], p_x[5]))
#        if plotting:
#            plt.plot(xsubvals,gaussian(xsubvals,pt[0], pt[1], pt[2], pt[3], pt[4], pt[5]))
#            plt.plot(xsubvals,gaussian(xsubvals,p_x[0], p_x[1], p_x[2], p_x[3],p_x[4], p_x[5]))
#        xcen = pt[1]
#        xsig = pt[2]
        p0=( np.average(xsubvals), 100.0/binning, 20.0/binning, 20.0/binning, np.max(xsubprof), 0)
        pt1,pv1=cfit(gaussbox,xsubvals,xsubprof,p0=p0, sigma=np.sqrt(np.sqrt(xsubprof*xsubprof))+1)
        if plotting:
            plt.plot(xsubvals,gaussbox(xsubvals,pt1[0], pt1[1], pt1[2], pt1[3], pt1[4], pt1[5]))
        xcen = pt1[0]
        print pt1
        # need to get a finer grid to get the width. 
        xfinevals=np.arange(np.min(xsubvals),np.max(xsubvals),0.01)
        xfineprof=gaussbox(xfinevals,pt1[0],pt1[1],pt1[2],pt1[3],pt1[4],0)
        q = xfinevals.compress((xfineprof> (0.5*np.max(xfineprof))).flat)
        # print np.max(q)-np.min(q)
        xsig=np.max(q)-np.min(q)
        # print "That."
        ###endif

    if plotting:
         plt.plot(xvals, xprofile)
         plt.plot(yvals, yprofile)
         
    print ysize
    print ymaxind
    print border 
    # find the Y centroid.
    if ( ymaxind < border or ymaxind > (ysize - border-1)) : 
        print "Y Near border"
        ycen = ymaxind
        ysig = 10.0
    else:
        print "Can centroid Y better!"
        ysubvals = yvals[ymaxind-border:ymaxind+border]
        ysubprof = yprofile[ymaxind-border:ymaxind+border]
#        p_y = [ ymax*1.0, ymaxind*1.0, 40.0/binning, ymedian, 0.0 , 0.0]
#        pt, pv = cfit(gaussian,ysubvals, ysubprof, p0=(p_y[0], p_y[1], p_y[2], p_y[3], p_y[4], p_y[5]))
#        if plotting:
#            plt.plot(ysubvals,gaussian(ysubvals,pt[0], pt[1], pt[2], pt[3], pt[4], pt[5]))
#            plt.plot(ysubvals,gaussian(ysubvals,p_y[0], p_y[1], p_y[2], p_y[3], p_y[4], p_y[5]))

#        ycen = pt[1]
#        ysig = pt[2]
        p0=( np.average(ysubvals), 100.0/binning, 20.0/binning, 20.0/binning, np.max(ysubprof), 0)
        pt1,pv1=cfit(gaussbox,ysubvals,ysubprof,p0=p0, sigma=np.sqrt(np.sqrt(ysubprof*ysubprof))+1.0)
        if plotting:
            plt.plot(ysubvals,gaussbox(ysubvals,pt1[0], pt1[1], pt1[2], pt1[3], pt1[4], pt1[5]))
        ycen = pt1[0]
        yfinevals=np.arange(np.min(ysubvals),np.max(ysubvals),0.01)
        yfineprof=gaussbox(yfinevals,pt1[0],pt1[1],pt1[2],pt1[3],pt1[4],0)
        q = yfinevals.compress((yfineprof> (0.5*np.max(yfineprof))).flat)
        # print np.max(q)-np.min(q)
        ysig=np.max(q)-np.min(q)
        # print "That."
    ###endif
        
        
    print "Centroid: {:7.4f} {:7.4f} {:7.4f}".format(xcen,ycen,significance)
    print "FWHM: {:7.4f} {:7.4f} {:7.4f} ".format(xsig,ysig,np.sqrt(xsig*xsig+ysig*ysig))
    print "INTCENTROID: {:5d} {:5d} {:d}".format(int(xcen),int(ycen),int(significance))

    if plotting:
        plt.show()




if __name__ == "__main__":
    
#    spotfn = './data/kfpc000007.fits'
#    darkfn = './data/kfpc000009.fits'

    if ( ( len(sys.argv) <3 ) or ( len(sys.argv) > 4 )  ):
        print "Insufficient parameters."
        print len(sys.argv)
        print "Usage: "
        print "   kfcs_centroid.py spotfile darkfile <rotangle>"
        exit(-1)
        
    spot_filename = sys.argv[1]
    dark_filename = sys.argv[2]
    if len(sys.argv) == 4:
        rotangle = float(sys.argv[3])
    else:
        rotangle = 0.0

    if ( not os.path.isfile(spot_filename) ):
        print "Filename '{:s}' does not exist.".format(spot_filename)
        exit(-1)

    if ( not os.path.isfile(dark_filename) ):
        print "Filename '{:s}' does not exist.".format(dark_filename)
        exit(-1)


    kfcs_centroid(spot_filename,dark_filename,rotangle)
    exit(0)

#
