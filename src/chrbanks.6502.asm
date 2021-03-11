  .target "6502"
  .format "nes"
  .setting "NESMapper", 3
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
  STA $0200, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0300, x
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
  CPX #$20              ; Compare X to hex $20, decimal 32
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down
              
              

  LDA #%10000000   ; enable NMI, sprites from Pattern Table 1
  STA $2000

  LDA #%00010000   ; enable sprites
  STA $2001

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


ReadA: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadADone   ; branch to ReadADone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)
  LDA $0203       ; load sprite X position
  CLC             ; make sure the carry flag is clear
  ADC #$01        ; A = A + 1
  STA $0203       ; save sprite X position
ReadADone:        ; handling this button is done
  

ReadB: 
  LDA $4016       ; player 1 - B
  AND #%00000001  ; only look at bit 0
  BEQ ReadBDone   ; branch to ReadBDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)
  LDA $0203       ; load sprite X position
  SEC             ; make sure carry flag is set
  SBC #$01        ; A = A - 1
  STA $0203       ; save sprite X position
ReadBDone:        ; handling this button is done


ReadSelect: 
  LDA $4016       ; player 1 - select
  AND #%00000001  ; only look at bit 0
  BEQ ReadSelectDone   ; branch to ReadSelectDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)

  LDA #$00
  JSR Bankswitch  ; change to graphics bank 0

ReadSelectDone:   ; handling this button is done


ReadStart: 
  LDA $4016       ; player 1 - start
  AND #%00000001  ; only look at bit 0
  BEQ ReadStartDone   ; branch to ReadStartDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)

  LDA #$01
  JSR Bankswitch  ; change to graphics bank 1

ReadStartDone:   ; handling this button is done


  
  RTI             ; return from interrupt
 
 
 
 
 
 
; Ok, this seems like voodoo, but here's what's going on.
; CNROM (mapper 3) is one of the mappers which suffers bus conflicts.
; So when you write to the register (which is located in ROM space) it also
; ends up reading from that ROM location, and one will win.
; The way you avoid this is to write a value to a location that has that value.
; So that's what's going on here; the bankswitch register is the entirety of
; $8000-$FFFF, so if we want to swap to bank 0-3 we need to write to a location
; in that space which contains that same value.  Hence the lookup table here;
; if X is 0 then we write to Bankvalues+0 which is $00, so it matches.  Same with
; X is 1 we write to Bankvalues+1 which is $01, again matching.
Bankswitch:
  TAX                    ;;copy A into X
  STA Bankvalues, X      ;;new bank to use
  RTS

Bankvalues:
  .b $00, $01, $02, $03 ;;bank numbers


 
 
;;;;;;;;;;;;;;  
  
  
  
  .segment "SETUP"
  .org $E000
palette:
  .b $0F,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$0F
  .b $0F,$1C,$15,$14,$31,$02,$38,$3C,$0F,$1C,$15,$14,$31,$02,$38,$3C

sprites:
     ;vert tile attr horiz
  .b $80, $32, $00, $80   ;sprite 0
  .b $80, $33, $00, $88   ;sprite 1
  .b $88, $34, $00, $80   ;sprite 2
  .b $88, $35, $00, $88   ;sprite 3

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
  .incbin "mario0.chr"   ;includes 8KB graphics file from SMB1
  
  .bank 2, 8, $0000, "NES_CHR1"
  .segment "TILES2"
  .org $0000
  .incbin "mario1.chr"   ;includes 8KB graphics file from SMB1, modified