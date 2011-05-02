#!/bin/sh

DROPBOX_HOME="$HOME/Dropbox"
XCAB_HOME="${DROPBOX_HOME}/`cat ${DROPBOX_HOME}/.com.PDAgent.XCAB.settings`"
SCM_WORKING_DIR="$HOME/src"
OVER_AIR_INSTALLS_DIR="$HOME/src/OverTheAirInstalls/"
BOXCAR_EMAIL="`cat boxcar_email.txt`"
BOXCAR_PASSWORD="`boxcar_pwd.txt`"
RSYNC_USER="web_products_sync"
XCAB_WEB_ROOT="www.pdagent.com:/var/www/htdocs/XCAB"


bin=`dirname "$0"`


#Find the most recent automatically generated provisioning profile
for f in `ls -1tr "$HOME/Library/MobileDevice/Provisioning Profiles/"`; do 
	grep -l 'Team Provisioning Profile: *' "$HOME/Library/MobileDevice/Provisioning Profiles/$f" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		provprofile="$HOME/Library/MobileDevice/Provisioning Profiles/$f"
	fi
done

if [ -f $bin/codeSigning_pwd.txt ] ; then
	security list-keychains -s $bin/forCodeSigningOnly.keychain
	security unlock-keychain -p "`cat $bin/codeSigning_pwd.txt`" $bin/forCodeSigningOnly.keychain
	if [ $? -ne 0 ] ; then
		echo "Error unlocking forCodeSigningOnly keychain" >&2
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
days=1 # don't build things more than 7 days old
cutoff_window="`expr $days \* 24 \* 60 \* 60`" 
cutoff_time="`expr $now - $cutoff_window`"

cd $XCAB_HOME

for target in *; do
	if [ -d "$SCM_WORKING_DIR/$target" ] ; then
		cd "$SCM_WORKING_DIR/$target"

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
						echo "Package Failed" >&2
						echo "$sha" > "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/sha.txt" #Don't try to build this again - it would fail over and over
						exit 3
					fi
					
					betabuilder /tmp/${build_target}.ipa $OVER_AIR_INSTALLS_DIR/$target/$build_time_human "http://${XCAB_WEB_ROOT}/${target}/$build_time_human"
					if [ $? -ne 0 ] ; then
						echo "betabuilder Failed" >&2
						echo "$sha" > "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/sha.txt" #Don't try to build this again - it would fail over and over
						exit 3
					else
						#We're making the implicit assumption here that there aren't going to be several new 
						rsync -r ${OVER_AIR_INSTALLS_DIR} ${RSYNC_USER}@${XCAB_WEB_ROOT}
						curl -d "notification[source_url]=http://${XCAB_WEB_ROOT}/$target/$build_time_human/" -d "notification[message]=New+${target}+Build+available" --user "${BOXCAR_EMAIL}:${BOXCAR_PASSWORD}" https://boxcar.io/notifications
					fi
										
					#TODO put this early so failures don't cause loop
					echo "$sha" > "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/sha.txt"
				fi
			fi
		done
		
	fi
	cd $XCAB_HOME
done

#One more Sync just to be sure
rsync -r ${OVER_AIR_INSTALLS_DIR} ${RSYNC_USER}@${XCAB_WEB_ROOT}
