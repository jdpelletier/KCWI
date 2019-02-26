#!/bin/csh -f

#NOTE: this is unfinished

#arg1 is server name
#arg2 is debug level

if ($#argv < 2) then
    echo USAGE: kcwiRunServer.csh server debug_level
    exit
endif


source ~/.cshrc


set server=$1
set debug=$2

echo Running server $1 with debug level $2


