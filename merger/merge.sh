#############################################################################
# merge.sh: functions for actually merging patches.  This contains
# definitions for functions typically called from do_merge().
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


# Usage: tag_packages
# Set the correct version number of all special packages and add hg tags.
# For sage_root, sage, sage_scripts, extcode, the version
# number equals the Sage version.  For other packages (currently none),
# the last number in the version is increased by one.
tag_packages()
{
	echo "******** tag_packages *******"

	for (( i = 0; i < $NSPKG; i++ )); do
		local spkg="${SPKG_NAME[i]}"
		local dirty="${SPKG_DIRTY[i]}"

		# Set version number
		case $spkg in
		sage_root|sage|sage_scripts|extcode)
			SPKG_VERSION[i]="$version";;
		*)
			# Bump last number of version if the package changed
			if [ "$dirty" = "yes" ]; then
				local vbase=`echo "${SPKG_VERSION[i]}" |sed 's|\(.*[^0-9]\)\([0-9]*\)|\1|'`
				local vn=`echo "${SPKG_VERSION[i]}" |sed 's|\(.*[^0-9]\)\([0-9]*\)|\2|'`
				SPKG_VERSION[i]="$vbase$((vn+1))"
			fi
		esac

		# Add hg tag if package is dirty and mark the repository
		# as "public" such that history cannot be rewritten.
		if [ "$dirty" = "yes" ]; then
			echo "Tagging ${SPKG_NAME[i]} ${SPKG_VERSION[i]}"
			( cd "$BUILD/${SPKG_SYMLINK[i]}" && hg tag "${SPKG_VERSION[i]}" && hg phase --public tip )
		else
			echo "Version ${SPKG_NAME[i]} ${SPKG_VERSION[i]}"
		fi
	done
}


# Usage: Version <version>
# ``version`` should be a numeric version number, e.g. "4.6.1.alpha0"
# Set the global version $version to ``version``.
# Bump the version numbers of the various special packages.
# Also check that all Trac tickets which are supposed to merged in
# this version, actually are.
Version()
{
	# Tag dirty packages
	tag_packages

	# Set new Sage version
	version="$1"
	echo "******** Version $version *******"

	# List of tickets supposed to be merged in this Sage version
	wget -q "$TRACURL/query?format=csv&order=id&col=merged&col=id&merged=sage-$version" -O- | \
		sed '1d; s|,| |; s|\r||' >>"$LOGDIR/trac_merged.log"

	# Reset dirty flags
	SPKG_DIRTY=(${SPKG_ALWAYSDIRTY[@]})
}


# Usage: hg_import <directory> <url>
# Download a patch from ``url`` and apply it into directory ``directory``
# using Mercurial.  Some sanity checking is done before applying the patch.
# In most cases, ``directory`` will be the special directory SAGELIB.
hg_import()
{
	local patchroot="$1"
	local url="$2"
	local ticket=`get_ticket_number "$url"`
	local patchname=`download_file "$url"`
	local patchbasename=`basename "$patchname" .patch`

	# If the first line of the patch does not start
        # with "# HG changeset patch", assume the file is a diff.
	# Apply it anyway, with an explicit commit message.
	if ! `head -n1 "$patchname" |grep -q "^# HG changeset patch"`; then
		# Copy the patch
		cp "$patchname" "$PATCHES/${patchbasename}.patch"
		patchname="$PATCHES/${patchbasename}.patch"

		echo "Applying $patchroot diff $url"
		( cd $patchroot && hg import -m "Trac #$ticket: not a HG changeset" "$patchname" )

		# Write an empty commit message and mark the error
		: >"$PATCHES/${patchbasename}.msg"
		echo "Not a proper HG changeset" >"$PATCHES/${patchbasename}.err"
	else
		# We have a true HG changeset.
		# Fix the patch
		"$MERGER_DIR/cleanpatch.pl" "Trac #$ticket: " <"$patchname" \
			>"$PATCHES/${patchbasename}.patch" 3>"$PATCHES/${patchbasename}.msg"
		patchname="$PATCHES/${patchbasename}.patch"

		echo "Applying $patchroot patch $url"
		( cd $patchroot && hg import "$patchname" )

		# Check for suspicuous stuff in the patch
		if ! sanity_check_hg_patch "$patchname"; then
			echo "$ERROR" >"$PATCHES/${patchbasename}.err"
		else
			# Delete the error file in case it existed
			rm -f "$PATCHES/${patchbasename}.err"
		fi
	fi

	# Log changes
	add_ticket $ticket
	echo "$ticket $patchroot $patchname $url" >>"$PATCHLOG"

	# Mark package dirty
	for (( i = 0; i < $NSPKG; i++ )); do
		if [ "${SPKG_SYMLINK[i]}" = "$patchroot" ]; then
			SPKG_DIRTY[i]="yes"; break
		fi
	done
}

# Usage: sanity_check_hg_patch <filename>
# Sanity check a HG changeset.  Return 0 if everything is fine.
# If there is a problem, set the variable $ERROR to an error message
# and return a non-zero value.
sanity_check_hg_patch()
{
	local patchname="$1"

	# File with commit message (saved by cleanpatch.pl)
	local message=`echo "$patchname" | sed 's/\.patch$//; s/$/.msg/'`

	# There must be a "User" field
	if ! head -n5 "$patchname" |grep -q "^# User "
	then
		ERROR="No user specified in patch"
		return 1
	fi

	# Check that the message does not contain [mq]
	if fgrep -q '[mq]' "$message"
	then
		ERROR="Commit message comes from Mercurial queue"
		return 1
	fi

	# Check that the message does not contain "imported patch"
	if grep -q 'imported patch ' "$message"
	then
		ERROR="Commit message is a patch name"
		return 1
	fi

	# The patch should not introduce "AssertionError"
        if grep -q '^[+].*AssertionError' "$patchname"
	then
		ERROR="Patch uses AssertionError"
		return 1
	fi

	# The patch should not introduce a bare except statement
        if grep -q '^[+] *except *:' "$patchname"
	then
		ERROR="Patch uses bare except:"
		return 1
	fi

	# The patch should not add TAB characters (but remove +++ lines
	# from diff which might contain TABs)
        if grep '^[+].*[	]' "$patchname" |grep -v '^[+][+][+]' >/dev/null
	then
		ERROR="Patch adds a TAB character"
		return 1
	fi
}


# Usage: patch_import <directory> <url> [<options>]
# Download a patch from ``url`` and apply it into directry ``directory``
# using Unix ``patch``.  If ``options`` is given, those are command line
# arguments to ``patch``.  If not given, use ``-p0``.
patch_import()
{
	local patchroot="$1"
	local url="$2"
	local opts="${3:--p0}"
	local ticket=`get_ticket_number "$url"`
	local patchname=`download_file "$url"`
	
	# If the patchroot contains only upper case letters,
	# add /. (otherwise notes.sh might be confused)
	if echo "$patchroot" | grep -q "^[A-Z]*$"; then
		patchroot="$patchroot/."
	fi

	# Apply the patch
	echo "Applying $patchroot patch $url"
	cat "$patchname" | ( cd "$patchroot" && patch "$opts" )

	# Log changes
	add_ticket $ticket
	echo "$ticket $patchroot $patchname $url" >>"$PATCHLOG"

	# Mark package dirty
	for (( i = 0; i < $NSPKG; i++ )); do
		if [ "${SPKG_SYMLINK[i]}" = "$patchroot" ]; then
			SPKG_DIRTY[i]="yes"; break
		fi
	done
}


# Usage: spkg_import <ticket> <url>
# Download a spkg from ``url`` and copy it to spkg/standard.
# ``ticket`` should be the ticket number.
spkg_import()
{
	local ticket="$1"
	local url="$2"
	local filename=`download_file "$url"`

	echo "new spkg $url (#$ticket)"

	# Package name with version, e.g. "numpy-1.5.1"
	local spkgnamever=`echo "$filename" | sed -n 's!.*/\([^/]*\).spkg!\1!p'`

	if [ "$spkgnamever" = "" ]; then
		echo >&2 "Cannot determine package version from URL $url"
		exit 1
	fi

	# Package name without version, e.g. "numpy"
	local spkgname=`echo "$filename" | sed -n 's!.*/\([^-/]*\)-[0-9][^/]*!\1!p'`

	if [ "$spkgname" = "" ]; then
		echo >&2 "Cannot determine package name from URL $url"
		exit 1
	fi

	# Old version of this package
	local spkgnameold=`ls 2>/dev/null "$SPKG_STANDARD/$spkgname"-*.spkg | sed -n 's!.*/\([^/]*\).spkg!\1!p'`
	[ -z "$spkgnameold" ] || echo "old spkg $spkgnameold.spkg"

	# Extract the spkg
	( cd "$SPKG_EXTRACT" && tar -x --delay-directory-restore -f "$filename" )

	# Check that the right directory exists
	if ! [ -d "$SPKG_EXTRACT/$spkgnamever" ]; then
		echo >&2 "spkg $url does not contain $spkgnamever directory"
		exit 1
	fi

	cd "$SPKG_EXTRACT/$spkgnamever"

	# Read potential commit message from SPKG.txt
	(
		exec >"${filename}.msg"
		echo -n "Trac #$ticket: "
		"$MERGER_DIR/getspkgtxt.pl" "$spkgnamever" <SPKG.txt
	)

	# Commit any outstanding changes
	hg commit >/dev/null 2>/dev/null -l "${filename}.msg" || true
	if ifoutput "echo >&2 '${spkgnamever}.spkg is not hg clean:'" "sage --hg status"; then
		exit 1
	fi

	# Extract actual commit message
	### hg export tip | "$MERGER_DIR/cleanpatch.pl" >/dev/null 3>"${filename}.msg"

	# Check that SPKG.txt and spkg-install are under revision control
	if ! hg log SPKG.txt |grep -q . ; then
		echo >&2 "SPKG.txt not under revision control"
		exit 1
	fi
	if ! hg log spkg-install |grep -q . ; then
		echo >&2 "spkg-install not under revision control"
		exit 1
	fi

	# Check that SPKG.txt contains a mention of the *old* spkg,
	# to make sure that the new spkg was based on the latest spkg.
	if [ -n "$spkgnameold" ]; then
		if ! grep -q "^==* *${spkgnameold}[, ]" SPKG.txt ; then
			echo >&2 "Header line for old version $spkgnameold not found.\n"
			exit 1
		fi
	fi

	# Check that spkg-install and spkg-check are executable
	# (for spkg-check, only do this if spkg-check exists)
	if [ ! -x spkg-install ]; then
		echo >&2 "spkg-install is not executable"
		exit 1
	fi
	if [ -f spkg-check ] && [ ! -x spkg-check ]; then
		echo >&2 "spkg-check is not executable"
		exit 1
	fi

        # Sanitize file permissions (depending on whether the executable
        # bit was set). This does not require a commit since hg (also git)
        # tracks only the executable bit.
        find . -perm -0100 -not -perm 0755 -exec chmod --verbose 0755 {} \;
        find . -not -perm -0100 -not -perm 0644 -exec chmod --verbose 0644 {} \;

	# Check type and permissions of files inside the spkg.
	# There should only be ordinary files with permission 0644 or 0755,
	# directories with permission 0755 and symlinks.
	if ifoutput "echo >&2 'Warning: suspicious file types/modes in ${spkgnamever}.spkg:'" \
		'find . -not \( \( -type f -perm 0644 \) -or \( -type f -perm 0755 \) -or \( -type d -perm 0755 \) -or -type l \) -ls'
	then
		:
	fi

	# Remove Mercurial backups
	rm -rf .hg/strip-backup

	# Add hg tag with the version number.  It is not an error if
	# this fails, maybe the version number already exists.
	hg tag "$spkgnamever" 2>/dev/null || true

	# Mark the repository public (this fails if the phase is
	# already public)
	hg phase --public tip 2>/dev/null || true

	# Package spkg and remove source directory
	cd ..
	sage --spkg "$spkgnamever" >/dev/null
	rm -rf "$spkgnamever"

	# Remove all old versions of this spkg
	cd "$BUILD"
	rm -f "$SPKG_STANDARD/$spkgname"-*.spkg

	# Move spkg file to spkg/standard and set date to original date
	mv "$SPKG_EXTRACT/$spkgnamever.spkg" "$SPKG_STANDARD"
	touch --no-create -r "$filename" "$SPKG_STANDARD/$spkgnamever.spkg"

	# Log changes
	add_ticket $ticket
	echo "$ticket $filename $url" >>"$SPKGLOG"
}


# Usage: get_ticket_number <url>
# Deduce a ticket number from a url
get_ticket_number()
{
	local ticket=`echo "$1" |sed -n 's!.*/ticket/\([0-9]\+\)/.*!\1!p'`

	if [ "$ticket" = "" ]; then
		echo >&2 "Cannot deduce ticket number for patch URL $1"
		exit 1
	fi

	echo "$ticket"
}

# Usage: add_ticket <ticket>
# Add ticket number ``ticket`` to $TICKETSLOG with some sanity checking
add_ticket()
{
	local ticket="$1"

	if [ "$version" = "" ]; then
		echo >&2 "No version specified, use the command 'Version'"
		exit 1
	fi

	# Check that ticket is numeric
	if ! echo "$ticket" | grep -q '^[1-9][0-9]*$'; then
		echo >&2 "Invalid ticket number '$ticket'"
		exit 1
	fi

	echo "sage-$version $ticket" >>"$TICKETSLOG"
}
