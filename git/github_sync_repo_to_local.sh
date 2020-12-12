#!/bin/bash
# https://www.linkedin.com/in/vadimzenin/
# Usage:
# . ./github_sync_repo_to_local.sh
# Tested on Ubuntu 18.04

################################################################################
# Main
################################################################################
function f_echoerr() { 
  echo "$@" 1>&2
}

function f_printferr() { 
  printf "$@\n" 1>&2
}

GITHUB_ORG="MyOrg"
 GITHUB_API_TOKEN="${1:-${GITHUB_API_TOKEN}}"
COMPANY_NAME_SHORT="${2:-${COMPANY_NAME_SHORT:-abc}}"
REPOS_LOCAL_DIR="$HOME/1vz/repos/${COMPANY_NAME_SHORT}"
# curl -i -u ${GITHUB_USER} https://api.github.com/orgs/${GITHUB_ORG}/repos?type=all,per_page=500
# curl -s -H "Authorization: token ${GITHUB_API_TOKEN}" "https://api.github.com/orgs/${GITHUB_ORG}/repos?type=all&per_page=500"
# curl -is -H "Authorization: token ${GITHUB_API_TOKEN}" "https://api.github.com/orgs/${GITHUB_ORG}/repos?type=all&per_page=500" | grep -o 'git@[^"]*'
# curl -is -H "Authorization: token ${GITHUB_API_TOKEN}" "https://api.github.com/orgs/${GITHUB_ORG}/repos?type=all&per_page=500" | grep -o 'name'
pushd ${REPOS_LOCAL_DIR}
curl -s -H "Authorization: token ${GITHUB_API_TOKEN}" "https://api.github.com/orgs/${GITHUB_ORG}/repos?type=all&per_page=500" | jq -r '.[].name' | tee ${REPOS_LOCAL_DIR}/${COMPANY_NAME_SHORT}-repos.txt

for REPO_PATH in $(cat ${REPOS_LOCAL_DIR}/${COMPANY_NAME_SHORT}-repos.txt) ; do 
  printf "INFO: processing ${REPO_PATH}\n"
  pushd ${REPOS_LOCAL_DIR}
  if [[ -d ${REPO_PATH} ]]; then
    pushd ${REPO_PATH}
    git checkout master
    git pull origin master
    popd
  else
    git clone git@github.com:MyOrg/${REPO_PATH}.git
  fi
  popd
done
