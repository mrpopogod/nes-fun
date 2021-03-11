song8_header:
    .byte $04           ;4 streams
    
    .byte MUSIC_SQ1         ;which stream
    .byte $01               ;status byte (stream enabled)
    .byte SQUARE_1          ;which channel
    .byte $B0               ;initial duty (10)
    .byte ve_short_staccato ;volume envelope
    .word song8_square1     ;pointer to stream
    .byte $60               ;tempo
    
    .byte MUSIC_SQ2         ;which stream
    .byte $01               ;status byte (stream enabled)
    .byte SQUARE_2          ;which channel
    .byte $B0               ;initial duty (10)
    .byte ve_short_staccato ;volume envelope
    .word song8_square2     ;pointer to stream
    .byte $60               ;tempo
    
    .byte MUSIC_TRI         ;which stream
    .byte $01               ;status byte (stream enabled)
    .byte TRIANGLE          ;which channel
    .byte $81               ;initial volume (on)
    .byte ve_short_staccato ;volume envelope
    .word song8_tri         ;pointer to stream
    .byte $60               ;tempo
    
    .byte MUSIC_NOI         ;which stream
    .byte $00               ;disabled.  Our load routine will skip the
                            ;   rest of the reads if the status byte is 0.
                            ;   We are disabling Noise because we haven't covered it yet.

    ; now that we have envelopes we don't need the weird rests for consecutive notes
song8_square1:
    .byte eighth, Fs4, Fs4, D4, B3, rest, B3, rest, E4
    .byte         rest, E4, rest, E4, Gs4, Gs4, A4, B4
    .byte         A4, A4, A4, E4, rest, D4, rest, Fs4
    .byte         rest, Fs4, rest, Fs4, E4, E4, Fs4, E4
    .byte loop
    .word song8_square1

song8_square2:
    .byte set_note_offset, $18 ; up an octave and a half - this enriches the sound and gets it closer to the synth of the original
    .byte eighth, Fs4, Fs4, D4, B3, rest, B3, rest, E4
    .byte         rest, E4, rest, E4, Gs4, Gs4, A4, B4
    .byte         A4, A4, A4, E4, rest, D4, rest, Fs4
    .byte         rest, Fs4, rest, Fs4, E4, E4, Fs4, E4
    .byte loop
    .word song8_square2
    
song8_tri:
    .byte quarter, B2, B3, eighth, rest, B2, quarter, B3
    .byte          E3, E4, eighth, rest, E3, quarter, E4
    .byte          A2, A3, eighth, rest, A2, quarter, A3
    .byte          D3, D4, C3, Cs4
    .byte loop
    .word song8_tri