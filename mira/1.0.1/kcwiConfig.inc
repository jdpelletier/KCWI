#-----------------------------------------------------------------------
# Help file included by Mias.sh
# This file should not be executed by itself.
#
# Author: Shui Hung Kwok
# Created: Nov 18 2002

#- Set DEBUG and VERBOSE accordingly.

#- Set INSTRUMENT to instrument name, no space allowed, ie. lris.
#- Set COMIRA to the right version, ie. /home/skwok/bin/comira_solaris2.7.
#- Check IMAGEDIR. Default is 'nightpath'.
#- Check LOGFILE. Default is where IMAGEDIR is.
#- Set MIRAHOST to host where Mira is running.
#- Set INSTRUMENTHOST to host where instrument server is running.
#- check HOSTNAME. This must be the current host.

# define key variables...
DEBUG="0"	# set to "1" for test-only mode
VERBOSE="1"	# set to "1" to receive additional diagnostic output
SILENT=""	# set this to "silent" to suppress output from MODIFY commands

# version info...
VERSION='1'
REVDATE='2017-Mar-08'
AUTHORS='S. Kwok/M. Kassis/G. Wirth/L.Rizzi' 

# Global Environment
# dcs and acs for testing. dcs1 and acs1 for real
#KROOT=/kroot ; export KROOT
DCS="dcs"
ACS="acs"
INSTRUMENT="kcwi"
SERIESNR="0"
SERIESFILE="/s/nightly2/log/MiasNumber"
LOCKFILE="/tmp/${INSTRUMENT}Mias.locked"
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:$KROOT/rel/default/lib
export LD_LIBRARY_PATH
COMIRA="comira"
#COMIRA="send_mira"
# Need to update when nightpath is updated.
IMAGEDIR="`outdir`"
IMAGEDIR2=`nightpath` # temp location where we can modify images
LOGFILE="$IMAGEDIR2${INSTRUMENT}Mira.log"	# name of the Mira logfile
MIAS_PID=$$
STATE_FILE="${RELDIR}/bin/kcwiMira.state"
STATE_FILE_PRE="/tmp/kcwiMira_config_pre"
#STATE_FILE_POST="/tmp/kcwiMira_config_post"

# If MIRAHOST and MIRAPORT are not set, then use the defaults.
HOSTNAME="${HOSTNAME=`hostname`}"
MIRAHOST="${MIRAHOST=k2server}"
MIRAPORT="${MIRAPORT=50010}"
INSTRUMENTHOST="kcwiserver"
