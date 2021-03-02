    .org $0300 ;sound engine variables will be on the $0300 page of RAM
    
sound_disable_flag  .ds 1   ;a flag variable that keeps track of whether the sound engine is disabled or not. 
sound_frame_counter .ds 1   ;a primitive counter used to time notes in this demo
sfx_playing .ds 1           ;a flag that tells us if our sound is playing or not.
sfx_index .ds 1             ;our current position in the sound data.