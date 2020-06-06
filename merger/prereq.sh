#############################################################################
# prereq.sh: check prerequisites for the merger script: check versions
# and command-line options of various programs.
#
# AUTHORS:
#
# - Jeroen Demeyer (2012-03-20): initial version for sage-5.0
#
#############################################################################

#*****************************************************************************
#       Copyright (C) 2012 Jeroen Demeyer <jdemeyer@cage.ugent.be>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#  as published by the Free Software Foundation; either version 2 of
#  the License, or (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************


# Check that bash properly supports 'set -e' with subshells
answer=`bash -c 'set -e; ( exit 42 ); exit 0'; echo $?`
if [ "$answer" != 42 ]; then
    echo >&2 "Error: bash does not support 'set -e' properly with subshells."
    echo >&2 "Upgrade GNU bash and try again."
    exit 1
fi

# Check that gzip supports --rsyncable
#if ! gzip --rsyncable -c </dev/null &>/dev/null; then
#    echo >&2 "Error: gzip --rsyncable is not supported."
#    exit 1
#fi
