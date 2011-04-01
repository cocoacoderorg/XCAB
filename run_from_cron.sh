#!/bin/sh

#give ourselves a little delay 
sleep 2

#Check for the number of different start times - that way if we're fork()ing, we don't show up as ourselves
count_of_me_running="`ps auxwwww | grep run_from_cron.sh | grep -v grep | awk '{print $9}' | sort -u | wc -l`"

if [ "$count_of_me_running" -ne "1" ] ; then
	echo "Bad count of running copies of this script $count_of_me_running - Bailing!"  >&2
	output_of_me_running="`ps auxwwww | grep run_from_cron.sh | grep -v grep`"
	echo "Bad count of running copies of this script $count_of_me_running - Bailing! (ps output: '$output_of_me_running')" | mail -s "run_XCAB_cron error" carlb@ftlv.com
	exit 5
fi

cd /Users/carlb/src/XCAB
bin=`dirname "$0"`
bin=`cd "$bin"; pwd`
echo "$0 run starting at `date`" > /tmp/run_XCAB_cron_start.log 2>&1

rm /tmp/run_XCAB_cron.log && touch /tmp/run_XCAB_cron.log

#Only want to see errors
git fetch >/dev/null 2>&1
git pull --rebase origin master >/dev/null 2>&1
if [ $? -ne 0 ] ; then
	echo "Error pulling from master" >&2
	git fetch >> /tmp/run_XCAB_cron.log 2>&1
	git status >> /tmp/run_XCAB_cron.log 2>&1
	git pull --rebase origin master >> /tmp/run_XCAB_cron.log 2>&1
	echo "Error pulling from master" >> /tmp/run_XCAB_cron.log
	cat /tmp/run_XCAB_cron_start.log /tmp/run_XCAB_cron.log | mail -s "run_XCAB_cron error and log" pdagent@me.com 
	exit 4
fi
git fetch  >/dev/null 2>&1

$bin/sync_from_Dropbox.sh >> /tmp/run_XCAB_cron.log 2>&1

$bin/build_and_notify.sh >> /tmp/run_XCAB_cron.log 2>&1

#Only send mail if there's something to report
if [  -s /tmp/run_XCAB_cron.log ] ; then
	cat /tmp/run_XCAB_cron_start.log /tmp/run_XCAB_cron.log | mail -s "run_XCAB_cron log" pdagent@me.com 
fi

