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
#       git-changelog.sh all
#       git-changelog.sh --file=CHANGELOG.md ...
#
set -e

# command info
declare -r SCRIPT_VERSION='0.1.0'
declare -r SCRIPT_NAME='GIT-changelog'
declare -r SCRIPT_SOURCES='http://github.com/e-picas/git-changelog'
declare -r SCRIPT_LICENSE='MIT license'
declare -r CMD_PROG="$(basename "$0")"
declare -r short_opts='qvx'
declare -r long_opts='help,version,quiet,verbose,debug,set-opt-v,set-opt-x,\
    file:,mask-title:,mask-header-upcoming:,mask-header-tag:,mask-commit:,tag-ignore:,\
    origin:,master:,remotes:';

# environment flags
declare DEBUG=false
declare QUIET=false
declare VERBOSE=false

# variables
declare TARGET_FILENAME=''
declare TAGNAME_IGNORE='#no-changelog'
declare MASK_GLOBAL_TITLE='# Change log for remote repository <%s>'
declare MASK_HEADER_UPCOMING='* (upcoming release)'
declare MASK_HEADER_TAG='* %(tag) (%(taggerdate:short) - %%s)'
declare MASK_COMMIT_LOG='    * %h - %s (@%cN)'

# repository organization
declare ORIGIN_REMOTE='origin'
declare MASTER_BRANCH='master'
declare ALTERNATE_REMOTES='upstream'

# log messages tagnames
declare -a ADDED_TAGNAMES=( 'added' )
declare -a DEPRECATED_TAGNAMES=( 'deprecated' )
declare -a REMOVED_TAGNAMES=( 'remove' 'removed' )
declare -a FIXED_TAGNAMES=( 'close' 'closes' 'closed' 'fix' 'fixes' 'fixed' 'resolve' 'resolves' 'resolved' )
declare -a CHANGED_TAGNAMES=( 'change' 'changed' )
declare -a SECURITY_TAGNAMES=( 'security' )

# throw an error
error() {
    {   echo "> $1"
        echo '---'
        usage
    } >&2
    exit "${2:-1}"
}

# echo to SDTERR in VERBOSE mode
verbose_echo() {
    $VERBOSE && echo "$*" >&2 || return 0;
}

# echo to SDTERR in DEBUG mode
debug_echo() {
    $DEBUG && echo "$*" >&2 || return 0;
}

# usage string
usage() {
    cat <<MESSAGE
usage: $CMD_PROG [--help] [--version] [-v | --verbose] [-q | --quiet]
            [--file=<path>] [--mask-title=<mask>] [--tag-ignore=<tagname>]
            [--mask-header-upcoming=<mask>] [--mask-header-tag=<mask>] [--mask-commit=<mask>]
            [--origin=<name>] [--master=<name>] [--remotes=<coma,list>]
            <type>
MESSAGE
}

# version string
version() {
    echo "${SCRIPT_NAME} ${SCRIPT_VERSION}"
}

# help string
help() {
    version
    echo
    usage
    cat <<MESSAGE

with <type> in:
        'list-tags'                     get a list of all available tags like '<tag_name>  <tag_hash>  <tag_remote>'
        'all'                           get the full repository changes log
        'init'                          get the full repository initial changes log (no tag is used)
        'tag1..tag2'                    get the changes log between tag1 and tag2 (tag1 < tag2)
        'hash'                          get a single commit change log message

available options:
        --file=<path>                   write the result in a file
        --help                          get this help information
        --mask-commit=<mask>            mask used to build commit message ; default is: '$MASK_COMMIT_LOG'
        --mask-header-tag=<mask>        mask used to build tag title ; default is: '$MASK_HEADER_TAG'
        --mask-header-upcoming=<mask>   mask used to build upcoming release title; default is: '$MASK_HEADER_UPCOMING'
        --mask-title=<mask>             mask used to build global title ; default is: '$MASK_GLOBAL_TITLE'
        --master=<name>                 name of the 'master' branch ; default is: '$MASTER_BRANCH'
        --origin=<name>                 name of the 'origin' remote ; default is: '$ORIGIN_REMOTE'
        -q, --quiet                     decrease script's verbosity
        --remotes=<coma,list>           coma separated list of allowed remotes ; default is: '$ALTERNATE_REMOTES'
        --tag-ignore=<tagname>          tag to match ignored commits ; default is: '$TAGNAME_IGNORE'
        -v, --verbose                   increase script's verbosity
        --version                       get current command version
MESSAGE
    if $DEBUG; then
        cat <<MESSAGE

development options:
        -x, --debug                     enable the DEBUG variable
        --set-opt-x                     enable 'set -x' (internal option): debug commands before to execute them
        --set-opt-v                     enable 'set -v' (internal option): print shell input lines as they are read
MESSAGE
    fi
    echo
    echo "This is free software under the terms of the ${SCRIPT_LICENSE}."
    echo "See <${SCRIPT_SOURCES}> for sources & updates."
}

# trim a string
trim() {
    echo -e "${1}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//';
}

# get first line of a multiline variable
first_line() {
    local arg=( "$*" )
    echo "${arg[0]}"
}

# usage: var_name=( "$(coma_list_to_array <list>)" )
coma_list_to_array() {
    echo "$*" | tr ',' '\n';
}

coma_list_to_regexp() {
    echo "$*" | tr ',' '|';
}

# get_remote_url
get_remote_url() {
    echo "$(git remote show -n origin | grep 'Fetch' | cut -d':' -f 2-)"
}

# build_tag_title TAG_REF
build_tag_title() {
    local TAGREF=$(get_tag_hash "${1}")
    local tmp=$(git --no-pager for-each-ref --sort='-taggerdate' --format="$MASK_HEADER_TAG" 'refs/tags' | grep " ${1} ")
    printf "$tmp" "$TAGREF"
}

# get_history_tag TAG1 TAG2
get_history_tag() {
    local history_tmp=''
    if [ $# -eq 2 ]; then
        history_tmp="$(git --no-pager log --oneline --first-parent --no-merges --decorate --pretty=tformat:"$MASK_COMMIT_LOG" "${1}..${2}")"
    elif [ $# -eq 1 ]; then
        history_tmp="$(git --no-pager log --oneline --first-parent --no-merges --decorate --pretty=tformat:"$MASK_COMMIT_LOG" "${1}")"
    fi
    if [ -n "$TAGNAME_IGNORE" ]; then
        local res="$(echo "$history_tmp" | grep -v "$TAGNAME_IGNORE" &>/dev/null; echo $?)"
        if [ "$res" -gt 0 ]; then
            return 0
        else
            history_tmp="$(echo "$history_tmp" | grep -v "$TAGNAME_IGNORE")"
        fi
    fi
    echo "$history_tmp"
}

# get_history_commit HASH
get_history_commit() {
    local history_tmp="$(git --no-pager log --oneline --first-parent --no-merges --decorate --pretty=tformat:"$MASK_COMMIT_LOG" -1 "${1}")"
    if [ -n "$TAGNAME_IGNORE" ]; then
        local res="$(echo "$history_tmp" | grep -v "$TAGNAME_IGNORE" &>/dev/null; echo $?)"
        if [ "$res" -gt 0 ]; then
            return 0
        else
            history_tmp="$(echo "$history_tmp" | grep -v "$TAGNAME_IGNORE")"
        fi
    fi
    echo "$history_tmp"
}

# get_history_full
get_history_full() {
    local history_tmp="$(git --no-pager log --oneline --all --decorate --pretty=tformat:"$MASK_COMMIT_LOG")"
    if [ -n "$TAGNAME_IGNORE" ]; then
        local res="$(echo "$history_tmp" | grep -v "$TAGNAME_IGNORE" &>/dev/null; echo $?)"
        if [ "$res" -gt 0 ]; then
            return 0
        else
            history_tmp="$(echo "$history_tmp" | grep -v "$TAGNAME_IGNORE")"
        fi
    fi
    echo "$history_tmp"
}

# get the last commit hash on master branch
get_last_commit_hash() {
    git rev-parse "$MASTER_BRANCH"
}

# get a tag commit hash
get_tag_hash() {
    local tagname="$1"
    if [ -e ".git/refs/tags/${tagname}" ]; then
#        git for-each-ref --format='%(objectname)' "refs/tags/${tagname}"
        git --no-pager show-ref --hash --abbrev "${tagname}"
    fi
}

# get the remotes containing a commit hash
get_remotes_from_hash() {
    local hash="$1"
    git branch -r --contains "$hash"
}

# guess original remote of a tag
guess_tag_original_remote() {
    local tagname="$1"
    tag_hash="$(get_tag_hash "$tag")"
    tag_remote=''
    tag_remote_full="$(get_remotes_from_hash "$tag_hash")"
    tag_remote_tmp="$(echo "$tag_remote_full" | grep -v "${ORIGIN_REMOTE}/")"

    if [ $? -eq 0 ]; then
        tag_remote_tmp="$(echo "$tag_remote_tmp" | grep -v "${ORIGIN_REMOTE}/")"
        remotes_grep="$(coma_list_to_regexp "$ALTERNATE_REMOTES")"
        if [ "$(echo "$tag_remote_tmp" | grep -E "(${remotes_grep})/" &>/dev/null; echo $?)" -eq 0  ]; then
            if (( $(grep -c . <<<"$tag_remote_tmp") > 1 )); then
                if [ "$(echo "$tag_remote_tmp" | grep "/${MASTER_BRANCH}" &>/dev/null; echo $?)" -eq 0  ]; then
                    tag_remote="$(echo "$tag_remote_tmp" | grep "/${MASTER_BRANCH}")"
                else
                    tag_remote="$(first_line "$tag_remote_tmp")"
                fi
            else
                tag_remote="$tag_remote_tmp"
            fi
        else
            if [ "$(echo "$tag_remote_tmp" | grep "/${MASTER_BRANCH}" &>/dev/null; echo $?)" -eq 0  ]; then
                tag_remote="$(echo "$tag_remote_tmp" | grep "/${MASTER_BRANCH}")"
            else
                tag_remote="$(first_line "$tag_remote_tmp")"
            fi
        fi
    else
        tag_remote="$(first_line "$(echo "$tag_remote_full" | grep -v ' -> ')")"
    fi

    if [ -n "$tag_remote" ]; then
        echo "$(trim "$tag_remote")"
    fi
}

# get_changelog ref1 [ref2]
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
        echo "$MASK_HEADER_UPCOMING"
    else
        echo "$(build_tag_title "$TAG2")"
    fi
    echo
    if [ -n "$TAG1" ]; then
        get_history_tag "$TAG1" "$TAG2"
    else
        get_history_tag "$TAG2"
    fi
    echo
}

# action 'init'
action_init() {
    verbose_echo "> calling action 'init'"
    REPO=$(get_remote_url)
    if [ -n "$TARGET_FILENAME" ]; then
        {   echo "$(printf "$MASK_GLOBAL_TITLE" "$(trim "$REPO")")"
            echo
            get_history_full
        } > "$TARGET_FILENAME"
        $EDITOR "$TARGET_FILENAME"
    else
        echo "$(printf "$MASK_GLOBAL_TITLE" "$(trim "$REPO")")"
        echo
        get_history_full
    fi
}

# action 'full' or 'all'
action_all() {
    verbose_echo "> calling action 'all'"
    REPO=$(get_remote_url)
    if [ -n "$TARGET_FILENAME" ]; then
        {   echo "$(printf "$MASK_GLOBAL_TITLE" "$(trim "$REPO")")"
            echo
        } > "$TARGET_FILENAME"
    else
        echo "$(printf "$MASK_GLOBAL_TITLE" "$(trim "$REPO")")"
        echo
    fi
    TAG1=''
    TAG2='HEAD'
    all_tags="$(git for-each-ref --sort='-taggerdate' --format='%(refname)' 'refs/tags')"
    COUNTER=1
    TAGSCOUNTER=$(echo "$all_tags" | wc -l)
    echo "$all_tags" | while read tag; do
        TAG1="${tag//refs\/tags\//}"
        if [ -n "$TAG2" ]; then
            if [ -n "$TARGET_FILENAME" ]; then
                get_changelog "$TAG1" "$TAG2" >> "$TARGET_FILENAME"
            else
                get_changelog "$TAG1" "$TAG2"
            fi
        else
            if [ -n "$TARGET_FILENAME" ]; then
                get_changelog "$TAG1" >> "$TARGET_FILENAME"
            else
                get_changelog "$TAG1"
            fi
        fi
        TAG2="${tag//refs\/tags\//}"
        COUNTER=$((COUNTER+1))
        if [ "$COUNTER" -eq $((TAGSCOUNTER+1)) ]; then
            if [ -n "$TARGET_FILENAME" ]; then
                get_changelog "$TAG2" >> "$TARGET_FILENAME"
            else
                get_changelog "$TAG2"
            fi
        fi
    done

    if [ -n "$TARGET_FILENAME" ]; then
        $EDITOR "$TARGET_FILENAME"
    fi
}

# action 'list-tags'
action_list_tags() {
    for tag in $(git tag --sort='-taggerdate'); do
        tag_remote="$(guess_tag_original_remote "tag")"
        tag_hash="$(get_tag_hash "$tag")"
        echo "$tag $tag_hash $tag_remote"
    done
}

action_devtest() {
    debug_echo "# all tags:";
    declare -a all_tags=()
    oldIFS="$IFS"
    IFS='
';
    for tag_line in $(action_list_tags); do
        debug_echo "$tag_line"
        tag="$(echo "$tag_line" | cut -d' ' -f 1)"
        tag_hash="$(echo "$tag_line" | cut -d' ' -f 2)"
        tag_remote="$(echo "$tag_line" | cut -d' ' -f 3)"
        tag_remote_origin="$(echo "$tag_remote" | grep "${BASE_REMOTE}/" || echo '';)"
        if [ $? -eq 0 ]; then
            all_tags["${#all_tags[@]}"]="$tag"
        fi
    done
    IFS="$oldIFS"

    debug_echo "# concerned tags:"
    TAG1=''
    TAG2=''
    COUNTER=1
    TAGSCOUNTER=$(echo "$all_tags" | wc -l )
    for tag in "${all_tags[@]}"; do
        debug_echo "> $tag"
        TAG1="${tag}"
        if [ "$COUNTER" -eq 1 ]; then
            debug_echo "$(get_last_commit_hash)"
            debug_echo "$(get_tag_hash "$TAG1")"
        fi
        if [ "$COUNTER" -eq 1 ] && [ "$(get_last_commit_hash)" != "$(get_tag_hash "$TAG1")" ]; then
            TAG2='HEAD'
        fi
        if [ -n "$TAG2" ]; then
            if [ -n "$TARGET_FILENAME" ]; then
                get_changelog "$TAG1" "$TAG2" >> "$TARGET_FILENAME"
            else
                get_changelog "$TAG1" "$TAG2"
            fi
        fi
        TAG2="${tag}"
        COUNTER=$((COUNTER+1))
        if [ "$COUNTER" -eq $((TAGSCOUNTER+1)) ]; then
            if [ -n "$TARGET_FILENAME" ]; then
                get_changelog "$TAG2" >> "$TARGET_FILENAME"
            else
                get_changelog "$TAG2"
            fi
        fi
    done

}

# special debug action (for development)
action_debug_env() {
    version
    echo
    echo "## command debug"
    echo "DEBUG                 : $DEBUG"
    echo "QUIET                 : $QUIET"
    echo "VERBOSE               : $VERBOSE"
    echo "ORIGIN_REMOTE         : '$ORIGIN_REMOTE'"
    echo "MASTER_BRANCH         : '$MASTER_BRANCH'"
    echo "ALTERNATE_REMOTES     : '$ALTERNATE_REMOTES'"
    echo "TARGET_FILENAME       : '$TARGET_FILENAME'"
    echo "TAGNAME_IGNORE        : '$TAGNAME_IGNORE'"
    echo "MASK_GLOBAL_TITLE     : '$MASK_GLOBAL_TITLE'"
    echo "MASK_HEADER_UPCOMING  : '$MASK_HEADER_UPCOMING'"
    echo "MASK_HEADER_TAG       : '$MASK_HEADER_TAG'"
    echo "MASK_COMMIT_LOG       : '$MASK_COMMIT_LOG'"
}

# user options
getoptvers="$(getopt --test > /dev/null; echo $?)"
if [[ "$getoptvers" -eq 4 ]]; then
    # GNU enhanced getopt is available
    CMD_REQ="$(getopt --shell 'bash' --options "${short_opts}-:" --longoptions "$long_opts" --name "$CMD_PROG" -- "$@")"
else
    # original getopt is available
    verbose_echo "> only the old version of the 'getopt' command is available ; use script options with caution"
    CMD_REQ="$(getopt "shorts" "$@")"
fi
[ "${CMD_REQ// /}" = '--' ] && CMD_REQ='';
[ -n "$CMD_REQ" ] && eval set -- "$CMD_REQ";

while [ $# -gt 0 ]; do
    case "$1" in
        -q | --quiet )      QUIET=true; VERBOSE=false;;
        -v | --verbose )    VERBOSE=true; QUIET=false;;
        -x | --debug )      DEBUG=true;;
        --set-opt-x )
            ## for dev usage: debug commands before to execute them
            set -x
            ;;
        --set-opt-v )
            ## for dev usage: print shell input lines as they are read
            set -v
            ;;
        --version )
            version; exit 0;;
        --help )
            help; exit 0;;
        --file )
            TARGET_FILENAME="$(echo "$2" | cut -d'=' -f2)"
            verbose_echo "> result will be written in file '$TARGET_FILENAME'"
            shift;;
        --mask-title )
            MASK_GLOBAL_TITLE="$(echo "$2" | cut -d'=' -f2)"
            verbose_echo "> mask title over-written as '$MASK_GLOBAL_TITLE'"
            shift;;
        --mask-header-upcoming )
            MASK_HEADER_UPCOMING="$(echo "$2" | cut -d'=' -f2)"
            verbose_echo "> mask header for upcoming release over-written as '$MASK_HEADER_UPCOMING'"
            shift;;
        --mask-header-tag )
            MASK_HEADER_TAG="$(echo "$2" | cut -d'=' -f2)"
            verbose_echo "> mask header for tags over-written as '$MASK_HEADER_TAG'"
            shift;;
        --mask-commit )
            MASK_COMMIT_LOG="$(echo "$2" | cut -d'=' -f2)"
            verbose_echo "> mask for commit messages over-written as '$MASK_COMMIT_LOG'"
            shift;;
        --tag-ignore )
            TAGNAME_IGNORE="$(echo "$2" | cut -d'=' -f2)"
            verbose_echo "> tag to match ignored commits over-written as '$TAGNAME_IGNORE'"
            shift;;
        --master )
            MASTER_BRANCH="$(echo "$2" | cut -d'=' -f2)"
            verbose_echo "> master branch over-written as '$MASTER_BRANCH'"
            shift;;
        --origin )
            ORIGIN_REMOTE="$(echo "$2" | cut -d'=' -f2)"
            verbose_echo "> origin remote over-written as '$ORIGIN_REMOTE'"
            shift;;
        --remotes )
            ALTERNATE_REMOTES="$(echo "$2" | cut -d'=' -f2)"
            verbose_echo "> allowed remotes over-written as '$ALTERNATE_REMOTES'"
            shift;;
        -- )    shift; break;;
        * )     error "unknown option '$1'";;
    esac
    shift
done

# is it a GIT repo?
if [ ! -e ".git" ]; then
    error "no GIT repository found in '$(pwd)'"
fi

# no argument
if [ $# -eq 0 ]; then
    usage >&2
    exit 1
fi

# arguments
ARG="$1"

# special development action
if [ "$ARG" = 'debug' ]; then
    action_debug_env;

# devtest
elif [ "$1" = 'devtest' ]; then
    action_devtest;

# get the list of all tags
elif [ "$ARG" = 'list-tags' ]; then
    action_list_tags;

# get the whole repo history
elif [ "$ARG" = 'full' ]||[ "$ARG" = 'all' ]; then
    action_all;

# get initial changelog
elif [ "$ARG" = 'init' ]; then
    action_init;

else

    tag=$(echo "$ARG" | grep '\.\.' &>/dev/null; echo $?)
    # get the history between two tags
    if [ "$tag" -eq 0 ]; then
        verbose_echo "> getting diff between references"
        tmpargs=$(echo "$ARG" | sed -e 's/\.\./;/g')
        TAG1=$(echo "$tmpargs" | cut -d';' -f 1)
        TAG2=$(echo "$tmpargs" | cut -d';' -f 2)
        get_changelog "$TAG1" "$TAG2"

    else

        commit=$(git branch -a --contains="$ARG" &>/dev/null; echo $?)
        # get the history of a single commit
        if [ "$commit" = 0 ]; then
            verbose_echo "> getting commit message"
            get_history_commit "$ARG"

        else
            # else error, argument not understood
            error "reference '$ARG' not found"

        fi
    fi
fi

exit 0
# vim: autoindent expandtab tabstop=4 shiftwidth=4 softtabstop=4 filetype=sh
