#!/usr/bin/env bash
################################################################################
# A script to collect the version of Jamf Connect Login is currently installed.#
# If JCL is not installed "Not Installed" will return back                     #
################################################################################

RESULT="Not Installed"

if [ -d /Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/ ]; then
RESULT=$( /usr/bin/defaults read /Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/Contents/Info.plist CFBundleShortVersionString)
fi

/bin/echo "<result>$RESULT</result>"