#############################################################################
# main.sh: Entry point for the merger scripts.  This will be sourced
# before anything else.
#
# AUTHORS:
#
# - Jeroen Demeyer (2010-11-10): initial version for sage-4.6.1
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


# Immediately exit whenever an error is encountered.
set -e

# Save original working directory and filename of merger script
ORIGINALWD=`pwd`

# Run Python
python()
{
	${PYTHON:-sage --python} "$@"
}
	

# Check prerequisites
source "$MERGER_DIR/prereq.sh"

# Read all functions
source "$MERGER_DIR/init.sh"
source "$MERGER_DIR/release.sh"
source "$MERGER_DIR/buildbot.sh"
source "$MERGER_DIR/pre_post_merge.sh"
source "$MERGER_DIR/merge.sh"
source "$MERGER_DIR/make.sh"
source "$MERGER_DIR/download.sh"

# Usage: run_with_hook <function>
# Run a function <function> after running a potential hook function
# <function>_hook.
run_with_hook()
{
	skip=no

	local hook=all_hook
	# Run hook if it exists
	if type $hook &>/dev/null; then
		echo "******** $hook *******"
		[ ! -d "$BUILD" ] || cd "$BUILD"
		time $hook
	fi

	local hook=${1}_hook
	# Run hook if it exists
	if type $hook &>/dev/null; then
		echo "******** $hook *******"
		[ ! -d "$BUILD" ] || cd "$BUILD"
		time $hook
	fi

	if [ "$skip" != yes ]; then
		echo "******** $1 *******"
		[ ! -d "$BUILD" ] || cd "$BUILD"
		time $1
	fi
}


###################################################
# Execute the various steps in the merger process #
###################################################
# Setup all environment variables
run_with_hook setup_environment
	
# From now on, any uninitialized variable gives an error
# (like "use strict" in Perl)
set -u
