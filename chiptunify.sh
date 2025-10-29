#!/bin/bash

# --- Csound MIDI Preprocessor and Runner Script ---
# Usage: ./chiptunify.sh <action> <csd_file> <midi_file> <synth_type>
# Example: ./chiptunify.sh play chiptune_synth.csd song1.mid FM
#
# The script automatically removes Tempo events from the MIDI file
# before running Csound to prevent timing errors.

FIXED_MIDI=""
ALLOWED_TYPES=("BUZZ" "SQUARE" "SAW" "FM" "SQUARENES")
DEFAULT_TYPE="BUZZ"

show_help() {
    echo "Usage: $0 <action> <csd_file> <midi_file> [SYNTH_TYPE]"
    echo ""
    echo "Actions: play (real-time) | build (to .wav)"
    echo "Default SYNTH_TYPE: ${DEFAULT_TYPE}"
    echo "Allowed SYNTH_TYPES: ${ALLOWED_TYPES[*]}"
    exit 0
}

# Function to remove Tempo events from the MIDI file
# Args: $1 = input MIDI file path
fix_midi() {
    local INPUT_MIDI="$1"
    # Create a temporary output file path for the fixed MIDI
    FIXED_MIDI="${INPUT_MIDI%.mid}_fixed_temp.mid"

    # Use midicsv, remove lines containing "Tempo", and pipe to csvmidi
    echo "--- Fixing MIDI: Removing Tempo events from ${INPUT_MIDI}..."
    midicsv "${INPUT_MIDI}" | grep -v "Tempo" | csvmidi > "${FIXED_MIDI}"

    # Check if the fix was successful and return the path
    if [ -f "${FIXED_MIDI}" ]; then
        echo "--- Fixed MIDI created: ${FIXED_MIDI}"
        echo "${FIXED_MIDI}"
        return 0
    else
        echo "Error: midicsv or csvmidi failed." >&2
        return 1
    fi
}

# --- Main Execution ---

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_help
fi

# 1. Check for required arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <action> <midi_file> [SYNTH_TYPE]"
    echo "Actions: play (real-time) | build (to .wav)"
    echo "Default SYNTH_TYPE: ${DEFAULT_TYPE}"
    echo "Allowed SYNTH_TYPES: ${ALLOWED_TYPES[*]}"
    exit 1
fi

ACTION="$1"
CSD_FILE="chiptune_synth.csd"
ORIGINAL_MIDI_FILE="$2"
SYNTH_TYPE="${4:-$DEFAULT_TYPE}"

# 2. Argument validation
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

# 3. FIX the MIDI file before proceeding
fix_midi "$ORIGINAL_MIDI_FILE"
if [ $? -ne 0 ]; then
    exit 1
fi

# Set trap to clean up the temporary fixed MIDI file upon exit
trap "rm -f \"$FIXED_MIDI\"" EXIT

echo "--- Synthesizing with $SYNTH_TYPE ---"

# 4. Execute the action
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
