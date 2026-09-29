#!/usr/bin/env bash
# Checks the files that go on the SD card.
#
# copie_scr.sh and the QNX tools cannot be reviewed as text, so their SHA-256
# is pinned here: any change to them must be deliberate and reviewed.

set -u
cd "$(dirname "$0")/../sdcard" || exit 2

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "  ok   $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL $1"; }

sha() { sha256sum "$1" | cut -d' ' -f1; }

pinned() {
    if [ "$(sha "$1")" = "$2" ]; then ok "$1 is the reviewed file"; else fail "$1 changed (sha256 $(sha "$1"))"; fi
}

pinned copie_scr.sh     3294b666e7bca567bf86275e64f1a9cc3a3727afb812c932f59323502f7ceb2c
pinned utils/sqlite3    3f920417793f8c50f83d35beb094163aa072f05d2bfff9d887f2eed463c8a804
pinned utils/showScreen 033174eb41f30a6197aac7fafcfbe22adcdeb0c637e9a43937ee90d20fd9bdd5

# the launcher is the documented one: same length as its decoded copy
if [ "$(wc -c < copie_scr.sh)" -eq "$(wc -c < ../docs/copie_scr.sh.dec)" ]; then
    ok "copie_scr.sh matches docs/copie_scr.sh.dec in length"
else
    fail "copie_scr.sh and docs/copie_scr.sh.dec differ in length"
fi

if [ -f upd ] && [ ! -s upd ]; then ok "upd is present and empty"; else fail "upd must be an empty file"; fi

for tool in utils/sqlite3 utils/showScreen; do
    if file "$tool" | grep -q 'ELF 32-bit LSB executable, Renesas SH.*ldqnx'; then
        ok "$tool is a QNX SH4 executable"
    else
        fail "$tool is not a QNX SH4 executable"
    fi
done

# run.sh: Korn shell, LF line endings, same version as the changelog
if [ "$(head -n 1 run.sh)" = "#!/bin/ksh" ]; then ok "run.sh starts with #!/bin/ksh"; else fail "run.sh shebang"; fi
if grep -q $'\r' run.sh; then fail "run.sh has CRLF line endings"; else ok "run.sh has LF line endings"; fi
VERSION=$(sed -n 's/^VERSION=//p' run.sh)
if grep -q "^## \[$VERSION\]" ../CHANGELOG.md; then
    ok "CHANGELOG.md has a section for $VERSION"
else
    fail "CHANGELOG.md has no section for $VERSION"
fi

# every screen used by run.sh exists, in the format of the original screens
while read -r png; do
    if file "screens/$png" | grep -q 'PNG image data, 800 x 480, 8-bit colormap'; then
        ok "screens/$png is an 800x480 8-bit PNG"
    else
        fail "screens/$png is missing or not an 800x480 8-bit PNG"
    fi
done < <(grep -o 'script[A-Za-z]*\.png' run.sh | sort -u)

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
