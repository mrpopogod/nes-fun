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
sleeping .ds 1          ;main program sets this and waits for the NMI to clear it.  Ensures the main program is run only once per frame.  
                        ;   for more information, see Disch's document: http://nesdevhandbook.googlepages.com/theframe.html
needdraw .ds 1          ;drawing flag.
dbuffer_index .ds 1     ;current position in the drawing buffer
ptr1 .ds 2              ;a pointer

    .include "skeleton_sound_engine_vars.6502.asm"
    
    .bank 0, 16, $8000, "NES_PRG0" ; these should always be 16kb for PRG, 8kb for CHR
                                 ; in tutorials the number of these should match
                                 ; the number in the inesprg/ineschr directives
    .segment "SOUND_CODE" ; Replaces the bank directive from nesasm format
    .org $8000  ;we have two 16k PRG banks now.  We will stick our sound engine in the first one, which starts at $8000.
    
    .include "skeleton_sound_engine.6502.asm"

    .bank 1, 16, $C000, "NES_PRG1"
    .segment "MAIN_CODE"
    .org $C000
    
irq:
    rti
NMI:
    pha     ;save registers
    txa
    pha
    tya
    pha
    
    ;do sprite DMA
    ;update palettes if needed
    ;draw stuff on the screen
    
    lda needdraw
    beq @drawing_done   ;if drawing flag is clear, skip drawing
    lda $2002           ;else, draw (load to clear the latch)
    jsr draw_dbuffer
    lda #$00            ;finished drawing, so clear drawing flag
    sta needdraw
    
@drawing_done:    
    lda #$00
    sta $2005
    sta $2005   ;set scroll
    
    jsr sound_play_frame    ;run our sound engine after all drawing code is done.
                            ;this ensures our sound engine gets run once per frame.
                            
    lda #$00
    sta sleeping            ;wake up the main program
    
    pla     ;restore registers
    tay
    pla
    tax
    pla
    rti

RESET:
    sei
    cld
    ldx #$FF   ; setup stack
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
    
    jsr draw_background
    
;Enable sound channels
    jsr sound_init
    
    ;jsr sound_load
    
    lda #$88
    sta $2000   ;enable NMIs
    lda #$18
    sta $2001   ;turn PPU on

forever:
    inc sleeping ;go to sleep (wait for NMI).
@loop:
    lda sleeping
    bne @loop ;wait for NMI to clear the sleeping flag and wake us up
    
    ;when NMI wakes us up, handle input, fill the drawing buffer and go back to sleep
    jsr read_joypad
    jsr handle_input
    jsr prepare_dbuffer
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
;   A - play sound
;   B - init sound engine
;   Start - disable sound engine
handle_input:
@check_A:
    lda joypad1_pressed
    and #$80
    beq @check_B
    jsr sound_load
@check_B:
    lda joypad1_pressed
    and #$40
    beq @check_start
    jsr sound_init
@check_start:
    lda joypad1_pressed
    and #$10
    beq @done
    jsr sound_disable
@done:
    rts
    
;-------------------------------
; prepare_dbuffer fills the drawing buffer with the text strings we need 
prepare_dbuffer:    
    ;first write either "enabled" or "disabled" to the dbuffer
    lda sound_disable_flag
    beq @sound_enabled
@sound_disabled:
    lda #<text_disabled ;set ptr1 to point to beginning of text string
    sta ptr1
    lda #>text_disabled
    sta ptr1+1
    jmp @dbuffer1
@sound_enabled:
    lda #<text_enabled
    sta ptr1
    lda #>text_enabled
    sta ptr1+1
@dbuffer1:
    lda #$20    ;target PPU address.  add_to_dbuffer expects the HI byte in A and the LO byte in Y
    ldy #$F2
    jsr add_to_dbuffer

    ;next write either "playing" or "not playing" to the dbuffer
    lda sfx_playing
    beq @sound_not_playing  ;if playing flag is clear, write "NOT PLAYING" on the screen
    lda sound_disable_flag
    bne @sound_not_playing  ;if the disable flag is set, we want to write "NOT PLAYING" too
@sound_playing:
    lda #<text_playing  ;set ptr1 to point to beginning of text string
    sta ptr1
    lda #>text_playing
    sta ptr1+1
    jmp @dbuffer2
@sound_not_playing:
    lda #<text_not_playing
    sta ptr1
    lda #>text_not_playing
    sta ptr1+1
@dbuffer2:
    lda #$21    ;target PPU address.  add_to_dbuffer expects the HI byte in A and the LO byte in Y
    ldy #$0B
    jsr add_to_dbuffer
    
    lda #$01
    sta needdraw    ;set drawing flag so the NMI knows to draw
    
    rts

;-------------------------
; add_to_dbuffer will convert a text string (terminated by $FF) into a dbuffer string and add it to the drawing buffer.
;   add_to_dbuffer expects:
;       HI byte of the target PPU address in A, 
;       LO byte of the target PPU address in Y
;       pointer to the source text string in ptr1
;   dbuffer string format:
;       byte 0: length of data (ie, length of the text string)
;       byte 1-2: target PPU address (HI byte first)
;       byte 3-n: bytes to copy
;   Note:   dbuffer starts at $0100.  This is the stack page.  The
;               stack counts backwards from $1FF, and this program is small enough that there
;               will never be a conflcit.  But for larger programs, watch out.
add_to_dbuffer:
    ldx dbuffer_index
    sta $0101, x    ;write target PPU address to dbuffer
    tya
    sta $0102, x
    
    ldy #$00
@loop:
    lda (ptr1), y
    cmp #$FF
    beq @done
    sta $0103, x    ;copy the text string to dbuffer,
    iny
    inx
    bne @loop
@done:
    ldx dbuffer_index
    tya
    sta $0100, x        ;store string length at the beginning of the string header
    
    clc
    adc dbuffer_index
    adc #$03        
    sta dbuffer_index   ;update buffer index.  new index = old index + 3-byte header + string length
    
    tax
    lda #$00
    sta $0100, x        ;stick a 0 on the end to terminate dbuffer.
    rts

;------------------------
; draw_dbuffer will write the contents of the drawing buffer to the PPU
;       dbuffer is made up of a series of drawing strings.  dbuffer is 0-terminated.
;       See add_to_dbuffer for drawing string format.
draw_dbuffer:
    ldy #$00
@header_loop:
    lda $0100, y
    beq @done       ;if 0, we are at the end of the dbuffer, so quit
    tax             ;else this is how many bytes we want to copy to the PPU
    iny
    lda $0100, y    ;set the target PPU address
    sta $2006
    iny
    lda $0100, y
    sta $2006
    iny
@copy_loop:
    lda $0100, y    ;copy the contents of the drawing string to PPU
    sta $2007
    iny
    dex
    bne @copy_loop
    beq @header_loop    ;when we finish copying, see if there is another drawing string.    
@done:
    ldy #$00
    sty dbuffer_index   ;reset index and "empty" the dbuffer by sticking a zero in the first position
    sty $0100
    rts

;----------------------------
; draw_background will draw some background strings on the screen
;   this hard-coded routine is called only once in RESET
draw_background:
    lda $2002
    lda #$20
    sta $2006
    lda #$42
    sta $2006
    
    ldy #$00
@loop1:
    lda text_a, y
    bmi @a_done ;$FF, a negative number, terminates our strings
    sta $2007
    iny
    bne @loop1

@a_done:
    lda #$20
    sta $2006
    lda #$62
    sta $2006
    ldy #$00
@loop2:
    lda text_b, y
    bmi @b_done
    sta $2007
    iny
    bne @loop2

@b_done:
    lda #$20
    sta $2006
    lda #$82
    sta $2006
    ldy #$00
@loop3:
    lda text_start, y
    bmi @start_done
    sta $2007
    iny
    bne @loop3

@start_done:
    lda #$20
    sta $2006
    lda #$E4
    sta $2006
    ldy #$00
@loop4:
    lda text_sound_engine, y
    bmi @engine_done
    sta $2007
    iny
    bne @loop4

@engine_done:
    lda #$21
    sta $2006
    lda #$04
    sta $2006
    ldy #$00
@loop5:
    lda text_sound, y
    bmi @sound_done
    sta $2007
    iny
    bne @loop5

@sound_done:
    rts

    .org $E000

;these are our text strings.  They are all terminated by $FF
text_a:
    .b $10, $0D, $00, $1F, $1B, $10, $28, $00, $22, $1E, $24, $1D, $13, $FF ;"A: PLAY SOUND"
text_b:
    .b $11, $0D, $00, $18, $1D, $18, $23, $00, $22, $1E, $24, $1D, $13, $00, $14, $1D, $16, $18, $1D, $14, $FF ;"B: INIT SOUND ENGINE"
text_start:
    .b $22, $23, $10, $21, $23, $0D, $00, $13, $18, $22, $10, $11, $1B, $14, $00, $22, $1E, $24, $1D, $13, $FF ;"START: DISABLE SOUND"
    
text_sound_engine:
    .b $22, $1E, $24, $1D, $13, $00, $14, $1D, $16, $18, $1D, $14, $0D, $FF ;"SOUND ENGINE:"
text_enabled:
    .b $14, $1D, $10, $11, $1B, $14, $13, $00, $FF ;"ENABLED"
text_disabled:
    .b $13, $18, $22, $10, $11, $1B, $14, $13, $FF ;"DISABLED"
text_sound:
    .b $22, $1E, $24, $1D, $13, $0D, $FF ;"SOUND:"
text_not_playing:
    .b $1D, $1E, $23, $00 ;"NOT "
text_playing:
    .b $1F, $1B, $10, $28, $18, $1D, $16, $00, $00, $00, $00, $FF ;"PLAYING    "

    
;---- vectors
    .org $FFFA     ;first of the three vectors starts here
    .w NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
    .w RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
    .w irq        ;external interrupt IRQ is not used in this tutorial
    
    .bank 3, 8, $0000, "NES_CHR0"
    .segment "TILES"
    .org $0000
    .incbin "skeleton.chr"