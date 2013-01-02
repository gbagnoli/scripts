#/bin/bash

set -e
set -u

[ $UID -ne 0 ] && echo "You have to be root to run this script" && exit 1

tmp_mount=$(mktemp -d)
mounted=0
remove_snapshot=""
today=$(date +%Y%m%d)
prog=$(basename $0)
config_dir="$HOME/.config/$prog"
settings="$config_dir/settings.sh"
extra_rsync_options=""
declare -a subvolumes
subvolumes[0]="__placeholder__"

# this can be overridden in settings
device=""
backup_directory=""
mount_options="defaults"
keepsnapshot=0
ask=1

[ -f $settings ] && source $settings

function cleanup()
{
    echo "Cleaning up"
    [ $keepsnapshot -ne 1 ] && [ ! -z $remove_snapshot ] && echo "Removing readonly snapshot" && sudo btrfs sub delete $remove_snapshot
    [ $mounted -ne 0 ] && echo "unmounting source device $device" && umount $tmp_mount
    echo "Removing local temporary directory"
    rmdir $tmp_mount
}

function usage()
{
    exit_code=$1; shift;
    echo "$prog [-b backup_directory] [-D <device>] [-s <subvolume> [-s <subvolume [...]]] [-S] [-f] [-h] [-k] <backup_directory>"
    echo
    echo -e " -b\t: Backup directory. required"
    echo -e " -D\t: BTRFS device to mount: defaults to $device"
    echo -e " -s\t: Add a subvolume to backup"
    echo -e " -S\t: Clear all defined subvolumes, included those added with -s prior to this flag"
    echo -e " -h\t: show this help"
    echo -e " -f\t: do not ask for confirmation"
    echo -e " -k\t: keep source read only snapshot"
    echo -e "\nConfiguration file at '$settings'"
    echo -e -n "\n Subvolumes: "
    if [ ${#subvolumes} -gt 1 ]; then
        echo ${subvolumes[@]:1}
    fi
    echo
    [ $# -gt 0 ] && echo && echo "$@" >&2 && echo
    exit $exit_code
}

function backup_subvolume() {
    sub=$1
    dest_path=$backup_directory/$sub
    dest_snap=$backup_directory/$today/$sub
    src_path=$tmp_mount/$sub
    src_snap=$tmp_mount/$today/$sub

    if [ ! -d $src_path ]; then echo "no such subvolume $sub"; return 1; fi
    mkdir -p $tmp_mount/$today
    echo "Snapshotting $sub to $src_snap"
    btrfs sub snapshot -r $src_path $src_snap
    remove_snapshot=$src_snap
    [ -d $dest_path ] || btrfs sub create $dest_path
    mkdir -p $backup_directory/$today/
    options="-axuHA --inplace --numeric-ids --delete --delete-excluded --progress $extra_rsync_options"
    [ -f $config_dir/$sub.exclude ] && options="$options --exclude-from=$config_dir/$sub.exclude"
    echo "Starting rsync on $sub to $dest_path"
    rsync $options $src_snap/ $dest_path/
    echo "Creating snapshot at $dest_snap"
    btrfs sub snapshot -r $dest_path $dest_snap
}


# MAIN
trap cleanup EXIT

while getopts ":hb:D:s:Sfk" opt; do
    case $opt in
    b)
        backup_directory=$OPTARG
        ;;
    f)
        ask=0
        ;;
    k)
        keepsnapshot=1
        ;;
    h)
        usage 0
        ;;
    D)
        device=$OPTARG
        ;;
    s)
        n=${#subvolumes[*]}
        subvolumes[$n]=$OPTARG
        ;;
    S)
        n=${#subvolumes[*]}
        for (( i=1; i< $n; i++ )); do unset subvolumes[$i]; done
        ;;
    \?)
        usage 1 "Invalid option -$OPTARG"
    ;;
    :)
        usage 1 "Option -$OPTARG requires an argument"
    ;;
    esac

done

[ -z $backup_directory ] && usage 1 "Missing backup directory"
[ -z $device ] && usage 1 "Missing device"
[ ${#subvolumes[*]} -eq 1 ] && usage 1 "No subvolumes to backup"

echo "Will backup subvolumes: '${subvolumes[@]:1}' of $device to $backup_directory"
if [ $ask -eq 1 ];
then
    echo -n "Continue [y/N]: "
    read answ
    [ -z $answ ] && exit 0
    if [ $answ != "y" ] && [ $answ != "Y" ] && [ $answ != "s" ] && [ $answ != "S" ]; then exit 0 ; fi
fi

echo "Starting backups"

mount $device $tmp_mount -o $mount_options
mounted=1 # set mounted to 1 so on_exit trap will unmount

for sub in "${subvolumes[@]:1}"; do
    backup_subvolume $sub
done
