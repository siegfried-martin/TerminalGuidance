#!/usr/bin/env bash
# Run the game with the touchpad's "disable while typing" suppressed, and put it
# back however the game exits.
#
# WHY THIS EXISTS. GNOME (libinput) mutes the touchpad for a short window after every
# key event, so a wrist resting below the keyboard cannot click on things while you
# type. Holding a key auto-repeats, which keeps that window open for as long as it is
# held — so in a game where W is the throttle and the trackpad is the stick, you can
# steer or accelerate and never both. The setting is worth keeping everywhere else,
# and there is no per-application override for it, so this is the next best thing:
# off for exactly the lifetime of the game, restored on the way out.
#
# It is deliberately noisy about touching a system setting, and deliberately a no-op
# where the setting does not exist (a mouse-only desktop, another environment, CI).
#
# Known gap: a hard kill (SIGKILL, a power cut) skips the trap and leaves the setting
# off. `gsettings reset` on the key below puts it back, and so does the next clean run.

set -u

KEY_SCHEMA="org.gnome.desktop.peripherals.touchpad"
KEY_NAME="disable-while-typing"
_previous=""

restore() {
	[ -n "$_previous" ] || return 0
	gsettings set "$KEY_SCHEMA" "$KEY_NAME" "$_previous" 2>/dev/null || true
	echo "touchpad: $KEY_NAME back to $_previous"
	_previous=""
}

if command -v gsettings >/dev/null 2>&1; then
	current=$(gsettings get "$KEY_SCHEMA" "$KEY_NAME" 2>/dev/null || true)
	if [ "$current" = "true" ]; then
		_previous="$current"
		gsettings set "$KEY_SCHEMA" "$KEY_NAME" false 2>/dev/null \
			&& echo "touchpad: $KEY_NAME off while the game is up" \
			|| _previous=""
		trap restore EXIT INT TERM HUP
	fi
fi

"$@"
