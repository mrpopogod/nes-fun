song4_header:
    .b $04           ;4 streams
    
    .b MUSIC_SQ1     ;which stream
    .b $01           ;status byte (stream enabled)
    .b SQUARE_1      ;which channel
    .b $BC           ;initial volume (C) and duty (10)
    .w song4_square1 ;pointer to stream
    
    .b MUSIC_SQ2     ;which stream
    .b $01           ;status byte (stream enabled)
    .b SQUARE_2      ;which channel
    .b $3A           ;initial volume (A) and duty (00)
    .w song4_square2 ;pointer to stream
    
    .b MUSIC_TRI     ;which stream
    .b $01           ;status byte (stream enabled)
    .b TRIANGLE      ;which channel
    .b $81           ;initial volume (on)
    .w song4_tri     ;pointer to stream
    
    .b MUSIC_NOI     ;which stream
    .b $00           ;disabled.  Our load routine will skip the
                        ;   rest of the reads if the status byte is 0.
                        ;   We are disabling Noise because we haven't covered it yet.
    
; three randomly generated note tables
song4_square1:
    .b C3, A4, F8, D7, G3, E5, F6, C3
    .b E6, D6, E6, E3, B8, D2, D4, F5
    .b D5, G7, A5, E5, C4, G7, A5, E8
    .b B4, A4, C8, F5, C5, D3, E5, C3
    .b $FF
    
song4_square2:
    .b G4, C7, G5, C3, D3, F6, A4, E7 
    .b A8, F7, A8, A7, C7, A7, A6, B8
    .b F4, A4, B2, C4, A2, G5, D8, A6
    .b G8, F6, B6, D7, A2, E4, G3, B7
    .b $FF
    
song4_tri:
    .b A4, F3, F7, G6, C4, D5, D3, E2
    .b A6, D5, G5, A6, A2, G8, E8, G2
    .b A8, C3, A5, B2, F4, G4, C7, F3
    .b B7, C3, F2, C8, A5, E7, B4, A3
    .b $FF
