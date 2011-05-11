#!/bin/sh

my_dir="`dirname \"$0\"`"
cd "$my_dir"
if [ $? -ne 0 ] ; then
	echo "Could not cd to $my_dir" >&2
	exit 5
fi

if [ ! -f $my_dir/XCAB.settings ] ; then
	echo "ERROR: $my_dir/XCAB.settings file not found." >&2
	echo "       Please copy $my_dir/XCAB.settings.sample to $my_dir/XCAB.settings" >&2
	echo "        and edit it for your environment." >&2
	exit 4
fi

. $my_dir/XCAB.settings
. $my_dir/functions.sh

EXIT_STATUS=0

if [ "$ERROR_EMAIL" == "user@example.com" ] ; then
	echo "ERROR: Please set ERROR_EMAIL in $my_dir/XCAB.settings to a valid value" >&2
	EXIT_STATUS=`expr $EXIT_STATUS + 1`
fi

if [ "$SUCCESS_EMAIL" == "user@example.com" ] ; then
	echo "ERROR: Please set SUCCESS_EMAIL in $my_dir/XCAB.settings to a valid value" >&2
	EXIT_STATUS=`expr $EXIT_STATUS + 1`
fi

if [ "$BOXCAR_EMAIL" == "user@example.com" ] ; then
	echo "ERROR: Please set BOXCAR_EMAIL in $my_dir/XCAB.settings to a valid value" >&2
	EXIT_STATUS=`expr $EXIT_STATUS + 1`
fi

if [ "$BOXCAR_PASSWORD" == "YOUR_BOXCAR_PASSWORD_GOES_HERE" ] ; then
	echo "ERROR: Please set BOXCAR_PASSWORD in $my_dir/XCAB.settings to a valid value" >&2
	EXIT_STATUS=`expr $EXIT_STATUS + 1`
fi

if [ "$PUBLIC_URL_PREFIX" == "http://dl.dropbox.com/u/YOUR_DROPBOX_ID_GOES_HERE" ] ; then
	echo "ERROR: Please set PUBLIC_URL_PREFIX in $my_dir/XCAB.settings to a valid value" >&2
	EXIT_STATUS=`expr $EXIT_STATUS + 1`
fi

if [ x"$CODESIGNING_KEYCHAIN_PASSWORD" == "xYOUR_CODESIGNING_PASSWORD_GOES_HERE" ] ; then
	echo "ERROR: Please set CODESIGNING_KEYCHAIN_PASSWORD in $my_dir/XCAB.settings to a valid value" >&2
	EXIT_STATUS=`expr $EXIT_STATUS + 1`
fi

if [ ! -d "$DROPBOX_HOME" ] ; then
	echo "ERROR: Cannot find Dropbox directory.  Please set the DROPBOX_HOME variable to the correct value" >&2
	EXIT_STATUS=`expr $EXIT_STATUS + 1`
fi

if [ ! -d "$XCAB_HOME" ] ; then
	echo "Making Directory $XCAB_HOME"
	mkdir -p $XCAB_HOME
fi

if [ "$EXIT_STATUS" -eq 0 ] ; then
	#Only set this file if everything else is okay
	if [ ! -f "$DROPBOX_HOME/.com.PDAgent.XCAB.settings" ] ; then
		echo "Making $DROPBOX_HOME/.com.PDAgent.XCAB.settings file so iOS app can find the right directory" 
		echo "$XCAB_DROPBOX_PATH" > "$DROPBOX_HOME/.com.PDAgent.XCAB.settings"
	fi

	if [ "`cat $DROPBOX_HOME/.com.PDAgent.XCAB.settings`" != "$XCAB_DROPBOX_PATH" ] ; then
		echo "Correcting $DROPBOX_HOME/.com.PDAgent.XCAB.settings file so iOS app can find the right directory" 
		echo "$XCAB_DROPBOX_PATH" > "$DROPBOX_HOME/.com.PDAgent.XCAB.settings"
	fi
fi

if [ ! -z "$CODESIGNING_KEYCHAIN" -a -f "$CODESIGNING_KEYCHAIN" -a ! -z "$CODESIGNING_KEYCHAIN_PASSWORD" ] ; then
	if [ "$EXIT_STATUS" -eq 0 ] ; then
		echo "You should be good to go.  Please put the following line in your crontab to start the script:"
		echo "* * * * * $my_dir/run_from_cron.sh"
	fi
else
	if [ "$EXIT_STATUS" -eq 0 ] ; then
		echo "You are set up to run, as long as you stay logged in.  You can run:"
		echo "$my_dir/run_in_terminal.sh"
		echo "in a termnial window"
	fi
fi


exit $EXIT_STATUS