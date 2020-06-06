#############################################################################
# release.sh: actually finalize the release, push it on the mirrors.
# The release manager still needs to send the email announcement by hand.
#
# AUTHORS:
#
# - Jeroen Demeyer (2013-01-08)
#
#############################################################################

#*****************************************************************************
#       Copyright (C) 2013 Jeroen Demeyer <jdemeyer@cage.ugent.be>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#  as published by the Free Software Foundation; either version 2 of
#  the License, or (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************

do_release()
{
	# Ask for confirmation, accidents can cause grave consequences.
	echo "This will finalize the release of Sage $VERSION and push it to the mirrors"
	echo -n "as development release.  Are you sure you want to continue? "
	read answer
	case "$answer" in
		y*|Y*) ;;
		*) echo "Aborted."; exit 1;;
	esac

	# Make "current" symlink in $DIST/..
	cd "$DIST/.."
	rm -f current
	ln -s `basename "$DIST"` current

	ssh sagemath@boxen "./mirrordevel $VERSION"

	# Make all files read-only and the merger script non-executable
	cd "$ORIGINALWD"
	chmod --changes a-wx "$MERGER_SCRIPT"
	cd "$DIST"
	rm -f README.FIRST
	chmod --changes a-w * .

	echo
	echo "Sage $VERSION is on the mirrors as development release."
	echo "Now send the announcement to sage-release!"
}
