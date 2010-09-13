#!/bin/sh

# "THE BEER-WARE LICENSE":
# <aldis@bsdroot.lv> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return. Aldis Berjoza

# wiki: 		http://wiki.bsdroot.lv/zfsnap
# repository:		http://aldis.git.bsdroot.lv/zfSnap/
# project email:	zfsnap@bsdroot.lv

readonly VERSION=1.3.0

s2time() {
	# convert seconds to human readable time
	xtime=$*

	years=`expr $xtime / 31536000`
	xtime=`expr $xtime % 31536000`
	[ ${years:-0} -gt 0 ] && years="${years}y" || years=""

	months=`expr $xtime / 2592000`
	xtime=`expr $xtime % 2592000`
	[ ${months:-0} -gt 0 ] && months="${months}m" || months=""

	days=`expr $xtime / 86400`
	xtime=`expr $xtime % 86400`
	[ ${days:-0} -gt 0 ] && days="${days}d" || days=""

	hours=`expr $xtime / 3600`
	xtime=`expr $xtime % 3600`
	[ ${hours:-0} -gt 0 ] && hours="${hours}h" || hours=""

	minutes=`expr $xtime / 60`
	[ ${minutes:-0} -gt 0 ] && minutes="${minutes}M" || minutes=""

	seconds=`expr $xtime % 60`
	[ ${seconds:-0} -gt 0 ] && seconds="${seconds}s" || seconds=""

	echo "${years}${months}${days}${hours}${minutes}${seconds}"
}

time2s() {
	# convert human readable time to seconds
	echo "$1" | sed -e 's/y/*31536000+/' -e 's/m/*2592000+/' -e 's/w/*604800+/' -e 's/d/*86400+/' -e 's/h/*3600+/' -e 's/M/*60+/' -e 's/s//' -e 's/\+$//' | bc -l
}

help() {
	cat << EOF
${0##*/} v${VERSION} by Aldis Berjoza
zfsnap project email: zfsnap@bsdroot.lv

Syntax:
${0##*/} [ generic options ] [[ -a ttl ] [ -r|-R ] z/fs1 ... ] ...

GENERIC OPTIONS:
  -d         = delete old snapshots
  -v         = verbose output
  -n         = only show actions that would be performed

OPTIONS:
  -a ttl     = set how long snapshot should be kept
  -r         = create recursive snapshots for all zfs file systems that fallow
               this switch
  -R         = create non-recursive snapshots for all zfs file systems that
               fallow this switch
  -p prefix  = use prefix for snapshots afterh this switch
  -P         = don't use prefix for snapshots after this switch
MORE INFO:
  http://wiki.bsdroot.lv/zfsnap

EOF
	exit
}

[ $# = 0 ] && help
[ "$1" = '-h' -o $1 = "--help" ] && help

readonly tfrmt='%Y-%m-%d_%T'
readonly htime_pattern='([0-9]+y)?([0-9]+m)?([0-9]+w)?([0-9]+d)?([0-9]+h)?([0-9]+M)?([0-9]+[s]?)?'
readonly date_pattern='20[0-9][0-9]-[01][0-9]-[0-3][0-9]_[0-2][0-9]:[0-5][0-9]:[0-5][0-9]'
ttl='1m'	# default snapshot ttl
delete_snapshots=0
verbose=0
dry_run=0
prefx=""	# default pretfix
prefxes=""

while [ "$1" = '-d' -o "$1" = '-v' -o "$1" = '-n' ]; do
	[ "$1" = "-d" ] && delete_snapshots=1 && shift
	[ "$1" = "-v" ] && verbose=1 && shift
	[ "$1" = "-n" ] && dry_run=1 && shift
done

[ $dry_run -eq 1 ] && zfs_list=`zfs list -H | awk '{print $1}'`
ntime=`date "+$tfrmt"`
while [ "$1" ]; do
	while [ "$1" = '-r' -o "$1" = '-R' -o "$1" = '-a' -o "$1" = '-p' -o "$1" = '-P' ]; do
		[ "$1" = '-r' ] && zopt='-r' && shift
		[ "$1" = '-R' ] && zopt='' && shift
		[ "$1" = '-a' ] && ttl="$2" && shift 2 && echo "$ttl" | grep -q -E -e "^[0-9]+$" && ttl=`s2time $ttl`
		[ "$1" = '-p' ] && prefx="$2" && shift 2 && prefxes="$prefxes|$prefx"
		[ "$1" = '-P' ] && prefx="" && shift
	done

	# create snapshots
	if [ $1 ]; then
		zfs_snapshot="zfs snapshot $zopt $1@${prefx}${ntime}--${ttl}${postfx}"
		if [ $dry_run -eq 0 ]; then
			$zfs_snapshot > /dev/stderr \
				&& { [ $verbose -eq 1 ] && echo "$zfs_snapshot	... DONE"; } \
				|| { [ $verbose -eq 1 ] && echo "$zfs_snapshot	... FAIL"; }
		else
			good_fs=0
			printf "%s\n" $zfs_list | grep -m 1 -q -E -e "^$1$" \
				&& echo "$zfs_snapshot" \
				|| echo "ERR: Looks like zfs filesystem '$1' doesn't exist" > /dev/stderr
		fi
		shift
	fi
done

prefxes=`echo "$prefxes" | sed -e 's/^\|//'`

# delete snapshots
if [ "$delete_snapshots" -eq 1 ]; then
	zfs_snapshots=`zfs list -H -t snapshot | awk '{print $1}' | grep -E -e "^.*@(${prefxes})?${date_pattern}--${htime_pattern}$" | sed -e 's#/.*@#@#'`
	for i in `printf '%s\n' $zfs_snapshots | sed -E -e "s/^.*@//" | sort -u`; do
		create_time=$(date -j -f "$tfrmt" $(echo "$i" | sed -E -e "s/--${htime_pattern}$//" -E -e "s/^(${prefxes})?//") +%s)
		stay_time=$(time2s `echo $i | sed -E -e "s/^(${prefxes})?${date_pattern}--//"`)
		[ `date +%s` -gt `expr $create_time + $stay_time` ] \
			&& rm_snapshot_pattern="$rm_snapshot_pattern $i"
	done

	if [ "$rm_snapshot_pattern" != '' ]; then
		rm_snapshots=$(printf '%s\n' $zfs_snapshots | grep -E -e "@`echo $rm_snapshot_pattern | sed -e 's/ /|/g'`" | sort -u)
		for i in $rm_snapshots; do
			zfs_destroy="zfs destroy -r $i"
			if [ $dry_run -eq 0 ]; then
				# hardening: make really, really sure we are deleting snapshot
				echo $i | grep -q -e '@'
				if [ $? -eq 0 ]; then
					$zfs_destroy > /dev/stderr && { [ $verbose -eq 1 ] && echo "$zfs_destroy	... DONE"; }
				else
					{
						echo "ERR: trying to delete zfs pool or filesystem? WTF?"
						echo "  This is bug, we definitely don't want that."
						echo "  Please report it to zfsnap@bsdroot.lv"
						echo "  Don't panic, nothing was deleted :)"
						exit 1
					} > /dev/stderr
				fi
			else
				echo "$zfs_destroy"
			fi
		done
	fi
fi
exit 0
