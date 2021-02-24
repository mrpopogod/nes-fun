  .target "6502"
  .format "nes"
  .setting "NESMapper", 0
  .setting "NESVerticalMirroring", true
  .setting "ShowLabelsAfterCompiling", true
  .setting "ShowLocalLabelsAfterCompiling", true
  .setting "LaunchCommand", "c:\\emulation\\fceux.exe {0}"
  .setting "DebugCommand", "c:\\emulation\\fceux.exe {0}"


;----- first 8k bank of PRG-ROM    
    .bank 0, 16, $C000, "NES_PRG0" ; these should always be 16kb for PRG, 8kb for CHR
                                 ; in tutorials the number of these should match
                                 ; the number in the inesprg/ineschr directives
    .segment "MAIN_CODE" ; Replaces the bank directive from nesasm format
    .org $C000
    
irq:
nmi:
    TXA
    bne skip

    lda #%00000001
    sta $4015 ;enable Square 1
    
    ;square 1
    lda #%10111111 ;Duty 10, Length Counter Disabled, Saw Envelopes disabled, Volume F
    sta $4000
    
    ;lda #$C9    ;0C9 is a C# in NTSC mode
    tya           ; our ever increasing period
    sta $4002   ;low 8 bits of period
    lda #$00
    sta $4003   ;high 3 bits of period

    iny      ; every time we play a note update the period  - period won't be audible until y = 9
    jmp nextframe

skip:
    lda #$00   ; disable sound
    sta $4015
nextframe:
    inx      ; play a note approximately one time per second
    inx
    inx
    inx  
    rti

reset:
    sei             ; bare minimum of setup, just disable the features we don't use
    cld
    
    ldx #$00        ; initialize our counter
    ldy #$00

    LDA #%10000000   ; enable NMI, sprites from Pattern Table 0
    STA $2000
    
forever:
    jmp forever
    
;---- vectors
    .segment "VECTORS"
    .org $FFFA     ;first of the three vectors starts here
    .dw nmi        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
    .dw reset      ;when the processor first turns on or is reset, it will jump
                   ;to the label reset:
    .dw irq        ;external interrupt IRQ is not used in this tutorial
    