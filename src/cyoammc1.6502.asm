; This is an example project that includes a bank swapping routine, but it doesn't actually
; invoke it because it isn't needed.  Mostly I just used it to play around with making
; it buildable and understanding how the file format works.
; Going foward can use this to pull out some bank swapping routines.
  
  .target "6502"
  .format "nes"
  .setting "NESMapper", 1
  .setting "NESBatteryBackedWRAM", true
  .setting "LaunchCommAND", "c:\\emulation\\fceux.exe {0}"
  .setting "DebugCommAND", "c:\\emulation\\fceux.exe {0}"

;;;;;;;;;;;;;;;

;; DECLARE SOME VARIABLES HERE
  .segment "RAM"
  .org $0000
  
gamestate     .ds 1  ;current State
palettenum    .ds 1  ; which palette to use every frame

currentpage    .ds 1  ;which page to display
currentoption1 .ds 1  ;which page each option line links to
currentoption2 .ds 1
maxpage        .ds 1  ;highest page number
option1enabled .ds 1
option2enabled .ds 1


sourceLo      .ds 1  ; some pointers for loading text info
sourceHi      .ds 1
sourceBank    .ds 1

buttons       .ds 1  ;current contROLler buttons
newbuttons    .ds 1  ;which contROLler buttons have just been pressed

result        .ds 1  ;some temporary variables used for rANDom code
temp          .ds 1

tempdec       .ds 5  ;used for hex->DECimal conversions
temphex       .ds 2

framecounter  .ds 1  ;used for some delays like button repeating


  .org $0100
stack         .ds 256 ;;not actually needed, just a place holder

  .org $0200
sprites       .ds 256  ;sprite ram area



;;;;These variables have been moved to the WRAM area at $6000-7FFF
;; they are set up normally just like the console RAM, but cannot be used until the WRAM is enabled

  .org $6000
pagebank      .ds 256  ;data table for bank of each page text
pagehi        .ds 256  ;data table for high byte of address for STArt of each page text
pagelo        .ds 256
option1       .ds 256  ;data table for which page each option links to
option2       .ds 256

resetSignature  .ds 2    ;;signature in WRAM to detect how many times the console was reset
resetCount      .ds 1    ;;if the battery is enabled, this will count up ever time the ROM is loaded or reset
                         ;;if the battery is disabled, this will clear when the ROM is loaded but count up when it is reset



;;;;;;;;;;;;;;;;





;;;;;;;;;;;;;;;;;;
;; DECLARE SOME CONSTANTS HERE
STATETITLE     = $00  ; displaying title screen
STATEFADEOUT   = $01  ; fade to black
STATELOADPAGE  = $02  ; copy page to screen
STATEFADEIN    = $03  ; fade from black
STATESHOWPAGE  = $04  ; move paddles/ball, check for collisions


;;constants for page num sprite position
PAGEX   = $1C
PAGEY   = $07
;;;;;;;;;;;;;;;;;;

;;; Here's the main thing of this example
; we define our list of banks and their starting offsets
; now, as it turns out the way things work what will happen
; is that it will load the first PRG bank at $8000 and the 
; last PRG bank at $C000 for its initial banks
; I have no idea if it matters if I swap in $8000 or $C000
; banks into the same space; it probably does because there
; is absolute addressing available.  For MMC1 you generally want
; to do 16kb swappable, 16kb fixed anyway, so make sure your primary
; logic (and interrupt vectors) are in the fixed bank at $C000
; and then have all the swappable stuff (level maps, specific area code
; routines, etc) in the $8000 banks

  .bank 0, 16, $8000, "NES_PRG0"

  .bank 1, 16, $8000, "NES_PRG1"

  .bank 2, 16, $8000, "NES_PRG2"

  .bank 3, 16, $8000, "NES_PRG3"

  .bank 4, 16, $8000, "NES_PRG4"

  .bank 5, 16, $8000, "NES_PRG5"

  .bank 6, 16, $8000, "NES_PRG6"

  .bank 7, 16, $C000, "NES_PRG7"

  .segment "TEXT", 0
  .org $8000
  .incbin "story.txt"

  .segment "GRAPHICS", 7
  .org $C000   ;;8KB graphics in this fixed bank
Graphics:
  .incbin "graphics.nes"
  .incbin "graphics.nes"

  .segment "MAINCODE", 7    ;all code will go in the last 8KB, which is not a swappable bank
  .org $E000    



;;;;;;;;;;;;;;;;;;;;;
;;;;all game code from here down



;;;;first some subroutines


vblankwait:   ;;manually wait for a vblank to happen
  BIT $2002
  BPL vblankwait
  RTS


;;;;;;;;;;;;;;;;;

LoadSpritePalette:      ;;set correct address, then jump to the palette loading loop
  LDA $2002             ; read PPU STAtus to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F10 address
  LDA #$10
  STA $2006             ; write the low byte of $3F10 address
  JMP LoadPalette


LoadBGPalette:          ;;set correct address, then jump to the palette loading loop
  LDA $2002             ; read PPU STAtus to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address



LoadPalette
  LDA palettenum        ;load which palette number to use
  CLC
  ASL A
  ASL A                 ;each palette is 16 bytes
  ASL A                 ;so shift 4 times to multiply by 16
  ASL A
  TAY                   ;transfer A to Y, because Y will use used as inDEX below
   
  LDX #$00              ; byte count STARTS at 0
LoadPalettesLoop:
  LDA palettes, y       ; load data from address (palette + the value in y)
  STA $2007             ; write to PPU
  INY
  INX                   ; X = X + 1
  CPX #$10              ; Compare X to hex $10 = 16 bytes
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 16, all done
  RTS
  
  
  
  
;;;;;;;;;;;;;;;;;;;;
  
  
LoadCHRRAM:            ;;copies 8KB of graphics from PRG to CHR RAM
  LDA $2002
  LDA #$00
  STA $2006            ;set PPU to the CHR RAM area $0000-1FFF
  STA $2006
  LDY #$00
  LDX #$20             ;32 x 256 bytes = 8 KB
  LDA #<Graphics
  STA sourceLo
  LDA #>Graphics  ;get the address of the graphics data ($C000)
  STA sourceHi         ;put into our source pointer
LoadCHRRamLoop:
  LDA (sourceLo), Y    ;copy from source pointer
  STA $2007            ;to PPU CHR RAM area
  INY
  BNE LoadCHRRamLoop   ;;loop 256 times
  INC sourceHi         ;;then INCrement the high address byte
  DEX                  ;;do that 32 times
  BNE LoadCHRRamLoop   ;;32 x 256 = 8KB
LoadCHRRamDone:
  RTS
  
  
;;;;;;;;;;;;;;;;;;;;;;;


ConfigWrite:     ; make sure this is in the last PRG bank so the RTS doesn't get swapped away
  LDA #$80
  STA $8000      ; reset the shift register
  
  LDA #%00001110 ; 8KB CHR, 16KB PRG, $8000-BFFF swappable, vertical mirroring
  STA $8000      ; first data bit
  LSR A          ; shift to next bit
  STA $8000      ; second data bit
  LSR A          ; etc
  STA $8000
  LSR A
  STA $8000
  LSR A
  STA $8000
  RTS


PRGBankWrite:     ; make sure this is in last bank so it doesnt get swapped away
  LDA sourceBank  ; load bank number into A
  
  AND #%01111111  ; clear the WRAM bit so it is always enabled
  
  STA $E000       ; first data bit
  LSR A           ; shift to next bit
  STA $E000
  LSR A
  STA $E000
  LSR A
  STA $E000
  LSR A
  STA $E000
  RTS



;bankvalues:  ;;This is the old bank switching code for UNROM
;  .db 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
;BankSwitch:
;  LDA sourceBank
;  tay
;  STA bankvalues, y  ;;make sure byte written = byte in ROM so there is no bus conflict
;  RTS
  
  
;;;;;;;;;;;;;;;;;;;;;;
  
IncSource:  ;;INCrements the source address in $8000-BFFF range
            ;;checks for bank overflow, switches bank if needed
            
  LDA sourceLo
  CLC
  ADC #$01
  STA sourceLo
  LDA sourceHi
  ADC #$00
  STA sourceHi
  CMP #$C0            ;;if high byte = C0, then address = $C000 AND bank overflowed
  BNE IncSourceDone
IncSourceOverflow:
  LDA #$80            ;;go to $8000 in next bank
  STA sourceHi
  INC sourceBank
  JSR PRGBankWrite
IncSourceDone:
  RTS


;;;;;;;;;;;;;;;;;;;;;;;;

  
;;data tables for DECimal -> hex conversions
hundreds:
  .b 0, 100, 200
tens:
  .b 0, 10, 20, 30, 40, 50, 60, 70, 80, 90
ones:
  .b 0, 1, 2, 3, 4, 5, 6, 7, 8, 9

DecToHex:  ;;DECimal to hex conversion
           ;;source address points to first character of 3 digit DECimal number
           ;;"result" will contain the hex answer
  JSR PRGBankWrite    ;;make sure bank is correct using sourceBank

  LDY #$00
  LDA (sourceLo), Y
  SEC
  SBC #$30           ;convert from ascii to 0-9
  TAX
  LDA hundreds, X    ;;get the hundreds digit
  STA result
  
  JSR IncSource     ;;go to next character
  
  LDY #$00
  LDA (sourceLo), Y
  SEC
  SBC #$30           ;convert from ascii to 0-9
  TAX
  LDA tens, X    ;;get the tens digit
  CLC
  ADC result     ;;add to hundreds
  STA result

  JSR IncSource     ;;go to next character
  
  LDY #$00
  LDA (sourceLo), y
  SEC
  SBC #$30           ;convert from ascii to 0-9
  TAX
  LDA ones, x    ;;get the ones digit
  CLC
  ADC result     ;;add to hundreds+tens
  STA result
  RTS
  
  
  
  
HexToDec: 
   LDA #$00 
   STA tempdec+0 
   STA tempdec+1 
   STA tempdec+2 
   STA tempdec+3 
   STA tempdec+4 
   LDX #$10 
BitLoop: 
   ASL temphex+0    ;;loop thro each bit, adding the equivalent DECimal number
   ROL temphex+1 
   LDY tempdec+0 
   LDA BitTable, y 
   ROL a
   STA tempdec+0 
   LDY tempdec+1 
   LDA BitTable, y 
   ROL a
   STA tempdec+1 
   LDY tempdec+2 
   LDA BitTable, y 
   ROL a
   STA tempdec+2 
   LDY tempdec+3 
   LDA BitTable, y 
   ROL a
   STA tempdec+3 
   ROL tempdec+4 
   DEX 
   BNE BitLoop 
   
   LDA tempdec    ;;convert to ascii by adding the ascii value of '0'
   CLC
   ADC #$30
   STA tempdec
   LDA tempdec+1
   CLC
   ADC #$30
   STA tempdec+1
   LDA tempdec+2
   CLC
   ADC #$30
   STA tempdec+2
   LDA tempdec+3
   CLC
   ADC #$30
   STA tempdec+3
   LDA tempdec+4
   CLC
   ADC #$30
   STA tempdec+4
   
   RTS 

;;data table for hex -> DEC conversions
BitTable: 
   .b $00, $01, $02, $03, $04, $80, $81, $82, $83, $84


;;;;;;;;;;;;;;;;;;;;;;;;

  
SavePageAddress:   ;;saves the address of page text to data table
  LDY currentpage
  LDA sourceLo
  STA pagelo, y
  LDA sourceHi
  STA pagehi, y
  LDA sourceBank
  STA pagebank, y
  RTS
  
SavePageOptions:    ;;saves the option numbers to data table
  LDY currentpage
  LDA currentoption1
  STA option1, y
  LDA currentoption2
  STA option2, y
  RTS


;;;;;;;;;;;;;;;;;;;;

;;page format:
;  main text TAB 
;  option 1 text TAB
;  option 1 number (3 digits) TAB 
;  option 2 text TAB 
;  option 2 number (3 digits) TAB


CalculatePages:    ;;calculate all the page offsets AND option numbers
                   ;;will read all the data, parsing it for the TAB delimiters
                   ;;keeping track of the address AND saving it in the data tables in ram
                   ;;this could be done by a PC app AND coded into the ROM instead
  LDA #$00
  STA sourceBank
  STA sourceLo
  LDA #$01
  STA currentpage   ;;STArt at page 1, page 0 is unused because excel has no row 0
  LDA #$80
  STA sourceHi     ;;STArt at $8000 of bank 0
  JSR PRGBankWrite    ;;make sure bank is correct
    
CalculatePagesLoop:
  JSR SavePageAddress    ;;save the current address before doing more searching
  
CalculatePagesMainText:   ;;loop until end of text (TAB) is found
  JSR IncSource           ;go to next byte
  LDY #$00
  LDA (sourceLo), Y
  CMP #$09                ;;ascii character for TAB
  BNE CalculatePagesMainText
  
CalculatePagesOption1Text:
  JSR IncSource           ;go to next byte (was stopped at TAB)
  LDY #$00
  LDA (sourceLo), Y
  CMP #$09                ;;ascii character for TAB
  BNE CalculatePagesOption1Text
  
CalculatePagesOption1Number:
  JSR IncSource           ;go to next byte (was stopped at TAB)
  JSR DecToHex            ;do the DECimal to hex conversion
  LDA result
  STA currentoption1      ;save the result
  JSR IncSource           ;go to next byte (was stopped end of number)

    
CalculatePagesOption2Text:
  JSR IncSource           ;go to next byte (was stopped at TAB)
  LDY #$00
  LDA (sourceLo), Y
  CMP #$09                ;;ascii character for TAB
  BNE CalculatePagesOption2Text
           
CalculatePagesOption2Number:
  JSR IncSource           ;go to next byte (was stopped at TAB)
  JSR DecToHex            ;do the DECimal to hex conversion
  LDA result
  STA currentoption2      ;save the result
  
  JSR SavePageOptions

  JSR IncSource           ;go to next byte (was stopped at end of number)

;;if next character = FF, reached end of tab file, no more pages
  LDY #$00
  LDA (sourceLo), Y
  CMP #$FF               ;;;;;;THIS LINE MAY HAVE TO BE FIXED DEPENDING ON YOUR ASSEMBLER
  BEQ CalculatePagesDone

;;if next+1 character = 0D, no more pages
  LDY #$01
  LDA (sourceLo), Y
  CMP #$0D
  BEQ CalculatePagesDone


;;check if this page was the maximum (256)
  LDA currentpage
  CMP #$FF
  BEQ CalculatePagesDone
  
;;all done with this page, go to next page AND search again
  INC currentpage
  JMP CalculatePagesLoop
  
CalculatePagesDone:
  LDA currentpage    ;save the last page number
  STA maxpage
  RTS

           
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;           
           
           
DrawPageNumber:
;;set sprite tile numbers for current page
  LDA currentpage
  STA temphex
  LDA #$00
  STA temphex+1
  JSR HexToDec
  LDA tempdec    ;;ones digit
  STA $020D
  LDA tempdec+1  ;;tens digit
  STA $0209
  LDA tempdec+2  ;;hundreds digit
  STA $0205
  RTS 
 
 
;;;;;;;;;;;;;;;;;;;;;;;;


ClearScreen:        ;;set all background to $00
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$00
  STA $2006
  LDX #$04
  LDY #$00
ClearScreenLoop:
  STA $2007
  DEY
  BNE ClearScreenLoop
  DEX
  BNE ClearScreenLoop
  RTS


;;;;;;;;;;;;;;;;;;;;;;

           
DrawPage:
  JSR ClearScreen
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$20
  STA $2006
  
  LDA #'P'
  STA $2007
  LDA #'a'
  STA $2007
  LDA #'g'
  STA $2007
  LDA #'e'
  STA $2007                 ;;draw page number header
  
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$40
  STA $2006  
DrawPageText:
  LDY currentpage
  LDA pagebank, Y
  STA sourceBank
  LDA pagelo, Y
  STA sourceLo
  LDA pagehi, Y
  STA sourceHi
  JSR PRGBankWrite             ;;set character pointer to correct position for this page
  
  LDX #$00                   ;;used for horiz position in line

  LDY #$00
  LDA (sourceLo), Y          ;;if first char is CR, skip it
  CMP #$0D
  BNE DrawPageTextLoop
  JSR IncSource
  
  
DrawPageTextLoop:
  LDY #$00
  LDA (sourceLo), Y
  CMP #$09
  BEQ DrawPageTextLoopDone   ;;TAB found, all done with text
  CMP #$0A
  BEQ DrawPageTextLoopNext   ;;NL new line (ignore)
  CMP #$0D
  BEQ DrawPageTextNextLine   ;;CR carriage return
  
  STA $2007                  ;;write char to screen
  
DrawPageTextLoopNext:
  JSR IncSource              ;;go to next character
  INX
  CPX #$20                   ;;INCrement horizontal position
  BNE DrawPageTextLoop       ;;check if at next line
  LDX #$00
  JMP DrawPageTextLoop
  
DrawPageTextNextLine:
  LDA #' '
  STA $2007                  ;;write spaces to screen
  INX
  CPX #$20                   ;;until line ends
  BNE DrawPageTextNextLine
  LDX #$00                   ;;then STArt next line
  JSR IncSource              ;;go to next character
  JMP DrawPageTextLoop

DrawPageTextLoopDone:
  JSR IncSource              ;;last char was TAB
   
  LDY #$00
  LDA (sourceLo), Y
  CMP #$09
  BEQ DrawPageOption1Done    ;;skip over option 1 if empty
  
  LDA $2002
  LDA #$23
  STA $2006
  LDA #$60
  STA $2006
  LDA #'A'
  STA $2007
  LDA #':'
  STA $2007
DrawPageOption1:
  LDY #$00
  LDA (sourceLo), Y
  CMP #$09
  BEQ DrawPageOption1Done   ;;TAB found, all done with text
  
  STA $2007                  ;;write char to screen
  JSR IncSource
  JMP DrawPageOption1
DrawPageOption1Done:
  JSR IncSource            ;;last char was tab
  
DrawPageSkipOptionNum:
  LDY #$00
  LDA (sourceLo), Y
  CMP #$09
  BEQ DrawPageSkipOptionNumDone    ;;skip over option 1 page number
  JSR IncSource
  JMP DrawPageSkipOptionNum
DrawPageSkipOptionNumDone:
  JSR IncSource
  
  LDY #$00
  LDA (sourceLo), Y
  CMP #$09
  BEQ DrawPageOption2Done    ;;skip over option 2 if empty

  LDA $2002
  LDA #$23
  STA $2006
  LDA #$80
  STA $2006
  LDA #'B'
  STA $2007
  LDA #':'
  STA $2007
DrawPageOption2:
  LDY #$00
  LDA (sourceLo), Y
  CMP #$09
  BEQ DrawPageOption2Done   ;;TAB found, all done with text
  
  STA $2007                  ;;write char to screen
  JSR IncSource
  JMP DrawPageOption2
DrawPageOption2Done:  
  RTS
            
            
;;;;;;;;;;;;;;;;;;;;;
            
            
DrawVersion:
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$40
  STA $2006

  LDY #$00
DrawVersionLoop:
  LDA version, y
  STA $2007
  INY 
  cpy #versionend-version
  BNE DrawVersionLoop
  RTS
  
version:
  .b "CYOA v0.10   www.retrousb.com"
versionend:
            

;;;;;;;;;;;;;;;;;;;;;           
            
            
DrawResetCount:
  LDA resetSignature           ;;read the signature bytes.  This checks if the WRAM was ever used before
  CMP #$AA                   ;; A sequence other than $AA $55 means this is the first time for WRAM.
  BNE DrawResetCountClear          
  LDA resetSignature+1         
  CMP #$55                 
  BNE DrawResetCountClear
  JMP DrawResetCountNumber    ;;sequence was found, so WRAM was used before     


DrawResetCountClear:
  LDA #$AA
  STA resetSignature          ;;sequence was not found, so write it AND set the count to 0
  LDA #$55
  STA resetSignature+1
  LDA #'0'
  STA resetCount

DrawResetCountNumber:
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$5F
  STA $2006
  LDA resetCount        ;;put the reset count at the end of the version line
  STA $2007
  
  CLC
  ADC #$01
  STA resetCount       ;;INCrement the counter, save into WRAM
  
  RTS
           

;;;;;;;;;;;;;;;;;;;;;
           
           
           

RESET:
  SEI          ; disable IRQs
  CLD          ; disable DECimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs


  JSR vblankwait    ; First wait for vblank to make sure PPU is ready



  JSR ConfigWrite   ; Set up the MMC1 banking AND config

  LDA #$00
  STA sourceBank
  JSR PRGBankWrite  ; do this switch to enable WRAM

  ;;8KB CHR RAM is used, so no banking or switching is needed
  ;;those registers are left alone



clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  
  STA $6000, x
  STA $6100, x
  STA $6200, x
  STA $6300, x
  STA $6400, x  ;;clear out the WRAM we use too
  
  LDA #$FE
  STA $0200, x
  INX
  BNE clrmem
   
  JSR vblankwait      ; Second wait for vblank, PPU is ready after this


  


;;load all the graphics information
  LDA #$00
  STA palettenum
  JSR LoadCHRRAM        
  JSR LoadBGPalette
  JSR LoadSpritePalette

  
;;calculate all the text offsets AND page option numbers
  JSR CalculatePages
  
;;set up title page number display
  LDA #PAGEY
  STA $0204
  LDA #$00
  STA $0205
  LDA #$01
  STA $0206
  LDA #PAGEX+$08
  STA $0207
  
  LDA #PAGEY
  STA $0208
  LDA #$00
  STA $0209
  LDA #$01
  STA $020A
  LDA #PAGEX+$10
  STA $020B
  
  LDA #PAGEY
  STA $020C
  LDA #$00
  STA $020D
  LDA #$01
  STA $020E
  LDA #PAGEX+$18
  STA $020F

  LDA #$01
  STA currentpage
  JSR DrawPageNumber
  JSR DrawPage
  JSR DrawVersion

  JSR DrawResetCount  ;;read from WRAM to see how many times the system was reset

;;:Set STArting game STAte, change to intro when finished
  LDA #STATETITLE
  STA gamestate

  JSR vblankwait   ;;wait for vblank so screen isnt turned on while rendering is happening
  
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001

  LDA #$00        ;;tell the ppu there is no background scROLling
  STA $2006
  STA $2006
  STA $2005
  STA $2005
  
  

Forever:
  JMP Forever     ;jump back to Forever, infinite loop, waiting for NMI
  
 

NMIHANDler:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, STArt the transfer


  JSR LoadBGPalette
  JSR LoadSpritePalette

NMIDone:
  ;;This is the PPU clean up section, so rendering the next frame STARTS properly.
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001
  LDA #$00        ;;tell the ppu there is no background scROLling
  STA $2005
  STA $2005
    
  ;;;all graphics updates done by here, run game engine

  LDA framecounter
  CMP #$00
  BEQ FrameCounterDone
  DEC framecounter     ;;DECrement until 0, then stop
FrameCounterDone:  

  JSR ReadContROLler1  ;;get the current button data for player 1


  
GameEngine:  
GameEngineTitle:
  LDA gamestate
  CMP #STATETITLE
  BNE GameEngineTitleDone
  JMP EngineTitle    ;;game is displaying title screen, checking contROLler for up/down/a/b
GameEngineTitleDone:

GameEngineFadeOut:
  LDA gamestate
  CMP #STATEFADEOUT
  BNE GameEngineFadeOutDone
  JMP EngineFadeOut    ;;game is fading to black
GameEngineFadeOutDone:

GameEngineFadeIn:
  LDA gamestate
  CMP #STATEFADEIN
  BNE GameEngineFadeInDone
  JMP EngineFadeIn    ;;game is from black to white
  GameEngineFadeInDone:

GameEngineLoadPage:
  LDA gamestate
  CMP #STATELOADPAGE
  BNE GameEngineLoadPageDone
  JMP EngineLoadPage    ;;game is loading current page
GameEngineLoadPageDone:

GameEngineShowPage:
  LDA gamestate
  CMP #STATESHOWPAGE
  BNE GameEngineShowPageDone
  JMP EngineShowPage    ;;game is showing a page, checking contROLler for A/B
GameEngineShowPageDone:

GameEngineDone:  
  RTI             ; return from interrupt
 
 
 
;;;;;;;;; 
 
EngineFadeOut:
  LDA framecounter
  BNE EngineFadeOutDone     ;;if framecounter still counting down, do nothing
  
  INC palettenum            ;;INCrement palette number, towards black
  LDA #$04
  STA framecounter          ;;STArt the delay again    

  LDA palettenum
  CMP #$05
  BNE EngineFadeOutDone
  LDA #$04                  ;;if palette = max palette 
  STA palettenum
  LDA #STATELOADPAGE        ;;screen is black so load next page
  STA gamestate
EngineFadeOutDone:
  JMP GameEngineDone
 
;;;;;;;;;;;
  
EngineLoadPage:
  LDA #$00
  STA $2000
  STA $2001             ;;turn screen off
  JSR DrawPage          ;;load new page, page number already set from options
  JSR DrawPageNumber    ;;load page number sprites
  JSR vblankwait
  LDA #%10010000        ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #%00011110        ; enable sprites, enable background, no clipping on left side
  STA $2001
  LDA #STATEFADEIN    ;;done loading, fade in
  STA gamestate
  JMP GameEngineDone

;;;;;;;;; 

EngineFadeIn:
  LDA framecounter
  BNE EngineFadeInDone     ;;if framecounter still counting down, do nothing
  
  DEC palettenum            ;;DECrement palette number, towards white text
  LDA #$04
  STA framecounter          ;;STArt the delay again    

  LDA palettenum
  CMP #$FF
  BNE EngineFadeOutDone
  LDA #$00                  ;;if palette = min palette 
  STA palettenum
  LDA #STATESHOWPAGE        ;;screen is displayed so show page
  STA gamestate
EngineFadeInDone:
  JMP GameEngineDone

;;;;;;;;; 
 
 
EngineShowPage:
  LDA newbuttons          ;;check for a new A press
  AND #%10000000
  BEQ EngineShowPageNotA
  LDY currentpage
  LDA option1, Y
  BEQ EngineShowPageNotA  ;;if option1 page = 0, skip
  STA currentpage
  LDA #STATEFADEOUT       ;;option 1 not zero, set up to load next page
  STA gamestate
  LDA #$00
  STA framecounter        ;;STArt the fade immediately
  JMP EngineShowPageDone
EngineShowPageNotA:
  
  LDA newbuttons          ;;check for a new B press
  AND #%01000000
  BEQ EngineShowPageNotB
  LDY currentpage
  LDA option2, Y
  BEQ EngineShowPageNotB  ;;if option2 page = 0, skip
  STA currentpage
  LDA #STATEFADEOUT       ;;option 2 not zero, set up to load next page
  STA gamestate
  LDA #$00
  STA framecounter        ;;STArt the fade immediately
  JMP EngineShowPageDone
EngineShowPageNotB:

EngineShowPageDone:
  JMP GameEngineDone
 
;;;;;;;;;;;


;;;;;;;;
 
EngineTitle:
  
;;;check the up button to change page numbers
EngineTitleButtons:
  LDA framecounter
  BNE EngineTitleButtonsDone        ;;delay for button repeat

EngineTitleButtonsUp:
  LDA buttons
  AND #%00001000                    ;;check up button
  BEQ EngineTitleButtonsUpDone
  
  LDA currentpage
  CMP maxpage
  BNE EngineTitleButtonsUpDelay     ;;check if at end of book
  
  LDA #$00
  STA currentpage                   ;;set to beginning of book
  
EngineTitleButtonsUpDelay:    
  INC currentpage                   ;;go to next page
  LDA #$08
  STA framecounter                  ;;set delay for button repeat

EngineTitleButtonsUpDone:


;;check the down button to change page numbers
EngineTitleButtonsDown:
  LDA buttons
  AND #%00000100                    ;;check down button
  BEQ EngineTitleButtonsDownDone

  DEC currentpage                   ;;go to next page
  LDA currentpage
  CMP #$00
  BNE EngineTitleButtonsDownDelay   ;;check if before beginning of book
  
  LDA maxpage
  STA currentpage                   ;;set to end of book
  
EngineTitleButtonsDownDelay:    
  LDA #$08
  STA framecounter                  ;;set delay for button repeat

EngineTitleButtonsDownDone:



EngineTitleButtonsStart:
  LDA buttons
  AND #%00010000                    ;;check STArt button
  BEQ EngineTitleButtonsStartDone
  LDA #STATEFADEOUT                 ;;jump to selected page
  STA gamestate
  LDA #$00
  STA framecounter                  ;;STArt the fade immediately
  JMP EngineShowPageDone
EngineTitleButtonsStartDone:


EngineTitleButtonsDone:
  JSR DrawPageNumber      ;;set page number sprites
  JMP EngineShowPage     ;;reuse the show page code to check contROLler A/B buttons



;;;;;;;;;;;;;;;;;;;;
     
;bit:   	7	6	5       4     3   2     1     0
;button:	A	B	select	STArt	up	down	left	right

ReadContROLler1:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadContROLler1Loop:   ;;read contROLler, save into temporary variable
  LDA $4016
  LSR A            ; bit0 -> Carry
  ROL temp        ; bit0 <- Carry
  DEX
  BNE ReadContROLler1Loop

  LDA temp                 ;;compare current buttons
  EOR buttons              ;;to previous buttons
  AND temp                 ;;only looking at buttons pressed now
  STA newbuttons           ;;to figure out which are new
  
  LDA temp
  STA buttons              ;;save current buttons
  
  RTS
    
        
;;;;;;;;;;;;;;  
  
  
  
palettes:
  .b $1D,$30,$30,$30, $1D,$30,$30,$30, $1D,$30,$30,$30, $1D,$30,$30,$30   ;; palette 0
  .b $1D,$20,$1D,$1D, $1D,$20,$1D,$1D, $1D,$20,$1D,$1D, $1D,$20,$1D,$1D   ;; palette 1
  .b $1D,$10,$1D,$1D, $1D,$10,$1D,$1D, $1D,$10,$1D,$1D, $1D,$10,$1D,$1D   ;; palette 2
  .b $1D,$00,$1D,$1D, $1D,$00,$1D,$1D, $1D,$00,$1D,$1D, $1D,$00,$1D,$1D   ;; palette 3
  .b $1D,$1D,$1D,$1D, $1D,$1D,$1D,$1D, $1D,$1D,$1D,$1D, $1D,$1D,$1D,$1D   ;; palette 4





  .org $FFFA     ;first of the three vectors STARTS here
  .w NMIHandler        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .w RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .w 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  