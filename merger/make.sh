#############################################################################
# make.sh: functions for building, testing and distributing a newly merged
# Sage.  This contains only function definitions and will be merged from
# main.sh.
#
# AUTHORS:
#
# - Jeroen Demeyer (2010-10-22): initial version for sage-4.6.1
#
#############################################################################

#*****************************************************************************
#       Copyright (C) 2010 Jeroen Demeyer <jdemeyer@cage.ugent.be>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#  as published by the Free Software Foundation; either version 2 of
#  the License, or (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************


# Build Sage
build_sage()
{
	# Intentionally break HTTP
	export http_proxy="http://localhost:9"
	export HTTP_PROXY="http://localhost:9"

	echo "<see $LOGDIR/build.log>"
	$MAKE build &> >( tee "$LOGDIR/build.log" /dev/fd/3 |grep --line-buffered '^Finished installing ' )

	# Copy required GCC runtime libraries into local/lib
	cp -pdv "$MERGER_DIR/lib"/* local/lib

	check_build_log
}

# Build the HTML and PDF documentation and check the logs
build_doc()
{
	echo "<see $LOGDIR/dochtml.log>"
	$MAKE doc-html &> >( tee "$LOGDIR/dochtml.log" >&3 )
	
	echo "<see $LOGDIR/docpdf.log>"
	$MAKE doc-pdf &> >( tee "$LOGDIR/docpdf.log" >&3 )

	check_doc_log
}


# Usage: test_sage
# ptest and ptestlong Sage
test_sage()
{
	$MAKE start

	# Allow everybody to write these logfiles, in particular the
	# buildbot user.
	touch ptest.log ptestlong.log
	chmod 0666 ptest.log ptestlong.log

	# Add symlinks to support #14328
	mkdir -p logs
	ln -s ../ptest.log logs/ptest.log
	ln -s ../ptestlong.log logs/ptestlong.log

	# Run this as the "buildbot" user with HOME=/ to check that
	# we don't require write access to $SAGE_ROOT (#5155)
	# nor $HOME, as long as $DOT_SAGE is writable.  We use
	# --nodotsage for this (#11932).
	echo "<see $LOGDIR/tests.log>"
	ssh "buildbot@`hostname`" <<EOF &> >( tee "$LOGDIR/tests.log" >&3 )

cd "$BUILD"

# Allow at most 2.5GB of virtual memory for doctests
ulimit -v 2500000

export SAGE_CRASH_LOGS=\$HOME/crashlogs
export HOME=/
export PATH="$MERGER_DIR/bin/test:/usr/bin:/bin"
export MAKE="\$MAKE"
unset VIRTUAL_ENV

env | sort
echo "############################################################"

`$MAKE -j1 -n ptest ptestlong |sed -n 's|[.]/sage -t|./sage --nodotsage -t|p'`

# Always exit successfully, we check for errors later
exit 0

EOF

	chmod 0644 "$BUILD/logs/ptest.log" "$BUILD/logs/ptestlong.log"
	cp -v "$BUILD/logs/ptest.log" "$BUILD/logs/ptestlong.log" "$LOGDIR"
	check_test_log "$LOGDIR/ptest.log"
	check_test_log "$LOGDIR/ptestlong.log"
}


# Usage: check_build_log
# Check whether there is anything suspicious in build.log
check_build_log()
{
	if grep -q -i -w downloading "$LOGDIR/build.log"; then
		echo >&2 "Build needs to download:"
		grep >&2 -i -w downloading "$LOGDIR/build.log"
		exit 1
	fi

	cd `$BUILD/sage --sh -c 'echo $SAGE_LOGS'`
	if grep -l "^WARNING" *.log |grep -v -q -e '^maxima-' -e '^singular-3-1-5.*' ; then
		echo >&2 "Build warnings:"
		grep >&2 "^WARNING" *.log
		exit 1
	fi
}


# Usage: check_doc_log
# Check whether there is anything suspicious in doc*.log
check_doc_log()
{
	# grep through the doc logs for errors
	(
		cd "$LOGDIR"
		exec 2>&1

		# grep returns a 1 status if it doesn't find a match.
		# We need set +e to make sure this is not seen as an error.
		set +e
		grep --with-filename -e WARNING dochtml.log
		grep --with-filename -e 'Segmentation fault' -e SEVERE -e ERROR -e '^make.*Error' -e 'Exception occurred' -e 'Sphinx error' dochtml.log docpdf.log
		exit 0  # Exit subshell successfully
	) > "$LOGDIR/docerror.log"

	# Check whether docerror.log is non-empty
	if [ -s "$LOGDIR/docerror.log" ]; then
		echo >&2 "Problems while building the documentation:"
		cat >&2 "$LOGDIR/docerror.log"
		exit 1
	fi
	rm "$LOGDIR/docerror.log"
}


# Usage: check_test_log <logfile>
# Let ``logfile`` be the logfile of some ./sage -t or -tp command.
# Check whether any errors occured, but allow errors for tests in
# $test_xfail
check_test_log()
{
	local logfile="$1"

	# Logfile should exist
	if ! [ -r "$logfile" ]; then
		echo >&2 "Test logfile $logfile does not exist"
		exit 1
	fi
	
	# Last lines should contain "Total time for all tests:"
	if ! tail -n3 "$logfile" |grep -q "^Total time for all tests:"; then
		echo >&2 "Test log $logfile seems to be unfinished"
		echo >&2 "Last 20 lines are:"
		tail >&2 -n20 "$logfile"
		exit 1
	fi

	# Extract the list of tests which failed
	local failed="$BUILD/failed.log"
	sed -n 's/^\t*sage -t[^/]* \([^ ]\+\) *#.*/\1/p' "$logfile" >"$failed"

	# Read lines from $failed and check whether they match $test_xfail
	failed_tests=""
	while read test; do
		local ignore=
		for xfail in $test_xfail; do
			if [ "$test" = "$xfail" ]; then
				ignore=yes
			fi
		done
		if [ "$ignore" != "yes" ]; then
			failed_tests="$failed_tests $test"
		fi
	done <"$failed"

	if [ "$failed_tests" != "" ]; then
		echo >&2 "The following tests failed (see $1):"
		echo >&2 $failed_tests
		exit 1
	fi
}


# Create source and binary distributions of Sage
dist_sage()
{
	cd "$BUILD"

	# Source distribution
	echo "<see $LOGDIR/sdist.log>"
	( ./sage --sdist "$VERSION" && ./sage --rsyncdist "$VERSION" ) &> >( tee "$LOGDIR/sdist.log" >&3 )

	# Binary distribution (with hostname)
	echo "<see $LOGDIR/bdist.log>"
	./sage --bdist "$VERSION-`uname -n`" &> >( tee "$LOGDIR/bdist.log" >&3 )
}


# Run dist_sage to create source and binary distributions of Sage,
# put them in $DIST, copy release notes and compute MD5 checksums
copy_dist()
{
	cd "$BUILD/dist"

	# Copy various tarballs and compute MD5 and SHA256 checksums
	for tarfile in *.tar *.tar.gz; do
		md5sum $tarfile >"$DIST/$tarfile.md5"
		sha256sum $tarfile >"$DIST/$tarfile.sha256"
		cp -pv $tarfile "$DIST"
	done

	# Upgrade path, first remove old version
	rm -rf "$DIST/sage-$VERSION"
	cp -pr "sage-$VERSION" "$DIST"

	# Release notes
	cp -v "$LOGDIR/tickets.html" "$LOGDIR/sage-$VERSION.txt" "$DIST"
}

# Test whether the various hg repositories are clean.
check_spkg_hg()
{
	for dir in `find dist -name .hg -type d`; do
		# Now check the hg status
		if ifoutput "echo '$dir not hg clean:'" "sage --hg -R '$dir/..' status"; then
			return 1
		fi
	done
}
