#! /usr/bin/env bash
for version in `ls -d pe-* | grep -E 'pe-[0-9].[0-9]+'`; do
    echo "Checking ${version}:"
    pushd $version > /dev/null
    for layout in `ls -d *`; do
        echo " * ${layout}:"
        pushd $layout > /dev/null
        echo "   `git log -1 --pretty='%h %ci %s'`"
        popd > /dev/null
    done 
    popd > /dev/null
done
