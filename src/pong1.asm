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
  
gamestate  .ds 1  ; .rs 1 means reserve one byte of space
ballx      .ds 1  ; ball horizontal position
bally      .ds 1  ; ball vertical position
ballup     .ds 1  ; 1 = ball moving up
balldown   .ds 1  ; 1 = ball moving down
ballleft   .ds 1  ; 1 = ball moving left
ballright  .ds 1  ; 1 = ball moving right
ballspeedx .ds 1  ; ball horizontal speed per frame
ballspeedy .ds 1  ; ball vertical speed per frame
paddle1ytop   .ds 1  ; player 1 paddle top vertical position
paddle2ytop   .ds 1  ; player 2 paddle top vertical position
paddlespeed .ds 1 ; paddle speed per frame
buttons1   .ds 1  ; player 1 gamepad buttons, one bit per button
buttons2   .ds 1  ; player 2 gamepad buttons, one bit per button
score1     .ds 1  ; player 1 score, 0-15
score2     .ds 1  ; player 2 score, 0-15
respawntimer .ds 1  ; ticker to decrement until the ball respawns


;; DECLARE SOME CONSTANTS HERE
STATETITLE     = $00  ; displaying title screen
STATEPLAYING   = $01  ; move paddles/ball, check for collisions
STATEGAMEOVER  = $02  ; displaying game over screen
  
RIGHTWALL      = $F4  ; when ball reaches one of these, do something
TOPWALL        = $20
BOTTOMWALL     = $E0
LEFTWALL       = $04
  
PADDLE1X       = $08  ; horizontal position for paddles, doesnt move
PADDLE2X       = $F0

;;;;;;;;;;;;;;;;;;


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
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $20, copying 8 palettes (each is 4 bytes)
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

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
  CPX #$80              ; Need to loop enough times to copy all bytes.  Each row is 32 bytes, we're doing 4 rows
  BNE LoadBackgroundLoop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down

  LDX #$00
LoadBackground2Loop:
  LDA background2, X
  STA $2007
  INX
  CPX #$80
  BNE LoadBackground2Loop

  LDX #$00
LoadBackground3Loop:
  LDA background3, X
  STA $2007
  INX
  CPX #$80
  BNE LoadBackground3Loop

    LDX #$00
LoadBackground4Loop:
  LDA background4, X
  STA $2007
  INX
  CPX #$80
  BNE LoadBackground4Loop

  LDX #$00
LoadBackground5Loop:
  LDA background5, X
  STA $2007
  INX
  CPX #$80
  BNE LoadBackground5Loop

 LDX #$00
LoadBackground6Loop:
  LDA background6, X
  STA $2007
  INX
  CPX #$80
  BNE LoadBackground6Loop

LDX #$00
LoadBackground7Loop:
  LDA background7, X
  STA $2007
  INX
  CPX #$A0                      ; last set has an extra row of tiles
  BNE LoadBackground7Loop
              
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
  CPX #$40              ; Compare X to hex $18; seven rows of attributes plus two bytes
  BNE LoadAttributeLoop  ; Branch to LoadAttributeLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down


;;;Set some initial states
  LDA #$01
  STA balldown
  STA ballright
  LDA #$00
  STA ballup
  STA ballleft
  
  LDA #$50
  STA bally
  
  LDA #$80
  STA ballx
  
  LDA #$02
  STA ballspeedx
  STA ballspeedy

  LDA #$03
  STA paddlespeed

  LDA #$40
  STA paddle1ytop
  STA paddle2ytop

  LDA #$00
  STA score1
  STA score2


;;:Set starting game state
  LDA #STATEPLAYING   ; TODO: when implemented the title screen load that state instead
  STA gamestate
              
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001

  LDA #$00        ;;tell the ppu there is no background scrolling
  STA $2005
  STA $2005

Forever:
  JMP Forever     ;jump back to Forever, infinite loop, waiting for NMI

NMIHandler:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer

  JSR DrawScore    ; need to do this early so we're still in vblank
                   ; TOdO: this section is all our background code, so we should have
                   ; DrawTitle, DrawScore, DrawGameOver

  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #$00        ;;tell the ppu there is no background scrolling
  STA $2005
  STA $2005
    
  ;;;all graphics updates done by here, run game engine

  JSR ReadController1  ;;get the current button data for player 1
  JSR ReadController2  ;;get the current button data for player 2
  
GameEngine:  
  LDA gamestate
  CMP #STATETITLE
  BEQ EngineTitle    ;;game is displaying title screen
    
  LDA gamestate
  CMP #STATEGAMEOVER
  BEQ EngineGameOver  ;;game is displaying ending screen
  
  LDA gamestate
  CMP #STATEPLAYING
  BEQ EnginePlaying   ;;game is playing
GameEngineDone:  
  
  JSR UpdateSprites  ;;set ball/paddle sprites from positions

  RTI             ; return from interrupt
 
 
;;;;;;;;
 
EngineTitle:
  ;; TODO
  ;;if start button pressed
  ;;  turn screen off
  ;;  load game screen
  ;;  set starting paddle/ball position
  ;;  go to Playing State
  ;;  turn screen on
  JMP GameEngineDone

;;;;;;;;; 
 
EngineGameOver:
  ;; TODO
  ;;if start button pressed
  ;;  turn screen off
  ;;  load title screen
  ;;  go to Title State
  ;;  turn screen on 
  JMP GameEngineDone
 
;;;;;;;;;;;
 
EnginePlaying:
  LDA respawntimer
  BNE GameEngineDone

MoveBallRight:
  LDA ballright
  BEQ MoveBallRightDone   ;;if ballright=0, skip this section

  LDA ballx
  CLC
  ADC ballspeedx        ;;ballx position = ballx + ballspeedx
  STA ballx

  LDA ballx
  CMP #RIGHTWALL
  BCC MoveBallRightDone      ;;if ball x < right wall, still on screen, skip next section

  INC score1          ; player one scores a point
  LDA #$00
  STA ballright
  LDA #$01
  STA ballleft         ; player 2 puts ball in play
  LDA #$50
  STA bally
  LDA #$80
  STA ballx            ; reset ball position
  LDA #$30             ; respawn in 30 ticks
  STA respawntimer
MoveBallRightDone:


MoveBallLeft:
  LDA ballleft
  BEQ MoveBallLeftDone   ;;if ballleft=0, skip this section

  LDA ballx
  SEC
  SBC ballspeedx        ;;ballx position = ballx - ballspeedx
  STA ballx

  LDA ballx
  CMP #LEFTWALL
  BCS MoveBallLeftDone      ;;if ball x > left wall, still on screen, skip next section

  INC score2          ; player two scores a point
  LDA #$01
  STA ballright
  LDA #$00
  STA ballleft         ; player 1 puts ball in play
  LDA #$50
  STA bally
  LDA #$80
  STA ballx            ; reset ball position
  LDA #$30             ; respawn in 30 ticks
  STA respawntimer
MoveBallLeftDone:


MoveBallUp:
  LDA ballup
  BEQ MoveBallUpDone   ;;if ballup=0, skip this section

  LDA bally
  SEC
  SBC ballspeedy        ;;bally position = bally - ballspeedy
  STA bally

  LDA bally
  CMP #TOPWALL
  BCS MoveBallUpDone      ;;if ball y > top wall, still on screen, skip next section
  LDA #$01
  STA balldown
  LDA #$00
  STA ballup         ;;bounce, ball now moving down
MoveBallUpDone:


MoveBallDown:
  LDA balldown
  BEQ MoveBallDownDone   ;;if ballup=0, skip this section

  LDA bally
  CLC
  ADC ballspeedy        ;;bally position = bally + ballspeedy
  STA bally

  LDA bally
  CMP #BOTTOMWALL
  BCC MoveBallDownDone      ;;if ball y < bottom wall, still on screen, skip next section
  LDA #$00
  STA balldown
  LDA #$01
  STA ballup         ;;bounce, ball now moving down
MoveBallDownDone:

MovePaddle1Up:
  LDA buttons1
  AND #%00001000
  BEQ MovePaddle1UpDone ; if up is not pressed then we're done here

  LDA paddle1ytop
  CMP #TOPWALL
  BCC MovePaddle1UpDone  ; if the paddle is already at the top don't move it

  SBC paddlespeed  ; the branch ensures the carry is set
  STA paddle1ytop
MovePaddle1UpDone:

MovePaddle1Down:
  LDA buttons1
  AND #%00000100
  BEQ MovePaddle1DownDone ; if down is not pressed then we're done here

  LDA paddle1ytop
  CLC
  ADC #$08
  CMP #BOTTOMWALL
  BCS MovePaddle1DownDone ; if we're trying to go below the bottom then don't move it

  LDA paddle1ytop
  ADC paddlespeed   ; since we didn't branch the carry can't be set
  STA paddle1ytop
MovePaddle1DownDone:

MovePaddle2Up:
  LDA buttons2
  AND #%00001000
  BEQ MovePaddle2UpDone ; if up is not pressed then we're done here

  LDA paddle2ytop
  CMP #TOPWALL
  BCC MovePaddle2UpDone  ; if the paddle is already at the top don't move it

  SBC paddlespeed  ; the branch ensures the carry is set
  STA paddle2ytop
MovePaddle2UpDone:

MovePaddle2Down:
  LDA buttons2
  AND #%00000100
  BEQ MovePaddle2DownDone ; if down is not pressed then we're done here

  LDA paddle2ytop
  CLC
  ADC #$08
  CMP #BOTTOMWALL
  BCS MovePaddle2DownDone ; if we're trying to go below the bottom then don't move it

  LDA paddle2ytop
  ADC paddlespeed   ; since we didn't branch the carry can't be set
  STA paddle2ytop
MovePaddle2DownDone:
  
CheckPaddle1Collision:
  LDA ballleft
  BEQ CheckPaddle1CollisionDone   ;;if ballleft=0, skip this section

  LDA ballx
  SEC
  SBC #$08               ; need to check the ball's left side against the right side of paddle 1
  CMP #PADDLE1X
  BCS CheckPaddle1CollisionDone      ;;if ball x > left paddle's right side then we couldn't have hit yet

  LDA bally
  CMP paddle1ytop
  BCC CheckPaddle1CollisionDone    ; if ball y < left paddle's top then we didn't hit

  SBC #$10            ; need to check against the bottom of paddle 1, and carry is set if we're here
  CMP paddle1ytop
  BCS CheckPaddle1CollisionDone    ; if ball y > left paddle's bottom then we didn't hit

  LDA #$01
  STA ballright
  LDA #$00
  STA ballleft         ;;bounce, ball now moving right
CheckPaddle1CollisionDone:

CheckPaddle2Collision:
  LDA ballright
  BEQ CheckPaddle2CollisionDone   ;;if ballleft=0, skip this section

  LDA ballx
  CLC
  ADC #$08                           ; need to check ball's right side against the paddle's left side
  CMP #PADDLE2X
  BCC CheckPaddle2CollisionDone      ;;if ball x < left paddle's right side then we couldn't have hit yet

  LDA bally
  CMP paddle2ytop
  BCC CheckPaddle2CollisionDone    ; if ball y < left paddle's top then we didn't hit

  SBC #$10            ; need to check against the bottom of paddle 1, and carry is set if we're here
  CMP paddle2ytop
  BCS CheckPaddle2CollisionDone    ; if ball y > left paddle's bottom then we didn't hit

  LDA #$00
  STA ballright
  LDA #$01
  STA ballleft         ;;bounce, ball now moving left
CheckPaddle2CollisionDone:

CheckEndOfGame:
  LDA score1
  CMP #$0F
  BEQ MoveToEndState
  LDA score2
  CMP #$0F
  BEQ MoveToEndState
  JMP CheckEndOfGameDone

MoveToEndState:
  LDA #STATEGAMEOVER
  STA gamestate
CheckEndOfGameDone:
  JMP GameEngineDone
 
 
UpdateSprites:
  LDA respawntimer
  BEQ DrawBall
  DEC respawntimer
  JMP DrawPaddles

DrawBall:
  LDA bally  ;;update all ball sprite info
  STA $0200
  
  LDA #$75   ; 30?
  STA $0201
  
  LDA #%00000000
  STA $0202
  
  LDA ballx
  STA $0203
  
DrawPaddles:
  ;;update paddle1 sprites
  LDA paddle1ytop
  STA $0204
  CLC
  ADC #$08
  STA $0208

  LDA #$87
  STA $0205
  STA $0209
  STA $020D     ; let's do paddle 2's sprite index while A is filled in
  STA $0211

  LDA #%01000001 ; top is flipped horizontally
  STA $0206
  LDA #%11000001 ; bottom is flipped both ways
  STA $020A

  LDA #PADDLE1X
  STA $0207
  STA $020B

  ;;update paddle2 sprites
  LDA paddle2ytop
  STA $020C
  CLC
  ADC #$08
  STA $0210

  LDA #%00000001 ; top is not flipped
  STA $020E
  LDA #%10000001 ; bottom is flipped vertically
  STA $0212

  LDA #PADDLE2X
  STA $020F
  STA $0213

  RTS
 
DrawScore:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006             ; write the high byte of $2041 address
  LDA #$41
  STA $2006             ; write the low byte of $2041 address
  LDA score1            ; since SMB1's background has the tiles go 0-9, A-Z, score is the tile number
  STA $2007             ; write out player 1's score
  LDA #$20
  STA $2006             ; write thie high byte of $205E address
  LDA #$5E
  STA $2006             ; write the low byte of the $205E address
  LDA score2            
  STA $2007             ; player 2's score, same as before
  RTS
 
ReadController1:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadController1Loop:
  LDA $4016
  LSR A            ; bit0 -> Carry
  ROL buttons1     ; bit0 <- Carry
  DEX
  BNE ReadController1Loop
  RTS
  
ReadController2:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadController2Loop:
  LDA $4017
  LSR A            ; bit0 -> Carry
  ROL buttons2     ; bit0 <- Carry
  DEX
  BNE ReadController2Loop
  RTS  
  
;;;;;;;;;;;;;;  
  
  .segment "SETUP"
  .org $E000
palette:
  .b $0F,$29,$1A,$22,  $0F,$36,$17,$15,  $0F,$30,$21,$0F,  $0F,$27,$17,$0F   ;;background palette
  .b $0F,$1C,$15,$14,  $0F,$02,$38,$3C,  $0F,$1C,$15,$14,  $0F,$02,$38,$3C   ;;sprite palette

;; NOTE - This is wasteful of memory; I could instead do one block for the status bar, then a second block for
;;        the playfield background which gets written out multiple times; probably could do it as an our loop
;;        for number of rows, and an inner loop to do 'copy a row'

background:                                                           ;; note - rows are split for readability
  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 1
  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all black

  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 2
  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all black

  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 3
  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all black

  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 4
  .b $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all black

background2:                                                          ;; since we only have 8 bits for our loop counter split into
                                                                      ;; groups of four rows
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 5
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 6
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 7
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 8
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

background3:                                                          ;; since we only have 8 bits for our loop counter split into
                                                                      ;; groups of four rows
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 9
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 10
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 11
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 12
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

background4:                                                          ;; since we only have 8 bits for our loop counter split into
                                                                      ;; groups of four rows
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 13
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 14
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 15
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 16
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

background5:                                                          ;; since we only have 8 bits for our loop counter split into
                                                                      ;; groups of four rows
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 17
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 18
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 19
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 20
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

background6:                                                          ;; since we only have 8 bits for our loop counter split into
                                                                      ;; groups of four rows
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 21
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 22
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 23
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 24
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

background7:                                                          ;; since we only have 8 bits for our loop counter split into
                                                                      ;; groups of four rows
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 25
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 26
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 27
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 28
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky

  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;row 29 - the odd row out, we have room in the counter
  .b $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27  ;;all sky


  attribute:
  .b %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101 ;; first four rows
  .b %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; next four rows
  .b %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; next four rows
  .b %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; next four rows
  .b %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; next four rows
  .b %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; next four rows
  .b %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; next four rows
  .b %00000000, %00000000                                                                   ;; last row

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