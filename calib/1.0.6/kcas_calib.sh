#!/bin/tcsh
#
# 160425
# Matuszewski -- matmat@caltech.edu
#
# The object of this script is to go through a flatfile
# to read in the various calibration settings and take the calibration images.
# 
# There are several stages to this.

# process the parameters
# options:
# -f,--file file to load cal script from
# -n,--night is this a night-time calibration? (auto-parks)
# -p,--park do we park CAL at the end of this one?



set temp=(`getopt -s tcsh -o f:np --long file:,night,park -- $argv:q`)
if ( $? != 0 ) then
    echo "Invalid arguments." > /dev/stderr
    echo $temp
    exit -1
endif 

eval set argv=\($temp:q\)

# lamp ids (bias isn't implemented yet)
set thar_lampid=1
set fear_lampid=0
set cont_lampid=3
set dome_lampid=-1
set bias_lampid=-2
set dark_lampid=-3


set filename=""
set caltype="day"
set park=0

set calcolumns=6

while (1)
    switch($1:q)
	case -f:
	case --file:
	    set filename=$2:q; shift; shift
	breaksw
	case -n:
	case --night:
	    set caltype="night"; shift
	    set park=1
	breaksw
	case -p:
	case --park:
	    set park=1
	breaksw
	case --:
	    shift
	    break
	breaksw
	default:
	    echo "Error: Invalid parameters ($temp)"
	    exit -1
	breaksw
    endsw
#end while
end



# are the arc lamps used? 
set thar_used=0
set fear_used=0
set dome_used=0

# what are the mode settings used for geometry 


set det_keys=( ampmode ccdmode gainmul )
set det_geom_vals=(  0 1 10 )
set det_init_vals= ($det_geom_vals)
set detsleep=1

#############
# This is where the file would get read in. 
# or perhaps keywords. 
# For now, it is just a set of variables that get set. 
#############
# which lamps are being used in individual sequence steps

if ( ! -r "$filename" ) then 
    echo "Error: Configuration file does not exist." >> /dev/stderr
    exit -11
endif

@ ctr=1
foreach linev ("`cat $filename`")
    set line=`echo "$linev" | egrep -v "^[[:space:]]*#"`
    set stat=$status
    if ( ! $stat ) then
	set fields = `echo "$line" | awk --field-separator=" " "{print NF}"`
	set fieldseq = `echo "$line" | awk --field-separator="=" "{print NF}"`
	if ( ( $fieldseq == 2 ) && ( $line[1] == "state" ) ) then
	    set statusfile=`echo "$line" | cut -d "=" -f2`
	    echo "Status file = $statusfile"
	endif
	if ( $fields == $calcolumns ) then
	    if ( $ctr == 1 ) then
		set seq_lamp=$line[1]
		set seq_objects=$line[2]
		set seq_expt=$line[3]
		set seq_aft=$line[4]
		set seq_night=$line[5]
		set seq_geom=$line[6]
	    else 
		set seq_lamp=( $seq_lamp $line[1] )
		set seq_objects = ( $seq_objects $line[2] )
		set seq_expt=( $seq_expt $line[3] )
		set seq_aft=( $seq_aft $line[4] )
		set seq_night=( $seq_night $line[5] )
		set seq_geom=( $seq_geom $line[6] )
	    endif 
	@ ctr++
	endif
    endif
end



set nseq = $#seq_lamp


if ( $nseq != $#seq_objects || \
     $nseq != $#seq_expt || \
     $nseq != $#seq_geom || \
     $nseq != $#seq_aft || \
     $nseq != $#seq_night ) then
     echo "Error: Incorrect file format." >> /dev/stderr
     exit -12
endif

# make sure the necessary servers are running (CAL + Detector + KBMS)
set detserver=kbds
set calserver=kcas
set bmsserver=kbms
set oktimeout=5
set servers= ( $detserver $calserver )
foreach server ( $servers )
    if ( ! `kcwiCheckServer $server` ) then 
	echo "Error: $server not running." >> /dev/stderr
	exit -1
    endif 
end

# save the objectname
set oldobject=`show -t -s kbds object`


@ ctr=1
foreach key ( $det_keys ) 
    set ret=`show -t -s $detserver $key`
    if ( $status ) then
	echo "Error: Can't get KBDS $key" >> /dev/stderr
    endif
    set det_init_vals[$ctr] = $ret
@ ctr++
end

set det_init_exptime=`show -t -s $detserver ttime`
if ( $status ) then
    echo "Error: Can't get KBDS TTIME" >> /dev/stderr
    exit -2
endif


# Make sure relevant calibration axes are homed.
# ignoring the two rotators.
foreach calaxis (calx caly calm)
    set ret=`show -t -s $calserver ${calaxis}homed`
    if ( $status ) then 
	echo "Error: Problem getting KCAS homing information from $calaxis" >> /dev/stderr
	exit -3
    endif 
    if ( ! $ret ) then
        echo "Error: KCAS $calaxis is not homed." >> /dev/stderr
	exit -3
    endif 
end
    
#############


set seq_count=$nseq

# Loop through the parameters. 
set seq_lampid=($seq_lamp)
@ ctr = 1
foreach lamp ( $seq_lampid ) 
    # convert to lowercase
    set lmp=`echo $lamp | tr "A-Z" "a-z"`
    switch ( $lmp )
	case thar:
	case tha:
	case th:
	case t:
	case 1:
	    set seq_lampid[$ctr] = $thar_lampid
	breaksw
	case fear:
	case fea:
	case fe:
	case f:
	case 0:
	    set seq_lampid[$ctr]=$fear_lampid
	breaksw
	case continuum:
	case cont:
	case 3:
	    set seq_lampid[$ctr]=$cont_lampid
	breaksw
	case dome:
	case dom:
	case d:
	case -1: 
	    set seq_lampid[$ctr]=$dome_lampid
	breaksw
	case bias:
	case bs:
	case -2:
	    set seq_lampid[$ctr]=$bias_lampid
	breaksw
	case dark:
	case dar:
	case dk:
	case ${dark_lampid}:
	    set seq_lampid[$ctr]=$dark_lampid
	breaksw
	default:
	    echo "Error: Invalid lamp ${lamp}."  >> /dev/stderr
	    exit -11
	breaksw
    endsw
@ ctr++
end

@ ctr=1
foreach object ( $seq_objects )
    # convert object to lowercase
    set obj=`echo $object | tr "A-Z" "a-z"`
    # Switch over possible calibration objects
    switch ( $obj )
	case dark:
	case 0:
	breaksw
	case pin300:
	case 1:
	breaksw
	case medbarsa:
	case medbars:
	case 2:
	breaksw
	case medbarsb:
	case 3:
	breaksw
	case finbars:
	case 4:
	breaksw
	case diaglin:
	case 5:
	breaksw
	case flata:
	case flat:
	case 6:
	breaksw
	case flatb:
	case 7:
	breaksw
	case lrgbarsa:
	case lrgbars:
	case 8:
	breaksw
	case lrgbarsb:
	case lrgbars:
	case 9:
	breaksw
	case pin500:
	case 10:
	breaksw
	case tpat:
	case 11:
	breaksw
	case horlin:
	case 12:
	breaksw
	case mira:
	case 13:
	breaksw
	default:
	    echo "Error: Unknown position in row ${ctr}: ${object}."
	    exit -9
	breaksw
    endsw
@ ctr++
end

@ ctr=1
foreach geometry ( $seq_geom ) 
    # convert aft_flag to lowercase 
    set geom=`echo $geometry | tr "A-Z" "a-z"`
    # switch over possible values
    switch ( $geom ) 
      case yes:
      case y:
      case 1:
	set seq_geom[$ctr]=1
      breaksw
      case no:
      case n:
      case 0:
	set seq_geom[$ctr]=0
      breaksw
      default:
	echo "Error: Invalid geometry flag for row ${ctr}: ${geometry}" >> /dev/stderr
	exit -5
      breaksw
    endsw
@ ctr++
end



# Check which lamps are used (continuum is always used)
@ tmpctr=1

    set thar_used=0
    set fear_used=0
    set dome_used=0
foreach lampid ( $seq_lampid )
    if ( $lampid == $thar_lampid ) then
	if ( ( ( $caltype == "day" ) && ( $seq_aft[$tmpctr] > 0 ) ) || ( ( $caltype == "night" ) && ( $seq_night[$tmpctr] > 0 ) ) ) then
	     set thar_used=1
	endif
    endif

    if ( $lampid == $fear_lampid ) then
	if ( ( ( $caltype == "day" ) && ( $seq_aft[$tmpctr] != "0" ) ) || ( ( $caltype == "night") && ( $seq_night[$tmpctr] != "0" ) ) ) then
	     set fear_used=1
	endif
    endif

    if ( $lampid == $dome_lampid ) then
	if ( ( $caltype == "day" ) && ( $seq_aft[$tmpctr] > 0 ) ) then
	    set dome_used=1
	endif
    endif
    @ tmpctr++
end

# We need a check to make sure that we are actually in the right place
# for domes
set instrument=`show -t -s dcs instrume`
set instrument=`tolower $instrument`
if ( $instrument != kcwi ) then 
    echo "The instrument is not correct, no domes."
    set dome_used=0
endif

set focalstr=`show -t -s dcs focalstr`
set focalstr=`tolower $focalstr`
if ( $focalstr != rnas ) then
    echo "The focal station is not RNAS. no domes."
    set dome_used=0
endif

set elevation=`show -t -s dcs el`
set requel=45.0
set reqtol=0.1

set eltoobig=` echo " $elevation - $requel > $reqtol " | bc -l`
set eltoosml=` echo " $elevation + $requel < $reqtol " | bc -l`

if ( ( $eltoobig == 1) || ( $eltoosml == 1) ) then 
    echo "Telescope not at domephlat position. no domes."
    set dome_used=0
endif

echo "Caltype = $caltype"
echo "thar = $thar_used"
echo "fear = $fear_used"
echo "dome = $dome_used"


#echo "Partially done!"
#exit 0


# turn on the ThAr lamp and close its shutter
if ( $thar_used ) then 
    kcas_lamp thar on
    if ( $status ) then
	echo "Error: Could not turn on ThAr."  >> /dev/stderr
	exit -4 
    endif
    sleep 2.0
    kcas_shutter thar close
    if ( $status ) then
	echo "Error: Could not close ThAr shutter." >> /dev/stderr
	exit -4 
    endif
endif

# turn on the FeAr lamp and close its shutter
if (  $fear_used  ) then 
    kcas_lamp fear on
    if ( $status ) then
	echo "Error: Could not turn on FeAr." >> /dev/stderr
	exit -4 
    endif
    sleep 2.0
    kcas_shutter fear close
    if ( $status ) then
	echo "Error: Could not close FeAr shutter." >> /dev/stderr
	exit -4 
    endif
endif

# Close the instrument hatch

kcas_hatch close



## Now that we are about to start moving things,
## trap CTRL-C
onintr intfunc


### Now start to move stages. 
### Loop over the lines of the script, based on the lamps
### This is for internal lamps. Dome flats are handled separately. 
@ ctr=1
foreach lampid ( $seq_lampid )

   if ( $caltype == "day" ) then
      set count=$seq_aft[$ctr]
   else
      set count=$seq_night[$ctr]
   endif

    echo "Count = $count."

   if ( $seq_geom[$ctr] != 0  ) then
      set geom=1
   else 
      set geom=0
   endif
   
    echo "Geom [$ctr] = $geom"
   # only internal lamps here
   if ( ( $lampid != $dome_lampid ) && ( $count > 0 ) ) then
    
    # Toggle the lamps, as needed ( shutters in arc's case )
    switch ( $lampid )
	case ${fear_lampid}:
	    kcas_shutter fear open
	    sleep 0.5
	    kcas_shutter thar close
	    sleep 0.5
	    kcas_lamp cont off
	    modify -s $detserver autoshut=1
	breaksw
	case ${thar_lampid}:
	    kcas_shutter fear close
	    sleep 0.5
	    kcas_shutter thar open
	    sleep 0.5
	    kcas_lamp cont off
	    modify -s $detserver autoshut=1
	breaksw
	case ${cont_lampid}:
	    kcas_shutter fear close
	    sleep 0.5
	    kcas_shutter thar close
	    sleep 0.5
	    kcas_lamp cont on
	    modify -s $detserver autoshut=1
	breaksw
	case ${bias_lampid}:
	case ${dark_lampid}:
	    kcas_shutter fear close
	    sleep 0.5
	    kcas_shutter thar close
	    sleep 0.5
	    kcas_lamp cont off
	    modify -s $detserver autoshut=0
	breaksw
	default:
	    echo "Error: Lamp not recognized ${lampid}." >> /dev/stderr
	    modify -s $detserver autoshut=1
	    exit -10
	breaksw
    endsw

    # move the mirror axis
    kcas_movelin calm mirror
    if ( $status ) then
	echo "Error: Can't move CALM." >> /dev/stderr
	exit -12
    endif
    
    # move cal x,y object
    kcas_movelin calx $seq_objects[$ctr]
    if ( $status ) then
	echo "Error: Can't move CALX." >> /dev/stderr
	exit -12
    endif
    kcas_movelin caly $seq_objects[$ctr]
    if ( $status ) then
	echo "Error: Can't move CALY." >> /dev/stderr
	exit -12
    endif
    
    # set the exposure time
    modify -s $detserver ttime=$seq_expt[$ctr]

    # switch detector settings, based on geom.
    @ detctr=1
    foreach key ( $det_keys )
	if ( $geom != 0 ) then
	    set keyval=$det_geom_vals[$detctr]
	else 
	    set keyval=$det_init_vals[$detctr]
	endif
	    sleep $detsleep
	    modify -s $detserver $key=$keyval
	    if ( $status ) then
		echo "Error: setting KBDS ${key} to '$keyval'." >> /dev/stderr
		exit -12
	    endif
	    sleep $detsleep
	    #waitfor -t $oktimeout -s $detserver $key=$keyval
	    #if ( $status ) then
		    #	echo "Error: timed out KBDS ${key} to '$keyval'." >> /dev/stderr
		    #exit -12
	    #endif

	@ detctr++
    end

    # populate the object
    modify -s $detserver object="$lampid-${seq_objects[$ctr]}-${seq_expt[$ctr]}"
    sleep 0.5
    # okay. at this point we take an image
    goib $count
    
   # not dome
   endif
# Increment counter
@ ctr++
end

# turn off continuum
kcas_lamp cont off
# close arc shutters
sleep 0.5
kcas_shutter thar close
sleep 0.5
kcas_shutter fear close



# return detector to initial configuration
@ detctr=1
foreach key ( $det_keys ) 
    set keyval=$det_init_vals[$detctr]
    sleep $detsleep
    modify -s $detserver $key=$keyval
    if ( $status ) then
	  echo "Error: setting KBDS ${key} to '$keyval'." >> /dev/stderr
	  exit -13
    endif
    sleep $detsleep
    #waitfor -t $oktimeout -s $detserver $key=$keyval
    #if ( $status ) then
	    #echo "Error: timed out KBDS ${key} to '$keyval'." >> /dev/stderr
	    #exit -13
	    #endif
@ detctr++
end

# now the dome flats.
if  ( $dome_used ) then
    @ ctr=1
    foreach lampid ( $seq_lampid )
    if ( $caltype == day ) then
	set count=$seq_aft[$ctr]
    else
	set count=$seq_night[$ctr]
    endif
    # more than one dome? 
    if ( ( $lampid == $dome_lampid ) && ( $count>0 ) ) then
	    # Turn on the dome lamp (is there a warmup time???)

	    set domelampstatus=`show -t -s dcs flspectr`
	    set instrument=`show -t -s dcs instrume`
	    if ( ( $domelampstatus == off ) ) then
		echo "Turning on Dome lamp (FLSPECTR)"
		modify -s dcs flspectr=on
	    endif

	    # Configure the detector for geometry. 
    
	    # Open hatch
	    kcas_hatch open

	    # Move cal mirror out of the way
	    kcas_movelin calm sky
	    
	    # Move cal x,y into place
	    kcas_movelin calx $seq_objects[$ctr]
	    kcas_movelin caly $seq_objects[$ctr]
	    
	    # Set the exposure time
	    modify -s $detserver autoshut=1
	    sleep $detsleep
	    modify -s $detserver ttime=$seq_expt[$ctr]
	    
	    # populate the object
	    modify -s $detserver object="$lampid-${seq_objects[$ctr]}-${seq_expt[$ctr]}"
	    sleep 0.5
	    # Take exposures!
	    goib $count
	

	endif
    # increment counter 
    @ ctr++
    end


kcas_hatch close

# Uncommented 170411
# check status of dome lamp
    set domelampstatus=`show -t -s dcs flspectr`
    set instrument=`show -t -s dcs INSTRUME`
        if ( ( $domelampstatus == 'on' )  ) then
	    echo "Turning off dome lamp."
	    modify -s dcs flspectr=off
        endif
endif

# recover the object name
modify -s $detserver object=$oldobject



# Return exposure time to original
sleep $detsleep
modify -s $detserver ttime=$det_init_exptime
if ($status) then
    echo "Error: Resetting KBDS ttime '$det_init_exptime'" >> /dev/stderr
    exit -15
endif

sleep $detsleep
modify -s $detserver autoshut=1

# At this point we are done taking images, so clean up 
# a little and exit

# Close arc shutters
if ( $fear_used ) then
    kcas_shutter fear close
    sleep 0.5
endif

if ( $thar_used ) then
    kcas_shutter thar close
    sleep 0.5
endif

# Turn off continuum lamp
kcas_lamp cont off


# Park the calibration unit, if asked to.
if ( $park ) then
    kcas_park
endif

# Exit successfully.
exit 0


### FUNCTION TO CAPTURE CTRL+C goes HERE.

intfunc:
    echo "Captured CTRL+C" >> /dev/stderr
    # turn off CTRL+C capture 
    onintr 
    # turn off lamps
    kcas_lamp all off

    # close shutters
    kcas_shutter thar close
    kcas_shutter fear close

    # turn off dome lamp?
    
    # abort current exposure? 
    set ret=`show -t -s $detserver exposeip`
    if ( $status ) then
	echo "Error: Can't determine if exposure in progress. Continuing quit." >> /dev/stderr
    else if ( $ret ) then
	modify -s $detserver abortex=1
	if ( $status ) then
	    echo "Error: Failed to abort exposure." >> /dev/stderr
	endif
    endif

    # see if there is motion happening, if so, abort it.
    set stat=`show -t -s $calserver status`
    if ( $stat == "Moving" ) then
	modify -t -s $calserver abort=1
	if ( $status ) then
	    echo "Error: Could not abort move." >> /dev/stderr
	    exit -2
	endif
    endif
    # wait for the status to be ok
    # waitfor -t $oktimeout -s $calserver status=OK
    gwaitfor -t $oktimeout -s $calserver '$status == "OK"' 
    # move the mirror axis back to sky
    echo "Warning: Aborted. Now moving mirror to SKY." >> /dev/stderr
    kcas_movelin calm sky
    
exit -1
