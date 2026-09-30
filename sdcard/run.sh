#!/bin/ksh
# =============================================================================
# Audi MMI 3G - Green Engineering Menu Activator
# https://github.com/50bvd/mmi3g-green-menu-activator
# =============================================================================
# Original method: Vlasoff / Keldo (2016); reference method: DrGER2
# (github.com/DrGER2/MMI3G-GEM-Enable)
# Maintained by:   Loup LIGNON KRASNIQI (50bvd) - BSD 2-Clause License
#
# Started by copie_scr.sh (decoded by the MMI's proc_scriptlauncher) when the
# SD card is inserted. Sets the existing Green Engineering Menu record
# (tb_intvalues: pst_namespace=4, pst_key=4100) in the persistence databases
# of /mnt/efs-persist and /mnt/hmisql, the same flag VCDS/ODIS sets through
# control unit 5F. /HBpersistence is never touched (it has its own CRC file).
#
# Safety rules followed by this script:
#   - nothing is changed before the start screen is confirmed;
#   - a database that does not exist is never created;
#   - every database is backed up to the SD card, and the backup is checked
#     with PRAGMA integrity_check, before it is changed;
#   - the first backup ever made (*.orig) is never overwritten;
#   - only the existing record is updated: no row is added or deleted;
#   - each change is one SQL statement (all or nothing) and is read back;
#   - a database that already has the right value is left untouched.
#
# Files at the root of the SD card change what the script does:
#   DRYRUN (or DRYRUN.txt)   test only: checks and backs up, changes nothing
#   DISABLE (or DISABLE.txt) switches the menu off again (value 0)
#
# Runs under the QNX 6 Korn shell (pdksh): keep to POSIX sh features.
# =============================================================================

VERSION=1.2.0

PST_NAMESPACE=4
PST_KEY=4100
PST_VALUE=1

# --- Paths -------------------------------------------------------------------
# copie_scr.sh passes the SD card mount point (e.g. /mnt/sdcard10t12) as $1.
# Without it, the directory of this script is the SD card.
if [ -n "$1" ] && [ -d "$1" ]; then
    SDPath=$1
else
    case "$0" in
        */*) SDPath=${0%/*} ;;
        *)   SDPath=. ;;
    esac
fi
SDPath=$(cd "$SDPath" && pwd)

# GEM_* variables are only used by the tests (tests/run_test.sh). They are
# never set on the car, where the defaults below apply.
SYSROOT=${GEM_SYSROOT:-}
SQLITE=${GEM_SQLITE:-$SDPath/utils/sqlite3}
SHOWSCREEN=${GEM_SHOWSCREEN:-$SDPath/utils/showScreen}

LOG=$SDPath/green_menu_activator.log
BACKUP=$SDPath/backup

# name:path of the persistence databases (flash copy and HMI copy), as in
# DrGER2's reference script
DATABASES="efs-persist:$SYSROOT/mnt/efs-persist/DataPST.db
hmisql:$SYSROOT/mnt/hmisql/DataPST.db"

STAMP=$(date +%Y%m%d-%H%M%S 2>/dev/null)
[ -n "$STAMP" ] || STAMP=run$$

# --- Helpers -----------------------------------------------------------------
log() {
    echo "$*" >> "$LOG"
}

# sql <database> <SQL>: errors go to the log. The MMI may hold a lock on the
# database for a moment, so a failed call is tried up to three times.
# A failed call changes nothing: several statements run as one transaction.
sql() {
    typeset try
    try=1
    while ! "$SQLITE" "$1" "$2" 2>> "$LOG"; do
        log "   attempt $try failed"
        [ $try -lt 3 ] || return 1
        try=$((try + 1))
        sleep 2
    done
    return 0
}

show() {
    [ -f "$SDPath/screens/$1" ] && "$SHOWSCREEN" "$SDPath/screens/$1"
}

finish() {
    sync 2>/dev/null
    log "RESULT: $1"
    log "======================================"
    if [ "$1" = "OK" ]; then
        show scriptDone.png
        exit 0
    fi
    if [ "$1" = "DRYRUN" ]; then
        show scriptDryRun.png
        exit 0
    fi
    show scriptError.png
    exit 1
}

# rows <database>: number of Green Menu rows
rows() {
    sql "$1" "SELECT count(*) FROM tb_intvalues WHERE pst_namespace=$PST_NAMESPACE AND pst_key=$PST_KEY;"
}

# value <database>: current Green Menu value(s), empty if there is none
value() {
    sql "$1" "SELECT group_concat(pst_value) FROM tb_intvalues WHERE pst_namespace=$PST_NAMESPACE AND pst_key=$PST_KEY;"
}

# wrong <database>: number of Green Menu rows that do not hold PST_VALUE
wrong() {
    sql "$1" "SELECT count(*) FROM tb_intvalues WHERE pst_namespace=$PST_NAMESPACE AND pst_key=$PST_KEY AND pst_value<>$PST_VALUE;"
}

# backup <name> <database>: copy to the SD card and check the copy
backup() {
    typeset dir copy
    dir=$BACKUP/$1
    copy=$dir/DataPST.db.$STAMP
    mkdir -p "$dir" || return 1
    cp "$2" "$copy" || return 1
    # a hot journal belongs to the database: keep it next to the copy
    if [ -f "$2-journal" ]; then
        cp "$2-journal" "$copy-journal" || return 1
    fi
    if [ "$(sql "$copy" "PRAGMA integrity_check;")" != "ok" ]; then
        log "   backup $copy failed the integrity check"
        return 1
    fi
    # the very first backup is the factory state: never overwrite it
    if [ ! -f "$dir/DataPST.db.orig" ]; then
        cp "$copy" "$dir/DataPST.db.orig" || return 1
    fi
    log "   backup  : $copy"
    return 0
}

# apply <database>: update the existing record (one statement, all or nothing)
apply() {
    sql "$1" "UPDATE tb_intvalues SET pst_value=$PST_VALUE WHERE pst_namespace=$PST_NAMESPACE AND pst_key=$PST_KEY;"
}

# patch_db <name> <database>: returns 0 when the database holds the right value
patch_db() {
    typeset name db tables count current bad
    name=$1
    db=$2

    tables=$(sql "$db" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='tb_intvalues';")
    if [ "$tables" != "1" ]; then
        log "   ERROR: cannot read table tb_intvalues, database left untouched"
        return 1
    fi

    count=$(rows "$db")
    current=$(value "$db")
    log "   before  : rows=$count value=${current:-none}"

    # The record exists on every production MMI (value 0). If it is missing,
    # something is unusual: do not invent one.
    if [ "$count" = "0" ]; then
        log "   ERROR: no Green Menu record in this database, left untouched"
        return 1
    fi
    case "$count" in
        ''|*[!0-9]*)
            log "   ERROR: cannot read the Green Menu record, left untouched"
            return 1 ;;
    esac

    if [ "$(wrong "$db")" = "0" ]; then
        log "   already set, nothing to do"
        return 0
    fi

    if ! backup "$name" "$db"; then
        log "   ERROR: backup failed, database left untouched"
        return 1
    fi

    if [ "$DRYRUN" = "1" ]; then
        log "   DRYRUN  : would set value=$PST_VALUE, nothing changed"
        return 0
    fi

    if ! apply "$db"; then
        log "   ERROR: the change was refused, database left as it was"
        return 1
    fi

    bad=$(wrong "$db")
    current=$(value "$db")
    log "   after   : value=${current:-none}"
    log "   check   : $(sql "$db" "PRAGMA quick_check;")"
    if [ "$bad" = "0" ]; then
        return 0
    fi
    log "   ERROR: the value read back is wrong"
    return 1
}

# --- Main --------------------------------------------------------------------
if [ -f "$SDPath/DISABLE" ] || [ -f "$SDPath/DISABLE.txt" ]; then
    PST_VALUE=0
    ACTION="disable"
else
    ACTION="enable"
fi
DRYRUN=0
if [ -f "$SDPath/DRYRUN" ] || [ -f "$SDPath/DRYRUN.txt" ]; then
    DRYRUN=1
    ACTION="$ACTION (DRYRUN: test only, nothing is changed)"
fi

log "======================================"
log " MMI 3G Green Menu Activator $VERSION"
log " https://github.com/50bvd/mmi3g-green-menu-activator"
log "======================================"
log "Date    : $(date)"
log "SD card : $SDPath"
log "Firmware: $(cat "$SYSROOT/dev/shmem/sw_trainname.txt" 2>/dev/null)"
log "Action  : $ACTION (pst_namespace=$PST_NAMESPACE pst_key=$PST_KEY value=$PST_VALUE)"

if [ ! -f "$SQLITE" ]; then
    log "ERROR: $SQLITE is missing, copy the whole release to the SD card"
    finish FAILED
fi

# Asks the user to press a key: nothing has been changed before this point
show scriptStart.png

# /mnt/efs-persist may be mounted read-only while the MMI runs
[ "$DRYRUN" = "1" ] || mount -uw "$SYSROOT/mnt/efs-persist" 2>> "$LOG"

found=0
failed=0
for entry in $DATABASES; do
    name=${entry%%:*}
    db=${entry#*:}
    log ""
    log ">> $name ($db)"
    if [ ! -f "$db" ]; then
        log "   not present on this MMI, skipped"
        continue
    fi
    found=$((found + 1))
    patch_db "$name" "$db" || failed=$((failed + 1))
done
log ""

if [ $found -eq 0 ]; then
    log "ERROR: no DataPST.db found, is this an MMI 3G?"
    finish FAILED
fi
if [ $failed -ne 0 ]; then
    log "$failed of $found database(s) could not be changed, see above."
    log "Backups are in $BACKUP on the SD card."
    finish FAILED
fi

if [ "$DRYRUN" = "1" ]; then
    log "DRYRUN: everything checked, nothing was changed on the MMI."
    log "Delete the DRYRUN file from the SD card to apply the change."
    finish DRYRUN
fi
log "Restart the MMI (hold SETUP or MENU + rotary knob + top-right soft key)."
[ "$ACTION" = "enable" ] && log "Then hold CAR + SETUP for about 5 seconds to open the Green Menu."
finish OK
