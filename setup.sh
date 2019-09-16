#!/bin/bash

#####################################################################################
#                        ADS-B EXCHANGE SETUP SCRIPT FORKED                         #
#####################################################################################
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2018 ADSBx                                    #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


## CHECK IF SCRIPT WAS RAN USING SUDO

if [ "$(id -u)" != "0" ]; then
    echo -e "\033[33m"
    echo "This script must be ran using sudo or as root."
    echo -e "\033[37m"
    exit 1
fi

## CHECK FOR PACKAGES NEEDED BY THIS SCRIPT

echo -e "\033[33m"
echo "Checking for packages needed to run this script..."

if [ $(dpkg-query -W -f='${STATUS}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "Installing the curl package..."
    echo -e "\033[37m"
    apt-get update
    apt-get install -y curl
fi
echo -e "\033[37m"

## ASSIGN VARIABLES

LOGDIRECTORY="$PWD/logs"
MLATCLIENTVERSION="0.2.6"
MLATCLIENTTAG="v0.2.6"

## WHIPTAIL DIALOGS

BACKTITLETEXT="ADS-B Exchange Setup Script"

whiptail --backtitle "$BACKTITLETEXT" --title "$BACKTITLETEXT" --yesno "Thanks for choosing to share your data with ADS-B Exchange!\n\nADSBexchange.com is a co-op of ADS-B/Mode S/MLAT feeders from around the world. This script will configure your current your ADS-B receiver to share your feeders data with ADS-B Exchange.\n\nWould you like to continue setup?" 13 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    exit 0
fi

ADSBEXCHANGEUSERNAME=$(whiptail --backtitle "$BACKTITLETEXT" --title "Feeder MLAT Name" --nocancel --inputbox "\nPlease enter a unique name for the feeder to be shown on MLAT matrix.\n\nIf you have more than one receiver, this name should be unique.\nText and Numbers only - everything else will be removed.\nExample: \"feedername-01\", \"feedername-02\", etc." 12 78 3>&1 1>&2 2>&3)

#((-90 <= RECEIVERLATITUDE <= 90))
LAT_OK=0
until [ $LAT_OK -eq 1 ]; do
    RECEIVERLATITUDE=$(whiptail --backtitle "$BACKTITLETEXT" --title "Receiver Latitude ${RECEIVERLATITUDE}" --nocancel --inputbox "\nEnter your receivers latitude in decimal degrees." 9 78 3>&1 1>&2 2>&3)
    LAT_OK=`awk -v LAT="$RECEIVERLATITUDE" 'BEGIN {printf (LAT<90 && LAT>-90 ? "1" : "0")}'`
done

#((-180<= RECEIVERLONGITUDE <= 180))
LON_OK=0
until [ $LON_OK -eq 1 ]; do
    RECEIVERLONGITUDE=$(whiptail --backtitle "$BACKTITLETEXT" --title "Receiver Longitude ${RECEIVERLONGITUDE}" --nocancel --inputbox "\nEnter your receivers longitude in decimal degrees." 9 78 3>&1 1>&2 2>&3)
    LON_OK=`awk -v LAT="$RECEIVERLONGITUDE" 'BEGIN {printf (LAT<180 && LAT>-180 ? "1" : "0")}'`
done

RECEIVERALTITUDE=$(whiptail --backtitle "$BACKTITLETEXT" --title "Receiver Altitude" --nocancel --inputbox "\nEnter your recivers altitude in meters > 0m (optional suffix m for meters or ft for feet)." 9 78 3>&1 1>&2 2>&3)

RECEIVERPORT=$(whiptail --backtitle "$BACKTITLETEXT" --title "Receiver Feed Port" --nocancel --inputbox "\nChange only if you were assigned a custom feed port.\nFor most all users it is required this port remain set to port 30005." 10 78 "30005" 3>&1 1>&2 2>&3)


whiptail --backtitle "$BACKTITLETEXT" --title "$BACKTITLETEXT" --yesno "We are now ready to begin setting up your receiver to feed ADS-B Exchange.\n\nDo you wish to proceed?" 9 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    exit 0
fi

## BEGIN SETUP

{

    # Make a log directory if it does not already exist.
    if [ ! -d "$LOGDIRECTORY" ]; then
        mkdir $LOGDIRECTORY
    fi
    LOGFILE="$LOGDIRECTORY/image_setup-$(date +%F_%R)"
    touch $LOGFILE

    echo 4
    sleep 0.25

    # BUILD AND CONFIGURE THE MLAT-CLIENT PACKAGE

    echo "INSTALLING PREREQUISITE PACKAGES" >> $LOGFILE
    echo "--------------------------------------" >> $LOGFILE
    echo "" >> $LOGFILE


    # Check that the prerequisite packages needed to build and install mlat-client are installed.
    if [ $(dpkg-query -W -f='${STATUS}' build-essential 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        apt-get install -y build-essential >> $LOGFILE  2>&1
    fi

    echo 10
    sleep 0.25

    if [ $(dpkg-query -W -f='${STATUS}' debhelper 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        apt-get install -y debhelper >> $LOGFILE  2>&1
    fi

    echo 16
    sleep 0.25

    if [ $(dpkg-query -W -f='${STATUS}' python 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        apt-get install -y python >> $LOGFILE  2>&1
    fi
    
    if [ $(dpkg-query -W -f='${STATUS}' python3-dev 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        apt-get install -y python3-dev >> $LOGFILE  2>&1
    fi

    echo 22
    sleep 0.25

    if [ $(dpkg-query -W -f='${STATUS}' socat 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        apt-get install -y socat >> $LOGFILE  2>&1
    fi

    echo 28
    sleep 0.25

    echo "" >> $LOGFILE
    echo " BUILD AND INSTALL MLAT-CLIENT" >> $LOGFILE
    echo "-----------------------------------" >> $LOGFILE
    echo "" >> $LOGFILE

    # Check if the mlat-client git repository already exists.
    if [ -d mlat-client ] && [ -d mlat-client/.git ]; then
        # If the mlat-client repository exists update the source code contained within it.
        cd mlat-client >> $LOGFILE
        git pull >> $LOGFILE 2>&1
        git checkout tags/$MLATCLIENTTAG >> $LOGFILE 2>&1
    else
        # Download a copy of the mlat-client repository since the repository does not exist locally.
        git clone https://github.com/adsbxchange/mlat-client.git >> $LOGFILE 2>&1
        cd mlat-client >> $LOGFILE 2>&1
        git checkout tags/$MLATCLIENTTAG >> $LOGFILE 2>&1
    fi

    echo 34
    sleep 0.25

    # Build and install the mlat-client package.
    dpkg-buildpackage -b -uc >> $LOGFILE 2>&1
    cd .. >> $LOGFILE
    dpkg -i mlat-client_${MLATCLIENTVERSION}*.deb >> $LOGFILE 2>&1

    echo 40
    sleep 0.25

    echo "" >> $LOGFILE
    echo " CREATE AND CONFIGURE MLAT-CLIENT STARTUP SCRIPTS" >> $LOGFILE
    echo "------------------------------------------------------" >> $LOGFILE
    echo "" >> $LOGFILE
    
    NOSPACENAME="$(echo -e "${ADSBEXCHANGEUSERNAME}" | tr -dc '[a-zA-Z0-9]_\-')"

    echo 46
    sleep 0.25

    # Remove old method of starting the feed script if present from rc.local
    sed -i -e '/adsbexchange-mlat_maint.sh/d' /etc/rc.local >> $LOGFILE 2>&1

    echo 58
    sleep 0.25


    # Kill the old adsbexchange-mlat_maint.sh script in case it's still running from a previous install
    PIDS=`ps -efww | grep -w "adsbexchange-mlat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [ ! -z "$PIDS" ]; then
        kill $PIDS >> $LOGFILE 2>&1
        kill -9 $PIDS >> $LOGFILE 2>&1
    fi

    echo 64
    sleep 0.25

    # copy adsbexchange-mlat service file
    cp $PWD/scripts/adsbexchange-mlat.service /lib/systemd/system >> $LOGFILE 2>&1

    # reload systemd daemons
    systemctl daemon-reload

    # Enable adsbexchange-mlat service
    systemctl enable adsbexchange-mlat >> $LOGFILE 2>&1

    # Start or restart adsbexchange-mlat service
    systemctl restart adsbexchange-mlat >> $LOGFILE 2>&1


    echo 70
    sleep 0.25

    # SETUP NETCAT TO SEND DUMP1090 DATA TO ADS-B EXCHANGE

    echo "" >> $LOGFILE
    echo " CREATE AND CONFIGURE NETCAT STARTUP SCRIPTS" >> $LOGFILE
    echo "-------------------------------------------------" >> $LOGFILE
    echo "" >> $LOGFILE

    mkdir -p /usr/local/bin
    cp $PWD/scripts/adsbexchange-feed.sh /usr/local/bin
    cp $PWD/scripts/adsbexchange-feed.service /lib/systemd/system

    tee /etc/default/adsbexchange > /dev/null <<EOF
    RECEIVERPORT="$RECEIVERPORT"
    USER="$NOSPACENAME"
    RECEIVERLATITUDE="$RECEIVERLATITUDE"
    RECEIVERLONGITUDE="$RECEIVERLONGITUDE"
    RECEIVERALTITUDE="$RECEIVERALTITUDE"
    RESULTS="beast,connect,localhost:30104"
    MLATSERVER="feed.adsbexchange.com:31090"
	INPUT="127.0.0.1:30005"
EOF

    echo 76
    sleep 0.25

    # Set permissions on the file adsbexchange-feed.sh.
    chmod +x /usr/local/bin/adsbexchange-feed.sh >> $LOGFILE

    echo 82
    sleep 0.25

    # Remove old method of starting the feed script if present from rc.local
    sed -i -e '/adsbexchange-netcat_maint.sh/d' /etc/rc.local >> $LOGFILE 2>&1

    # Enable adsbexchange-feed service
    systemctl enable adsbexchange-feed  >> $LOGFILE 2>&1

    echo 88
    sleep 0.25

    # Kill the old adsbexchange-netcat_maint.sh script in case it's still running from a previous install
    PIDS=`ps -efww | grep -w "adsbexchange-netcat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [ ! -z "$PIDS" ]; then
        kill $PIDS >> $LOGFILE 2>&1
        kill -9 $PIDS >> $LOGFILE 2>&1
    fi

    echo 94
    sleep 0.25

    # reload systemd daemons
    systemctl daemon-reload

    # Start or restart adsbexchange-feed service
    systemctl restart adsbexchange-feed  >> $LOGFILE 2>&1


    echo 100
    sleep 0.25

} | whiptail --backtitle "$BACKTITLETEXT" --title "Setting Up ADS-B Exchange Feed"  --gauge "\nSetting up your receiver to feed ADS-B Exchange.\nThe setup process may take awhile to complete..." 8 60 0

## SETUP COMPLETE

# Display the thank you message box.
whiptail --title "ADS-B Exchange Setup Script" --msgbox "\nSetup is now complete.\n\nYour feeder should now be feeding data to ADS-B Exchange.\nThanks again for choosing to share your data with ADS-B Exchange!\n\nIf you have questions or encountered any issues while using this script feel free to post them to one of the following places.\n\nhttp://www.adsbexchange.com/forums/topic/ads-b-exchange-setup-script/" 17 73

exit 0
