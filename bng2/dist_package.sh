#!/bin/bash
#
#  Read the VERSION file and construct the name of the installation package.
echo " PLATFORM_ENV = " ${TRAVIS_OS_NAME} 
echo " pwd = " ; pwd
uname -a

echo '  '
echo '  '

# Presumably there is only one line in the file:  VERSION
input="./VERSION"
while read -r var
do
  vbase="BioNetGen-$var"
done < "$input"



if [ "${TRAVIS_OS_NAME}" = "linux" ]; then
  vall=$vbase"-Linux.tar.gz" 
else
  vall=$vbase"-MacOSX.tar.gz" 
fi

echo " Name of package is " $vall

ls -l $vall
#  curl -T $vall  -u roberthclark:P1ttsburgh ftp://ftp.midcapsignals.com/midcap/junk/
