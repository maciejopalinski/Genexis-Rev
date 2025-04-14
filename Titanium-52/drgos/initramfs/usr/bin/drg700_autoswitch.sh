#!/bin/sh
#
#

timeout="5"
if [ "$1" -ge "1" ] && [ "$1" -le "10" ]; then
    timeout="$1"
fi

msconfig_set ()
{
    #echo "msconfig $1" 2>&1
    msconfig $1
}

lstate="sDown"
lspeed="1000"
lsFSM="NOLINK" #NOLINK, 100MOK, FINAL
DONE="no"

#set default values, assume link is 1000 and down
msconfig_set "FX state on"
msconfig_set "CU state off"
# Use "auto" for FX port as this ensures that auto-negotiation bit is
# set in control register (0.12). This is required for 1000base-X operation
# on media converter
msconfig_set "FX speed auto full"
msconfig_set "CU autocap 1000 full"
msconfig_set "CU speed auto full"
msconfig_set "FX reset"


#enter forever loop, assume link is up
while [ $DONE = "no" ]; do
    #echo "sleep $timeout seconds in state $lstate"
    sleep $timeout
    fiberlink=`msconfig FX status | grep link | cut -d':' -f2`
    #echo "Fiber link is $fiberlink"

    if [ "$lstate" = "sDown" ]; then
        if [ "$lsFSM" = "NOLINK" ]; then
            if [ "$fiberlink" = "up" ]; then
                if [ $lspeed = "100" ]; then
                    lspeed="1000"
                    fspeed="auto"
                    lsFSM="100MOK"
                    msconfig_set "FX speed $fspeed full"
                    msconfig_set "FX state off"
                    msconfig_set "FX state on"
                else
                    msconfig_set "CU autocap $lspeed full"
                    msconfig_set "CU state on"
                    lstate="sUp"
                    lsFSM="FINAL"
                fi
            else
                if [ $lspeed = "100" ]; then
                    lspeed="1000"
                    fspeed="auto"
                    lsFSM="NOLINK"
                    msconfig_set "FX speed $fspeed full"
                    msconfig_set "FX state off"
                    msconfig_set "FX state on"
                else
                    lspeed="100"
                    fspeed="100"
                    lsFSM="NOLINK"
                    msconfig_set "FX speed $fspeed full"
                    msconfig_set "FX state off"
                    msconfig_set "FX state on"
                fi
            fi
        elif [ "$lsFSM" = "100MOK" ]; then
            if [ "$fiberlink" = "up" ]; then
                if [ $lspeed = "100" ]; then
                    msconfig_set "CU autocap $lspeed full"
                    msconfig_set "CU state on"
                    lstate="sUp"
                    lsFSM="FINAL"
                else
                    msconfig_set "CU autocap $lspeed full"
                    msconfig_set "CU state on"
                    lstate="sUp"
                    lsFSM="FINAL"
                fi
            else
                if [ $lspeed = "100" ]; then
                    lspeed="1000"
                    fspeed="auto"
                    lsFSM="NOLINK"
                    msconfig_set "FX speed $fspeed full"
                    msconfig_set "FX state off"
                    msconfig_set "FX state on"
                else
                    lspeed="100"
                    fspeed="100"
                    lsFSM="100MOK"
                    msconfig_set "FX speed $fspeed full"
                    msconfig_set "FX state off"
                    msconfig_set "FX state on"
                fi
            fi
        elif [ "$lsFSM" = "FINAL" ]; then
            if [ "$fiberlink" = "up" ]; then
                if [ $lspeed = "100" ]; then
                    lspeed="1000"
                    fspeed="auto"
                    lsFSM="100MOK"
                    msconfig_set "FX speed $fspeed full"
                    msconfig_set "FX state off"
                    msconfig_set "FX state on"
                else
                    msconfig_set "CU autocap $lspeed full"
                    msconfig_set "CU state on"
                    lstate="sUp"
                    lsFSM="FINAL"
                fi
            else
                if [ $lspeed = "100" ]; then
                    lspeed="1000"
                    fspeed="auto"
                    lsFSM="NOLINK"
                    msconfig_set "FX speed $fspeed full"
                    msconfig_set "FX state off"
                    msconfig_set "FX state on"
                else
                    lspeed="100"
                    fspeed="100"
                    lsFSM="NOLINK"
                    msconfig_set "FX speed $fspeed full"
                    msconfig_set "FX state off"
                    msconfig_set "FX state on"
                fi
            fi
        fi
    elif [ "$lstate" = "sUp" ]; then
        if [ "$fiberlink" = "down" ]; then
            lstate="sDown"
            #disable LED
            msconfig_set "CU state off"
        fi
    else
        echo "Unknown state! You should not be here!"
    fi
done
