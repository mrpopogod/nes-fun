; This file serves as a dumping ground for things like the basic bare bones of a valid NES program and then any functions
; or other snippets which would be useful for other programs.  HEAVILY commented.

  .target "6502"                                                ; assembler directive of target ISA
  .format "nes"                                                 ; assembler directive of output file format
  .setting "NESMapper", 0                                       ; sets the NES mapper
  .setting "NESVerticalMirroring", true                         ; are we vertical or horizontal mirroring in the nametable?
  .setting "NESBatteryBackedWRAM", false                        ; do we have battery backed wram?
  .setting "ShowLabelsAfterCompiling", true                     ; assembler directive to dump our labels to STDOUT on compile
  .setting "ShowLocalLabelsAfterCompiling", true                ; ditto for local labels
  .setting "LaunchCommand", "c:\\emulation\\fceux.exe {0}"      ; what application to use when we IDE run
  .setting "DebugCommand", "c:\\emulation\\fceux.exe {0}"       ; what application to use when we IDE debug

  .segment "RAM", 0                                             ; define a segment, this will be where RAM is $0000-$07FF
  .org $0000                                                    ; everything past this point starts its addressing at $0000

                                                                ; it is extremely helpful to predefine a couple of bytes
                                                                ; to store a 16 bit address for passing to subroutines
pointerLo     .ds 1                                             ; little endian, low byte first
pointerHi     .ds 1                                             ; high byte immediately after

myvar         .ds 4                                             ; reserve 4 bytes of space and label the lowest byte "myvar"
  
MY_CONSTANT   =   $01                                           ; predefine a constant; this is an assembler macro which
                                                                ; will replace any instance of the constant label with the
                                                                ; constant's value in the actual instructions

  .bank 0, 16, $C000, "NES_PRG0"                                ; define a bank at $C000 that's 16kb large
                                                                ; NES_PRG# is the heuristic for the assembler
                                                                ; if you skip a number it stops creating PRG banks
                                                                ; check mapper documentation for where banks are situated
                                                                ; NOTE: these just need to exist somewhere as a directive
                                                                ; to the assembler; you could cluster them all at the top
                                                                ; so you know how many banks you have and their sizes,
                                                                ; or you can in-line them with your segment and org directives
                                                                ; so you know that this chunk is part of the bank

  .segment "MAIN_CODE", 0                                       ; have our code start in bank PRG0
  .org $C000 

RESET:                                                          ; code that triggers when the NES is reset
  SEI                                                           ; disable IRQs
  CLD                                                           ; disable decimal mode - NES doesn't support it anyway
  LDX #$40
  STX $4017                                                     ; disable APU frame IRQ
  LDX #$FF
  TXS                                                           ; Stack grows down and is hardcoded to be the $01 page, so
                                                                ; set the initial stack pointer to be $01FF
  INX                                                           ; wrap X because it's cheaper than LDX
  STX $2000                                                     ; disable NMI
  STX $2001                                                     ; disable rendering
  STX $4010                                                     ; disable DMC IRQs

                                                                ; PPU isn't ready until two vblanks have happened
vblankwait1:                                                    ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1                                               ; bit 7 is when vblank has happened, so loop until no 
                                                                ; longer positive

                                                                ; Now that a vblank has happened do some work
                                                                ; while we wait so we aren't idle

                                                                ; loop through all the memory and set it to a known
clrmem:                                                         ; good state so we don't get surprises later
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x                                                  ; sprites are loaded into OAM by teling the PPU to load
                                                                ; from $xx00-$xxFF by sending the PPU the value of xx
                                                                ; the convention is for this to be in $02xx, so we
                                                                ; initialize it to be $FE so that the X and Y coords
                                                                ; are off screen; thus all the sprites don't get rendered
                                                                ; and we get no glitches until we properly set up any
                                                                ; sprites we want to display
  INX                                                           ; loop x from 0 through FF, then when it wraps we break
  BNE clrmem
   
vblankwait2:                                                    ; Wait for the second vblank and then the PPU is ready
  BIT $2002
  BPL vblankwait2

  LDA #$00
  STA pointerLo                                                 ; snippet code assumes palettes are at $E000
  LDA #$E0
  STA pointerHi                                                 ; can instead LDA #<label and LDA #>label for lo/hi
  LoadPalettes()                                                ; Palettes are frequently static, so this is a good one
                                                                ; time loading spot for them

  LDA #$00
  STA pointerLo
  LDA #$F0
  STA pointerHi
  LoadBackground()                                              ; load the initial background because it's fairly expensive

  LDA #%10010000                                                ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110                                                ; enable sprites, enable background, no clipping on left side
  STA $2001

Forever:
  JMP Forever                                                   ;jump back to Forever, infinite loop, waiting for NMI


                                                                ; function is an assembler directive; this becomes a label
                                                                ; and references to it become JSR <label>
.function LoadPalettes()                                        ; function to load palettes from pointerLo/Hi address
  LDA $2002                                                     ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006                                                     ; write the high byte of $3F00 address
  LDA #$00
  STA $2006                                                     ; write the low byte of $3F00 address
  LDX #$00                                                      ; start out at 0
LoadPalettesLoop:
  LDA pointerLo, x                                              ; load data from address (palette + the value in x)
                                                                ; 1st time through loop it will load palette+0
                                                                ; 2nd time through loop it will load palette+1
                                                                ; 3rd time through loop it will load palette+2
                                                                ; etc
  STA $2007                                                     ; write to PPU
  INX
  CPX #$20                                                      ; 4 background and 4 sprite palettes of 4 bytes each
  BNE LoadPalettesLoop
.endfunction                                                    ; replaced with RTS

                                                                ; given a starting memory address load all of it into
                                                                ; nametable 0 - to extend this add a third variable
.function LoadBackground()                                      ; to pass in the nametable hi address
  LDA $2002                                                     ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006                                                     ; write the high byte of $2000 address
  LDA #$00
  STA $2006                                                     ; write the low byte of $2000 address
  
  LDX #$00                                                      ; start at pointer + 0
  LDY #$00
@OutsideLoop:                                                   ; make these local labels so we can reuse the generic name
@InsideLoop:
  LDA (pointerLo), y                                            ; copy one background byte from address in pointer plus Y
  STA $2007                                                     ; this runs 256 * 4 times
  
  INY                                                           ; inside loop counter
  CPY #$00
  BNE @InsideLoop                                               ; run the inside loop 256 times before continuing down
  
  INC pointerHi                                                 ; low byte went 0 to 256, so high byte needs to be changed now
  
  INX
  CPX #$04
  BNE @OutsideLoop                                              ; run the outside loop 4 times before continuing down
.endfunction
  
NMIHandler:                                                     ; label we setup to handle the NMI interrupt which occurs
                                                                ; every time we vblank
  LDA #$00
  STA $2003                                                     ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014                                                     ; set the high byte (02) of the RAM address, start the OAM transfer
                                                                ; always do this first because it's lengthy but is also async

                                                                ; Do other background modification code here

                                                                ; This is the PPU clean up section, so rendering the next 
                                                                ; frame starts properly.
  LDA #%10010000                                                ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #%00011110                                                ; enable sprites, enable background, no clipping on left side
  STA $2001
  LDA #$00                                                      ; tell the ppu there is no background scrolling
  STA $2005
  STA $2005

                                                                ; any sprite updates go here as well as general game logic

  RTI                                                           ; we're done doing what we did in vblank

                                                                ; some more handy functions

                                                                ; function to convert a 16 bit binary number
                                                                ; to decimal in constant time.  for readability
                                                                ; this uses five single byte labels, but we could
                                                                ; also use a single five byte label and +1, +2 when addressing
                                                                ; incoming binary is in a 16 bit address which will be
                                                                ; modified, so needs to be separate from the real value
.function BinaryToDecimal()                                     
  LDA #$00 
  STA scoreOnes
  STA scoreTens
  STA scoreHundreds
  STA scoreThousands
  STA scoreTenThousands
  LDX #$10 
@BitLoop: 
  ASL temporaryScore 
  ROL temporaryScore + 1
  LDY scoreOnes
  LDA binTable, Y
  ROL A
  STA scoreOnes
  LDY scoreTens
  LDA binTable, Y
  ROL A
  STA scoreTens
  LDY scoreHundreds
  LDA binTable, y 
  ROL A
  STA scoreHundreds
  LDY scoreThousands
  LDA binTable, Y
  ROL A
  STA scoreThousands
  ROL scoreTenThousands
  DEX
  BNE @BitLoop  
.endfunction

binTable:                                                       ; table for the bin to dec conversion
  .b $00, $01, $02, $03, $04, $80, $81, $82, $83, $84


                                                                ; functions to read controller input
                                                                ; every read from $4016/7 will get whether
                                                                ; the next button in order is pressed or not
                                                                ; order is A B select start up down left right
.function ReadController1()
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016                                                     ; these two writes tell both controllers to snapshot the buttons
  LDX #$08
@ReadController1Loop:
  LDA $4016
  LSR A                                                         ; bit0 -> Carry
  ROL buttons1                                                  ; bit0 <- Carry
  DEX
  BNE @ReadController1Loop
.endfunction
  
.function ReadController2()
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
@ReadController2Loop:
  LDA $4017
  LSR A                                                         ; bit0 -> Carry
  ROL buttons2                                                  ; bit0 <- Carry
  DEX
  BNE @ReadController2Loop
.endfunction
  
                                                                ; VERY IMPORTANT
                                                                ; need to set up the three interrupt vectors 
                                                                ; and the must be at this exact spot in the address layout
                                                                ; Note that this also means one of our banks is going to want
                                                                ; to be situated so that it ends here
  .org $FFFA                                                    ; first of the three vectors starts here
  .dw NMIHandler                                                ; when an NMI happens (once per frame if enabled) the 
                                                                ; processor will jump to the label NMIHandler:
  .dw RESET                                                     ; when the processor first turns on or is reset, it will jump
                                                                ; to the label RESET:
  .dw 0                                                         ; external interrupt IRQ is for fancy stuff, so don't have
                                                                ; a usage pattern for it yet

  .bank 1, 8, $0000, "NES_CHR0"                                 ; like the PRG bank, set up one or more CHR banks
  .segment "TILES"
  .org $0000                                                    ; the CHR banks are their own memory space
  .incbin "mario.chr"                                           ; includes 8KB graphics file from SMB1