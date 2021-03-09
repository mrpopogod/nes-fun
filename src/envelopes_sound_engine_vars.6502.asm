    .org $0300 ;sound engine variables will be on the $0300 page of RAM
sound_disable_flag  .ds 1   ;a flag variable that keeps track of whether the sound engine is disabled or not. 
sound_temp1 .ds 1           ;temporary variables
sound_temp2 .ds 1
sound_sq1_old .ds 1  ;the last value written to $4003
sound_sq2_old .ds 1  ;the last value written to $4007
soft_apu_ports .ds 16

;reserve 6 bytes, one for each stream
stream_curr_sound .ds 6     ;current song/sfx loaded
stream_status .ds 6         ;status byte.   bit0: (1: stream enabled; 0: stream disabled)
stream_channel .ds 6        ;what channel is this stream playing on?
stream_ptr_LO .ds 6         ;low byte of pointer to data stream
stream_ptr_HI .ds 6         ;high byte of pointer to data stream
stream_ve .ds 6             ;current volume envelope
stream_ve_index .ds 6       ;current position within the volume envelope
stream_vol_duty .ds 6       ;stream volume/duty settings
stream_note_LO .ds 6        ;low 8 bits of period for the current note on a stream
stream_note_HI .ds 6        ;high 3 bits of period for the current note on a stream 
stream_tempo .ds 6          ;the value to add to our ticker total each frame
stream_ticker_total .ds 6   ;our running ticker total.
stream_note_length_counter .ds 6
stream_note_length .ds 6