#!/bin/sh

PREFS_DIR="$HOME/Library/Application Support/XCAB"
ERROR_EMAIL="carlb@ftlv.com"
SUCCESS_EMAIL="pdagent@me.com"

my_dir="`dirname \"$0\"`"
cd "$my_dir"
if [ $? -ne 0 ] ; then
	echo "Could not cd to $my_dir" >&2
	echo "Could not cd to $my_dir" | mail -s "$0 error" "$ERROR_EMAIL"
	exit 5
fi

my_name="`basename \"$0\"`"



if [ ! -d "$PREFS_DIR" ] ; then
	mkdir -p "$PREFS_DIR"
fi
if [ ! -d "$PREFS_DIR/logs" ] ; then
	mkdir -p "$PREFS_DIR/logs"
fi
if [ ! -d "$PREFS_DIR/run" ] ; then
	mkdir -p "$PREFS_DIR/run"
fi

TEMPFILE="$PREFS_DIR/run/$my_name.$$"
LOCKFILE="$PREFS_DIR/run/$my_name.lock"
START_LOG="$PREFS_DIR/logs/${my_name}_start.log"
RUN_LOG="$PREFS_DIR/logs/${my_name}.log"

#Make a temp file with our pid in it
echo $$ > "$TEMPFILE" 2>/dev/null
if [ $? -ne 0 ] ; then
	echo "Could not create $TEMPFILE" >&2
	echo "Could not create $TEMPFILE" | mail -s "$0 error" "$ERROR_EMAIL"
	exit 5
fi

#Now atomically create our lockfile
ln "$TEMPFILE" "$LOCKFILE"  > /dev/null 2>&1
if [ $? -eq 0 ] ; then
	#lockfile created, remove the temp file, then continue on
	rm -f "$TEMPFILE"
else
	#Couldn't create the lock file, see if the process that made it is still around 
	#	by sending it a dummy signal
	kill -0 `cat "$LOCKFILE"` > /dev/null 2>&1
	if [ $? -eq 0 ] ; then
		#process received the signal, so still running, so we give up
		rm -f "$TEMPFILE"
		exit 0
	else
		echo "Removing stale lock file"
		rm -f "$LOCKFILE"
		#Now atomically create our lockfile again
		ln "$TEMPFILE" "$LOCKFILE"  > /dev/null 2>&1
		if [ $? -eq 0 ] ; then
			#lockfile created, remove the temp file, then continue on
			rm -f "$TEMPFILE"
		else
			echo "Could not create lock file, even after removing stale one" >&2
			echo "Could not create lock file, even after removing stale one" | mail -s "$0 error" "$ERROR_EMAIL"
			rm -f "$TEMPFILE"
			exit 5
		fi
	fi
fi

echo "$0 run starting at `date`" > "$START_LOG" 2>&1

rm "$RUN_LOG" && touch "$RUN_LOG"

#Only want to see errors
git fetch >/dev/null 2>&1
git pull --rebase origin master >/dev/null 2>&1
if [ $? -ne 0 ] ; then
	echo "Error pulling from master" >&2
	git fetch >> "$RUN_LOG" 2>&1
	git status >> "$RUN_LOG" 2>&1
	git pull --rebase origin master >> "$RUN_LOG" 2>&1
	echo "Error pulling from master" >> "$RUN_LOG"
	cat "$START_LOG" "$RUN_LOG" | mail -s "$my_dir error and log"  "$SUCCESS_EMAIL"
	rm -f "$LOCKFILE"
	exit 4
fi
git fetch  >/dev/null 2>&1

$my_dir/sync_from_Dropbox.sh >> "$RUN_LOG" 2>&1

$my_dir/build_and_notify.sh >> "$RUN_LOG" 2>&1

#Only send mail if there's something to report
if [  -s "$RUN_LOG" ] ; then
	cat "$START_LOG" "$RUN_LOG" | mail -s "$my_dir log" "$SUCCESS_EMAIL" 
	rm -f "$LOCKFILE"
fi

rm -f "$LOCKFILE"

