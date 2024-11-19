#!/bin/bash

# More safety, by turning some bugs into errors.
set -o errexit -o pipefail -o noclobber -o nounset

# option --output/-o requires 1 argument
LONGOPTS=playerbots,verbose
OPTIONS=pv

# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
# -if getopt fails, it complains itself to stdout
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

p=n v=n
# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -p|--playerbots)
            p=y
            shift
            ;;
        -v|--verbose)
            v=y
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

echo "verbose: $v, playerbots: $p"

DEFAULT_URL="https://github.com/azerothcore/azerothcore-wotlk.git"
PLAYERBOT_URL="https://github.com/liyunfan1223/azerothcore-wotlk.git"

if [[ -d "azerothcore-wotlk" ]]
then
	if [[ "$v" == "y" ]]
		echo "azerothcore-wotlk directory exists, deleting it."
	then
	rm -rf azerothcore-wotlk
fi

fi

if [[ "$p" == "n" ]]
then
	if [[ "$v" == "y"  ]]
	then
		echo "Playerbots disabled, cloning master from: $DEFAULT_URL:"
	fi
	git clone $DEFAULT_URL --branch master
else
	        if [[ "$v" == "y"  ]]
        then
                echo "Playerbots enabled, cloning Playerbot from: $PLAYERBOT_URL:"
        fi
        git clone $PLAYERBOT_URL --branch Playerbot
	cd azerothcore-wotlk/modules
	git clone https://github.com/liyunfan1223/mod-playerbots.git --branch=master
	cd ../../
fi

# Patch the Dockerfile to work with podman (Unsure why it works with docker, by appearances it shouldn't)
cat azerothcore-wotlk/apps/docker/Dockerfile | sed 's/FROM skeleton AS client-data/FROM runtime AS client-data\n\nUSER 0/g' > Dockerfile
mv Dockerfile azerothcore-wotlk/apps/docker/Dockerfile

# For lower chance of conflict when running as a rootless podman container, an id that is reasonably available is used.
export DOCKER_USER_ID=1315185
export DOCKER_GROUP_ID=1315185

VERSION=$(git show -s --format=%ci | cut -d ' ' -f 1 | tr - .)
PACKAGE=acore
if [[ "$p" == "n" ]]
then
	PACKAGE=$PACKAGE-playerbot
fi

cd azerothcore-wotlk
podman build --target db-import --tag gchr.io/zjwillims/$PACKAGE/db-import:$VERSION azerothcore-wotlk azerothcore-wotlk/apps/docker/Dockerfile
podman build --target worldserver --tag gchr.io/zjwillims/$PACKAGE/worldserver:$VERSION azerothcore-wotlk azerothcore-wotlk/apps/docker/Dockerfile
podman build --target authserver --tag gchr.io/zjwillims/$PACKAGE/authserver:$VERSION azerothcore-wotlk azerothcore-wotlk/apps/docker/Dockerfile
podman build --target client-data --tag gchr.io/zjwillims/$PACKAGE/client-data:$VERSION azerothcore-wotlk azerothcore-wotlk/apps/docker/Dockerfile
podman build --target tools --tag gchr.io/zjwillims/$PACKAGE/tools:$VERSION azerothcore-wotlk azerothcore-wotlk/apps/docker/Dockerfile
podman build --target dev --tag gchr.io/zjwillims/$PACKAGE/dev:$VERSION azerothcore-wotlk azerothcore-wotlk/apps/docker/Dockerfile

