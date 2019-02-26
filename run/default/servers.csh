#!/bin/csh -f

# Get the required arguments passed in
set function=$1

# Get any other optional arguments passed in
set otherargs = "${argv[2-]}"

# Call the next script
if ($function =~ "start") then
    if ($?KBDS_LOGLVL) then
	set function = debug$KBDS_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kbds $otherargs


if ($function =~ "start") then
    if ($?KROS_LOGLVL) then
	set function = debug$KROS_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kros $otherargs

if ($function =~ "start") then
    if ($?KCAS_LOGLVL) then
	set function = debug$KCAS_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kcas $otherargs

if ($function =~ "start") then
    if ($?KBMS_LOGLVL) then
	set function = debug$KBMS_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kbms $otherargs

if ($function =~ "start") then
    if ($?KBVS_LOGLVL) then
	set function = debug$KBVS_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kbvs $otherargs


if ($function =~ "start") then
    if ($?KBGS_LOGLVL) then
	set function = debug$KBGS_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kbgs $otherargs

if ($function =~ "start") then
    if ($?KP1S_LOGLVL) then
	set function = debug$KP1S_LOGLVL
    else
	set function = $1
    endif
endif
#kcwi $function kp1s $otherargs
kcwi $function kp1s $otherargs

if ($function =~ "start") then
    if ($?KP2S_LOGLVL) then
	set function = debug$KP2S_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kp2s $otherargs

if ($function =~ "start") then
    if ($?KP3S_LOGLVL) then
	set function = debug$KP3S_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kp3s $otherargs

if ($function =~ "start") then
    if ($?KT1S_LOGLVL) then
	set function = debug$KT1S_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kt1s $otherargs

if ($function =~ "start") then
    if ($?KT2S_LOGLVL) then
	set function = debug$KT2S_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kt2s $otherargs

if ($function =~ "start") then
    if ($?KBES_LOGLVL) then
	set function = debug$KBES_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kbes $otherargs

if ($function =~ "start") then
    if ($?KFCS_LOGLVL) then
	set function = debug$KFCS_LOGLVL
    else
	set function = $1
    endif
endif
kcwi $function kfcs $otherargs

# if (($function != "stop") && ($function != "killrpc")) then
#   sleep 15
#     if ($function =~ "start") then
# 	if ($?KCWI_LOGLVL) then
# 	    set function = debug$KCWI_LOGLVL
# 	else
# 	    set function = $1
# 	endif
#     endif
#   kcwi $function kcwi $otherargs
# else
#     if ($function =~ "start") then
# 	if ($?KCWI_LOGLVL) then
# 	    set function = debug$KCWI_LOGLVL
# 	else
# 	    set function = $1
# 	endif
#     endif
#   kcwi $function kcwi $otherargs
# endif
