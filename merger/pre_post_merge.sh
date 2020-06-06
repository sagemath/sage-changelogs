#############################################################################
# pre_post_merge.sh: functions which will be called right before and right
# after do_merge().
#
# AUTHORS:
#
# - Jeroen Demeyer (2012-04-06): split off from merge.sh
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


# Download and extract old Sage version
extract_old_tarball()
{
	version="$OLDVERSION"

	# Extract the old version in a special directory
	SAGE_EXTRACT_DIR=`readlink -m "$BUILD/../extract-$VERSION"`
	mkdir -p "$SAGE_EXTRACT_DIR"
	cd "$SAGE_EXTRACT_DIR"
	echo "Downloading and extracting old release sage-$OLDVERSION"
	wget --no-verbose "$RELEASEURL/sage-$OLDVERSION/sage-$OLDVERSION.tar" -O- | tar x

	# Remove an existing BUILD directory and move the old Sage
	# version to BUILD
	rm -rf "$BUILD"
	mv "sage-$OLDVERSION" "$BUILD"

	cd "$BUILD"
	rmdir "$SAGE_EXTRACT_DIR"
}

# Setup variables for the "special" spkgs sage, sage_scripts, extcode.
# These are special because developers simply post patches to these
# spkgs instead of complete new spkgs.
# Do some sanity checks, these will be extracted later by extract_old_spkgs.
setup_spkgs()
{
	cd "$BUILD"

	# Directory containing the spkgs
	SPKG_STANDARD="$BUILD/spkg/standard"

	# Make some arrays containing information about special spkgs
	SPKG_NAME=(sage_root sage sage_scripts extcode)
	# Number of special spkgs
	NSPKG=${#SPKG_NAME[*]}
	# Symlinks to be made
	SPKG_SYMLINK=(SAGE_ROOT SAGELIB SCRIPTS EXTCODE)
	# Symlinks targets inside spkg
	SPKG_SYMLINK_TARGET=("" "" "" "")
	# New versions (initially equal to old version)
	SPKG_VERSION=
	# Will this package always have its version number bumped?
	SPKG_ALWAYSDIRTY=(yes yes yes yes)
	# Have we changed this package?
	SPKG_DIRTY=

	# Check sizes
	if [ ${#SPKG_SYMLINK[*]} != $NSPKG ]; then
		echo >&2 "$0: SPKG_SYMLINK has wrong number of elements"
		exit 1
	fi
	if [ ${#SPKG_SYMLINK_TARGET[*]} != $NSPKG ]; then
		echo >&2 "$0: SPKG_SYMLINK_TARGET has wrong number of elements"
		exit 1
	fi
	if [ ${#SPKG_ALWAYSDIRTY[*]} != $NSPKG ]; then
		echo >&2 "$0: SPKG_ALWAYSDIRTY has wrong number of elements"
		exit 1
	fi

	# Find out old versions of these spkgs and check that new version is different
	cd "$SPKG_STANDARD"
	for (( i = 0; i < $NSPKG; i++ )); do
		local spkg=${SPKG_NAME[i]}
		local oldver=None
		for oldspkg in $spkg-*.spkg; do
			if [ "$oldver" != "None" ]; then
				echo "Found multiple $spkg packages:"
				ls $spkg-*.spkg
				exit 1
			fi
			oldver=`echo $oldspkg | sed -n 's!^'${spkg}'-\(.*\)\.spkg$!\1!p'`
			if [ "$oldver" = "" ]; then
				echo >&2 "Cannot determine old version of $spkg."
				exit 1
			fi
		done
		SPKG_OLDVERSION[i]=$oldver
		SPKG_VERSION[i]=$oldver     # new version equal to old version
		SPKG_DIRTY[i]="no"          # package is not dirty
	done
}

# Extract the "special" spkgs.
extract_old_spkgs()
{
	# Create an empty directory to extract spkgs
	SPKG_EXTRACT="$TMPDIR/merger-tmp-$VERSION"
	rm -rf "$SPKG_EXTRACT"
	mkdir "$SPKG_EXTRACT"

	# Extract the spkgs
	cd "$SPKG_EXTRACT"
	for (( i = 0; i < $NSPKG; i++ )); do
		local spkg=${SPKG_NAME[i]}

		# Extract the spkg
		echo "Extracting package $spkg"
		tar xjf "$SPKG_STANDARD/$spkg-${SPKG_OLDVERSION[i]}.spkg"

		# Create symlink (e.g. $BUILD/SAGELIB points to EXTRACT/sage-$VERSION)
		ln -s "$SPKG_EXTRACT/$spkg-${SPKG_VERSION[i]}/${SPKG_SYMLINK_TARGET[i]}" "$BUILD/${SPKG_SYMLINK[i]}"
	done


	# Test the symlinks by making sure we can cd to them
	for dir in SAGELIB SCRIPTS EXTCODE; do
		cd "$BUILD/$dir"
	done
}


# Repackage sage, sage-scripts, extcode spkg's and make
# release notes
post_merge()
{
	# Tag dirty packages
	tag_packages

	# Pull root repository
	cd "$BUILD"
	hg pull -u SAGE_ROOT

	# Repackage the spkgs if the version number has changed
	cd "$SPKG_EXTRACT"
	for (( i = 0; i < $NSPKG; i++ )); do
		local spkg=${SPKG_NAME[i]}

		# Remove symlink
		rm "$BUILD/${SPKG_SYMLINK[i]}"

		# If old and new version numbers are the same,
		# don't do anything
		if [ "${SPKG_OLDVERSION[i]}" = "${SPKG_VERSION[i]}" ]; then
			echo "Keeping package $spkg-${SPKG_OLDVERSION[i]}.spkg"
			continue
		fi

		# Rename old version directory to new version
		mv "$spkg-${SPKG_OLDVERSION[i]}" "$spkg-${SPKG_VERSION[i]}"
		
		# Remove old version
		rm "$SPKG_STANDARD/$spkg-${SPKG_OLDVERSION[i]}.spkg"

		# Make new package
		local newspkg="$SPKG_STANDARD/$spkg-${SPKG_VERSION[i]}.spkg"
		local spkgdir="$spkg-${SPKG_VERSION[i]}"
		echo "Making package $spkg-${SPKG_VERSION[i]}.spkg"
		tar c "$spkgdir" |bzip2 --best >"$newspkg"
	done

	rm -r "$SPKG_EXTRACT"

	# Make release notes
	source "$MERGER_DIR/notes.sh"
}
