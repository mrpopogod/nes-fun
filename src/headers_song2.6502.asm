song2_header:
    .b $01           ;1 stream
    
    .b SFX_1         ;which stream
    .b $01           ;status byte (stream enabled)
    .b SQUARE_2      ;which channel
    .b $7F           ;initial volume (F) and duty (01)
    .w song2_square2 ;pointer to stream
    
    
song2_square2:
    .b D3, D2
    .b $FF