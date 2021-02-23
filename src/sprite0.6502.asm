  .target "6502"
  .format "nes"
  .setting "NESMapper", 0
  .setting "NESVerticalMirroring", true
  .setting "ShowLabelsAfterCompiling", true
  .setting "ShowLocalLabelsAfterCompiling", true
  .setting "LaunchCommand", "c:\\emulation\\fceux.exe {0}"
  .setting "DebugCommand", "c:\\emulation\\fceux.exe {0}"
  

;;;;;;;;;;;;;;;

;; DECLARE SOME VARIABLES HERE
  .segment "RAM"
  .org $0000  ;;start variables at ram location 0
  
scroll     .ds 1  ; horizontal scroll count
nametable  .ds 1  ; which nametable to use, 0 or 1
columnLow  .ds 1  ; low byte of new column address
columnHigh .ds 1  ; high byte of new column address
sourceLow  .ds 1  ; source for column data
sourceHigh .ds 1
columnNumber .ds 1  ; which column of level data to draw
 
;;;;;;;;;;;;
    
  .bank 0, 16, $C000, "NES_PRG0" ; these should always be 16kb for PRG, 8kb for CHR
                                 ; in tutorials the number of these should match
                                 ; the number in the inesprg/ineschr directives
  .segment "MAIN_CODE" ; Replaces the bank directive from nesasm format
  .org $C000 
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down



LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$14              ; Compare X to hex $14, decimal 20 = 5 sprites
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 16, keep going down
              
              
InitializeNametables:
  LDA #$01
  STA nametable
  LDA #$00
  STA scroll
  STA columnNumber
InitializeNametablesLoop:
  JSR DrawNewColumn     ; draw bg column
  LDA scroll            ; go to next column
  CLC
  ADC #$08
  STA scroll
  INC columnNumber
  LDA columnNumber      ; repeat for first nametable 
  CMP #$20
  BNE InitializeNametablesLoop
  
  LDA #$00
  STA nametable
  LDA #$00
  STA scroll
  JSR DrawNewColumn     ; draw first column of second nametable
  INC columnNumber
  
  LDA #$00              ; set back to increment +1 mode
  STA $2000
InitializeNametablesDone:
  

InitializeAttributes:
  LDA #$01
  STA nametable
  LDA #$00
  STA scroll
  STA columnNumber
InitializeAttributesLoop:
  JSR DrawNewAttributes     ; draw attribs
  LDA scroll                ; go to next column
  CLC
  ADC #$20
  STA scroll

  LDA columnNumber      ; repeat for first nametable 
  CLC 
  ADC #$04
  STA columnNumber
  CMP #$20
  BNE InitializeAttributesLoop
  
  LDA #$00
  STA nametable
  LDA #$00
  STA scroll
  JSR DrawNewAttributes     ; draw first column of second nametable
InitializeAttributesDone:


InitializeStatusBar:
  ldy #$00
  ldx #$80  
  lda $2002
  lda #$20
  sta $2006
  lda #$00
  sta $2006
InitializeStatusBarLoop:     ; copy status bar to first nametable
  lda statusbar, y
  sta $2007
  iny
  dex
  bne InitializeStatusBarLoop

  ldy #$00
  ldx #$80    
  lda $2002
  lda #$24
  sta $2006
  lda #$00
  sta $2006
InitializeStatusBar2Loop:   ; copy status bar to second nametable
  lda statusbar, y
  sta $2007
  iny
  dex
  bne InitializeStatusBar2Loop



  LDA #$21
  STA columnNumber

  LDA #$00
  STA $2006
  STA $2006
  STA $2005
  STA $2005
              
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001
  

Forever:
  JMP Forever     ;jump back to Forever, infinite loop
  
 

NMIHandler:
  INC scroll            ; add one to our scroll variable each frame


NTSwapCheck:
  LDA scroll            ; check if the scroll just wrapped from 255 to 0
  BNE NTSwapCheckDone  
NTSwap:
  LDA nametable         ; load current nametable number (0 or 1)
  EOR #$01              ; exclusive OR of bit 0 will flip that bit
  STA nametable         ; so if nametable was 0, now 1
                        ;    if nametable was 1, now 0
NTSwapCheckDone:


NewAttribCheck:
  LDA scroll
  AND #%00011111            ; check for multiple of 32
  BNE NewAttribCheckDone    ; if low 5 bits = 0, time to write new attribute bytes
  jsr DrawNewAttributes
NewAttribCheckDone:


NewColumnCheck:
  LDA scroll
  AND #%00000111            ; throw away higher bits to check for multiple of 8
  BNE NewColumnCheckDone    ; done if lower bits != 0
  JSR DrawNewColumn         ; if lower bits = 0, time for new column
  
  lda columnNumber
  clc
  adc #$01             ; go to next column
  and #%01111111       ; only 128 columns of data, throw away top bit to wrap
  sta columnNumber
NewColumnCheckDone:


  LDA #$00
  STA $2003       
  LDA #$02
  STA $4014       ; sprite DMA from $0200
  
  ; run other game graphics updating code here

  LDA #$00
  STA $2006        ; clean up PPU address registers
  STA $2006
  
  LDA #$00         ; start with no scroll for status bar
  STA $2005
  STA $2005
  
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000        ; start with nametable = 0 for status bar

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001
  
  
  
WaitNotSprite0:
  lda $2002
  and #%01000000
  bne WaitNotSprite0   ; wait until sprite 0 not hit

WaitSprite0:
  lda $2002
  and #%01000000
  beq WaitSprite0      ; wait until sprite 0 is hit



  ; at this point the TV scanline is at the sprite 0 point
  
  ; add some delay to make sure the scanline is below the status bar
  ; this delay can be adjusted to be as short as needed
  
  ldx #$10
WaitScanline:
  dex
  bne WaitScanline
  
  ; now set the scroll and nametable to use for the rest of the screen down
  
  LDA scroll
  STA $2005        ; write the horizontal scroll count register

  LDA #$00         ; no vertical scrolling
  STA $2005
    
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  ORA nametable    ; select correct nametable for bit 0
  STA $2000
    
  ; run normal game engine code here
  ; reading from controllers, etc
  
  RTI              ; return from interrupt
 
 
 
 

DrawNewColumn:
  LDA scroll       ; calculate new column address using scroll register
  LSR A
  LSR A
  LSR A            ; shift right 3 times = divide by 8
  STA columnLow    ; $00 to $1F, screen is 32 tiles wide

  LDA nametable     ; calculate new column address using current nametable
  EOR #$01          ; invert low bit, A = $00 or $01
  ASL A             ; shift up, A = $00 or $02
  ASL A             ; $00 or $04
  CLC
  ADC #$20          ; add high byte of nametable base address ($2000)
  STA columnHigh    ; now address = $20 or $24 for nametable 0 or 1


  LDA columnLow
  CLC
  ADC #$80
  STA columnLow
  LDA columnHigh
  ADC #$00
  STA columnHigh     ; add $80 to go down 4 rows, skipping status bar

  LDA columnNumber   ; column number * 32 = column data offset
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A           
  STA sourceLow
  LDA columnNumber
  LSR A
  LSR A
  LSR A
  STA sourceHigh
  
  LDA sourceLow
  CLC
  ADC #<columnData   ; column data start + offset = address to load column data from
  STA sourceLow
  LDA sourceHigh
  ADC #>columnData
  STA sourceHigh

DrawColumn:
  LDA #%00000100        ; set to increment +32 mode
  STA $2000
  
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA columnHigh
  STA $2006             ; write the high byte of column address
  LDA columnLow
  STA $2006             ; write the low byte of column address
  LDX #$1A              ; copy 26 bytes
  LDY #$04              ; start 4 bytes in to not overwrite status bar
DrawColumnLoop:
  LDA (sourceLow), y
  STA $2007
  INY
  DEX
  BNE DrawColumnLoop

  RTS
  
  
  
DrawNewAttributes:
  LDA nametable
  EOR #$01          ; invert low bit, A = $00 or $01
  ASL A             ; shift up, A = $00 or $02
  ASL A             ; $00 or $04
  CLC
  ADC #$23          ; add high byte of attribute base address ($23C0)
  STA columnHigh    ; now address = $23 or $27 for nametable 0 or 1
  
  LDA scroll
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$C0
  STA columnLow     ; attribute base + scroll / 32

  LDA columnNumber  ; (column number / 4) * 8 = column data offset
  AND #%11111100
  ASL A
  STA sourceLow
  LDA columnNumber
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  STA sourceHigh
  
  LDA sourceLow       ; column data start + offset = address to load column data from
  CLC 
  ADC #<attribData
  STA sourceLow
  LDA sourceHigh
  ADC #>attribData
  STA sourceHigh

  LDY #$00
  LDA $2002             ; read PPU status to reset the high/low latch
DrawNewAttributesLoop
  LDA columnHigh
  STA $2006             ; write the high byte of column address
  LDA columnLow
  STA $2006             ; write the low byte of column address
  LDA (sourceLow), y    ; copy new attribute byte
  STA $2007
  
  INY
  CPY #$08              ; copy 8 attribute bytes
  BEQ DrawNewAttributesLoopDone 
  
  LDA columnLow         ; next attribute byte is at address + 8
  CLC
  ADC #$08
  STA columnLow
  JMP DrawNewAttributesLoop
DrawNewAttributesLoopDone:

  rts
;;;;;;;;;;;;;;  
  
  
  

  
  .segment "SETUP"
  .org $E000
palette:
  .b $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette
  .b $22,$16,$27,$18,  $22,$1A,$30,$27,  $22,$16,$30,$27,  $22,$0F,$36,$17   ;;sprite palette

sprites:
     ;vert tile attr horiz
  .b $18, $FF, $01, $58   ; sprite 0       ; change attrib to $23 to hide behind coin (01 makes it obvious what's going on)
  .b $7F, $32, $00, $80   ;mario sprite
  .b $7F, $33, $00, $88   ;mario sprite
  .b $87, $34, $00, $80   ;mario sprite
  .b $87, $35, $00, $88   ;mario sprite


statusbar:
  .b $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24
  .b $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24
  .b $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24
  .b $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24
  .b $24, $24, $24, $16, $0A, $1B, $12, $18, $24, $24, $24, $24, $24, $24, $24, $24
  .b $24, $24, $20, $18, $1B, $15, $0D, $24, $24, $1D, $12, $16, $0E, $24, $24, $24
  .b $24, $24, $24, $00, $00, $00, $00, $00, $00, $24, $24, $2E, $29, $00, $00, $24
  .b $24, $24, $24, $01, $28, $01, $24, $24, $24, $24, $02, $03, $06, $24, $24, $24


columnData:
  .incbin "SMBlevel.bin"

attribData:
  .incbin "SMBattrib.bin"

  .org $FFFA     ;first of the three vectors starts here
  .dw NMIHandler        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 1, 8, $0000, "NES_CHR0"
  .segment "TILES"
  .org $0000
  .incbin "mario.chr"   ;includes 8KB graphics file from SMB1