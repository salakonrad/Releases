#!/usr/bin/env bash
set -e
set -x
if [ ! -d ./repos ]; then
    echo "Please run check-versions job first!"
    exit
fi
function release_repo {
    if [ $# -lt 6 ]; then
        printf "Usage: release_repo REPOSITORY RELEASE_VERSION DEVELOPMENT_VERSION RELEASE_BRANCH branch-delete|no-branch-delete new-branch|existing-branch [RELEASE_PROFILE]\n"
        exit
    fi
    RELEASE_BRANCH=$4
    BRANCH_DELETE=$5
    BRANCH_STATUS=$6

    INIT_DIR=$(pwd)
    REPO=$1
    NAME=$(echo $REPO | awk -F/ '{print $NF}' | awk -F. '{print $1}')
    printf "Releasing $NAME... "
    cd repos/$NAME

    if [ $BRANCH_STATUS == "new-branch" ]; then
        git checkout -b $RELEASE_BRANCH
    elif [ $BRANCH_STATUS == "existing-branch" ]; then
        git checkout $RELEASE_BRANCH
    fi

    mvn -B versions:use-dep-version -DforceVersion=true -Dincludes=com.bombardier.* -DdepVersion=1.0.0
    mvn -B versions:use-latest-versions -Dincludes=com.bombardier.* -DallowSnapshots=false versions:update-parent
    mvn -B versions:commit
    git commit -am "[pre-release] Using latest release dependencies and parent"
    if [ ! -z $7 ] ; then
        PROFILE=-P$7
    fi

    if [ $NAME == "master" ] ; then
        mvn $PROFILE -B -Dtag=MDC-TEST-SA-$2 -DreleaseVersion=$2 -DdevelopmentVersion=$3 release:prepare release:perform
    elif [ $NAME == "gp" ]; then
        mvn $PROFILE -B -Dtag=mdc-$2 -DreleaseVersion=$2 -DdevelopmentVersion=$3 release:prepare release:perform
    else
        mvn $PROFILE -B -DreleaseVersion=$2 -DdevelopmentVersion=$3 release:prepare release:perform
    fi
    mvn -B versions:use-dep-version -DforceVersion=true -Dincludes=com.bombardier.* -DdepVersion=1.0.0-SNAPSHOT
    mvn -B versions:use-latest-versions -Dincludes=com.bombardier.* -DallowSnapshots=true
    mvn -B versions:update-parent -DallowSnapshots=true -DparentVersion=1.1.0-SNAPSHOT
    mvn -B versions:commit &> /dev/null
    git commit -am "[post-release] Restoring SNAPSHOT dependencies and parent back"
    if [ $NAME == "authentication-service" ] ; then
        mvn -B clean deploy -Dtests.skip -Dmaven.install.skip=true -Dmaven.test.skip=true -Pansible,adapter-native,adapter-jms,broadcast-jms,broadcast-jca
    elif [ $NAME == "notification-gateway" ]; then
        mvn -B deploy -Dtests.skip -Dmaven.install.skip=true -Dmaven.test.skip=true -Pansible	    
    else
        mvn -B deploy -Dtests.skip -Dmaven.install.skip=true -Dmaven.test.skip=true
    fi
    git push --set-upstream origin $RELEASE_BRANCH

    git checkout master
    git merge -m "Merge $RELEASE_BRANCH branch into master" $RELEASE_BRANCH

    git checkout develop
    git merge -m "Merge $RELEASE_BRANCH branch into develop" $RELEASE_BRANCH

    if [ $BRANCH_DELETE == "branch-delete" ]; then
        git branch -D $RELEASE_BRANCH
        git push --all && git push --tags
        git push --delete origin $RELEASE_BRANCH
        printf "Pushed - Release branch removed."
    elif [ $BRANCH_DELETE == "no-branch-delete" ]; then
        git push --all && git push --tags
        printf "Pushed - Release branch not removed."
    fi

    printf "released.\n"
    cd $INIT_DIR
}

#release_repo git@gitlab.xyz.net/abc.git 1.0.9 1.1.0-SNAPSHOT release/7.9.1 no-branch-delete new-branch