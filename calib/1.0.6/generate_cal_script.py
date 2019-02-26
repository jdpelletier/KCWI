#!/home/kcwirun/anaconda3/bin/python

import sys,os
import glob
import pandas as pd
import subprocess

try:
    p=subprocess.run('outdir',stdout=subprocess.PIPE)
except:
    print("Cannot run outdir\n")
    sys.exit(1)

def openNewFile(filename):
    if os.path.exists(filename):
         try:
             os.remove(filename)
         except OsError as e:
             say("Error: %s - %s." % (e.filename,e.strerror))
            
    # open the file
    try:
        stateFile = open(filename,'w')
    except:
        raise RuntimeError("The state file cannot be opened")
    return stateFile




dataDir = str(p.stdout.decode()).replace('\n','')

searchPattern = '*.state'

# find the state files
stateFiles = glob.glob(dataDir+'/'+searchPattern)

if len(stateFiles)==0:
    print("The are no state files in %s\n" % (dataDir))
    sys.exit(1)


def remove_whitespace(x):
    if isinstance(x,str):
        return x.replace(' ','')
    else:
        return x  

# read first state file and convert into a panda data structure
df = pd.read_csv(stateFiles[0], delimiter="=",header=None, names=['keyword','state_0'])

# read remaining state files and add them to the data structure
fileNum=1
for file in stateFiles[1:]:
    tmp = pd.read_csv(file, delimiter="=", header=None, names=['keyword','state_'+str(fileNum)])
    df = pd.merge(df,tmp, how='outer', on=['keyword'])
    fileNum +=1

# remove white spaces and tranpose (columns now are the keywords)
mydf = df.applymap(remove_whitespace).transpose()

# remove white spaces from the original
df = df.applymap(remove_whitespace)

# replace the column names in the transposed df with the keyword names 
mydf.columns = [x for x in df['keyword']]

# drop the "keyword" row
mydf = mydf.drop(['keyword'])

# open the output files
gencals = openNewFile("generate_cal_files.csh")
allcals = openNewFile("all_calibrations.csh")
domeonly = openNewFile("dome_calibrations.csh")
nodome = openNewFile("nodome_calibrations.csh")

for index,row in mydf.iterrows():
    output = "makecalib %s___%s.state\n" % (row['progname'],row['statenam'])
    sys.stdout.write(output)
    gencals.write(output)
gencals.close()

# do we have binning 2,2 ?
binning2 = mydf['binningb']=="2,2"

if len(mydf[binning2])==0:
    sorted = mydf.sort_values(by=["gratingb","image_slicer"])
    sys.stdout.write("******************************\n")
    sys.stdout.write(sorted.to_string())
    sys.stdout.write("\n")
    for index,row in sorted.iterrows():
        output = "restore_state -calib -nomask %s___%s.state\n" % (row['progname'],row['statenam'])
        sys.stdout.write(output)
        allcals.write(output)
        domeonly.write(output)
        nodome.write(output)

        output = "kcas_calib -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        sys.stdout.write(output)
        allcals.write(output)
        output = "kcas_calib -domeonly -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        domeonly.write(output)
        output = "kcas_calib -nodome -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        nodome.write(output)
    output = 'lamp all off'
    allcals.write(output)
    domeonly.write(output)
    nodome.write(output)
    allcals.close()
    domeonly.close()
    nodome.close()

    sys.exit()

# write out the configurations for binning 2,2
sys.stdout.write("# Binning 2,2\n")
for index,row in mydf[binning2].iterrows():
        output = "restore_state -calib -nomask %s___%s.state\n" % (row['progname'],row['statenam'])
        sys.stdout.write(output)
        allcals.write(output)
        domeonly.write(output)
        nodome.write(output)

        output = "kcas_calib -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        sys.stdout.write(output)
        allcals.write(output)
        output = "kcas_calib -domeonly -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        domeonly.write(output)
        output = "kcas_calib -nodome -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        nodome.write(output)

        #sys.stdout.write("restore_state -nomask %s___%s.state\n" % (row['progname'],row['statenam']))
        #sys.stdout.write("kcas_calib -f %s___%s.cal\n" % (row['progname'],row['statenam']))
        sys.stdout.write("\n")
# record the value of the last grating used, and remove all the 1,1 lines
last_grating = mydf[binning2].ix[-1].gratingb
binning2_labels=mydf.query('binningb=="2,2"').index.tolist()
for row in binning2_labels:
    mydf = mydf.drop(row)

# select the lines corresponding to this grating, and run then sorted by slicer
run_now = mydf['gratingb']==last_grating
sorted = mydf[run_now].sort_values(by="image_slicer")

# print configurations for these lines
afterABinningChange = True
sys.stdout.write("# Binning  1,1  Grating %s\n" % (last_grating))
for index,row in sorted.iterrows():
        output = "restore_state -calib -nomask %s___%s.state\n" % (row['progname'],row['statenam'])
        sys.stdout.write(output)
        allcals.write(output)
        domeonly.write(output)
        nodome.write(output)
        if afterABinningChange:
            output = "object ClearCCD; ampmodeb 0; ccdmodeb 1; tintb 0; goib 2\n"
            sys.stdout.write(output)
            allcals.write(output)
            domeonly.write(output)
            nodome.write(output)
            afterABinningChange = False

        output = "kcas_calib -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        sys.stdout.write(output)
        allcals.write(output)
        output = "kcas_calib -domeonly -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        domeonly.write(output)
        output = "kcas_calib -nodome -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        nodome.write(output)
        mydf = mydf.drop(index)
# a bit of output
#sys.stdout.write(mydf.to_string())
sys.stdout.write("\n")

# build a list of remaining gratings
gratings = ['BL','BM','BH1','BH2','BH3']
gratings.remove(last_grating)

# look for each grating in the remaining list and print out their configuration

for grating in gratings:
    sys.stdout.write("# Binning  1,1  Grating %s\n" % (grating))
    run_now = mydf['gratingb']==grating
    sorted = mydf[run_now].sort_values(by="image_slicer")
    for index,row in sorted.iterrows():
        output = "restore_state -calib -nomask %s___%s.state\n" % (row['progname'],row['statenam'])
        sys.stdout.write(output)
        allcals.write(output)
        domeonly.write(output)
        nodome.write(output)

        output = "kcas_calib -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        sys.stdout.write(output)
        allcals.write(output)
        output = "kcas_calib -domeonly -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        domeonly.write(output)
        output = "kcas_calib -nodome -f %s___%s.cal\n" % (row['progname'],row['statenam'])
        nodome.write(output)

        sys.stdout.write("\n")
output = 'lamp all off'
allcals.write(output)
domeonly.write(output)
nodome.write(output)

allcals.close()
domeonly.close()
nodome.close()

