#! /bin/sh

### This script automates creating a pull request
### by publishing your current topic branch to your remote,
### opening the pull request page in your browser,
### and (optionally) switching you back to your master branch 
### so that you can start a new branch.

## Get arguments
# Invoke with no arguments to print usage
print_usage_and_exit () {
    echo >&2
    echo >&2 "Usage: `basename $0` [-t <fork:branch>] [-m <master>] <remote_name>"
    echo >&2
    echo >&2 "\t<remote_name>:\tThe name of the remote to which to publish your current branch"
    echo >&2 "\t   \t\tto serve as the source of the pull request."
    echo >&2 "\t   \t\tA branch \"[foo/]bar\" will be published as \"username/bar\"."
    echo >&2 "\t   \t\tYou must set your username in the script."
    echo >&2
    echo >&2 "\t-t:\t\tThe target fork/branch to which to submit the pull request."
    echo >&2 "\t   \t\tIf not specified, Github will target the default branch of the specified remote,"
    echo >&2 "\t   \t\tunless your remote is a fork of another repo, in which case Github will target"
    echo >&2 "\t   \t\tthe default branch of that repo."
    echo >&2
    echo >&2 "\t-m:\t\tThe name of the branch (e.g. master) to switch to after the pull request has been submitted."
    echo >&2 "\t   \t\tAfter switching to this branch, this script will fetch/pull the branch and update submodules."
    echo >&2 "\t   \t\tThis argument is not used to set the request target (see the -t option)."
    echo >&2

    exit 2
}

NAME="foo"
if [[ "$NAME" == "foo" ]]; then
    echo "You must set NAME=<your name> before running this script."
    exit 1
fi

while getopts t:m: OPTION
do
    case ${OPTION} in
        t) REQUEST_TARGET=$OPTARG;;
        m) MASTER=$OPTARG;;
      [?]) print_usage_and_exit;;
    esac
done
shift $((OPTIND-1))

REMOTE=$1
if [[ -z "${REMOTE}" ]]; then
    print_usage_and_exit
fi

## Determine base url to submit pull request
# (use perl for minimal matching, not supported by bash/sed)
request_base_url=`git remote -v show | tr '\n' ' ' | perl -pe 's|.*${REMOTE}\s+?git@(.*?):(.*?)\.git\s+?\(push\).*|http://\1/\2/pull/new/|'`
if [[ -n "${REQUEST_TARGET}" ]]; then
    target_fork=${REQUEST_TARGET%:*}
    target_branch=${REQUEST_TARGET#*:}
    if [ -z "${target_fork}" ] || [ -z "${target_branch}" ]; then
        print_usage_and_exit
    fi
    request_base_url=${request_base_url}${target_fork}:${target_branch}...
fi

## Publish current branch [foo/]bar as username/bar
# get branch name
raw_current_branch=`git branch | grep "*"`
current_branch=${raw_current_branch#* }

# get last component of branch name
current_branch_name=${current_branch##*\/}

# publish branch, setting tracking at the same time
# (the extended format is necessary because the local and remote branch names may differ)
remote_branch_name=$NAME/$current_branch_name
git push -u $REMOTE $current_branch:refs/heads/$remote_branch_name

## Open browser to submit pull request from published branch
pull_request_url=${request_base_url}${remote_branch_name}
open $pull_request_url

## Move branch to archive and switch back to master if specified
if [[ -n "${MASTER}" ]]; then
    git checkout $MASTER
    git fetch $REMOTE && git pull && git submodule update --init --recursive

    git branch -m ${current_branch} archive/${current_branch_name}
fi