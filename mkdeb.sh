#!/bin/bash
MAINTAINER="Jeroen Steenbeeke <j.steenbeeke@gmail.com>"


TARGET=target
TARGET_DATA=$TARGET/data
TARGET_CONTROL=$TARGET/control
USR_LIB_JETTY="lib modules VERSION.txt README.TXT license-eplv10-aslv20.html start.jar start.ini notice.html webapps"
ETC_JETTY="etc"
BASE=`pwd`

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ $# == 1 ]; then
	if [ -d $1 ]; then
		if [ -d target ]; then
			echo Removing target folder
			rm -rf $TARGET
		fi

		# Create data folder
		fakeroot mkdir -p $TARGET_DATA

		echo Creating folders

		fakeroot mkdir -p $TARGET_DATA/etc/init.d/
		fakeroot mkdir -p $TARGET_DATA/etc/default/
		fakeroot mkdir -p $TARGET_DATA/etc/jetty9/
		fakeroot mkdir -p $TARGET_DATA/usr/share/jetty9/
		fakeroot mkdir -p $TARGET_DATA/var/log/jetty9/
		fakeroot mkdir -p $TARGET_DATA/var/cache/jetty9/
		fakeroot mkdir  -p $TARGET_DATA/var/lib/jetty9/

		cd $1

		echo Copying config files
		for i in $ETC_JETTY; do
			fakeroot cp -r $i/* $BASE/$TARGET_DATA/etc/jetty9/
		done
		
		fakeroot cp $BASE/etc-default-jetty $BASE/$TARGET_DATA/etc/default/jetty9

		echo Copying default files
		for i in $USR_LIB_JETTY; do
			fakeroot cp -r $i $BASE/$TARGET_DATA/usr/share/jetty9/
		done

		fakeroot cp bin/jetty.sh $BASE/$TARGET_DATA/etc/init.d/jetty9

		cd $BASE/$TARGET_DATA/

		echo Creating symlinks

		cd var/lib/jetty9
		fakeroot ln -s /usr/share/jetty9/webapps webapps
		cd ../../..
		cd usr/share/jetty9
		fakeroot ln -s /etc/jetty9 etc
		cd ../../..

		fakeroot tar --lzma -cf ../data.tar.xz *	

		cd $BASE

		# Create CONTROL folder
		DU_INSTALLED_SIZE=(`du -sx $TARGET_DATA`)
		INSTALLED_SIZE=${DU_INSTALLED_SIZE[0]}
		VERSION=`cat $TARGET_DATA/usr/share/jetty9/VERSION.txt | grep -m1 ^jetty | sed -e 's/^jetty-\([^\s]\+\)/\1/g' | sed -e 's/\s.*$//'`

		echo Creating control file	

		fakeroot mkdir -p $TARGET_CONTROL
		fakeroot cp -r $BASE/control/* $TARGET_CONTROL

		echo "Package: jetty9" > $TARGET_CONTROL/control
		echo "Version: $VERSION" >> $TARGET_CONTROL/control
		echo "Architecture: all" >> $TARGET_CONTROL/control
		echo "Maintainer: $MAINTAINER" >> $TARGET_CONTROL/control
		echo "Installed-size: $INSTALLED_SIZE" >> $TARGET_CONTROL/control
		echo "Depends: adduser, apache2-utils, java8-runtime-headless" >> $TARGET_CONTROL/control
		echo "Recommends: authbind" >> $TARGET_CONTROL/control
 		echo "Section: java" >> $TARGET_CONTROL/control
 		echo "Priority: optional" >> $TARGET_CONTROL/control
 		echo "Homepage: http://www.eclipse.org/jetty/" >> $TARGET_CONTROL/control
 		echo "Description: Java servlet engine and webserver" >> $TARGET_CONTROL/control
 		echo " Jetty is an Open Source HTTP Servlet Server written in 100% Java." >> $TARGET_CONTROL/control
 		echo " It is designed to be light weight, high performance, embeddable," >> $TARGET_CONTROL/control
 		echo " extensible and flexible, thus making it an ideal platform for serving" >> $TARGET_CONTROL/control
 		echo " dynamic HTTP requests from any Java application." >> $TARGET_CONTROL/control

		echo "Generating: conffiles"
		
		cd $BASE/$TARGET_DATA/etc
		
		for i in `find *`; do
			if [ ! -d $i ]; then
				fakeroot echo /etc/$i >> $BASE/$TARGET_CONTROL/conffiles
			fi
		done

		echo "Setting file permissions"

		fakeroot chmod 644 $BASE/$TARGET_CONTROL/conffiles
		fakeroot chmod 755 $BASE/$TARGET_CONTROL/postinst
		fakeroot chmod 755 $BASE/$TARGET_CONTROL/prerm
		fakeroot chmod 755 $BASE/$TARGET_CONTROL/postrm

		echo "Generating: md5sums"

		cd $BASE/$TARGET_DATA/

		fakeroot touch $BASE/$TARGET_CONTROL/md5sums
		fakeroot chmod 644 $BASE/$TARGET_CONTROL/md5sums

		fakeroot find . -type f ! -regex '.*.hg.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -printf '%P ' | xargs md5sum > $BASE/$TARGET_CONTROL/md5sums

		echo "Generating: debian-binary"

		fakeroot echo "2.0" >> $BASE/$TARGET/debian-binary

		cd $BASE/$TARGET/

		echo Fixing directory file permissions

		for i in `find *`; do
			if [ -d $i ]; then
				fakeroot chmod 755 $i
			fi
		done

		echo "Packaging data"

		cd $BASE/$TARGET_DATA/

		fakeroot tar --lzma -cf $BASE/$TARGET/data.tar.xz *

		echo "Packaging control"

		cd $BASE/$TARGET_CONTROL/

		fakeroot tar -czf $BASE/$TARGET/control.tar.gz *

		cd $BASE/$TARGET

		fakeroot ar -r jetty9-$VERSION.deb debian-binary control.tar.gz data.tar.xz

		lintian jetty9-$VERSION.deb --suppress-tags unknown-java-class-version
	else
		echo $1 is not a folder
	fi
else
	echo Usage:
	echo	mkdata.sh DISTRIBUTION_FOLDER
fi
