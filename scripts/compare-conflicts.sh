#! /bin/bash
set -x

file=${1:?}
current=${2:-flanders}
older=${3:-2016.5.x}

tmp=/home/jpartlow/work/tmp
current_out="$tmp/file.$current"
older_out="$tmp/file.$older"

git show "upstream/$older":"$file" > "$older_out"
git show "upstream/$current":"$file" > "$current_out"
vimdiff "$older_out" "$current_out"
