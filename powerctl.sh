#!/bin/sh
# powerctl.sh — FreeBSD power mode switcher via kdialog + powerd

# grab sorted frequency list from freq_levels (lowest first)
FREQS=$(sysctl -n dev.cpu.0.freq_levels | tr ' ' '\n' | cut -d/ -f1 | sort -n)
FREQ_MIN=$(echo "$FREQS" | head -1)
FREQ_MAX=$(echo "$FREQS" | tail -1)
FREQ_MAX2=$(echo "$FREQS" | tail -2 | head -1)

# freq_levels represents turbo as base+1 (e.g. 2601 for 2.6GHz turbo)
TURBO_LABEL="Turbo"

# get current powerd flags if running
CURRENT_PID=$(pgrep -x powerd)
if [ -n "$CURRENT_PID" ]; then
    CURRENT_FLAGS=$(ps -o args= -p "$CURRENT_PID" | sed 's/^powerd//')
else
    CURRENT_FLAGS="(powerd not running)"
fi

MODE=$(kdialog --title "Power Mode" \
    --menu "Select power mode\n\nCurrent: $CURRENT_FLAGS\nFrequency range: ${FREQ_MIN}–${TURBO_LABEL} MHz" \
    battery "Battery Saver (${FREQ_MIN} MHz)" \
    balanced "Balanced (${FREQ_MIN}–${TURBO_LABEL})" \
    performance "Performance (${FREQ_MAX2} MHz + ${TURBO_LABEL})")

[ $? -ne 0 ] && exit 0

case "$MODE" in
    battery)
        FLAGS="-a min -b min -M $FREQ_MIN -m $FREQ_MIN"
        ;;
    balanced)
        FLAGS="-a adaptive -b adaptive"
        ;;
    performance)
        FLAGS="-a max -b max -m $FREQ_MAX2"
        ;;
esac

# restart powerd with new flags
if [ "$(id -u)" -ne 0 ]; then
    if command -v pkexec >/dev/null 2>&1; then
        pkexec sh -c "service powerd onestop 2>/dev/null; powerd $FLAGS"
        if [ $? -ne 0 ]; then
            kdialog --error "Authentication failed or cancelled"
            exit 1
        fi
    elif command -v doas >/dev/null 2>&1; then
        doas sh -c "service powerd onestop 2>/dev/null; powerd $FLAGS &"
    elif command -v sudo >/dev/null 2>&1; then
        sudo sh -c "service powerd onestop 2>/dev/null; powerd $FLAGS &"
    else
        kdialog --error "No privilege escalation tool found"
        exit 1
    fi
else
    service powerd onestop 2>/dev/null
    powerd $FLAGS &
fi

kdialog --passivepopup "Power mode: $MODE" 3
