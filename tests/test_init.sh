#!/bin/bash
# Proves what `roba init` writes, in a throwaway home each time: the login it is given or asked for, the
# placeholder when nobody answers, a refusal of anything that is not a login or a folder, and an existing
# config left alone. No server is reached: every login here is an example, and the placeholder stops first.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
fails=0
expect() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails+1)); fi; }
home() { mktemp -d; }
init() { local h=$1; shift; HOME=$h python3 "$HERE/roba" init "$@" </dev/null >"$h/out" 2>&1; }
cfg() { cat "$1/.config/roba/config" 2>/dev/null; }

H=$(home); init $H --host someone@lab.example
expect "--host is written as the login"            'cfg $H | grep -qx "host = someone@lab.example"'
expect "the folder is backups when not given"       'cfg $H | grep -qx "root = backups"'
expect "the key is made"                            '[ -f $H/.ssh/roba_ed25519 ] && [ "$(stat -c %a $H/.ssh)" = 700 ]'
H2=$(home); init $H2 --host someone@lab.example --root store/roba
expect "--root is written as the folder"            'cfg $H2 | grep -qx "root = store/roba"'

P=$(home); init $P
expect "nobody to ask and no --host: the placeholder" 'cfg $P | grep -qx "host = you@your-lab-server"'
expect "and init says to set it"                    'grep -q "set \[server\] host" $P/out'
HOME=$P python3 "$HERE/roba" install-server >$P/stop 2>&1; code=$?
expect "the placeholder stops install-server"       '[ $code = 1 ] && grep -q "to your own login first" $P/stop'

for bad in "-oProxyCommand=touch_x" "someone@lab.example;rm" "nobody" "a b@lab.example"; do
  B=$(home); init $B "--host=$bad"; code=$?
  expect "--host '$bad' is refused, nothing written" '[ $code = 1 ] && [ ! -e $B/.config/roba/config ]'
done
for bad in "../outside" "/abs/path" "a b" "x;y"; do
  B=$(home); init $B --host someone@lab.example "--root=$bad"; code=$?
  expect "--root '$bad' is refused, nothing written" '[ $code = 1 ] && [ ! -e $B/.config/roba/config ]'
done

K=$(home); init $K --host someone@lab.example; before=$(cfg $K); init $K --host other@lab.example
expect "an existing config is kept"                 '[ "$(cfg $K)" = "$before" ]'
expect "and init says --host was not written"       'grep -q "were not written" $K/out'

E=$(home); init $E --host someone@lab.example; sed -i 's/^host = .*/host = -oProxyCommand=touch_x/' $E/.config/roba/config
HOME=$E python3 "$HERE/roba" install-server >$E/stop 2>&1; code=$?
expect "a hand-written login of the wrong shape stops" '[ $code = 1 ] && grep -q "is not user@address" $E/stop'

# AT A TERMINAL it asks, and writes what was typed.
T=$(home)
python3 - "$HERE/roba" "$T" <<'PY'
import os, pty, select, sys, time
roba, home = sys.argv[1], sys.argv[2]
pid, fd = pty.fork()
if pid == 0:
    os.environ['HOME'] = home
    os.execvp('python3', ['python3', roba, 'init'])
seen = b''
def wait_for(word, limit=20):
    global seen
    end = time.time() + limit
    while word not in seen and time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try: seen += os.read(fd, 4096)
            except OSError: break
    return word in seen
ok = wait_for(b'user@address') and (os.write(fd, b'someone@lab.example\n') or True) and wait_for(b'[backups]') and (os.write(fd, b'store/roba\n') or True)
wait_for(b'next:')
os.waitpid(pid, 0)
sys.exit(0 if ok else 1)
PY
expect "at a terminal it asks, and writes the answers" 'cfg $T | grep -qx "host = someone@lab.example" && cfg $T | grep -qx "root = store/roba"'

echo; [ $fails = 0 ] && echo "all passed" || echo "$fails failed"
exit $fails
