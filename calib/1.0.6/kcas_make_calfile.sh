#!/bin/tcsh
# 160418
# Matuszewski -- matmat@caltech.edu
#
# Purpose. 
# Ingest the instrument settings and generate a list of
# calibrations to take in the afternoon and a list to take at night. 
#
# Method.
# The KCWI pipeline requires an arc flat and continuum bars image to
# correct for instrument distortions and to generate a wavelength
# solution. Additionally, a continuum flat field provides
# pixel-to-pixel flat corrections. The geometry solutions can alter
# the detector gain and amplifier selection (quad vs. single, for
# instance), but the continuum flat should not. 
#
# The shortest exposure times (for a given grating)
# - 2x2 binning*
# - high gain (DN/e)
# - large slicer*
# - polarizer retracted*
#
# * = can't be changed for calibration images
# 
# Other configurations will require longer exposure times. The script
# will determine the multipliers based on the settings and then grab
# the exposure time from the look-up table for each grating. 
# 
# The arc lamp selected is FeAr for the LOW resolution grating and the
# ThAr for any other grating. 
#
# For arc flats and continuum bars, the quad amplifier and high gain
# mode will be used to minimize data acquisition, without sacrificing
# quality. For the continuum flats, the same amplifier and gain as the
# science needs to be used. This means there are actually two multipliers.
#
# The logic is something like: 
# 
# 1. Check detector binning. adjust both multipliers
# 2. Check slicer. adjust both multipliers
# 3. Check polarizer. adjust both multipliers
# 4. Check detector gain. adjust contflat multiplier
# 5. Look up the exposure time for current grating and wavelength
#    setting
# 6. Based on resultant exposure time, determine whether to use 
#    the ND filter equipped objects for any of the images
# 7. Generate the flat files, where in each row:
#       Lamp, ObjectID, Exposure time, Exposure count, geomonly, otherflags?
#
# One more possible wrinkle: 
# For the continuum flats, we could move the slicer a few hundred
# microns in either direction to make sure that we get a good flat
# field everywhere. This may be more of an engineering situation,
# though.
#
# When it is time to take night-time calibrations:
# 0. Make sure all cal axes are homed and instrument is inactive
# 1. Turn on desired arc lamp, make sure shutter is closed
# 2. Go to appropriate bars
# 3. switch to quad amp, fast, high gain mode
# 4. turn on continuum lamp and take exposure
# 5. turn off continuum lamp
# 6. move to appropriate flat field
# 7. open arc shutter 
# 8. Take arc flat
# 9. close arc shutter, turn off arc
#10. take a bias exposure to make sure CCD is prepped (or clear??)
#11. as bias image is being read out, park calibration stage



if ($# != 1) then 
    echo "Error: Provide a KCWI save state filename."
    exit -1
endif

set instatefile=$1

if ( ! -r "$instatefile" ) then
    echo "Error: Specified KCWI save state file '$instatefile' is not valid."
    exit -2
endif

set statefile=`basename $instatefile`
set realfile=`realpath $instatefile`
set filepath=`dirname $instatefile`
set basename=`basename $instatefile .state`
set calfile="$filepath/${basename}.cal"


if ( -f $calfile ) then
    echo 
    echo "Warning: Specified KCWI cal file exist '$calfile'" >> /dev/stderr
    echo "         Renaming to '${calfile}.old'" >> /dev/stderr
    echo 
    mv $calfile ${calfile}.old
endif


set keys=`egrep -v '^[[:space:]]*#' $realfile | cut -d= -f1`
set values=`egrep -v '^[[:space:]]*#' $realfile | cut -d= -f2 | cut  -d\# -f1`


# Key defaults.
set bgrating=BL
set bfilter=IN
set polarizer=Sky
set slicer=Large
set bcamangle=30.0
set bgratangle=15.0
set cwaveb=4500.0

set bwave=4900.0
set bbinning="2,2"
set bbinx=2
set bbiny=2
set bamp=0
set bgain=10
set bspeed=0


@ nct = $#keys
@ ct = 1

# Loop over keywords.
while ( $ct <= $nct ) 
    # Capitalize the key-value pairs
    set key = `echo $keys[$ct] | tr "[a-z]" "[A-Z]"`
    set value = `echo $values[$ct] | tr "[a-z]" "[A-Z]"`
    # Case block to deal with the keys
    switch ( $key ) 
	case GRATINGB:
	    set bgrating = $value
	    printf "%20s = %-15s\n" $key $value
	breaksw
	case GRANGLEB:
	    set bgratangle = $value
	    printf "%20s = %-15s\n" $key $value
	breaksw
	case CWAVEB:
	    set cwaveb = $value
	    printf "$20s = %-15s\n" $key $value
	breaksw
	case CAMANGLEB:
	    set bcamangle = $value
	    printf "%20s = %-15s\n" $key $value
	breaksw
	case FILTERB: 
	    set bfilter = $value
	    printf "%20s = %-15s\n" $key $value
	breaksw
	case POLARIZER:
	    set polarizer = $value
	    printf "%20s = %-15s\n" $key $value
	breaksw
#	case POLANGLE:
#	    set polangle = $value
#	    printf "%20s = %-15s\n" $key $value
#	breaksw
	case IMAGE_SLICER:
	    set slicer = $value
	    printf "%20s = %-15s\n" $key $value
	breaksw
	case BINNINGB:
	    set bbinning = $value
	    printf "%20s = %-15s\n" $key $value
	breaksw
	case AMPMODEB:
	    set bamp = $value
	    printf "%20s = %-15s\n" $key $value
	breaksw
	case GAINMULB:
	    set bgain = $value
	    printf "%20s = %-15s\n" $key $value
	breaksw
	case CCDMODEB:
	    set bspeed = $value
	    printf "%20s = %-15s\n" $key $value
	breaksw
	case CAL_MIRROR:
	    set cal_mirror = $value
	    printf "%20s = %-15s\n" $key $value
	breaksw
	default:
	    printf "%20s = %-15s %20s\n" $key $value "Unused or Unrecognized!" >> /dev/stderr
	breaksw
    endsw
    # 
@ ct++
end



# Parameters. 


# derived values
set bbinx=`echo $bbinning | cut -d , -f1`
set bbiny=`echo $bbinning | cut -d , -f2`


# These are the exposure time multipliers for calibration images
# also a read-out time multiplier. The read-out multiplier is affected
# by  CCD speed, number of amplifiers used, and the binning.
set sci_mult=1.0
set geom_mult=1.0
set arc_mult=1.0
set read_mult=1.0

# read-out time for geometry and science modes. 
# the geometry read-out is for fast, 2x2 binning, quad amp.
set geom_readout=15.0
set sci_readout=15.0

# Multipliers
set pol_mult=2.1

set large_slicer_mult=1.0
set medium_slicer_mult=2.0
set small_slicer_mult=4.0

set bin1_mult=2.0
set bin2_mult=1.0
set bin4_mult=0.5

set gain1_mult=10.0
set gain2_mult=5.0
set gain5_mult=2.0
set gain10_mult=1.0

# primary and secondary arc.
set primary_arc=THAR
set secondary_arc=FEAR

# objects
set medbar_object=MedBarsA
set widebar_object=LrgBarsA
set finbar_object=FinBars


# There are 5 basic Cal images to be taken, 
# Primary Arc flat
# Secondary Arc flat 
# Continuum flat
# Continuum Bars
# Dome Flat

# additionally, there could be darks and biases

# default exposure times 
set fear_base_exptime=30
set thar_base_exptime=30
set cont_base_exptime=1
set dome_base_exptime=30
set bias_exptime=0
set dark_exptime=0

# max exposure times
set dome_flat_maxtime=300

# default objects 
set fear_arc_object=FlatA
set thar_arc_object=FlatA
set cont_flat_object=FlatA
set cont_bars_object=$medbar_object
set dome_flat_object=Dark

# default image counts
# set fear_arc_count=1
# set thar_arc_count=1
# set cont_flat_count=3
# set cont_bars_count=1
# set dome_flat_count=3

#default afternoon flag
set fear_arc_aft=1
set thar_arc_aft=0
set cont_flat_aft=6
set cont_bars_aft=1
set dome_flat_aft=3
set bias_aft=7
set dark_aft=0

# default night flag
set fear_arc_night=1
set thar_arc_night=0
set cont_flat_night=0
set cont_bars_night=1
set dome_flat_night=0
set bias_night=0
set dark_night=0

# default geometry flags
set fear_arc_geom=yes
set thar_arc_geom=yes
set cont_flat_geom=no
set cont_bars_geom=yes
set dome_flat_geom=no
set bias_geom=no
set bias_geom2=yes
set dark_geom=no


# Process the multipliers

# Polarizer
# ---------
# Capitalize
set polarizer=`echo $polarizer | tr "a-z" "A-Z"`
# Default multiplier
set mult=1.0
switch ( $polarizer ) 
    case POLAR:
	set mult=$pol_mult
    breaksw
    case SKY:
    breaksw
    default:
    breaksw
endsw
# Apply multipliers
set sci_mult=`echo "$sci_mult * $mult" | bc`
set geom_mult=`echo "$geom_mult * $mult" | bc`
set arc_mult=`echo "$arc_mult * $mult" | bc `

echo "Polarizer: $sci_mult $geom_mult $arc_mult"

# Slicer
# ------
# Capitalize
set slicer=`echo $slicer | tr "a-z" "A-Z"`
# Default multiplier
set mult=1.0
switch ( $slicer )
    case LARGE:
	set mult=$large_slicer_mult
    breaksw
    case MEDIUM:
	set mult=$medium_slicer_mult
    breaksw
    case SMALL:
	set mult=$small_slicer_mult
    breaksw
    default:
	echo "Error: Invalid slicer position '${slicer}'!" > /dev/stderr
	exit -1
    breaksw
endsw
# Apply multipliers
# Strangely, the choice of slicer does not affect arc exposure time, and 
# neither does the binning in the spectral direction. 
set sci_mult=`echo "$sci_mult * $mult" | bc`
set geom_mult=`echo "$geom_mult * $mult" | bc`
set arc_mult=$arc_mult 

# Filter currently no impact on the exposure times, since it is very
# high throughput  
# Capitalize
set bfilter=`echo $bfilter | tr "a-z" "A-Z"`
set mult=1.0
switch ( $bfilter ) 
    case KBLUE:
    breaksw
    case NONE:
    breaksw
    case default:
	echo "Error: Invalid filter name '$bfilter'!" > /dev/stderr
	exit -1
    breaksw
endsw

# Grating and wavelength
set bgrating=`echo $bgrating | tr "a-z" "A-Z"`
set gratfile="BL.dat"

# Grating determines which arc gets used as the primary
# Also determines the wavelength, which drives exposure times
# (more on that later)
# Primary and secondary arc
set arc=NONE
switch ( $bgrating ) 
    case BL:
	set gratfile="BL.dat"
	set arc=FEAR
    breaksw
    case BM:
	set gratfile="BM.dat"
	set arc=THAR
    breaksw
    case BH1:
	set gratfile="BH1.dat"
	set arc=THAR
    breaksw
    case BH2:
	set gratfile="BH2.dat"
	set arc=THAR
    breaksw
    case BH3:
	set gratfile="BH3.dat"
	set arc=THAR
    breaksw
    case NONE:
	set gratfile="Direct.dat"
	set arc=NONE
    breaksw
    case default:
	echo "Error: Invalid grating name 'bgrating'!" > /dev/stderr
	exit -1
    breaksw
endsw

# Binning
# -------
# Binning in X.
# Note that binning affects the readout times the same way. 
set mult=$bin2_mult
set ros_mult=1.0
switch ( $bbinx )
    case 1:
	echo "Fine bars!"
	set bar_object=$finbar_object
	set mult=$bin1_mult
	set ros_mult=2.0
    breaksw
    case 2:
	set bar_object=$medbar_object
	set mult=$bin2_mult
	set ros_mult=1.0
    breaksw
    case 4:
	set bar_object=$widebar_object
	set mult=$bin4_mult
	set ros_mult=0.5
    breaksw
    default:
	set bar_object=$medbar_object
	set mult=$bin2_mult
	set ros_mult=1.0
    breaksw
endsw
# Apply multipliers
set sci_mult=`echo "$sci_mult * $mult" | bc`
set geom_mult=`echo "$geom_mult * $mult" | bc`
set arc_mult=`echo "$arc_mult * $mult" | bc`
set geom_readout=`echo "$geom_readout * $ros_mult" | bc`
set sci_readout=`echo "$geom_readout * $ros_mult" | bc`



# Binning in Y.
set mult=$bin2_mult
set ros_mult=1.0
switch ( $bbiny )
    case 1:
	set mult=$bin1_mult
	set ros_mult=2.0
    breaksw
    case 2:
	set mult=$bin2_mult
	set ros_mult=1.0
    breaksw
    case 4:
	set mult=$bin4_mult
	set ros_mult=0.5
    breaksw
    default:
	set mult=$bin2_mult
	set ros_mult=1.0
    breaksw
endsw
# Apply multipliers
set sci_mult=`echo "$sci_mult * $mult" | bc`
set geom_mult=`echo "$geom_mult * $mult" | bc`
set arc_mult=`echo "$arc_mult * $mult" | bc`
set geom_readout=`echo "$geom_readout * $ros_mult" | bc`
set sci_readout=`echo "$geom_readout * $ros_mult" | bc`


# Detector gain
set mult=$gain10_mult
switch ( $bgain ) 
    case 1:
    case 1.0:
    case 1.00:
	set mult=$gain1_mult
    breaksw
    case 2:
    case 2.0:
    case 2.00:
	set mult=$gain2_mult
    breaksw
    case 5:
    case 5.0:
    case 5.00:
	set mult=$gain5_mult
    breaksw
    case 10:
    case 10.0:
    case 10.00:
	set mult=$gain10_mult
    breaksw
    default:
	set mult=$gain10_mult
    breaksw
endsw
# Apply multipliers
set sci_mult=`echo "$sci_mult * $mult" | bc`

# how many amplifiers are we using?
# 0: 4
# 1-8: 1
# 9,10: 2
set ros_mult=1.0
switch ( $bamp )
    case 0:
	set ros_mult=1.0
    breaksw
    case 1:
    case 2:
    case 3:
    case 4:
    case 5:
    case 6: 
    case 7:
    case 8:
	set ros_mult=4.0
    breaksw
    case 9:
    case 10:
	set ros_mult=2.0
    breaksw
    default:
	set ros_mult=1.0
endsw
# geom readout is already taking this into account.
set sci_readout=`echo "$sci_readout * $ros_mult" | bc`


# apply CCD speed multiplier to sci_readout
switch ( $bspeed ) 
    case 0:
	# fast
	set ros_mult=1.0
    breaksw
    case 1:
	# slow
	set ros_mult=3.0
    breaksw
    default:
	set ros_mult=1.0
    breaksw
endsw
set sci_readout=`echo "$sci_readout * $ros_mult" | bc`

# OK. Load in the exposure times
echo $bgrating $cwaveb
echo "yo"
set exptimes=( `kcas_find_exptimes.py $bgrating $cwaveb | grep "EXPTIMES"` ) 

# set exptimes = (EXPTIMES 6 5 4 3)
# echo $#exptimes
echo "Exposure times are: $exptimes"

if ( $#exptimes != 7 ) then
    echo "Error: Exptimes can't be computed." >> /dev/stderr
    exit -2
else 
    echo $exptimes[1] $exptimes[2]
    set cont_base_exptime = $exptimes[2]
    set fear_base_exptime = $exptimes[3]
    set thar_base_exptime = $exptimes[4]
    set dome_base_exptime = $exptimes[5]
endif


printf "Writing calfile: $calfile\n"
# Write out the lines
printf "state = $statefile\n" >! $calfile
set dt=`date`
printf "#\n# SCI_MULT=%-5.1f\n" $sci_mult >> $calfile
printf "# GEOM_MULT=%-5.1f\n#\n" $geom_mult >> $calfile
printf "# Generated:  $dt \n" >> $calfile
printf "# %-10s" "Lamp" >> $calfile
printf "%-12s" "CalObj." >> $calfile
printf "%-10s" "Time(s)" >> $calfile
printf "%-10s" "Aft" >> $calfile
printf "%-10s" "Night" >> $calfile
printf "%-10s\n" "Geom?" >> $calfile


# Cont Bars line
if ($cont_bars_geom == yes) then
    set cont_bars_exptime = `echo "$cont_base_exptime * $geom_mult" | bc -l`
    echo $cont_base_exptime
else 
    set cont_bars_exptime = `echo "$cont_base_exptime * $sci_mult" | bc -l`
endif
kcas_line_to_file $calfile CONT $bar_object\
	$cont_bars_exptime $cont_bars_aft\
	$cont_bars_night $cont_bars_geom

echo $arc

# FeAr Line
if ( $arc == FEAR ) then
    set fear_arc_geom=yes
    set fear_arc_aft=1
    set fear_arc_night=1
else
    # temporary change to 1
    set fear_arc_aft=1
    set fear_arc_night=0
    set fear_arc_geom=yes
endif

if ( $fear_arc_geom == yes ) then
    set fear_arc_exptime=`echo "$fear_base_exptime * $arc_mult" | bc `
else 
    set fear_arc_exptime=`echo "$fear_base_exptime * $sci_mult * $arc_mult / $geom_mult" | bc `
endif
kcas_line_to_file $calfile FEAR $fear_arc_object\
	$fear_arc_exptime  $fear_arc_aft\
	$fear_arc_night $fear_arc_geom

# ThAr Line
if ( $arc == THAR ) then
    set thar_arc_geom=yes
    set thar_arc_aft=1
    set thar_arc_night=1
else
    # temporary change to 1
    set thar_arc_aft=1
    set thar_arc_night=0
    set thar_arc_geom=yes
endif
if ( $thar_arc_geom == yes ) then
    set thar_arc_exptime=`echo "$thar_base_exptime * $arc_mult" | bc `
else 
    set thar_arc_exptime=`echo "$thar_base_exptime * $sci_mult * $arc_mult / $geom_mult " | bc `
endif
kcas_line_to_file $calfile THAR $thar_arc_object\
	$thar_arc_exptime $thar_arc_aft\
	$thar_arc_night $thar_arc_geom

# Continuum flat logic is a little more complex if we are in direct mode. 
# There are two lines. First is for pixel flats. We may want to take
# this one with the articulation stage moving, but for now, NOPE.  
# Cont Flat line
set cont_flat_exptime = `echo "$cont_base_exptime * $sci_mult" | bc `

kcas_line_to_file $calfile CONT $cont_flat_object\
	$cont_flat_exptime $cont_flat_aft\
	$cont_flat_night $cont_flat_geom

if ( $arc == NONE ) then
    set cont_flat_exptime = `echo "$cont_base_exptime * $geom_mult" | bc`
    set cont_flat_night = 1
    set cont_flat_geom = yes
    set cont_flat_aft = 1

    kcas_line_to_file $calfile CONT $cont_flat_object\
	    $cont_flat_exptime $cont_flat_aft\
	    $cont_flat_night $cont_flat_geom

endif


# Dome line
set dome_flat_exptime = `echo "$dome_base_exptime * $sci_mult" | bc `
echo "Here. $dome_flat_exptime"
if ( `echo " $dome_flat_exptime > $dome_flat_maxtime " | bc -l` ) then
    set dome_flat_exptime=$dome_flat_maxtime
endif
echo "Here, too."
kcas_line_to_file $calfile "DOME" $dome_flat_object $dome_flat_exptime\
	$dome_flat_aft\
	$dome_flat_night $dome_flat_geom

# Bias lines
kcas_line_to_file $calfile "BIAS" $dome_flat_object $bias_exptime\
	$bias_aft\
	$bias_night $bias_geom

kcas_line_to_file $calfile "BIAS" $dome_flat_object $bias_exptime\
	$bias_night\
	$bias_night $bias_geom2

# Dark lines

kcas_line_to_file $calfile "DARK" $dome_flat_object $dark_exptime\
	$dark_aft\
	$dark_night $dark_geom

kcas_line_to_file $calfile "DARK" $dome_flat_object $dark_exptime\
	$dark_aft\
	$dark_night $dark_geom

echo "Done."

# echo $sci_mult $bgain

exit 0 


