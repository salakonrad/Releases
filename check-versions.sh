#!/usr/bin/env bash
set -e
function check_repo {
    if [ $# -eq 0 ]; then
        printf "Usage: check_repo REPOSITORY [BRANCH]\n"
        exit
    fi
    INIT_DIR=$(pwd)
    mkdir -p repos/
    cd repos/
    RELEASEMSG="[maven-release-plugin] prepare for next development iteration"
    RELEASEMSG2="[post-release] Restoring SNAPSHOT dependencies and parent back"
    REPO=$1
    if [ -z "$2" ]; then
        BRANCH="develop"
    else
        BRANCH=$2
    fi
    NAME=$(echo $REPO | awk -F/ '{print $NF}' | awk -F. '{print $1}')
    printf "$NAME:\n"
    git clone -b $BRANCH $REPO &> /dev/null
    cd $NAME
    printf "  needs release: "
    LASTMSG=$(git log --pretty="format:%s" | head -n 1)
    if [ "$RELEASEMSG" == "$LASTMSG" ] ; then
        ANSWER="NO"
    elif [ "$RELEASEMSG2" == "$LASTMSG" ] ; then
        ANSWER="NO"
    else
        ANSWER="YES"
    fi
    printf "$ANSWER\n"
    if [ "$ANSWER" == "YES" ] ; then
        git fetch --tags &> /dev/null
        LASTTAG=$(git describe $(git rev-list --tags --max-count=1))
        printf "  last tag: $LASTTAG\n"
    fi
    cd $INIT_DIR
}

rm ./repos -rf
check_repo git@gitlab.xyz.net/abc.git develop