;silence song.  disables all streams

song0_header:
    .b $06           ;6 streams
    
    .b MUSIC_SQ1     ;which stream
    .b $00           ;status byte (stream disabled)
    
    .b MUSIC_SQ2     ;which stream
    .b $00           ;status byte (stream disabled)
    
    .b MUSIC_TRI     ;which stream
    .b $00           ;status byte (stream disabled)
    
    .b MUSIC_NOI     ;which stream
    .b $00           ;disabled.
    
    .b SFX_1         ;which stream
    .b $00           ;disabled

    .b SFX_2         ;which stream
    .b $00           ;disabled