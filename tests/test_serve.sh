#!/bin/bash
# Proves server/roba-serve's promises without a server: it refuses what is not a roba command,
# accepts a push, and a backup repository refuses a deletion and a non-fast-forward push.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
fails=0
expect() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails+1)); fi; }
serve() { HOME=$S SSH_ORIGINAL_COMMAND="$1" python3 "$HERE/server/roba-serve" </dev/null >/dev/null 2>&1; }
expect "no command is refused"            '! serve ""'
expect "a shell is refused"               '! serve "bash -i"'
expect "a path outside git/ is refused"   "! serve \"git-receive-pack '../../etc/x.git'\""
expect "listing answers"                  'serve "roba-list"'
mkdir "$S/src"; git -C "$S/src" init -q; git -C "$S/src" commit -q --allow-empty -m one
RP="env SSH_ORIGINAL_COMMAND=\"git-receive-pack 'backups/git/src.git'\" HOME=$S python3 $HERE/server/roba-serve"
expect "a push is accepted"               "git -C '$S/src' push -q --receive-pack=\"\$RP\" '$S/x' 'refs/heads/*:refs/heads/*' 2>/dev/null"
git -C "$S/src" branch side
expect "a second branch is accepted"     "git -C '$S/src' push -q --receive-pack=\"\$RP\" '$S/x' side 2>/dev/null"
# not the current branch: git itself already refuses to delete a bare repository's HEAD branch
expect "a deletion is refused"            "! git -C '$S/src' push -q --receive-pack=\"\$RP\" '$S/x' :refs/heads/side 2>/dev/null"
git -C "$S/src" commit -q --amend --allow-empty -m rewritten
expect "a rewrite is refused"             "! git -C '$S/src' push -q --force --receive-pack=\"\$RP\" '$S/x' master 2>/dev/null"
expect "the old history is still there"   "[ \"\$(git -C '$S/backups/git/src.git' log --format=%s -1)\" = one ]"
exit $fails
