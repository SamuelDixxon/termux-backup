#!/bin/bash

if ! command -v termux-clipboard-set &> /dev/null; then
    pkg install termux-api -y
fi

if date -v-1d >/dev/null 2>&1; then
    PREV_MON=$(date -v-prev Mon +"%B %d, %Y")
    PREV_SUN=$(date -v-prev Sun +"%B %d, %Y")
else
    PREV_MON=$(date -d "last monday - 7 days" +"%B %d, %Y")
    PREV_SUN=$(date -d "last sunday" +"%B %d, %Y")
fi

OUTPUT=$(cat <<END
TITLE: Pistol Squat Progress (573-615)
DATE RANGE: $PREV_MON – $PREV_SUN

DESCRIPTION:
Welcome to another weekly breakdown of the Pistol Squat Progress series! This log tracks single-leg strength, balance, and mobility development from $PREV_MON through $PREV_SUN. Follow along to see key metric updates, volume progression, and training insights for reps 573 through 615.
END
)

echo "$OUTPUT" | termux-clipboard-set
echo "Copied to clipboard!"
