#############################################################################
# init.sh: Initialization of the merger scripts.  This will be sourced by
# the "init_merger" function.
#
# AUTHORS:
#
# - Jeroen Demeyer (2010-10-28): initial version for sage-4.6.1
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

# Setup various (environment) variables for the merger
setup_environment()
{
	# Normalize some environment variables.  Note the inclusion of
	# bin in the $PATH which contains some useful executables but
	# also some disable executables like "autoconf" which should not
	# be used.
	export MAKE="/usr/bin/make -j6"
	export PATH="$MERGER_DIR/bin/ccache:$MERGER_DIR/bin:/usr/local/bin:/usr/bin:/bin"
	export TZ=UTC

	export SAGE_PARALLEL_SPKG_BUILD=no   # Better predictability, logs easier to read
	export SAGE_INSTALL_GCC=no

	# Provide default values for all the unset variables
	[ -n "$SAGE_MERGER_TOP" ] || SAGE_MERGER_TOP="$HOME/merger"
	[ -n "$TMPDIR" ] || TMPDIR=`readlink -mv "$SAGE_MERGER_TOP/tmp"`
	[ -n "$DOWNLOADS" ] || DOWNLOADS="$SAGE_MERGER_TOP/downloads"
	[ -n "$PATCHES" ] || PATCHES="$SAGE_MERGER_TOP/patches"
	[ -n "$BUILD" ] || BUILD="$SAGE_MERGER_TOP/sage-$VERSION"
	[ -n "$LOGDIR" ] || LOGDIR="$DIST/logs"
	[ -n "$RELEASEURL" ] || RELEASEURL="http://boxen.math.washington.edu/home/release"
	[ -n "$TRACURL" ] || TRACURL="http://trac.sagemath.org/sage_trac"
	[ -n "$RELEASEMANAGER" ] || RELEASEMANAGER=`getrealname`
	export TMPDIR
	
	# Check that VERSION and OLDVERSION are specified
	if [ -z "$VERSION" ]; then
		echo >&2 "init_merger: no VERSION specified!"
		exit 1
	fi
}
	

# Usage: mkdirlink <dir>
# Like mkdir -p dir, but dereferences components of dir if they are
# dangling symbolic links.
mkdirlink()
{
        local dir="$1"
	#local dir=`readlink -mv "$1"`   ### linux only
	mkdir -p "$dir"
}


# Create logfile directory, redirect stdout and stderr
setup_logging()
{
	# Clean pre-existing LOGDIR
	rm -rf "$LOGDIR"
	mkdirlink "$LOGDIR"
}
