#!/bin/bash

echo ""
echo "Building docker image"
echo "---------------------"

# Default parameters
#
IMAGE_TAG=pitrho/zm-ftp
CERTS_PATH=''

# Custom die function
#
die() { echo >&2 -e "\nRUN ERROR $@\n"; usage; exit 1; }

usage()
{
cat << EOF
usage: ./build.sh -c [-t] [-h]

    OPTIONS:
     -h     Show this message
     -c     The path to the SSL certificates
     -t     The image tag name. Defaults to $IMAGE_TAG
EOF
}

# Parse the command line flags
#
while getopts "hc:t:" opt; do
  case $opt in
    h)
      usage
      exit 1
      ;;
    c)
      CERTS_PATH=${OPTARG}
      ;;
    t)
      IMAGE_TAG=${OPTARG}
      ;;
    \?)
       die "Invalid option: -$OPTARG"
       ;;
  esac
done

# validation
if [ -z "$CERTS_PATH" ]; then
    die "Please specify path to SSL certificates!"
fi

# create build directory
rm -rf build
mkdir build

cp run-vsftpd.sh build/

# cert_count=$(ls -l ${CERTS
cp $CERTS_PATH/server* build/
cp Dockerfile build/
cp vsftpd.conf build/

docker build --no-cache -t="${IMAGE_TAG}" build/
