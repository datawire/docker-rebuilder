#!/bin/bash

# This stuff is stack-overflow boilerplate to find the directory this
# script is being run from.

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Here is where the interesting stuff starts.

# The basic strategy we use is to run a customizable background
# container that stays running in order to do our fast incremental
# builds. Then at any point we can produce an image from this
# container by using docker commit to snapshot it's filesystem.

if [ "$1" == "clean" ]; then
    # This cleans up our background container in case we want to do a
    # clean build.
    docker kill builder
    docker rm builder
else
    # Grab the id of the background container
    CONTAINER=$(docker ps -qaf name=builder)

    # If the background container isn't running, we start it.
    if [ -z "${CONTAINER}" ]; then
        docker build . -t poc_container
        CONTAINER=$(docker run --name builder -dit poc_container /bin/sh)
    fi

    # This syncs our source tree with the background container. We
    # just rm the source tree in the container and replace it with our
    # external source. This could probably be made to be smarter, but
    # it seems to work.
    docker cp "${DIR}/build.gradle" "${CONTAINER}:/app"
    docker cp "${DIR}/settings.gradle" "${CONTAINER}:/app"
    docker exec -it "${CONTAINER}" rm -rf /app/src
    docker cp "${DIR}/src" "${CONTAINER}:/app/src"

    # Now after syncing the updated source code, we run the build
    # inside our background container, and if it succeeds we use
    # docker commit to update our image.
    docker exec -it "${CONTAINER}" gradle build && docker commit "${CONTAINER}" poc_container
fi
