#!/bin/bash
set -ev
docker build -t openservice/acl-database:latest .

if [ "${TRAVIS_PULL_REQUEST}" = "false" ] && [ "${TRAVIS_REPO_SLUG}" = "InteractiveLecture/acl-database" ] ; then
  docker login -u="$DOCKER_USERNAME" -p="$DOCKER_PASSWORD" -e="$DOCKER_EMAIL"
  docker push openservice/acl-database:latest
fi
