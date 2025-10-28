<CsoundSynthesizer>
<CsOptions>
; Set sample rate and channels
-sr 44100 -nchnls 1
; Terminate the performance when the end of MIDI file is reached
-T
</CsOptions>

<CsInstruments>
; Header section
sr = 44100 ; standard sample rate for cd quality audio
kr = 4410 ; control rate
ksmps = 10 ; control samples
nchnls = 1 ; number of channels. stero would be 2

; note: remove tempo from midi
; csound will recalculate relative delta/timestamps in midi as absolute timestamps from beginning
; due to tempo change and that could introduce silence gaps

; https://csound.com/docs/manual/ScoreGenRef.html
gisine   ftgen 1, 0, 16384, 10, 1	;sine wave
gisquare ftgen 2, 0, 16384, 10, 1, 0 , .33, 0, .2 , 0, .14, 0 , .11, 0, .09 ;odd harmonics
gisquarenes ftgen 3, 0, 16384, 7, 1, 8192, 1, 8192, 0 ; 50% duty wave
gisaw    ftgen 4, 0, 16384, 10, 0, .2, 0, .4, 0, .6, 0, .8, 0, 1, 0, .8, 0, .6, 0, .4, 0,.2 ;even harmonics

instr 1
    ; --- 1. MIDI Parameter Reading & Duration Fix ---
    iFreq cpsmidi ; Cycles Per Second from Midi. midi note -> freq
    iAmp ampmidi 127, 0.5 ; amplitude midi. 0-127, so 127 is loudest. 0.5 leaves headroom due to potential effects adding more volume
    
    ; Define the instrument's release time
    ; This is the extra time needed to fade out smoothly.
    ; super small release/attack time used to circumvent issues with 1/16, 1/32 notes in fast tempo
    ; could probably go higher here
    iReleaseTime = 0.001
    
    ; The xtratim opcode extends the life of the instrument
    ; by the amount of the release time, preventing a click.
    xtratim iReleaseTime
    
    ; Define a minimum duration to override a "zero-duration" MIDI glitch.
    iMinDuration = 0.01
    iDuration = p3
    if iDuration < iMinDuration then
        iDuration = iMinDuration
    endif
    
    ; --- 2. Synthesis and Envelope ---
    iScale = 10
    #ifdef BUZZ
    ; amplitude, freq, ratio, function table
        aSig buzz iFreq, iFreq, 0.25, gisine
    #end
    #ifdef SQUARE
        aSig poscil3 iScale, iFreq, gisquare
    #endif
    #ifdef SQUARENES
        aSig poscil3 iScale, iFreq, gisquarenes
    #endif
    #ifdef SAW
        aSig poscil3 iScale, iFreq, gisaw
    #endif
    #ifdef FM
        kcar = 1.41
        kmod = p4
        kndx line 0, p3, 5	;intensivy sidebands

        aSig foscil 250, iFreq, kcar, kmod, kndx, gisine
    #end

    ; midicsv shows tempo like 1, 46080, Tempo, 285714
    ; where a quarter note is 258714 microseconds
    ; therefore a 1/16 note would be 71milsecs in duration
    iAttackTime = 0.001 

    ; Use linsegr (linear segment with release).
    ; This opcode uses p3 (iDuration) for the main body of the note,
    ; and then automatically fades out over the iReleaseTime specified above.
    ; linsegr: 0, Attack_Time, Peak_Amplitude, Sustain_Time, Release_Time
    ; aEnv=linsegr(iStartAmp,iAttackTime,iPeakAmp,iSustainTime,iReleaseTime)
    aEnv linsegr 0, iAttackTime, iAmp, iDuration, iReleaseTime
    
    ; The iDuration used here is now the actual time the note is played at full amplitude,
    ; or the safe minimum if the MIDI p3 was too short.

    ;prints "Freq:%f, asig %f, aenv %f\n", iFreq, aSig, aEnv
    ; --- 3. Output ---
    out aSig * aEnv * 0.7 
endin


</CsInstruments>

<CsScore>
; Run for a long time, the -T flag will stop it when the MIDI ends.
f0 10000
</CsScore>
</CsoundSynthesizer>
