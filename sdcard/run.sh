#!/bin/ksh
# =============================================================================
# Audi MMI 3G - Green Engineering Menu Activator
# https://github.com/50bvd/mmi3g-green-menu-activator
# =============================================================================
# Original method: Vlasoff / Keldo (2016)
# Maintained by:   Loup LIGNON KRASNIQI (50bvd) - BSD 2-Clause License
#
# Started by copie_scr.sh (decoded by the MMI's proc_scriptlauncher) when the
# SD card is inserted. Sets the Green Engineering Menu flag
# (tb_intvalues: pst_namespace=4, pst_key=4100) in every DataPST.db found,
# the same flag VCDS/ODIS sets through control unit 5F.
#
# Safety rules followed by this script:
#   - nothing is changed before the start screen is confirmed;
#   - a database that does not exist is never created;
#   - every database is backed up to the SD card, and the backup is checked
#     with PRAGMA integrity_check, before it is changed;
#   - the first backup ever made (*.orig) is never overwritten;
#   - each change is one SQL transaction (all or nothing) and is read back;
#   - a database that already has the right value is left untouched.
#
# Put an empty file named DISABLE (or DISABLE.txt) at the root of the SD card
# to switch the menu off again (value 0) instead of on.
#
# Runs under the QNX 6 Korn shell (pdksh): keep to POSIX sh features.
# =============================================================================

VERSION=1.1.0

PST_NAMESPACE=4
PST_KEY=4100
PST_VALUE=1

# --- Paths -------------------------------------------------------------------
# copie_scr.sh changes to the SD card directory and starts ./run.sh, so the
# directory of this script is the SD card, whichever slot it is in.
case "$0" in
    */*) SDPath=${0%/*} ;;
    *)   SDPath=. ;;
esac
SDPath=$(cd "$SDPath" && pwd)

# GEM_* variables are only used by the tests (tests/run_test.sh). They are
# never set on the car, where the defaults below apply.
SYSROOT=${GEM_SYSROOT:-}
SQLITE=${GEM_SQLITE:-$SDPath/utils/sqlite3}
SHOWSCREEN=${GEM_SHOWSCREEN:-$SDPath/utils/showScreen}

LOG=$SDPath/green_menu_activator.log
BACKUP=$SDPath/backup

# name:path of each persistence database, depending on the MMI variant
DATABASES="efs-persist:$SYSROOT/mnt/efs-persist/DataPST.db
HBpersistence:$SYSROOT/HBpersistence/DataPST.db
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
    show scriptError.png
    exit 1
}

# rows <database>: number of Green Menu rows
rows() {
    sql "$1" "SELECT count(*) FROM tb_intvalues WHERE pst_namespace=$PST_NAMESPACE AND pst_key=$PST_KEY;"
}

# value <database>: current Green Menu value (empty if there is none)
value() {
    sql "$1" "SELECT pst_value FROM tb_intvalues WHERE pst_namespace=$PST_NAMESPACE AND pst_key=$PST_KEY;"
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

# apply <database>: delete and insert in one transaction (all or nothing)
apply() {
    sql "$1" "BEGIN;
DELETE FROM tb_intvalues WHERE pst_namespace=$PST_NAMESPACE AND pst_key=$PST_KEY;
INSERT INTO tb_intvalues (pst_namespace, pst_key, pst_value) VALUES ($PST_NAMESPACE, $PST_KEY, $PST_VALUE);
COMMIT;"
}

# patch_db <name> <database>: returns 0 when the database holds the right value
patch_db() {
    typeset name db tables count current
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

    if [ "$count" = "1" ] && [ "$current" = "$PST_VALUE" ]; then
        log "   already set, nothing to do"
        return 0
    fi

    if ! backup "$name" "$db"; then
        log "   ERROR: backup failed, database left untouched"
        return 1
    fi

    if ! apply "$db"; then
        log "   ERROR: the change was refused, database left as it was"
        return 1
    fi

    count=$(rows "$db")
    current=$(value "$db")
    log "   after   : rows=$count value=${current:-none}"
    log "   check   : $(sql "$db" "PRAGMA quick_check;")"
    if [ "$count" = "1" ] && [ "$current" = "$PST_VALUE" ]; then
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

# /mnt/efs-persist is mounted read-only while the MMI runs
mount -uw "$SYSROOT/mnt/efs-persist" 2>> "$LOG"

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

log "Restart the MMI (hold MENU + rotary knob + top-right soft key)."
[ "$ACTION" = "enable" ] && log "Then hold CAR + SETUP for about 5 seconds to open the Green Menu."
finish OK
