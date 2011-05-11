#!/bin/sh


my_dir="`dirname \"$0\"`"
cd "$my_dir"
if [ $? -ne 0 ] ; then
	echo "Could not cd to $my_dir" >&2
	exit 5
fi

. $my_dir/XCAB.settings
. $my_dir/functions.sh

echo "Starting loop to check for modifications."
echo "   Hit Control-C to Stop."

while [ : ] ; do
	/Users/carlb/PDAgent/XCAB/run_from_cron.sh 
	sleep 60
done
