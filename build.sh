#!/bin/bash

# More safety, by turning some bugs into errors.
set -o errexit -o pipefail -o noclobber -o nounset

# option --output/-o requires 1 argument
LONGOPTS=playerbots,publish,verbose,target:
OPTIONS=pPvt:

# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
# -if getopt fails, it complains itself to stdout
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

p=n v=n P=n target=-
# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -p|--playerbots)
            p=y
            shift
            ;;
	-P|--publish)
	    P=y
	    shift
	    ;;
        -v|--verbose)
            v=y
            shift
            ;;
	-t|--target)
 	    target="$2"
	    shift 2
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

echo "verbose: $v, playerbots: $p, publish: $P, target: $target"

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

if [[ "$v" == "y" ]]
then
	echo "Patching Dockerfile."
fi

# Patch the Dockerfile to work with podman (Unsure why it works with docker, by appearances it shouldn't)
cat azerothcore-wotlk/apps/docker/Dockerfile | \
        sed 's/ # lts//g' | \
	sed 's/--mount=type=cache,target=\/ccache,sharing=locked//g' | \
	sed 's/--mount=type=bind,target=\/azerothcore\/.git,source=.git//g' | \
	sed 's/FROM skeleton AS client-data/FROM runtime AS client-data\n\nUSER 0/g' | \
	sed 's/$DOCKER_USER:$DOCKER_USER/$USER_ID:$GROUP_ID/g' | \
	sed 's/USER $DOCKER_USER//g' | \
	sed 's/CMD/USER $DOCKER_USER\nCMD/g' | \
	sed 's/ARG DOCKER_USER=acore//g' | \
	sed 's/$DOCKER_USER/acore/g' | \
	sed 's/ARG USER_ID=1000//g' | \
	sed 's/$USER_ID/50000/g' | \
	sed 's/ARG GROUP_ID=1000//g' | \
	sed 's/$GROUP_ID/50000/g' \
	> Dockerfile
mv Dockerfile azerothcore-wotlk/apps/docker/Dockerfile

VERSION=$(git show -s --format=%ci | cut -d ' ' -f 1 | tr - .)
PACKAGE=acore
if [[ "$p" == "y" ]]
then
	PACKAGE=$PACKAGE-playerbot
fi


if [[ "$target" == "-" ]]
then
	podman build --target db-import --squash-all \
		--tag docker.io/zjwilliams/$PACKAGE-db-import:$VERSION azerothcore-wotlk \
		--file azerothcore-wotlk/apps/docker/Dockerfile
	podman build --target worldserver --squash-all \
		--tag docker.io/zjwilliams/$PACKAGE-worldserver:$VERSION azerothcore-wotlk \
		--file azerothcore-wotlk/apps/docker/Dockerfile
	podman build --target authserver --squash-all \
		--tag docker.io/zjwilliams/$PACKAGE-authserver:$VERSION azerothcore-wotlk \
		--file azerothcore-wotlk/apps/docker/Dockerfile
	podman build --target client-data --squash-all \
		--tag docker.io/zjwilliams/$PACKAGE-client-data:$VERSION azerothcore-wotlk \
		--file azerothcore-wotlk/apps/docker/Dockerfile
	podman build --target tools --squash-all \
		--tag docker.io/zjwilliams/$PACKAGE-tools:$VERSION azerothcore-wotlk \
		--file azerothcore-wotlk/apps/docker/Dockerfile
elif [[ "$target" == "db-import" ]]
then
	podman build --target db-import --squash-all \
                --tag docker.io/zjwilliams/$PACKAGE-db-import:$VERSION azerothcore-wotlk \
                --file azerothcore-wotlk/apps/docker/Dockerfile
elif [[ "$target" == "worldserver" ]]
then
	podman build --target db-worldserver --squash-all \
                --tag docker.io/zjwilliams/$PACKAGE-worldserver:$VERSION azerothcore-wotlk \
                --file azerothcore-wotlk/apps/docker/Dockerfile
elif [[ "$target" == "authserver" ]]
then
	podman build --target authserver --squash-all \
                --tag docker.io/zjwilliams/$PACKAGE-authserver:$VERSION azerothcore-wotlk \
                --file azerothcore-wotlk/apps/docker/Dockerfile
elif [[ "$target" == "client-data" ]]
then
	podman build --target client-data --squash-all \
                --tag docker.io/zjwilliams/$PACKAGE-client-data:$VERSION azerothcore-wotlk \
                --file azerothcore-wotlk/apps/docker/Dockerfile
elif [[ "$target" == "tools" ]]
then
	podman build --target tools --squash-all \
                --tag docker.io/zjwilliams/$PACKAGE-tools:$VERSION azerothcore-wotlk \
                --file azerothcore-wotlk/apps/docker/Dockerfile
else
	echo "Invalid target. Valid options are: db-import, worldserver, authserver, client-data, tools"
fi

if [[ "$P" == "y" ]]
then
	if [[ "$target" == "-" ]]
	then
		podman push docker.io/zjwilliams/$PACKAGE-db-import:$VERSION
		podman push docker.io/zjwilliams/$PACKAGE-worldserver:$VERSION
		podman push docker.io/zjwilliams/$PACKAGE-authserver:$VERSION
		podman push docker.io/zjwilliams/$PACKAGE-client-data:$VERSION
		podman push docker.io/zjwilliams/$PACKAGE-tools:$VERSION
	elif [[ "$target" == "db-import" ]]
	then
	        podman push docker.io/zjwilliams/$PACKAGE-db-import:$VERSION
	elif [[ "$target" == "worldserver" ]]
	then
                podman push docker.io/zjwilliams/$PACKAGE-worldserver:$VERSION
	elif [[ "$target" == "authserver" ]]
	then
                podman push docker.io/zjwilliams/$PACKAGE-authserver:$VERSION
	elif [[ "$target" == "client-data" ]]
	then
                podman push docker.io/zjwilliams/$PACKAGE-client-data:$VERSION
	elif [[ "$target" == "tools" ]]
	then
                podman push docker.io/zjwilliams/$PACKAGE-tools:$VERSION
	else
	        echo "Invalid target. Valid options are: db-import, worldserver, authserver, client-data, tools"
	fi
fi
