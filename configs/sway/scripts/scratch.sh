#!/bin/sh
# scratch.sh — drop-down terminal (mango Super+grave)
#
# Spawns a single foot-scratch terminal on first press, then toggles it
# in/out of the scratchpad. A script (not a criteria bindsym) so a press
# with no scratch window can't fail with sway's "No matching node." error
# (swaymsg exit 2) that the old `[app_id] scratchpad show` binding threw.
#
# Used by: bindsym $mod+grave exec ~/.config/sway/scripts/scratch.sh
# plus:    for_window [app_id="foot-scratch"] move scratchpad

if swaymsg -t get_tree | grep -Fq '"foot-scratch"'; then
	# Existing scratch window: show it (hides again if already visible —
	# sway's scratchpad show toggles).
	swaymsg '[app_id="foot-scratch"] scratchpad show'
else
	# First press: spawn it; the for_window rule moves it to the scratchpad.
	foot --app-id foot-scratch &
fi
