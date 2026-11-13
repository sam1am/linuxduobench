#!/bin/sh
# Sxmo device profile: Surface Duo 1 (this kernel's first DT compatible is qcom,sm8150-mtp). See sxmo.org/deviceprofile.
# Experimental, phone-only (2026-11-13). The two panels, their touchscreens and rotation are set up by
# ~/.config/sxmo/sway and duo-sway-init, not here.
export SXMO_POWER_BUTTON="0:0:pm8941_pwrkey"
export SXMO_VOLUME_BUTTON="1:1:gpio-keys 0:0:pm8941_resin"
export SXMO_MONITOR="DSI-1"
export SXMO_DISABLE_LEDS=1
export SXMO_WORKSPACE_WRAPPING=4
