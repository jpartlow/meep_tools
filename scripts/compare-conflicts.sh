#! /bin/bash
#set -x

file=${1}
current=${2:-glisan}
older=${3:-flanders}

if [ -z "$file" ]; then
  echo "Usage: compare-conflicts.sh file [current_version] [older_version]"
  echo "  current_version currently defaults to : $current"
  echo "  older_version currently defaults to   : $older"
  exit 1
fi

tmp=/home/jpartlow/work/tmp
current_out="$tmp/file.$current"
older_out="$tmp/file.$older"

current_ref="upstream/$current"
if ! git rev-parse "$current_ref"; then
  current_ref="$current"
fi

older_ref="upstream/$older"
if ! git rev-parse "$older_ref"; then
  older_ref="$older"
fi


git show "$older_ref":"$file" > "$older_out"
git show "$current_ref":"$file" > "$current_out"
vimdiff "$older_out" "$current_out"
