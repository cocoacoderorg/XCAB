#!/bin/sh

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

