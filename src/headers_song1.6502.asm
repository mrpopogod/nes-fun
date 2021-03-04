song1_header:
    .b $04           ;4 streams
    
    .b MUSIC_SQ1     ;which stream
    .b $01           ;status byte (stream enabled)
    .b SQUARE_1      ;which channel
    .b $77           ;initial volume (7) and duty (01)
    .w song1_square1 ;pointer to stream
    
    .b MUSIC_SQ2     ;which stream
    .b $01           ;status byte (stream enabled)
    .b SQUARE_2      ;which channel
    .b $B7           ;initial volume (7) and duty (10)
    .w song1_square2 ;pointer to stream
    
    .b MUSIC_TRI     ;which stream
    .b $01           ;status byte (stream enabled)
    .b TRIANGLE      ;which channel
    .b $81           ;initial volume (on)
    .w song1_tri     ;pointer to stream
    
    .b MUSIC_NOI     ;which stream
    .b $00           ;disabled.  Our load routine will skip the
                        ;   rest of the reads if the status byte is 0.
                        ;   We are disabling Noise because we haven't covered it yet.
    
song1_square1:
    .b B2, D3, F3, Gs3, B3, D4, F4, Gs4, B4, D5, F5, Gs5, B5, D6, F6, Gs6    ;bunch of minor thirds.  diminished sound
    .b Bb2, Db3, E3, G3, Bb3, Db4, E4, G4, Bb4, Db5, E5, G5, Bb5, Db6, E6, G6 ;same again but down a half step
    .b $FF
    
song1_square2:
    .b Gs5, F5, D5, Gs5, F5, D5, B4, F5, D5, B4, Gs4, D5, B4, Gs4, F4, B4
    .b G5, E5, Db5, G5, E5, Db5, Bb4, E5, Db5, Bb4, G4, Db5, Bb4, G4, E4, Bb4
    .b $FF
    
song1_tri:
    .b F6, D6, B5, D6, B5, Gs5, B5, Gs5, F5, Gs5, F5, D5, F5, D5, B4, Gs4
    .b E6, Db6, Bb5, Db6, Bb5, G5, Bb5, G5, E5, G5, E5, Db5, E5, Db5, Bb4, G4
    .b $FF