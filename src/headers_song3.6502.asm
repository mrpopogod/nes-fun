song3_header:
    .b $04           ;4 streams
    
    .b MUSIC_SQ1     ;which stream
    .b $01           ;status byte (stream enabled)
    .b SQUARE_1      ;which channel
    .b $BC           ;initial volume (C) and duty (10)
    .w song3_square1 ;pointer to stream
    
    .b MUSIC_SQ2     ;which stream
    .b $01           ;status byte (stream enabled)
    .b SQUARE_2      ;which channel
    .b $3A           ;initial volume (A) and duty (00)
    .w song3_square2 ;pointer to stream
    
    .b MUSIC_TRI     ;which stream
    .b $01           ;status byte (stream enabled)
    .b TRIANGLE      ;which channel
    .b $81           ;initial volume (on)
    .w song3_tri     ;pointer to stream
    
    .b MUSIC_NOI     ;which stream
    .b $00           ;disabled.  Our load routine will skip the
                        ;   rest of the reads if the status byte is 0.
                        ;   We are disabling Noise because we haven't covered it yet.
    
song3_square1:
    .b A3, C4, E4, A4, C5, E5, A5, F3 ;some notes.  A minor
    .b G3, B3, D4, G4, B4, D5, G5, E3  ;Gmajor
    .b F3, A3, C4, F4, A4, C5, F5, C5 ;F major
    .b F3, A3, C4, F4, A4, C5, F5 ;F major
    .b $FF
    
song3_square2:
    .b A3, A3, A3, E4, A3, A3, E4, A3 
    .b G3, G3, G3, D4, G3, G3, D4, G3
    .b F3, F3, F3, C4, F3, F3, C4, F3
    .b F3, F3, F3, C4, F3, F3, C4
    .b $FF
    
song3_tri:
    .b A3, A3, A3, A3, A3, A3, A3, G3
    .b G3, G3, G3, G3, G3, G3, G3, F3
    .b F3, F3, F3, F3, F3, F3, F3, F3
    .b F3, F3, F3, F3, F3, F3, F3
    .b $FF