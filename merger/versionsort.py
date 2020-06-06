#!/usr/bin/env python
"""
Given a list of (Sage) versions, one per line, on stdin,
sort them to stdout.

TESTS::

    >>> L  = ["abc", "abc-42", "abc-24", "abc-123", "abc-456", "abc-420", "abc-42x"]
    >>> L += ["abc-42.0", "abc-42.01", "abc-42.0.99", "abc-42.alpha1", "abc-42.rc", "abc-42.rc0"]
    >>> L += ["abc-42.beta1", "abc-42.beta2", "abc-42.beta10", "abc-42.beta1-test", "abc-42.beta1.test"]
    >>> L += ["x", "xy", "y", "xyz", "XYZ", ""]
    >>> L = [VersionNumber(v) for v in L]
    >>> S = sorted(L)
    >>> print S
    ['',
     'XYZ',
     'abc',
     'abc-24',
     'abc-42.alpha1',
     'abc-42.beta1.test',
     'abc-42.beta1',
     'abc-42.beta1-test',
     'abc-42.beta2',
     'abc-42.beta10',
     'abc-42.rc',
     'abc-42.rc0',
     'abc-42',
     'abc-42.0',
     'abc-42.0.99',
     'abc-42.01',
     'abc-42x',
     'abc-123',
     'abc-420',
     'abc-456',
     'x',
     'xy',
     'xyz',
     'y']

    >>> import random
    >>> for i in range(1000):
    ...     random.shuffle(L)
    ...     assert sorted(L) == S
    ...
"""

import sys
from functools import total_ordering

@total_ordering
class VersionNumber(str):
    def __getitem__(self, i):
        # Return the empty string instead of errors
        try:
            return str.__getitem__(self, i)
        except IndexError:
            return ""
    def __eq__(self, other):
        return str.__eq__(self, other)
    def __ne__(self, other):
        return str.__ne__(self, other)
    def __lt__(self, other):
        i = 0
        while self[i] == other[i]:
            if i >= len(self):
                assert len(self) == len(other)
                return False   # strings are equal
            i += 1

        # We found a difference
        a = self[i]
        b = other[i]
        
        # Check for a special case: [.][^0-9] sorts before any other string
        if a == '.' and not self[i+1].isdigit():
            return True
        if b == '.' and not other[i+1].isdigit():
            return False

        # Find longest digit string (possibly of zero length) in both
        # strings and compare lengths first.
        # This implies "A" will be sorted before "0" and "2" before "10".
        j = i
        while self[j].isdigit() and other[j].isdigit():
            j += 1
        a = self[j]
        b = other[j]
        if b.isdigit() and not a.isdigit():  # other has longer digit string
            return True
        if a.isdigit() and not b.isdigit():  # self has longer digit string
            return False
        # Both digit strings are equally long:
        # fall back to ordinary string comparison.
        return self[i] < other[i]

if __name__ == "__main__":
    L = [VersionNumber(v.strip()) for v in sys.stdin]
    for x in sorted(L):
        print x
