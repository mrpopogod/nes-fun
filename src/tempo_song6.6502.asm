song6_header:
    .byte $04           ;4 streams
    
    .byte MUSIC_SQ1     ;which stream
    .byte $01           ;status byte (stream enabled)
    .byte SQUARE_1      ;which channel
    .byte $BC           ;initial volume (C) and duty (10)
    .word song6_square1 ;pointer to stream
    .byte $60           ;tempo
    
    .byte MUSIC_SQ2     ;which stream
    .byte $00           ;this song wants a single clear tone for the melody, so no square 2
    
    .byte MUSIC_TRI     ;which stream
    .byte $01           ;status byte (stream enabled)
    .byte TRIANGLE      ;which channel
    .byte $81           ;initial volume (on)
    .word song6_tri     ;pointer to stream
    .byte $60           ;tempo
    
    .byte MUSIC_NOI     ;which stream
    .byte $00           ;disabled.  Our load routine will skip the
                        ;   rest of the reads if the status byte is 0.
                        ;   We are disabling Noise because we haven't covered it yet.

    ; note - in order to get individual notes our eighths need to be dotted sixteenths with thirtysecond rests    
song6_square1:
    .byte d_sixteenth, Fs4, thirtysecond, rest, d_sixteenth, Fs4, thirtysecond, rest, d_sixteenth, D4, thirtysecond, rest, d_sixteenth, B3, thirtysecond, rest
    .byte eighth, rest, d_sixteenth, B3, thirtysecond, rest, eighth, rest, d_sixteenth, E4, thirtysecond, rest
    .byte eighth, rest, d_sixteenth, E4, thirtysecond, rest, eighth, rest, d_sixteenth, E4, thirtysecond, rest
    .byte d_sixteenth, Gs4, thirtysecond, rest, d_sixteenth, Gs4, thirtysecond, rest, d_sixteenth, A4, thirtysecond, rest, d_sixteenth, B4, thirtysecond, rest

    .byte d_sixteenth, A4, thirtysecond, rest, d_sixteenth, A4, thirtysecond, rest, d_sixteenth, A4, thirtysecond, rest, d_sixteenth, E4, thirtysecond, rest
    .byte eighth, rest, d_sixteenth, D4, thirtysecond, rest, eighth, rest, d_sixteenth, Fs4, thirtysecond, rest
    .byte eighth, rest, d_sixteenth, Fs4, thirtysecond, rest, eighth, rest, d_sixteenth, Fs4, thirtysecond, rest
    .byte d_sixteenth, E4, thirtysecond, rest, d_sixteenth, E4, thirtysecond, rest, d_sixteenth, Fs4, thirtysecond, rest, d_sixteenth, E4, thirtysecond, rest

    .byte $FF
    
song6_tri:
    .byte quarter, B2, B3, eighth, rest, B2, quarter, B3
    .byte          E3, E4, eighth, rest, E3, quarter, E4
    .byte          A2, A3, eighth, rest, A2, quarter, A3
    .byte          D3, D4, C3, Cs4
    .byte $FF