#! /usr/bin/env bash

address=$(ip addr show scope global | grep inet | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
echo "{\"address\":\"$address\"}"
