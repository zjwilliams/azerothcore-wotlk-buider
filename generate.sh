#!/bin/bash

# More safety, by turning some bugs into errors.
set -o errexit -o pipefail -o noclobber -o nounset

# option --output/-o requires 1 argument
LONGOPTS=version:db-password:playerbots
OPTIONS=v:d:p

# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
# -if getopt fails, it complains itself to stdout
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

version=- db_password=password p=acore
# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
	-v|--version)
 	    version="$2"
	    shift 2
	    ;;
	-d|--db-password)
	    db_password="$2"
	    shift 2
	    ;;
	-p|--playerbots)
	    p=acore-playerbot
	    shift
	    ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

echo "version: $version, password: $db_password, playerbots: $p"

if [[ "$version" == "-" ]]
then
	echo "A version is required"
	exit 1
fi

rm -rf build
mkdir -p build/quadlet
cat templates/quadlet/ac-authserver.container | \
	sed "s/\${DOCKER_DB_ROOT_PASSWORD}/$db_password/g" | \
	sed "s/\${DOCKER_IMAGE_TAG}/$version/g" | \
	sed "s/\${IMAGE_FLAVOR}/$p/g" > build/quadlet/ac-authserver.container
cat templates/quadlet/ac-client-data-init.container | \
        sed "s/\${DOCKER_DB_ROOT_PASSWORD}/$db_password/g" | \
        sed "s/\${DOCKER_IMAGE_TAG}/$version/g" | \
        sed "s/\${IMAGE_FLAVOR}/$p/g" > build/quadlet/ac-client-data-init.container
cat templates/quadlet/ac-database.container | \
        sed "s/\${DOCKER_DB_ROOT_PASSWORD}/$db_password/g" | \
        sed "s/\${DOCKER_IMAGE_TAG}/$version/g" | \
        sed "s/\${IMAGE_FLAVOR}/$p/g" > build/quadlet/ac-database.container
cat templates/quadlet/ac-db-import.container | \
        sed "s/\${DOCKER_DB_ROOT_PASSWORD}/$db_password/g" | \
        sed "s/\${DOCKER_IMAGE_TAG}/$version/g" | \
        sed "s/\${IMAGE_FLAVOR}/$p/g" > build/quadlet/ac-db-import.container
cat templates/quadlet/ac-worldserver.container | \
        sed "s/\${DOCKER_DB_ROOT_PASSWORD}/$db_password/g" | \
        sed "s/\${DOCKER_IMAGE_TAG}/$version/g" | \
        sed "s/\${IMAGE_FLAVOR}/$p/g" > build/quadlet/ac-worldserver.container
cat templates/quadlet/azeroth-core.pod | \
        sed "s/\${DOCKER_DB_ROOT_PASSWORD}/$db_password/g" | \
        sed "s/\${DOCKER_IMAGE_TAG}/$version/g" | \
        sed "s/\${IMAGE_FLAVOR}/$p/g" > build/quadlet/azeroth-core.pod

