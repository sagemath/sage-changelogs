#!/usr/bin/env bash

TOP=`pwd`
MERGER_DIR="$TOP/merger"
SAGE_ROOT="$TOP/sage"
DIST="$TOP"
VERSION=9.2
RELEASEMANAGER="Volker Braun"

cd "$SAGE_ROOT"

git fetch
git checkout $VERSION || exit $?
source src/bin/sage-version.sh

source "$MERGER_DIR/main.sh"
setup_logging

git tag -l | \
python "$MERGER_DIR/versionsort.py" >"$LOGDIR/allversions.log"

# Compute version deltas, filtering out "local" tags such as 9.2.beta13+mk-1
while read version; do
    if echo "$version" | grep -q "^$VERSION[^-+]*$" ; then
        if [ -n ${prevversion+} ]; then
            BASEVERSION=${BASEVERSION:-$prevversion}
        fi
        echo "$version $prevversion"
    fi
    if echo "$version" | grep -q -v "[-+]"; then
        prevversion=$version
    fi
done <"$LOGDIR/allversions.log" > "$LOGDIR/versiondelta.log"
echo VERSION=$VERSION
echo BASEVERSION=$BASEVERSION
echo Version deltas:
cat "$LOGDIR/versiondelta.log"

while read version prevversion; do
    git log "$version" "^$prevversion" "--author=Release Manager" "--format=%s" | \
    sed -n 's/^Trac #\([0-9]*\):.*/sage-'$version' \1/p'
done <"$LOGDIR/versiondelta.log" >"$LOGDIR/tickets0.log"

touch "$LOGDIR/spkg.log"
touch "$LOGDIR/patches.log"
touch "$LOGDIR/trac_merged.log"
source "$MERGER_DIR/notes.sh"

cp "$LOGDIR"/*.txt "$DIST/notes"
