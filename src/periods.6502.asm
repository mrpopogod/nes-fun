  .target "6502"
  .format "nes"
  .setting "NESMapper", 0
  .setting "NESVerticalMirroring", true
  .setting "ShowLabelsAfterCompiling", true
  .setting "ShowLocalLabelsAfterCompiling", true
  .setting "LaunchCommand", "c:\\emulation\\fceux.exe {0}"
  .setting "DebugCommand", "c:\\emulation\\fceux.exe {0}"

    .segment "RAM"
  .org $0000  ;;start variables at ram location 0
joypad1 .ds 1           ;button states for the current frame
joypad1_old .ds 1       ;last frame's button states
joypad1_pressed .ds 1   ;current frame's off_to_on transitions
current_note .ds 1      ;used to index into our note_table
note_value .ds 1        ;there are 12 possible note values. (A-G#, represented by $00-$0B)
note_octave .ds 1       ;what octave our note is in (1-9)
triangle_enabled .ds 1  ;are we doing triangle or square?
sleeping .ds 1          ;main program sets this and waits for the NMI to clear it.  Ensures the main program is run only once per frame.  
                        ;   for more information, see Disch's document: URL HERE
ptr1 .ds 2              ;a pointer
;----- first 8k bank of PRG-ROM    
    .bank 0, 16, $C000, "NES_PRG0" ; these should always be 16kb for PRG, 8kb for CHR
                                 ; in tutorials the number of these should match
                                 ; the number in the inesprg/ineschr directives
    .segment "MAIN_CODE" ; Replaces the bank directive from nesasm format
    .org $C000
    
irq:
NMI:
    pha ;backup registers
    txa
    pha
    tya
    pha
    
    jsr draw_note   ;draws the note and octave to the screen
    
    lda #$00        ;set scroll
    sta $2005
    sta $2005
    
    lda #$00
    sta sleeping    ;wake up the main program
    
    pla ;restore registers
    tay
    pla
    tax
    pla
    rti

RESET:
    sei
    cld
    ldx #$FF
    txs
    inx
    
vblankwait1:
    bit $2002
    bpl vblankwait1
    
clearmem:
    lda #$00
    sta $0000, x
    sta $0100, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    lda #$FE
    sta $0200, x
    inx
    bne clearmem
    
 vblankwait2:
    bit $2002
    bpl vblankwait2
    
;set a couple palette colors.  This demo only uses two
    lda $2002   ;reset PPU HI/LO latch
    
    lda #$3F
    sta $2006
    lda #$00
    sta $2006   ;palette data starts at $3F00
    
    lda #$0F    ;black
    sta $2007
    lda #$30    ;white
    sta $2007
    
;Enable sound channels
    lda #%00000101 
    sta $4015 ;enable Square 1
    
    lda #C4
    sta current_note ;start with a middle C
    jsr get_note_and_octave
    lda #$00
    sta triangle_enabled ;start with square wave
    
    lda #$88
    sta $2000   ;enable NMIs
    lda #$18
    sta $2001   ;turn PPU on
    
;main program starts here   
forever:
    inc sleeping ;go to sleep (wait for NMI).
@loop:
    lda sleeping
    bne @loop ;wait for NMI to clear the sleeping flag and wake us up
    
    ;when NMI wakes us up, handle input and go back to sleep
    jsr read_joypad
    jsr handle_input
    jmp forever ;go back to sleep
    
;----------------------------
; read_joypad will capture the current button state and store it in joypad1.  
;       Off-to-on transitions will be stored in joypad1_pressed
read_joypad:
    lda joypad1
    sta joypad1_old ;save last frame's joypad button states
    
    lda #$01
    sta $4016
    lda #$00
    sta $4016
    
    ldx #$08
@loop:    
    lda $4016
    lsr a
    rol joypad1  ;A, B, select, start, up, down, left, right
    dex
    bne @loop
    
    lda joypad1_old ;what was pressed last frame.  EOR to flip all the bits to find ...
    eor #$FF    ;what was not pressed last frame
    and joypad1 ;what is pressed this frame
    sta joypad1_pressed ;stores off-to-on transitions
    
    rts
    
;---------------------
; handle_input will perform actions based on input:
;   up - play current note
;   down - stop playing the note
;   left - cycle down a note
;   right - cycle up a note
handle_input:
    lda joypad1_pressed
    and #$8F ;check d-pad + a only
    beq @done
@check_a:
    and #$80 ;a
    beq @check_up
    jsr swap_channels
@check_up:
    lda joypad1_pressed
    and #$08 ;up
    beq @check_down
    jsr play_note
@check_down:
    lda joypad1_pressed
    and #$04 ;down
    beq @check_left
    jsr silence_note
@check_left:
    lda joypad1_pressed
    and #$02 ;left
    beq @check_right
    jsr note_down
@check_right:
    lda joypad1_pressed
    and #$01 ;right
    beq @done
    jsr note_up    
@done:
    rts

;----------------------
; swap_channels swaps us between square and triangle
swap_channels:
    lda triangle_enabled
    eor #01     ; toggle the bottom bit
    sta triangle_enabled
    rts
    
;----------------------
; play_note plays the note stored in current_note
play_note:
    lda triangle_enabled
    bne @triangle
@square:
    lda #$7F    ;Duty 01, Volume F
    sta $4000
    lda #$08    ;Set Negate flag so low notes aren't silenced
    sta $4001

    lda current_note
    asl a               ;multiply by 2 because we are indexing into a table of words
    tay
    lda note_table, y   ;read the low byte of the period
    sta $4002           ;write to SQ1_LO
    lda note_table+1, y ;read the high byte of the period
    sta $4003           ;write to SQ1_HI
    rts
@triangle
    lda #$81            ;disable internal counters, channel on
    sta $4008
    
    lda current_note
    asl a               ;multiply by 2 because we are indexing into a table of words
    tay
    lda note_table, y   ;read the low byte of the period
    sta $400A           ;write to SQ1_LO
    lda note_table+1, y ;read the high byte of the period
    sta $400B           ;write to SQ1_HI
    rts
    
;--------------------
; silence_note silences the square and triangle channel
silence_note:
    lda #$30
    sta $4000   ;silence Square 1 by setting the volume to 0.
    sta $4008   ;also silence triangle; faster than actually testing which one to hit
    rts
    
;--------------------
; note_down will move current_note down a half-step (eg, C#4 -> C4).  Lowest note will wrap to highest note
note_down:
    dec current_note
    lda current_note
    cmp #$FF
    bne @done
    lda #Fs9    ;highest note.  We wrapped from 0
    sta current_note
@done:
    jsr get_note_and_octave
    rts
    
;----------------------
; note_up will move current_note up a half-step (eg, C#4 -> D4) .  Highest note will wrap to lowest note   
note_up:
    inc current_note
    lda current_note
    cmp #Fs9+1          ;did we move past the highest note index in our note table?
    bne @done           ;if not, no problem
    lda #$00            ;but if we did, wrap around to 0 (the lowest note)
    sta current_note
@done:
    jsr get_note_and_octave
    rts
    
;------------------
; get_note_and_octave will take current_note and seperate the note part (A, B, F#, etc) from the octave (1, 2, 3, etc)
;   and store them separately.
get_note_and_octave:
    ldx #$02    ;x will count octaves.  The lowest C is octave 2, so we start at 2.
    lda current_note
    cmp #$0C
    bcc @store_note_value   ;if we are in the lowest octave already, we are done
    sec                     ;else we need to find out what octave we are in.
@loop:
    sbc #$0C    ;subtract an octave
    inx         ;count how many subtractions we've made
    cmp #$0C    ;when we are down to the lowest octave, quit
    bcs @loop
@store_note_value:
    sta note_value  ;store the note value
    cmp #$03
    bcs @store_octave
    dex             ;On the NES, A, A# and B start at octave 1, not 2.
@store_octave:
    stx note_octave
    rts

;-------------
; draw_note will draw the note value and octave on the screen
;   this subroutine writes to the PPU registers, so it should only be run during vblank (ie, in NMI)
draw_note:
    lda $2002
    lda #$21
    sta $2006
    lda #$4D
    sta $2006   ;$214D is a nice place in the middle of the screen to draw
    
    lda note_value  ;use note_value as an index into our pointer table
    asl a           ;multiply by 2 because we are indexing into a table of pointers (which are words)
    tay
    lda text_pointers, y    ;setup pointer to the text data
    sta ptr1
    lda text_pointers+1, y
    sta ptr1+1
    ldy #$00
@loop:
    lda (ptr1), y   ;read a byte from the string
    bmi @end    ;if negative, we are finished (our strings are terminated by $FF, a negative number)
    sta $2007   ;else draw on the screen
    iny
    jmp @loop
@end:
    lda note_octave ;the CHR #s for numbers are $01-$09, so we can just write the value directly
    sta $2007
    rts
    
    
;----- second 8k bank of PRG-ROM    
    .segment "FIXED_DATA_AND_VECTORS"
    .org $E000
    
    .include "note_table.6502.asm" ;our NTSC note lookup table
    
;this is a table of pointers.  These pointers point to the beginning of text strings.
text_pointers:
     .w text_A, text_Asharp, text_B, text_C, text_Csharp, text_D
     .w text_Dsharp, text_E, text_F, text_Fsharp, text_G, text_Gsharp
    
;CHR     
;   $00 = blank
;   $0A = "#"
;   $10-$16 = "A"- "G"    
text_A:
    .b $00, $10, $FF
text_Asharp:
    .b $10, $0A, $FF 
text_B:
    .b $00, $11, $FF 
text_C:
    .b $00, $12, $FF
text_Csharp:
    .b $12, $0A, $FF
text_D:
    .b $00, $13, $FF
text_Dsharp:
    .b $13, $0A, $FF
text_E:
    .b $00, $14, $FF
text_F:
    .b $00, $15, $FF
text_Fsharp:
    .b $15, $0A, $FF
text_G:
    .b $00, $16, $FF
text_Gsharp:
    .b $16, $0A, $FF
    
;---- vectors
    .org $FFFA     ;first of the three vectors starts here
    .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
    .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
    .dw irq        ;external interrupt IRQ is not used in this tutorial
    
;------ 8k chr bank
    .bank 1, 8, $0000, "NES_CHR0"
    .segment "TILES"
    .org $0000
    .incbin "periods.chr"