#!/bin/sh
#                _   _         _     
#  ___  ___ ___ | |_| |_ _   _( )___ 
# / __|/ __/ _ \| __| __| | | |// __|
# \__ \ (_| (_) | |_| |_| |_| | \__ \
# |___/\___\___/ \__|\__|\__, | |___/
#                        |___/       
#  \ \ \ \ \ Continous Integration Bash Script
# 
# This script pulls, compiles, and puts the files on the configured ftp server.
# Usage:
# sh build.sh [force]

export PROJECT=/home/ci/ci/projects/scotty
export RELEASES_FOLDER=/home/ci/ci/release/
RELEASES_FOLDER_ARCHIVE=/home/ci/ci/release-archive/`date +%s`
FILE_PATTERN=".*\.\(war\|jar\|zip\|php\)"
PATTERN=".*/target/scotty$FILE_PATTERN"
MVN_SETTINGS=/home/ci/ci/settings.xml

REMOTE_USER=$REMOTE_USER
PASSWORD=$PASSWORD
HOSTNAME=$HOSTNAME
REMOTE_DIR=$REMOTE_DIR
LOGFILE=$SCOTTY_LOGFILE
AFTER_BUILD_SCRIPT=/home/ci/ci/afterBuild.sh
# Profles to run:
PROFILES[0]=
PROFILES[1]="-P gae"
LOCKFILE=$PROJECT/.scotty_ci_lockfile

FORCE=$1
NOMAVEN=$2

echo ====\> `date`

# pull git repo
cd $PROJECT
sh /home/ci/ci/isUpdateNeeded.sh
RET=$?
if [ $RET -eq 3 ];then
	echo Something is wrong, git pull unsuccessful

	exit $RET
fi

if ([ -e "$LOCKFILE" ] || [ $RET -eq 0 ]) && [ "$FORCE" != "force" ]; then
	if [ -e "$LOCKFILE" ]; then
		echo Lockile $LOCKFILE exists..build is currently running
	fi
elif [ $RET -eq 2 ] || [ "$FORCE" == "force" ];then 
	touch $LOCKFILE
	# make dirs, if not existing
	mkdir -p $RELEASES_FOLDER
	mkdir -p $RELEASES_FOLDER_ARCHIVE

	# Mave old Release to archive
	stat $RELEASES_FOLDER* &> /dev/null
	if [ $? -eq 0 ]; then
        	mv -f $RELEASES_FOLDER* $RELEASES_FOLDER_ARCHIVE/
	fi

	#run each profile and copy to RELEASES_FOLDER
	for p in "${PROFILES[@]}" 
	do
		echo ------------------------------ Profile $p ---------------------------------- &>> $LOGFILE
		if [ "$NOMAVEN" == "nomaven" ];then
			echo Maven DISABLED!
		else
			mvn -l $SCOTTY_LOGFILE -s $MVN_SETTINGS $p -U clean install
		fi
		if [ $? -ne 0 ];then 
			echo BUILD FAILED
			rm $LOCKFILE
			exit $?
		fi
		for i in `find ./ -maxdepth 4 -regex $PATTERN`;do echo cp -f $i $RELEASES_FOLDER &>> $LOGFILE; cp -f $i $RELEASES_FOLDER;done
	done
	echo Running afterbuild Script:
	if [ -f "$AFTER_BUILD_SCRIPT" ];then
		sh $AFTER_BUILD_SCRIPT &>> $LOGFILE
	fi

	echo Uploading to FTP: &>> $LOGFILE
	for i in `find $RELEASES_FOLDER -regex $FILE_PATTERN`
	do
		ncftpput -T PART -u $REMOTE_USER -p $PASSWORD $HOSTNAME $REMOTE_DIR $i &>> $LOGFILE
	done
	rm -f $LOCKFILE
fi
