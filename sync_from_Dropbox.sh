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

	#If we don't have a copy of this project in our SCM Working Dir, check it out
	if [ ! -d "${SCM_WORKING_DIR}/$src_dir" ] ; then
		echo "Checking out into working dir"
		cd "${SCM_WORKING_DIR}"
		git clone $origin_url $src_dir
	fi
	
	#Get the latest updates from source control
	cd "${SCM_WORKING_DIR}/$src_dir"
	git fetch >/dev/null #only want to see errors

	#If this project doesn't have a corresponding folder in Dropbox, make one
	if [ ! -d "${XCAB_HOME}/$src_dir" ] ; then
		mkdir "${XCAB_HOME}/$src_dir"
	fi
	
	#Update the list of available branches so the user can find them by looking at Dropbox
	git branch -a | sed -e 's/^..//' -e 's/ ->.*$//' -e 's,^remotes/,,' > "${XCAB_HOME}/$src_dir/branches.txt"
	
	cd "${XCAB_HOME}/$src_dir"
	
	for entry in * ; do
		active_branch=""
		GIT_DIR="${SCM_WORKING_DIR}/$src_dir/.git"
		export GIT_DIR
		
		if [ -d "$entry" ] ; then
			#This is a directory - we need to decide if we need to do anything with this
			cd "${XCAB_HOME}/$src_dir/$entry"
			item_count="`ls -1 | wc -l | sed -e 's/[^0-9]//g'`"
			
			if [ "$item_count" == "0" ] ; then
				#Empty directory, need to check the correct branch out into it
				
				cd "${XCAB_HOME}/$src_dir"
				rm -rf tmp_checkout_dir
				mv $entry tmp_checkout_dir
				cd tmp_checkout_dir
				
				#Now we need to figure out the right branch
				if [ -f "${GIT_DIR}/refs/heads/$entry" ] ; then
					#Branch exists, this is the one we want
					active_branch="$entry"
				elif [ -f "${GIT_DIR}/refs/remotes/origin/$entry" ] ; then
						#Branch exists, but is remote
						active_branch="$entry"
						echo "Creating Local branch '$entry' from remote branch 'origin/$entry'"
						git branch "$entry" "origin/$entry"
				else 
					#directory doesn't match an existing branch
					for potential_branch in `grep -v '/' "${XCAB_HOME}/$src_dir/branches.txt"`; do
						substring_match=`echo $entry | grep "^$potential_branch"`
						if [ x"$substring_match" != "x" ] ; then
							active_branch=$potential_branch
						fi
					done
					if [ x"$active_branch" != "x" ] ; then
						git branch "$entry" "$active_branch"
						active_branch="$entry"
					else
						#Do the same thing with remote branches
						for potential_branch in `grep '/' "${XCAB_HOME}/$src_dir/branches.txt"`; do
							localized_potential_branch="`echo $potential_branch | sed -e 's,^[^/]*/,,'`"
							substring_match=`echo $entry | grep "^$localized_potential_branch"`
							if [ x"$substring_match" != "x" ] ; then
								active_branch=$potential_branch
							fi
						done
						if [ x"$active_branch" != "x" ] ; then
							git branch "$entry" "$active_branch"
							active_branch="$entry"
						fi
					fi
				fi
				if [ x"$active_branch" == "x" ] ; then
					echo "Could not figure out an active branch - using master"
					git branch "$entry" master
					active_branch="$entry"
				fi
				git checkout -f $active_branch
				git reset --hard $active_branch
				cd ..
				#TODO - wait for Dropbox to finish syncing
				mv tmp_checkout_dir "$entry"
				
				git branch -a | sed -e 's/^..//' -e 's/ ->.*$//' -e 's,^remotes/,,' > "${XCAB_HOME}/$src_dir/branches.txt"
			else
				#This directory has files in it, see if any of them have changed
				our_status="`git status | grep 'nothing to commit'`"
				if [ x"$our_status" == "x" ] ; then
					#Something changed, check it in
					git checkout "$entry"
					comment="`git diff | grep '^+[^+]' | sed -e 's/^\+//' | egrep '#|//|/\*|\*/'`"
					git add .
					#TODO: Make comment understand other comment styles like in between /* */ or # only for other languages
					if [ x"$comment" == "x" ] ; then
						comment="Checked in from Dropbox on `date`"
					fi
					git commit -a -m "$comment"
				fi
			fi
		fi
		unset GIT_DIR
		cd "${XCAB_HOME}/$src_dir"
	done 

done

