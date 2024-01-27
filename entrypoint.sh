#!/usr/bin/env bash

set -x

UPSTREAM_REPO=$1
UPSTREAM_BRANCH=$2
DOWNSTREAM_BRANCH=$3
GITHUB_TOKEN=$4
FETCH_ARGS=$5
MERGE_ARGS=$6
PUSH_ARGS=$7
SPAWN_LOGS=$8
DOWNSTREAM_REPO=$9
BRANCH_PREFIX=${10}

target_remote=origin

if [[ -z "$UPSTREAM_REPO" ]]; then
  echo "Missing \$UPSTREAM_REPO"
  exit 1
fi

if [[ -z "$DOWNSTREAM_BRANCH" ]]; then
  echo "Missing \$DOWNSTREAM_BRANCH"
  echo "Default to ${UPSTREAM_BRANCH}"
  DOWNSTREAM_BRANCH=$UPSTREAM_BRANCH
fi

echo "UPSTREAM_REPO=$UPSTREAM_REPO"
if [[ $DOWNSTREAM_REPO == "GITHUB_REPOSITORY" ]]
then
  git clone $UPSTREAM_REPO work
  cd work || { echo "Missing work dir" && exit 2 ; }
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${UPSTREAM_REPO/https:\/\/github.com\//}"
  git fetch ${FETCH_ARGS} origin
else
  git clone $DOWNSTREAM_REPO work
  cd work || { echo "Missing work dir" && exit 2 ; }
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${DOWNSTREAM_REPO/https:\/\/github.com\//}"
  git remote add upstream "$UPSTREAM_REPO"
  git fetch ${FETCH_ARGS} upstream
  target_remote=upstream
fi

git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
git config --local user.password ${GITHUB_TOKEN}

git remote -v
ls -al
echo $(dirname "$0")/get-latest-branch.sh
ls -al /home/ci
pwd
if [[ $BRANCH_PREFIX != "" ]]
then
  latest_branch=$($(dirname "$0")/get-latest-branch.sh $BRANCH_PREFIX)
  if [[ $latest_branch == $DOWNSTREAM_BRANCH ]]
  then
    echo "PASS: The input $DOWNSTREAM_BRANCH branch is the latest version"
  else
    echo "FAIL: The input $DOWNSTREAM_BRANCH branch is NOT the latest version($latest_branch)"
    rm -rf ../work
    exit 1
  fi
fi  

git checkout ${DOWNSTREAM_BRANCH}

case ${SPAWN_LOGS} in
  (true)    echo -n "sync-upstream-repo https://github.com/dabreadman/sync-upstream-repo keeping CI alive."\
            "UNIX Time: " >> sync-upstream-repo
            date +"%s" >> sync-upstream-repo
            git add sync-upstream-repo
            git commit sync-upstream-repo -m "Syncing upstream";;
  (false)   echo "Not spawning time logs"
esac

git push origin

MERGE_RESULT=$(git merge ${MERGE_ARGS} ${target_remote}/${UPSTREAM_BRANCH})

echo ${MERGE_RESULT}

if [[ $MERGE_RESULT == "" ]] || [[ $MERGE_RESULT == *"merge failed"* ]]
then
  exit 1
elif [[ $MERGE_RESULT != *"Already up to date."* ]]
then
  git commit -m "Merged upstream"
  git push ${PUSH_ARGS} origin ${DOWNSTREAM_BRANCH} || exit $?
fi

cd ..
rm -rf work
