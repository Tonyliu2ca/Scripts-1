#!/bin/bash

########## INTRODUCTION #############
#
# improvements from https://aporlebeke.wordpress.com/2019/01/04/auto-clearing-failed-mdm-commands-for-macos-in-jamf-pro/
#
# Kudos to Neil Martin
#
# this is designed to for a policy to flush mdm failed commands once a week
#
# the decryption used is from here https://github.com/jamf/Encrypted-Script-Parameters
#
#####################################

# $4 USERNAME TO DECRYPT
# $5 PASSWORD TO DECRYPT
# $6 JSS URL


## CLEARING VARIABLES
USERNAME=""
PASSWORD=""
SERIAL=""

## SETTING VARIABLES


SERIAL=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F'"' '/IOPlatformSerialNumber/{print $4}')
CURRENT_JAMF_URL=$6  

TEMPFILE1="/private/tmp/CheckJSSConnection1.txt"

####### FUNCTIONS

function getjsscomputerid () {
	computerID=$(/usr/bin/curl -u "$USERNAME":"$PASSWORD" "$CURRENT_JAMF_URL"/JSSResource/computers/serialnumber/"$SERIAL" -H "accept: text/xml" | /usr/bin/xpath "/computer[1]/general/id/text()")
}


function getfailedmdmcommands () {
	xmlresult=$(/usr/bin/curl -sfku "$USERNAME":"$PASSWORD" "$CURRENT_JAMF_URL"/JSSResource/computerhistory/serialnumber/"$SERIAL"/subset/Commands -X GET -H "accept: application/xml" | /usr/bin/xpath "/computer_history/commands/failed")
}


function clearfailedmdmcommands () {
	/usr/bin/curl -sfku "$USERNAME":"$PASSWORD" "$CURRENT_JAMF_URL"/JSSResource/commandflush/computers/id/"$computerID"/status/Failed -X DELETE
}


# Carryout Check  JSSConnection
	function checkCurrJamf() {
	curl -L "$CURRENT_JAMF_URL"/healthCheck.html -o "$TEMPFILE1" > /dev/null 2>&1
	READ_TEMPFILE1=$(cat $TEMPFILE1)
}

function DecryptString() {
    echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}

# Encrypted Username & password we will use for the api
USERNAME=$(DecryptString $4 'XXXXXXX' 'XXXX') 
PASSWORD=$(DecryptString $5 'XXXXXX' 'XXXXX')

####### SCRIPT


# check to see if we can access the db and it is up
checkCurrJamf

# If anything other than [] then there is a problem
	if [[ $READ_TEMPFILE1 != "[]" ]]; then
			echo "There is a problem connecting to the DBs"
		exit 1

# if the DB is ok then it will read []
	elif [[ $READ_TEMPFILE1="[]" ]]; then
			echo "Connection to the DB is OK"
            rm "$TEMPFILE1"
			

getfailedmdmcommands

# An empty failed XML node will look like this: <failed />
parseresult=`/bin/echo "$xmlresult" | /usr/bin/grep "<failed />"`
exitcode=$(/bin/echo $?)

# Clear failed MDM commands if they exist
	if [ "$exitcode" != 0 ]; then
	
		getjsscomputerid
	
		/bin/echo "Removing failed MDM commands ..."
	
		clearfailedmdmcommands
	
		result="Removed Failed MDM Commands"
		else
		result="No Failed MDM Commands Exist"
	fi

/bin/echo "$result"


fi

exit 0
