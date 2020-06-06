#############################################################################
# buildbot.sh: interface to the buildbot
#
# AUTHORS:
#
# - Jeroen Demeyer (2013-01-21)
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

configure_buildbot()
{
	ssh buildbot@boxen 'cd config && cat >version.sh && ./rescript' <<EOF
# Automatically configured by merger script
VERSION=$VERSION
EOF

	echo "Configured buildbot to build sage-$VERSION."
	echo "Now go and start the builders!"
}
