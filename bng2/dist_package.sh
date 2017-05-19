#!/bin/bash
#
#  Read the VERSION file and construct the name of the installation package.
echo " PLATFORM_ENV = " ${TRAVIS_OS_NAME} $0
#
#input="./bng2/VERSION"
#while read -r var
#do
#  vbase="BioNetGen-$var"
#  vall=$vbase"-Linux.tar.gz" 
#  curl -T $vall  -u roberthclark:P1ttsburgh ftp://ftp.midcapsignals.com/midcap/junk/
#done < "$input"
