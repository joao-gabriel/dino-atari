; ****************************************************************************
; TODO:
;	- Implement X positioning
; - Implement showing bird, cactus, or none
; - Change GRP1 pattern when it reaches leftmost position
; - Implement six-digit score
; - Implement lives
; - Implement Game start
;
; ****************************************************************************


	processor 6502
	include includes/vcs.h
	include includes/macro.h

	org $F000


Start
	
	CLEAN_START

; Variables	
DinoVerticalVelocity = $80
DinoVerticalPos = $81
DinoVerticalDelay = $82
DinoBitmapBuffer = $83
DinoLineBeingDraw = $84
DinoBitmapLocation = $85 ; it takes 2 bytes
VarButtonLock = $87;
DinoAnimateSpriteBitmap = $88
DinoAnimateSpriteDelay = $89
CactusBitmapBuffer = $8A
CactusLineBeingDraw = $8B
Seed = $8C 
Helper = $8D ; TODO: D0 = Game Start, D1 = Show Cactus, D2 = Show bird 
CactusHorizontalPos = $8E

; Constants
GroundVerticalPos = 65
DinoAnimateSpriteFramesDelay = 8
	
	lda #$9C
	sta COLUBK

	lda #$C2
	sta COLUP0
	sta COLUP1
	
	lda #$E2
	sta COLUPF

	lda #0
	sta DinoVerticalDelay
	sta VarButtonLock

	lda #GroundVerticalPos
	sta DinoVerticalPos
	
	lda #DinoAnimateSpriteFramesDelay
	sta DinoAnimateSpriteDelay

	lda #0
	sta DinoVerticalVelocity
	sta HMP0
	
	lda #6
	sta CactusHorizontalPos

	sta WSYNC
	sta RESP1
	SLEEP 30
	sta RESP0

FrameLoop

	VERTICAL_SYNC
	
	lda #43
	sta TIM64T
	
	lda #$00
	sta PF0
	sta PF1
	sta PF2
	
	inc Seed
	
	jsr AnimateDinoSprite
	jsr HandleDinoJump

	lda #%00010000
	sta HMP1
	
	dec CactusHorizontalPos
	bne DontResetCactusHorizontalPos
	
	lda #160
	sta CactusHorizontalPos

DontResetCactusHorizontalPos

	lda CactusHorizontalPos
	cmp #160
	bne DontChangeCactusPattern
	
	lda Seed
	sta NUSIZ1

DontChangeCactusPattern


WaitForVblankEnd
	lda INTIM
	bne WaitForVblankEnd
	lda #0
	sta WSYNC
	sta VBLANK

	ldy #0

ScanlineLoop
	sta WSYNC

	lda DinoBitmapBuffer
	sta GRP0
	
	lda CactusBitmapBuffer
	sta GRP1

  lda #0
  sta DinoBitmapBuffer
	sta CactusBitmapBuffer

	cpy DinoVerticalPos
	bne SkipDinoDrawBegin
	
	lda #14
	sta DinoLineBeingDraw	

SkipDinoDrawBegin

  tya
  tax
	ldy DinoLineBeingDraw
	beq FinishDraw

  lda (DinoBitmapLocation),Y
	sta DinoBitmapBuffer
	dec DinoLineBeingDraw
	
FinishDraw

	sta WSYNC

  txa
  tay
  
	cpy #GroundVerticalPos
	bne SkipCactusDrawBegin
	
	lda #14
	sta CactusLineBeingDraw	

SkipCactusDrawBegin  
  
  ldx CactusLineBeingDraw
  beq CactusFinishDraw

	lda Cactus,X
	sta CactusBitmapBuffer
	dec CactusLineBeingDraw
  
CactusFinishDraw
 
	iny
	cpy #80
	bne ScanlineLoop
	
	sta WSYNC
	lda #0
	sta GRP0
	sta GRP1
	
	lda #$FF
	sta PF0
	sta PF1
	sta PF2
	
	ldy #20
GroundScanlineLoop
	sta WSYNC
	dey 
	bne GroundScanlineLoop

	; Overscan
	lda #2
	sta WSYNC
	sta HMOVE
	sta VBLANK
	ldx #30
OverScanWait
	sta WSYNC
	dex
	bne OverScanWait
	
	jmp FrameLoop

	include dino.asm
	include data/bitmaps.asm
	
	org $FFFC
	.word Start
	.word Start
