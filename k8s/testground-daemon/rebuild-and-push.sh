#!/bin/bash

set -o errexit
set -o pipefail

set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

pushd $GOPATH/src/github.com/testground/testground
docker build -t nonsens3/testground:daemon -f Dockerfile.daemon .
docker push nonsens3/testground:daemon
popd
