#!/bin/sh

DROPBOX_HOME="$HOME/Dropbox"
XCAB_HOME="${DROPBOX_HOME}/`cat ${DROPBOX_HOME}/.com.PDAgent.XCAB.settings`"
XCAB_CONF="${XCAB_HOME}/XCAB.conf"
SCM_WORKING_DIR="$HOME/src"

if [ ! -d "${XCAB_HOME}" ] ; then
	mkdir "${XCAB_HOME}"
fi

exec<$XCAB_CONF
while read line 
do
	src_dir="`echo $line | sed -e 's/=.*$//'`"
	origin_url="`echo $line | sed -e 's/^[^=]*=//'`"

	if [ ! -d "${SCM_WORKING_DIR}/$src_dir" ] ; then
		echo "Checking out into working dir"
		cd "${SCM_WORKING_DIR}"
		git clone $origin_url $src_dir
	fi
	
	cd "${SCM_WORKING_DIR}/$src_dir"
	git fetch

	if [ ! -d "${XCAB_HOME}/$src_dir" ] ; then
		mkdir "${XCAB_HOME}/$src_dir"
	fi
	git branch -a > "${XCAB_HOME}/$src_dir/branches.txt"

done

