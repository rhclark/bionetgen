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
  rall=$vbase"-Linux.tar.gz" 
else
  rall=$vbase"-MacOSX.tar.gz" 
fi
lall=$vbase".tar.gz" 

echo " Local name of package is " $lall
echo " Remote name of package is " $rall

ls -l $lall
#  curl -T $vall  -u roberthclark:P1ttsburgh ftp://ftp.midcapsignals.com/midcap/junk/
