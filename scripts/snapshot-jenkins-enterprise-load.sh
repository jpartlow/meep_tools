#! /bin/bash

set -x

downloads=~/Documents/integration/jenkins-load
timestamp=$(date +'%Y-%m-%d_%H.%M.%S%z')
all_url="https://jenkins-enterprise.delivery.puppetlabs.net/overallLoad/graph?type=min&width=1450&height=500"
smoke_url="https://jenkins-enterprise.delivery.puppetlabs.net/label/beaker-integration-smoke/loadStatistics/graph?type=min&width=1370&height=500"
bigjob_url="https://jenkins-enterprise.delivery.puppetlabs.net/label/beaker-bigjob/loadStatistics/graph?type=min&width=1370&height=500"

mkdir -p "$downloads"
pushd "$downloads"
wget -O "load-statistics-$timestamp" "$all_url"
wget -O "smoke-load-statistics-$timestamp" "$smoke_url"
wget -O "bigjob-load-statistics-$timestamp" "$bigjob_url"
popd
