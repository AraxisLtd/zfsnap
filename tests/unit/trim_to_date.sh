#!/bin/sh
# This file is licensed under the BSD-3-Clause license.
# See the AUTHORS and LICENSE files for more information.

. ../spec_helper.sh
. ../../share/zfsnap/core.sh

# These include a date matching the "date pattern", and should be trimmed accordingly
ItsRetvalIs "TrimToDate 'zpool@2009-04-05_23.32.00--1y'"        "2009-04-05_23.32.00"  0  # a full dataset name
ItsRetvalIs "TrimToDate '2011-04-05_23.32.00--1y'"              "2011-04-05_23.32.00"  0  # snapshot name
ItsRetvalIs "TrimToDate '2014-01-29_04.59.00--1y54m2w4d5s'"     "2014-01-29_04.59.00"  0  # long TTL
ItsRetvalIs "TrimToDate 'hourly-2010-04-30_12.16.00--5M'"       "2010-04-30_12.16.00"  0  # w/ prefix
ItsRetvalIs "TrimToDate 'daily--2010-12-30_01.02.00--12w'"      "2010-12-30_01.02.00"  0  # w/ prefix including TTL delimiter
ItsRetvalIs "TrimToDate '2013-08-14_14.02.00'"                  "2013-08-14_14.02.00"  0  # only date submitted
ItsRetvalIs "TrimToDate 'zpool@2004-04-05_23.32.00--2008-01-05_23.32.00--1y'"  "2008-01-05_23.32.00"  0  # an asshole uses a date in the prefix

# These do not include a date matching the "date pattern", and should return an empty string
ItsRetvalIs "TrimToDate '201-04-05_23.32.00--1y'"               ""  1                     # year has 3 characters
ItsRetvalIs "TrimToDate '2001-34-05_23.32.00--1y'"              ""  1                     # month is invalid
ItsRetvalIs "TrimToDate '2001-04-05_23x32y00--2w'"              ""  1                     # make sure dots in pattern are literal
ItsRetvalIs "TrimToDate '2014.03.05.0924'"                      ""  1                     # wrong date format
ItsRetvalIs "TrimToDate '1899-10-12_10.00.00'"                  ""  1                     # 1800's are not supported

ItsRetvalIs "TrimToDate ''"                                     ""  1                     # empty
ItsRetvalIs "TrimToDate 'zpool_child'"                          ""  1                     # special character in poolname
ItsRetvalIs "TrimToDate 'zpool/child'"                          ""  1                     # w/ child w/o snapshot
ItsRetvalIs "TrimToDate 'zpool/child/grandchild'"               ""  1                     # w/ grandchild w/o snapshot

ExitTests
