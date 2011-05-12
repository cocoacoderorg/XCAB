#!/bin/sh

my_dir="`dirname \"$0\"`"
cd "$my_dir"
if [ $? -ne 0 ] ; then
	echo "Could not cd to $my_dir" >&2
	exit 5
fi

. $my_dir/XCAB.settings
. $my_dir/functions.sh

#Find the most recent automatically generated provisioning profile
for f in `ls -1tr "$HOME/Library/MobileDevice/Provisioning Profiles/"`; do 
	grep -l 'Team Provisioning Profile: *' "$HOME/Library/MobileDevice/Provisioning Profiles/$f" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		provprofile="$HOME/Library/MobileDevice/Provisioning Profiles/$f"
	fi
done

if [ ! -z "$CODESIGNING_KEYCHAIN" -a ! -z "$CODESIGNING_KEYCHAIN_PASSWORD" -a -f "$CODESIGNING_KEYCHAIN" ] ; then
	security list-keychains -s $CODESIGNING_KEYCHAIN
	security unlock-keychain -p $CODESIGNING_KEYCHAIN_PASSWORD $CODESIGNING_KEYCHAIN
	if [ $? -ne 0 ] ; then
		echo "Error unlocking $CODESIGNING_KEYCHAIN keychain" >&2
		exit 4
	fi
else
	echo "Please enter your password to allow access to your code signign keychain"
	security list-keychains -s $HOME/Library/Keychains/login.keychain
	security unlock-keychain $HOME/Library/Keychains/login.keychain
	if [ $? -ne 0 ] ; then
		echo "Error unlocking login keychain" >&2
		exit 4
	fi
fi


if [ ! -d "$OVER_AIR_INSTALLS_DIR" ] ; then
	mkdir -p "$OVER_AIR_INSTALLS_DIR" 2>/dev/null
fi

build_time_human="`date +%Y%m%d%H%M%S`"

now="`date '+%s'`"
days=2 # don't build things more than 2 days old
cutoff_window="`expr $days \* 24 \* 60 \* 60`" 
cutoff_time="`expr $now - $cutoff_window`"

cd $XCAB_HOME

for target in *; do
	if [ -d "$SCM_WORKING_DIR/$target" ] ; then
		cd "$SCM_WORKING_DIR/$target"

		#Bring the local repo up to date
		# But if we can't talk to the server, ignore the error
		#TODO make sure that, if there is an error, it's only
		#  a connection error before we ignore it
		git fetch > /dev/null 2>&1

		if [ x"`ls -1d *xcodeproj 2>/dev/null`" == x ] ; then
			#Not an iphone dir
			continue
		fi
		
		already_built="`cat $OVER_AIR_INSTALLS_DIR/$target/*/sha.txt 2>/dev/null`"
		
		for candidate in `git branch -l | sed -e 's/^..//'` ; do
			sha="`git rev-parse $candidate`"
			commit_time="`git log -1 --pretty=format:"%ct" $sha`"
			if [ $commit_time -gt $cutoff_time ] ; then
				is_built="`echo $already_built | grep $sha`"
				if [ -z "$is_built" ] ; then
					git checkout -f $candidate
					git reset --hard $candidate
					git clean -d -f -x
					mkdir -p "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/"
					#TODO need to figure out a way to indicate that the user wants to build other targets
					build_target=`xcodebuild -list | awk '$1=="Targets:",$1==""' | grep -v "Targets:" | grep -v "^$" | sed -e 's/^  *//' | head -1`
					#TODO need to make sure we're building for the device
					xcodebuild build -target $build_target
					if [ $? -ne 0 ] ; then
						echo "Build Failed" >&2
						echo "$sha" > "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/sha.txt" #Don't try to build this again - it would fail over and over
						exit 3
					fi
					mkdir -p $OVER_AIR_INSTALLS_DIR/$target/$build_time_human
					
					if [ -d "./build/Release-iphoneos/${build_target}.app" ] ; then
						xcrun -sdk iphoneos PackageApplication "./build/Release-iphoneos/${build_target}.app" -o "/tmp/${build_target}.ipa" --sign "iPhone Developer" --embed "$provprofile"
					else
						xcrun -sdk iphoneos PackageApplication "./build/Debug-iphoneos/${build_target}.app" -o "/tmp/${build_target}.ipa" --sign "iPhone Developer" --embed "$provprofile"
					fi
					if [ $? -ne 0 ] ; then
						rm -rf /tmp/${build_target}.ipa
						echo "Package Failed" >&2
						echo "$sha" > "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/sha.txt" #Don't try to build this again - it would fail over and over
						exit 3
					fi
					
					betabuilder /tmp/${build_target}.ipa $OVER_AIR_INSTALLS_DIR/$target/$build_time_human "${XCAB_WEB_ROOT}/${target}/$build_time_human"
					if [ $? -ne 0 ] ; then
						rm -rf /tmp/${build_target}.ipa
						echo "betabuilder Failed" >&2
						echo "$sha" > "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/sha.txt" #Don't try to build this again - it would fail over and over
						exit 3
					else
						#Save off the symbols, too
						if [ -d "./build/Release-iphoneos/${build_target}.app.dSYM" ] ; then
							tar czf "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/${build_target}.app.dSYM.tar.gz" "./build/Release-iphoneos/${build_target}.app.dSYM"
						else
							tar czf "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/${build_target}.app.dSYM.tar.gz" "./build/Debug-iphoneos/${build_target}.app.dSYM"
						fi

						rm -rf /tmp/${build_target}.ipa
						
						if [ ! -z "$RSYNC_USER" ] ; then
							#If we're not using Dropbox's public web server, run rsync now
							rsync -r ${OVER_AIR_INSTALLS_DIR} ${RSYNC_USER}@${XCAB_WEBSERVER_HOSTNAME}:${XCAB_WEBSERVER_XCAB_DIRECTORY_PATH}
						fi
					
						wait_for_idle_dropbox

						#We're making the implicit assumption here that there aren't 
						#  going to be a bunch of new changes per run
						#   so it won't spam the user to notify for each one
						#Notify with Boxcar
						curl -d "notification[source_url]=${XCAB_WEB_ROOT}/$target/$build_time_human/index.html" -d "notification[message]=New+${target}+Build+available" --user "${BOXCAR_EMAIL}:${BOXCAR_PASSWORD}" https://boxcar.io/notifications
					fi
										
					echo "$sha" > "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/sha.txt"
				fi
			fi
		done
		
	fi
	cd $XCAB_HOME
done

if [ ! -z "$RSYNC_USER" ] ; then
	#One more Sync just to be sure If we're not using Dropbox's public web server, run rsync now
	rsync -r ${OVER_AIR_INSTALLS_DIR} ${RSYNC_USER}@${XCAB_WEBSERVER_HOSTNAME}:${XCAB_WEBSERVER_XCAB_DIRECTORY_PATH}
fi
