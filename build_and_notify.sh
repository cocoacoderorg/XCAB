#!/bin/sh

DROPBOX_HOME="$HOME/Dropbox"
XCAB_HOME="${DROPBOX_HOME}/`cat ${DROPBOX_HOME}/.com.PDAgent.XCAB.settings`"
SCM_WORKING_DIR="$HOME/src"
OVER_AIR_INSTALLS_DIR="$HOME/src/OverTheAirInstalls"
PUBLISHED_URLS=""

bin=`dirname "$0"`


#TODO - dynamically get the profile
provprofile="/Users/carlb/Library/MobileDevice/Provisioning Profiles/42348AF7-5BCE-440E-AAF8-E00B7398198C.mobileprovision"

if [ -f $bin/codeSigning_pwd.txt ] ; then
	security list-keychains -s $HOME/Library/Keychains/forCodeSigningOnly.keychain
	security unlock-keychain -p "`cat $bin/codeSigning_pwd.txt`" $HOME/Library/Keychains/forCodeSigningOnly.keychain
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
					build_target=`xcodebuild -list | awk '$1=="Targets:",$1==""' | grep -v "Targets:" | grep -v "^$" | sed -e 's/^  *//' | head -1`
					xcodebuild build -target $build_target
					if [ $? -ne 0 ] ; then
						echo "Build Failed" >&2
						exit 3
					fi
					mkdir -p $OVER_AIR_INSTALLS_DIR/$target/$build_time_human
					
					xcrun -sdk iphoneos PackageApplication "./build/Release-iphoneos/${build_target}.app" -o "/tmp/${build_target}.ipa" --sign "iPhone Developer" --embed "$provprofile"
					if [ $? -ne 0 ] ; then
						echo "Package Failed" >&2
						exit 3
					fi
					
					betabuilder /tmp/${build_target}.ipa $OVER_AIR_INSTALLS_DIR/$target/$build_time_human "http://www.pdagent.com/XCAB/${target}/$build_time_human"
					if [ $? -ne 0 ] ; then
						echo "betabuilder Failed" >&2
						exit 3
					else
						PUBLISHED_URLS="$PUBLISHED_URLS http://www.pdagent.com/XCAB/${target}/$build_time_human/"
					fi
					
					echo "$sha" > "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/sha.txt"
				fi
			fi
		done
		
	fi
	cd $XCAB_HOME
done

rsync -r $HOME/src/OverTheAirInstalls/ web_products_sync@www.pdagent.com:/var/www/htdocs/XCAB

if [ $? -eq 0 -a x"$PUBLISHED_URLS" != "x" ] ; then
	echo "Published the following urls: $PUBLISHED_URLS"
fi