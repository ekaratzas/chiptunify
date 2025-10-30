#!/bin/bash

# --- Csound MIDI Preprocessor and Runner Script ---
# Usage: ./chiptunify.sh <action> <csd_file> <midi_file> <synth_type>
# Example: ./chiptunify.sh play chiptune_synth.csd song1.mid FM
#
# The script automatically removes Tempo events from the MIDI file
# before running Csound to prevent timing errors.

FIXED_MIDI=""
ALLOWED_TYPES=("BUZZ" "SAW" "FM" "SQUARENES")
DEFAULT_TYPE="BUZZ"

show_help() {
    echo "Usage: $0 <action> -m <midi_file> [-s <synth_type>] [-a]"
    echo "  action: play | build"
    echo "  -a accelerates tempo if original midi is too slow"
    echo "  Default SYNTH_TYPE: ${DEFAULT_TYPE}"
    echo "  Allowed SYNTH_TYPES: ${ALLOWED_TYPES[*]}"
    exit 1
}

# Function to remove Tempo events from the MIDI file
# Args: $1 = input MIDI file path
# Args: $2 = output MIDI file path
# Args: $3 = optional tempo adjust
fix_midi_tempo() {
    local INPUT_MIDI="$1"
    local OUTPUT_MIDI="$2"
    local FASTER="$3"

    # Use midicsv, remove lines containing "Tempo", and pipe to csvmidi
    echo "--- Fixing MIDI: Removing Tempo events from ${INPUT_MIDI}..."
    midicsv "${INPUT_MIDI}" | grep -v "Tempo" | csvmidi > "${OUTPUT_MIDI}"

    if [[ ! -z ${FASTER} ]]; then
        echo "GO FASTER"
        local TMP_FILE=$(mktemp)
        cp ${OUTPUT_MIDI} ${TMP_FILE}

        midicsv "$TMP_FILE" \
          | awk -F', ' 'BEGIN{OFS=", "} {
              # scale absolute tick timestamp (column 2) by 0.5
              if ($2 ~ /^[0-9]+$/) $2 = int($2 * 0.67 + 0.5)
              print
            }' \
          | csvmidi > "$OUTPUT_MIDI"

        rm -f $TMP_FILE
    fi

    # Check if the fix was successful and return the path
    if [ -f "${OUTPUT_MIDI}" ]; then
        echo "--- Fixed MIDI created: ${OUTPUT_MIDI}"
        return 0
    else
        echo "Error: midicsv or csvmidi failed." >&2
        return 1
    fi
}

ACTION="$1"
if [[ "$ACTION" != "play" && "$ACTION" != "build" ]]; then
  echo "Error: Missing or invalid action (must be 'play' or 'build')."
  show_help
fi
shift

SYNTH_TYPE=${DEFAULT_TYPE}
GOFASTER=""
CSD_FILE="chiptune_synth.csd"

while getopts ":m:s:a" opt; do
  case $opt in
    m) ORIGINAL_MIDI_FILE="$OPTARG" ;;
    s) SYNTH_TYPE="$OPTARG" ;;
    a) GOFASTER=1 ;;
    \?) echo "Error: Invalid option -$OPTARG" >&2; show_help ;;
    :) echo "Error: Option -$OPTARG requires an argument." >&2; show_help ;;
  esac
done


if [ ! -f "$CSD_FILE" ]; then
    echo "Error: CSD file '$CSD_FILE' not found."
    exit 1
fi
if [ ! -f "$ORIGINAL_MIDI_FILE" ]; then
    echo "Error: MIDI file '$ORIGINAL_MIDI_FILE' not found."
    exit 1
fi

# Validate Synthesis Type
VALID=0
for TYPE in "${ALLOWED_TYPES[@]}"; do
    if [ "$TYPE" == "$SYNTH_TYPE" ]; then
        VALID=1
        break
    fi
done

if [ "$VALID" -eq 0 ]; then
    echo "Error: Invalid SYNTH_TYPE '$SYNTH_TYPE'."
    echo "Allowed SYNTH_TYPES: ${ALLOWED_TYPES[*]}"
    exit 1
fi

CSOUND_FLAG="--omacro:${SYNTH_TYPE}=1"

# Create a temporary output file path for the fixed MIDI
FIXED_MIDI="${INPUT_MIDI%.mid}_fixed_temp.mid"
fix_midi_tempo "$ORIGINAL_MIDI_FILE" "$FIXED_MIDI" "$GOFASTER"
if [ $? -ne 0 ]; then
    exit 1
fi

# Set trap to clean up the temporary fixed MIDI file upon exit
trap "rm -f \"$FIXED_MIDI\"" EXIT

echo "--- Synthesizing with $SYNTH_TYPE ---"

case "$ACTION" in
    play)
        echo "--- Running Csound (Real-time) ---"
        csound -odac -F "$FIXED_MIDI" $CSOUND_FLAG "$CSD_FILE"
        ;;
    
    build)
        WAV_FILE="${CSD_FILE%.csd}.wav"
        MP3_FILE="${ORIGINAL_MIDI_FILE%.mid}.mp3"
        echo "--- Running Csound (Build) to ${WAV_FILE} ---"
        csound -F "$FIXED_MIDI" $CSOUND_FLAG -W -o "$WAV_FILE" "$CSD_FILE"
        if [[ $? -eq 0 ]]; then
            ffmpeg -i ${WAV_FILE} -codec:a libmp3lame -q:a 2 ${MP3_FILE}
        fi
        ;;
    
    *)
        echo "Error: Invalid action '$ACTION'. Use 'play' or 'build'."
        exit 1
        ;;
esac

# 5. The trap handles cleanup, but we exit cleanly here.
exit 0
