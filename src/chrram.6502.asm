  .target "6502"
  .format "nes"
  .setting "NESMapper", 0
  .setting "NESVerticalMirroring", true
  .setting "ShowLabelsAfterCompiling", true
  .setting "ShowLocalLabelsAfterCompiling", true
  .setting "LaunchCommand", "c:\\emulation\\fceux.exe {0}"
  .setting "DebugCommand", "c:\\emulation\\fceux.exe {0}"

;;;;;;;;;;;;;;;

  .segment "RAM"
  .org $0000  ;;start variables at ram location 0

src .ds 2

    
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
  STA $0200, x    ;move all sprites off screen
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2

; ************** NEW CODE ****************
LoadPalettes:
  LDA $2002    ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006    ; write the high byte of $3F00 address
  LDA #$00
  STA $2006    ; write the low byte of $3F00 address
  LDX #$00     ; reset X to 0 for the loop
LoadPalettesLoop:
  LDA palette, x        ;load palette byte
  STA $2007             ;write to PPU
  INX                   ;set index to next byte
  CPX #$20            
  BNE LoadPalettesLoop  ;if x = $20, 32 bytes copied, all done

; Code to position the sprites
  LDA #$80
  STA $0200        ; put sprite 0 in center ($80) of screen vert
  STA $0203        ; put sprite 0 in center ($80) of screen horiz
  LDA #$00
  STA $0201        ; tile number = 0
  STA $0202        ; color = 0, no flipping

  LDA #$80
  STA $0204        ; center vert
  LDA #$88         
  STA $0207        ; one tile over horiz
  LDA #$01
  STA $0205        ; tile number 1
  STA $0206        ; color = 1, no flipping

  LDA #$88
  STA $0208        ; one over vert
  LDA #$80         
  STA $020B        ; center horiz
  LDA #$02
  STA $0209        ; tile number 2
  STA $020A        ; color = 2, no flipping

  LDA #$88
  STA $020C        ; one over vert
  STA $020F        ; one tile over horiz
  LDA #$03
  STA $020D        ; tile number 3
  STA $020E        ; color = 3, no flipping

  JSR CopyTiles

  LDA #%10000000   ; enable NMI, sprites from Pattern Table 0
  STA $2000

  LDA #%00010000   ; enable sprites
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop

CopyTiles:
  lda #<mytiles_chr  ; load the source address into a pointer in zero page
  sta src
  lda #>mytiles_chr
  sta src+1

  ldy #0       ; starting index into the first page
  sty $2001    ; turn off rendering just in case
  sty $2006    ; load the destination address into the PPU - Pattern table is at $0000 through $0FFF and $1000 through $1FFF
  sty $2006
  ldx #32      ; number of 256-byte pages to copy
loop:
  lda (src),y  ; copy one byte
  sta $2007
  iny
  bne loop  ; repeat until we finish the page
  inc src+1  ; go to the next page
  dex
  bne loop  ; repeat until we've copied enough pages
  rts
  
NMIHandler:
  LDA #$00
  STA $2003  ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014  ; set the high byte (02) of the RAM address, start the DMA transfer

  INX
  TXA
  AND #%00001000
  EOR #%10000000
  STA $2000             ; swapping the pattern table; since the data of what to render
                        ; is still good we see it swap between "sprites" and "background" in the mario CHR.
                        ; 
  
  RTI        ; return from interrupt

  .segment "RODATA"
  .org $C200
mytiles_chr: .incbin "mario.chr"
 
;;;;;;;;;;;;;;  
  
  .segment "SETUP"
  .org $F000
palette:
  .byte $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F
  .byte $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C


  .org $FFFA     ;first of the three vectors starts here
  .w NMIHandler        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .w RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .w 0          ;external interrupt IRQ is not used in this tutorial
  
;;;;;;;;;;;;;;  
