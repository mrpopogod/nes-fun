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
  
square1period     .ds 1
square1counter    .ds 1
square2period     .ds 1
square2counter    .ds 1
triangleperiod    .ds 1
trianglecounter   .ds 1


;----- first 8k bank of PRG-ROM    
    .bank 0, 16, $C000, "NES_PRG0" ; these should always be 16kb for PRG, 8kb for CHR
                                 ; in tutorials the number of these should match
                                 ; the number in the inesprg/ineschr directives
    .segment "MAIN_CODE" ; Replaces the bank directive from nesasm format
    .org $C000
    
irq:
NMI:
    ldy #$00                ; figure out which channels we want to play a note this frame
    lda square1counter
    bne square2check
    tya
    ora #%00000001
    tay
    inc square1period    ; every time we play a note increment its period
square2check:
    lda square2counter
    bne trianglecheck
    tya
    ora #%00000010
    tay
    inc square2period    ; every time we play a note increment its period
trianglecheck:
    lda trianglecounter
    bne donechecks
    tya
    ora #%00000100
    tay
    inc triangleperiod    ; every time we play a note increment its period

donechecks:
    tya
    beq nosound

playnote:

    ;Enable sound channels
    sta $4015 ;enable Square 1, Square 2 and Triangle
    
;Square 1
    lda #%00111000 ;Duty 00, Length Counter Disabled, Saw Envelopes disabled, Volume 8
    sta $4000
    lda square1period    ;0C9 is a C# in NTSC mode
    sta $4002   ;low 8 bits of period
    lda #$00
    sta $4003   ;high 3 bits of period
    
;Square 2
    lda #%01110110  ;Duty 01, Volume 6
    sta $4004
    lda square2period        ;$0A9 is an E in NTSC mode
    sta $4006
    lda #$00
    sta $4007

;Triangle    
    lda #$81    ;disable internal counters, channel on
    sta $4008
    lda triangleperiod    ;$042 is a G# in NTSC mode
    sta $400A
    lda #$00
    sta $400B
    jmp nextframe

nosound:
    lda #$00   ; disable sound
    sta $4015
nextframe:
    ; increments counters
    inc square1counter
    inc square1counter
    inc square1counter
    inc square1counter
    inc square2counter
    inc square2counter
    inc square2counter
    inc square2counter
    inc trianglecounter
    inc trianglecounter
    inc trianglecounter
    inc trianglecounter

    rti

RESET:
    sei
    cld
    ldx #$FF
    txs
    
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
    
    lda #$80
    sta $2000 ;enable NMIs

    lda #$00
    sta square1period
    sta square2period
    sta triangleperiod
    sta square1counter
    lda #$40
    sta square2counter
    lda #$80
    sta trianglecounter     ; set up the tracking around our three channels
    
forever:
    jmp forever
    
;----- second 8k bank of PRG-ROM    
    .segment "VECTORS"
    .org $E000
;---- vectors
    .org $FFFA     ;first of the three vectors starts here
    .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
    .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
    .dw irq        ;external interrupt IRQ is not used in this tutorial
    