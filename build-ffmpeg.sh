#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $ROOT/utils.sh

VERSION=0.9
CC=clang

echo "ffmpeg-build-script v$VERSION"
echo "========================="
echo ""

function ShowUsage () {
	echo "Usage: $0"
    echo "   --build: start building process"
    echo "   --cleanup: remove all working dirs"
    echo "   --help: show this help"
    echo ""
}

while getopts cbd:j:vh OPTION; do
    case "$OPTION" in
        c) COMMAND=clean; break;;
        b) COMMAND=build ;;
        d) WORKSPACE="$OPTARG" ;;
        j) MJOBS="$OPTARG" ;;
        v) VERBOSE=yes ;;
        h) ShowUsage; exit 1 ;;
    esac
done

COMMAND=${COMMAND:-build}
PACKAGES=${PACKAGES:-$ROOT/packages}
WORKSPACE=${WORKSPACE:-$ROOT/workspace}
MJOBS=${MJOBS:-0}
VERBOSE=${VERBOSE:-no}
LDFLAGS="-L${WORKSPACE}/lib -lm" 
CFLAGS="-I${WORKSPACE}/include"
PKG_CONFIG_DIR="${WORKSPACE}/lib/pkgconfig"

make_dir $PACKAGES
make_dir $WORKSPACE

export PATH=${WORKSPACE}/bin:$PATH

if [ "$MJOBS" = 0 ] 
then  
	MJOBS=$(numjobs) ;
fi 
echo "Using $MJOBS make jobs simultaneously."

case "$COMMAND" in
	clean) clean; exit 0 ;;
	build) build $PACKAGES $WORKSPACE; exit 0 ;;
	*) ShowUsage; exit 0 ;;
esac
