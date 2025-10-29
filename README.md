# 8-Bit Chiptune Synthesizer

This project uses Csound to process MIDI files, converting them into classic 8-bit chiptune sounds. The synthesis style is controlled via a shell script flag.

## Script dependencies

debian/ubuntu/mint

> ./install_dependencies.sh

## Usage

Execute the main script, passing the CSD file, your MIDI input, and a optional synthesis type:

# play a file
> ./chiptunify.sh play -m your_song.mid

# play a file with specific synt type
> ./chiptunify.sh play -m your_song.mid -s SAW

# convert to .wav
> ./chiptunify.sh build -m your_song.mid

Refer to ./chiptunify.sh --help for a list of supported SYNTH types
