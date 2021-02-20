  .target "6502"
  .format "nes"
  .setting "NESMapper", 0
  .setting "NESVerticalMirroring", true
  .setting "ShowLabelsAfterCompiling", true
  .setting "ShowLocalLabelsAfterCompiling", true
  .setting "LaunchCommand", "c:\\emulation\\fceux.exe {0}"
  .setting "DebugCommand", "c:\\emulation\\fceux.exe {0}"
  
;;;;;;;;;;;;;;;

    
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
  TXS          ; Set up stack pointer - by convention set it to $FF because stack is $0100-$01FF and grows down
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready; since we
                   ; need to wait twice set one wait here after basic init
                   ; then the other wait after RAM init
  BIT $2002
  BPL vblankwait1  ; keep looping until $2002 is 1xxxxxxx

clrmem:            ; set internal RAM $0000-$07FF to a known good value
  LDA #$00         ; X is still zero at this point
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x    ; $02xx is our OAM buffer, so initialize it to something large to have all sprites
                  ; be off screen should we start rendering before we've set their positions properly
  INX             ; causes x to go from $00 to $FF, then wrap to $00 and break the loop
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2 ; keep looping until $2002 is 1xxxxxxx


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
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
  CPX #$10              ; Compare X to hex $10, decimal 16
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 16, keep going down
              
              
              
LoadBackground:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006             ; write the high byte of $2000 address
  LDA #$00
  STA $2006             ; write the low byte of $2000 address
  LDX #$00              ; start out at 0
LoadBackgroundLoop:
  LDA background, x     ; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$C0              ; Need to loop enough times to copy all bytes.  Each row is 32 bytes, we're doing 6 rows
  BNE LoadBackgroundLoop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down
              
              
LoadAttribute:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$23
  STA $2006             ; write the high byte of $23C0 address
  LDA #$C0
  STA $2006             ; write the low byte of $23C0 address
  LDX #$00              ; start out at 0
LoadAttributeLoop:
  LDA attribute, x      ; load data from address (attribute + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$10              ; Compare X to hex $10; two rows of attributes
  BNE LoadAttributeLoop  ; Branch to LoadAttributeLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down

  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001

  LDX #$00         ; zero out X

Forever:
  JMP Forever     ;jump back to Forever, infinite loop
  
 

NMIHandler:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer


LatchController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016       ; tell both the controllers to latch buttons

  LDA $4016       ; 1 - A
  LDA $4016       ; 1 - B
  LDA $4016       ; 1 - Select
  LDA $4016       ; 1 - Start

ReadUp:
  LDA $4016       ; player 1 - Up
  AND #%00000001  ; only look at bit 0
  BEQ ReadUpDone  ; if not pressed don't do anything
  DEC $0200       ; move our sprites up
  DEC $0204
  DEC $0208
  DEC $020C
ReadUpDone:

ReadDown:
  LDA $4016         ; player 1 - Down
  AND #%00000001    ; only look at bit 0
  BEQ ReadDownDone  ; if not pressed don't do anything
  INC $0200         ; move our sprites down
  INC $0204
  INC $0208
  INC $020C
ReadDownDone:

ReadLeft:
  LDA $4016        ; player 1 - Left
  AND #$00000001   ; only bit 0
  BEQ ReadLeftDone ; skip if not pressed
  DEC $0203        ; move sprites left
  DEC $0207
  DEC $020B
  DEC $020F
ReadLeftDone:

ReadRight:
  LDA $4016         ; player 1 - Right
  AND #$00000001    ; only bit 0
  BEQ ReadRightDone ; skip if not pressed
  INC $0203         ; move sprites right
  INC $0207
  INC $020B
  INC $020F
ReadRightDone:

  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  ;;Before the end of vblank we need to set the scroll position - if we don't do this
  ;;in time we get fun bugs
  INY               ; horizontal auto scroll
  BNE ScrollCoords  ; did we scroll past the edge of the nametable?
  TXA
  EOR #%00000001    ; Toggle the bottom bit to switch nametables
  TAX
  ORA #%10010000    ; NMI enabled, sprites from pattern table 0, background from pattern table 1
  STA $2000         ; Set the nametable
ScrollCoords:
  TYA
  STA $2005         ; set horizontal position
  LDA #$00          ; no vertical scroll
  STA $2005         ; set vertical position
  
  RTI             ; return from interrupt
 
;;;;;;;;;;;;;;  
  
  
  
  .segment "SETUP"
  .org $E000
palette:
  .b $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette
  .b $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

sprites:
     ;vert tile attr horiz
  .b $80, $32, $00, $80   ;sprite 0
  .b $80, $33, $00, $88   ;sprite 1
  .b $88, $34, $00, $80   ;sprite 2
  .b $88, $35, $00, $88   ;sprite 3


background:                                                           ;; note - rows are split for readability
  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 1
  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky

  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 2
  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky

  .b $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

  .b $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;; row 5
  .b $6B,$2C,$6C,$6D,$6E,$6F,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;; mushroom platform blocks

  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;; row 6
  .b $70,$2D,$71,$72,$73,$74,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;; mushroom platform bottom

attribute:
  .b %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000 ;; first four rows
  .b %00000000, %00000000, %00000000, %00000000, %00001111, %00001111, %00000000, %00000000 ;; next four rows

  .org $FFFA     ;first of the three vectors starts here
  .w NMIHandler        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .w RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .w 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 1, 8, $0000, "NES_CHR0"
  .segment "TILES"
  .org $0000
  .incbin "mario.chr"   ;includes 8KB graphics file from SMB1