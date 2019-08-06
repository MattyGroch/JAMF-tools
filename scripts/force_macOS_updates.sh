#!/bin/bash

jssAPIUsername=$4
jssAPIPassword=$5
jssAddress=$6

serialnumber=$(ioreg -l | grep IOPlatformSerialNumber|awk '{gsub(/"/,""); print $4}')
xmlfileread="/tmp/XMLFILEREAD.xml"
xmlfilewrite="/tmp/XMLFILEWRITE.xml"
SNOOZELIMIT=$7
updatePolicy=$8

# Get list of updates
LISTOFUPDATES=`softwareupdate -l | egrep -v "Update Tool|Finding available|found the following" | grep -v '\*'|cut -d , -f 1`

# Pull snoozes from JSS
touch $xmlfileread
cat /dev/null > $xmlfileread
curl -s -k -H "Accept: application/xml" -u ${jssAPIUsername}:${jssAPIPassword} ${jssAddress}/JSSResource/computers/serialnumber/${serialnumber} > $xmlfileread
SNOOZEVALUE=$(xmllint --xpath 'string(//extension_attribute[name="OS Update Snoozes"]/value)' $xmlfileread )


prompt_for_updates_snooze () {
    if [ "${SNOOZEVALUE:-0}" -lt 1 ]
       then
          SNOOZEVALUE=0
    fi

  # Call jamfhelper to prompt for updates
RESULT=$(/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "Service Desk Alert" -heading "Updates available from your friendly neighborhood Service Desk" -description "OS Updates are available for your machine. These can take up to 30 minutes, and may require a restart.
You have these updates available:
$LISTOFUPDATES

You have snoozed these updates $SNOOZEVALUE times. You can snooze them $SNOOZELIMIT times before they run automatically.

You can always run the updates manually when you have time by searching for 'macOS Updates' in the Self Service app." -button1 "UPDATE" -button2 "Snooze" -iconSize 1)

touch $xmlfilewrite
cat /dev/null > $xmlfilewrite

if [ $RESULT -eq 0 ]
  then
    /usr/local/bin/jamf policy -event $updatePolicy
    exit 0
  else
    SNOOZEVALUE=$((SNOOZEVALUE+1))
    echo "<computer><extension_attributes><extension_attribute><id>13</id><name>OS Update Snoozes</name><type>Integer</type><value>$SNOOZEVALUE</value></extension_attribute></extension_attributes></computer>" > $xmlfilewrite
    curl -s -k -u ${jssAPIUsername}:${jssAPIPassword} -X PUT -H "Content-Type: application/xml" -d "@${xmlfilewrite}" ${jssAddress}/JSSResource/computers/serialnumber/${serialnumber}
    exit 0
fi


exit 0
}

prompt_for_updates_limit () {
# Call jamfhelper to prompt for updates
RESULT=$(/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "Service Desk Alert" -heading "Updates available from your friendly neighborhood Service Desk" -description "OS Updates are available for your machine. These can take up to 30 minutes, and may require a restart.
You have these updates available:
$LISTOFUPDATES
THIS IS YOUR FINAL WARNING. These updates will install automatically tomorrow if snoozed again.

You can always run the updates manually when you have time by searching for 'macOS Updates' in the Self Service app." -button1 "UPDATE" -button2 "Snooze" -iconSize 1)

touch $xmlfilewrite
cat /dev/null > $xmlfilewrite

if [ $RESULT -eq 0 ]
  then
    /usr/local/bin/jamf policy -event $updatePolicy
    exit 0
  else
    SNOOZEVALUE=$((SNOOZEVALUE+1))
    echo "<computer><extension_attributes><extension_attribute><id>13</id><name>OS Update Snoozes</name><type>Integer</type><value>$SNOOZEVALUE</value></extension_attribute></extension_attributes></computer>" > $xmlfilewrite
    curl -s -k -u ${jssAPIUsername}:${jssAPIPassword} -X PUT -H "Content-Type: application/xml" -d "@${xmlfilewrite}" ${jssAddress}/JSSResource/computers/serialnumber/${serialnumber}
    exit 0
fi

}

prompt_for_updates_force () {
# Force Updates
  /usr/local/bin/jamf policy -event $updatePolicy &
# Call jamfhelper
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "Service Desk Alert" -heading "Updates available from your friendly neighborhood Service Desk" -description "You have these updates available:
$LISTOFUPDATES
You have exceeded your maximum snooze limit, so these updates are already installing.  Your computer will restart shortly." -button1 "Oops!" -iconSize 1
}

reset_snooze_counter () {
  touch $xmlfilewrite
  cat /dev/null > $xmlfilewrite
  SNOOZEVALUE=0
  echo "<computer><extension_attributes><extension_attribute><id>13</id><name>OS Update Snoozes</name><type>Integer</type><value>$SNOOZEVALUE</value></extension_attribute></extension_attributes></computer>" > $xmlfilewrite
  curl -s -k -u ${jssAPIUsername}:${jssAPIPassword} -X PUT -H "Content-Type: application/xml" -d "@${xmlfilewrite}" ${jssAddress}/JSSResource/computers/serialnumber/${serialnumber}
}


if [ -z $LISTOFUPDATES ]
  then
    echo "No updates available."
    reset_snooze_counter
    exit 0
elif [ "${SNOOZEVALUE:-0}" -lt $((SNOOZELIMIT - 1)) ]
  then
    prompt_for_updates_snooze
elif [ $SNOOZEVALUE -eq $((SNOOZELIMIT - 1)) ]
  then
    prompt_for_updates_limit
elif [ $SNOOZEVALUE -ge $SNOOZELIMIT ]
  then
    reset_snooze_counter
    prompt_for_updates_force
    exit 0
else
   echo "Uh oh, what happened?"
   exit 2
fi