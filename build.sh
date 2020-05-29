#!/bin/bash

VERSION='0.1.0'
IMAGE_REPOSITORY='matteverett/homeauto-api'

scriptDir=`dirname $(readlink -f "$0" 2> /dev/null)`

docker build ${scriptDir} -f ${scriptDir}/docker/Dockerfile -t ${IMAGE_REPOSITORY}:${VERSION} --network host
docker push ${IMAGE_REPOSITORY}:${VERSION}
