AnimateDinoSprite

  dec DinoAnimateSpriteDelay
	bne KeepDinoSprite
	
	lda DinoAnimateSpriteBitmap
	eor #1
	sta DinoAnimateSpriteBitmap
	lda #DinoAnimateSpriteFramesDelay
	sta DinoAnimateSpriteDelay	
	
KeepDinoSprite

	lda DinoAnimateSpriteBitmap
	bne DinoBitmap2	
	
  lda #<Dino0
  sta DinoBitmapLocation
  lda #>Dino0
  sta DinoBitmapLocation + 1
	jmp DinoBitmapChooseEnd
	
DinoBitmap2	
	
  lda #<Dino1
  sta DinoBitmapLocation
  lda #>Dino1
  sta DinoBitmapLocation + 1
	
DinoBitmapChooseEnd

	rts


HandleDinoJump

  lda DinoVerticalVelocity
	adc DinoVerticalPos
	sta DinoVerticalPos
	
	lda #65
	adc DinoVerticalDelay
	cmp #$ff
	bvc DontAdjustVerticalVelocity
	
	lda DinoVerticalVelocity
	adc #1
	sta DinoVerticalVelocity
	
DontAdjustVerticalVelocity

	sta DinoVerticalDelay

	; Check if Dino is touching the ground
	lda DinoVerticalPos
	cmp #GroundVerticalPos
	bcc DinoIsJumping

	lda #0
	sta DinoVerticalDelay

	lda #GroundVerticalPos
	sta DinoVerticalPos
	
	; Check if button is pressed (1 = not pressed)
	lda #%10000000
	and INPT4
	bne ButtonNotPressed

	; Reset Seed for pseudo-random value
	lda #0
	sta Seed

	; Check if button is locked
	lda #1
	and VarButtonLock
	bne ButtonIsLocked

	lda #1
	sta VarButtonLock

	lda #-5
	sta DinoVerticalVelocity
	
	jmp EndButtonCheck

ButtonIsLocked
ButtonNotPressed

	; Check if button is pressed
	lda #%10000000
	and INPT4
	beq ButtonStillPressed

	lda #0
	sta VarButtonLock

DinoIsJumping
ButtonStillPressed
EndButtonCheck

	rts
