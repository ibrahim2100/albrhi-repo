#!/bin/bash
# Runs the whole control/pairing story against the daemon HOST build (a moving test picture, no phone, no simulator):
#   bash experiments/mirror/mac/build.sh && bash experiments/mirror/test.sh
# Expect: off by default, pairing only through an open window, wrong codes burn the attempts, the code works once,
# a session needs the pairing, switching off or unpairing ends it.
D=/tmp/albrhi-mirror-test/mirrord-host
V=~/Desktop/Albrhi-Mirror/viewer
STATE=/tmp/t_state; PORT=9811
rm -rf $STATE /tmp/t_mac_secret; mkdir -p $STATE
($D --port $PORT --fps 8 --state-dir $STATE > /tmp/t_ctl.log 2>&1 &); sleep 1
ctl() { $D --state-dir $STATE --control "$1"; }
field() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d$1)" 2>/dev/null; }

echo "--- 0. fresh install"; head -1 /tmp/t_ctl.log
echo "    socket: $(ls -l $STATE/control.sock | awk '{print $1, $9}')   state dir: $(ls -ld $STATE | awk '{print $1}')"
echo "--- 1. switched OFF by default: the viewer must be told so and get nothing"
$V --selftest --port $PORT --secret-file /tmp/t_mac_secret | head -1
echo "    (a pairing attempt while off)"; echo 000000 | $V --selftest-pair --port $PORT --secret-file /tmp/t_mac_secret | head -1
echo "--- 2. pair-start while off is refused"; ctl pair-start
echo "--- 3. switch ON from the app"; ctl enable | field "['enabled']"
echo "    enabled flag file: $(ls $STATE/enabled)"
echo "--- 4. a Mac asks to pair but no window is open"; echo 000000 | $V --selftest-pair --port $PORT --secret-file /tmp/t_mac_secret | head -1
echo "--- 5. the app opens the window and shows the code"
REPLY=$(ctl pair-start); echo "    status: $REPLY"
CODE=$(echo "$REPLY" | field "['pairing']['code']"); echo "    code shown in the app: $CODE"
echo "--- 6. wrong codes burn the attempts (the window closes after three)"
printf '111111\n222222\n333333\n' | $V --selftest-pair --port $PORT --secret-file /tmp/t_mac_secret | head -1
echo "    paired afterwards? $(ctl status | field "['paired']")   window open? $(ctl status | field ".get('pairing')")"
echo "--- 7. a fresh window, the RIGHT code"
CODE=$(ctl pair-start | field "['pairing']['code']")
echo "$CODE" | $V --selftest-pair --port $PORT --secret-file /tmp/t_mac_secret | head -1
echo "    paired: $(ctl status | field "['paired']")  window open: $(ctl status | field ".get('pairing')")"
echo "    secret on the phone side: $(ls -l $STATE/pairing | awk '{print $1}')"
echo "--- 8. the code cannot be used twice (window closed)"; echo "$CODE" | $V --selftest-pair --port $PORT --secret-file /tmp/t_mac_secret | head -1
echo "--- 9. a session"; $V --selftest --port $PORT --secret-file /tmp/t_mac_secret --save /tmp/t_frame.jpg | head -1

echo "--- 10. switching OFF in the app ends a running session"
( $V --selftest --port $PORT --secret-file /tmp/t_mac_secret --save /tmp/t_frame2.jpg > /tmp/t_sess.out 2>&1 & )
sleep 0.4; ctl disable | field "['enabled']"; sleep 2
echo "    daemon still serving? session flag: $(ctl status | field "['session']")"
echo "--- 11. after disabling, a session is refused again"; $V --selftest --port $PORT --secret-file /tmp/t_mac_secret | head -1
echo "--- 12. unpair from the app"; ctl enable >/dev/null; ctl unpair | field "['paired']"; $V --selftest --port $PORT --secret-file /tmp/t_mac_secret | head -1

echo "--- 13. the control socket is not reachable by someone else's uid (peer check is by getpeereid; socket mode shown above)"
pkill -f "mirrord-host --port $PORT"
