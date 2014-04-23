#!/bin/bash
set -e
set -u

function fixgps() {
    [ ! -f coord.txt ] && return 0
    files=()
    for i in *.jpg
    do
        exiftool -a "$i" | grep -q "GPS" || files+=("$i")
    done
    [ ${#files[@]} -eq 0 ] && return
    coordraw=$(<coord.txt)
    coord=(${coordraw//,/})
    lat=${coord[0]}
    long=${coord[1]}
    exiftool -exif:gpslatitude=$lat -xmp:gpslatitude=$lat -exif:gpslongitude=$long -xmp:gpslongitude=$long -overwrite_original_in_place "${files[@]}"
}

function renamefiles() {
    ls *.jpg &>/dev/null || return 0
    exiftool -overwrite_original_in_place "-FileName<CreateDate" -d "%Y-%m-%d %H.%M.%S.%%e" *.jpg
}

function removefiles() {
    rm -rfv IMG_* pano* PANO*
}

while read -r -d $'\0'
do
    pushd "$REPLY" &> /dev/null
    pwd
    fixgps
    renamefiles
    popd &>/dev/null
done < <(find . -type d -print0)

find . -type f -name coord.txt -delete
