#!/usr/bin/env bash
#
# git-changelog.sh : generates a CHANGELOG from a GIT history
#
# Sources at <http://github.com/e-picas/git-changelog.git>
# Copyright (c) 2014-2016 Pierre Cassat
# This project is released under the terms of the MIT license;
# see `LICENSE` for details.
#
# Usage:
#
# - with no argument, the help will be displayed
# - with 'all', the whole changelog will be displayed
# - with a TAG1..TAG2, the diff changelog only will be displayed
#
#       git-changelog.sh all
#       git-changelog.sh hash
#       git-changelog.sh TAG1..TAG2
#       git-changelog.sh all CHANGELOG.md
#       git-changelog.sh ... > CHANGELOG
#
set -e

# current version
declare SCRIPT_VERSION='0.1.0'
declare DEV_DEBUG=false

# variables
declare MESSAGE_IGNORE='#no-changelog'
declare CHANGELOG_TITLE='# Change log for remote repository <%s>'
declare HEAD_HEADER='* (upcoming release)'
declare TAG_HEADER='* %(tag) (%(taggerdate:short) - %%s)'
declare TAG_HEADER_NOTORIGIN='    * %(tag) (%(taggerdate:short) - %%s - from remote %%s)'
declare COMMIT_LOG='    * %h - %s (@%cN)'

# throw an error
error() {
    {   echo "> $1"
        echo '---'
        usage
    } >&2
    exit "${2:-1}"
}

# usage string
usage() {
    cat <<MESSAGE
usage:          $0 <type> [filename=NULL]
                $0 [-h|-V|--help|--version]

arguments:
    - <type> in:
        'all'        : get the full repository changes log
        'init'       : get the full repository initial changes log (no tag is used)
        'tag1..tag2' : get the changes log between tag1 and tag2 (tag1 < tag2)
        'hash'       : get a single commit change log message
    - <filename> usage:
        if not set (default) result is written to STDOUT
        is set with types 'all' or 'init', result is written to a file which is opened with EDITOR
MESSAGE
}

# version string
version() {
    echo "GIT-changelog $SCRIPT_VERSION"
}

# help string
help() {
    version
    echo
    usage
    echo
    echo "This is free software under the terms of the MIT license."
    echo "See <http://github.com/e-picas/git-changelog> for sources & updates."
}

# trim a string
trim() {
    echo -e "${1}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//';
}

# repo_remote
repo_remote() {
    echo "$(git remote show -n origin | grep 'Fetch' | cut -d':' -f 2-)"
}

# tag_title TAG_REF
tag_title() {
    local TAGREF=$(tag_header "${1}")
    local isorigin=$(git branch -r --contains "$TAGREF" | wc -l)
    if [ $isorigin -eq 2 ]; then
        local tmp=$(git --no-pager for-each-ref --sort='-taggerdate' --format="$TAG_HEADER" 'refs/tags' | grep " ${1} ")
        printf "$tmp" "$TAGREF"
    else
        local tmp=$(git --no-pager for-each-ref --sort='-taggerdate' --format="$TAG_HEADER_NOTORIGIN" 'refs/tags' | grep " ${1} ")
        local remote=$(git branch -r --contains "$TAGREF" | sed -n 3p)
        printf "$tmp" "$TAGREF" "$remote"
    fi

}

# tag_header TAG_REF
tag_header() {
    git --no-pager show-ref --hash --abbrev "${1}"
}

# tag_history TAG1 TAG2
tag_history() {
    if [ $# -eq 2 ]; then
        if [ -n "$MESSAGE_IGNORE" ]; then
            git --no-pager log --oneline --first-parent --no-merges --decorate --pretty=tformat:"$COMMIT_LOG" "${1}..${2}" | grep -v "$MESSAGE_IGNORE"
        else
            git --no-pager log --oneline --first-parent --no-merges --decorate --pretty=tformat:"$COMMIT_LOG" "${1}..${2}"
        fi
    elif [ $# -eq 1 ]; then
        if [ -n "$MESSAGE_IGNORE" ]; then
            git --no-pager log --oneline --first-parent --no-merges --decorate --pretty=tformat:"$COMMIT_LOG" "${1}" | grep -v "$MESSAGE_IGNORE"
        else
            git --no-pager log --oneline --first-parent --no-merges --decorate --pretty=tformat:"$COMMIT_LOG" "${1}"
        fi
    fi
}

# commit_history HASH
commit_history() {
    if [ -n "$MESSAGE_IGNORE" ]; then
        git --no-pager log --oneline --first-parent --no-merges --decorate --pretty=tformat:"$COMMIT_LOG" -1 "${1}" | grep -v "$MESSAGE_IGNORE"
    else
        git --no-pager log --oneline --first-parent --no-merges --decorate --pretty=tformat:"$COMMIT_LOG" -1 "${1}"
    fi
}

# get_history
get_history() {
    if [ -n "$MESSAGE_IGNORE" ]; then
        git --no-pager log --oneline --all --decorate --pretty=tformat:"$COMMIT_LOG" | grep -v "$MESSAGE_IGNORE"
    else
        git --no-pager log --oneline --all --decorate --pretty=tformat:"$COMMIT_LOG"
    fi
}

# get_changelog TAG1 TAG2
get_changelog() {
    if [ $# -eq 2 ]; then
        local TAG1="${1}"
        local TAG2="${2}"
    elif [ $# -eq 1 ]; then
        local TAG2="${1}"
        local TAG1=''
    else
        return 1
    fi
    if [ "$TAG2" = 'HEAD' ]; then
        echo "$HEAD_HEADER"
    else
        echo "$(tag_title "$TAG2")"
    fi
    echo
    if [ -n "$TAG1" ]; then
        tag_history "$TAG1" "$TAG2"
    else
        tag_history "$TAG2"
    fi
    echo
}

# no argument
if [ $# -eq 0 ]; then
    usage >&2
    exit 1
fi

# -h / --help
if [[ "$1" =~ ^--?h(elp)?$ ]]; then
    help
    exit 0
fi

# -V / --version
if [ "$1" = '-V' ]||[ "$1" = '--version' ]; then
    version
    exit 0
fi

# is it a GIT repo?
if [ ! -e ".git" ]; then
    error "no GIT repository found in '$(pwd)'"
fi

# arguments
ARGS="$1"
FILENAME="${2:-}"

# get the whole repo history
if [ "$ARGS" = 'full' ]||[ "$ARGS" = 'all' ]; then
    REPO=$(repo_remote)
    if [ -n "$FILENAME" ]; then
        {   echo "$(printf "$CHANGELOG_TITLE" "$(trim "$REPO")")"
            echo
        } > "$FILENAME"
    else
        echo "$(printf "$CHANGELOG_TITLE" "$(trim "$REPO")")"
        echo
    fi
    TAG1=''
    TAG2='HEAD'
    all_tags="$(git for-each-ref --sort='-taggerdate' --format='%(refname)' 'refs/tags')"
    COUNTER=1
    TAGSCOUNTER=$(echo "$all_tags" | wc -l )
    echo "$all_tags" | while read tag; do
        TAG1="${tag//refs\/tags\//}"
        if [ -n "$TAG2" ]; then
            if [ -n "$FILENAME" ]; then
                get_changelog "$TAG1" "$TAG2" >> "$FILENAME"
            else
                get_changelog "$TAG1" "$TAG2"
            fi
        else
            if [ -n "$FILENAME" ]; then
                get_changelog "$TAG1" >> "$FILENAME"
            else
                get_changelog "$TAG1"
            fi
        fi
        TAG2="${tag//refs\/tags\//}"
        COUNTER=$((COUNTER+1))
        if [ "$COUNTER" -eq $((TAGSCOUNTER+1)) ]; then
            if [ -n "$FILENAME" ]; then
                get_changelog "$TAG2" >> "$FILENAME"
            else
                get_changelog "$TAG2"
            fi
        fi
    done

    if [ -n "$FILENAME" ]; then
        $EDITOR "$FILENAME"
    fi

# get initial changelog
elif [ "$ARGS" = 'init' ]; then
    REPO=$(repo_remote)
    if [ -n "$FILENAME" ]; then
        {   echo "$(printf "$CHANGELOG_TITLE" "$(trim "$REPO")")"
            echo
            get_history
        } > "$FILENAME"
        $EDITOR "$FILENAME"
    else
        echo "$(printf "$CHANGELOG_TITLE" "$(trim "$REPO")")"
        echo
        get_history
    fi

else

    tag=$(echo "$ARGS" | grep '\.\.')
    # get the history between two tags
    if [ -n "$tag" ]; then
        tmpargs=$(echo "$ARGS" | sed -e 's/\.\./;/g')
        TAG1=$(echo "$tmpargs" | cut -d';' -f 1)
        TAG2=$(echo "$tmpargs" | cut -d';' -f 2)
        get_changelog "$TAG1" "$TAG2"

    else

        commit=$(git branch -a --contains="$ARGS" &>/dev/null; echo $?)
        # get the history of a single commit
        if [ "$commit" = 0 ]; then
            commit_history "$ARGS"

        else
            # else error, args not understood
            error "reference $ARGS not found"

        fi
    fi
fi

exit 0
# vim: autoindent expandtab tabstop=4 shiftwidth=4 softtabstop=4 filetype=sh
