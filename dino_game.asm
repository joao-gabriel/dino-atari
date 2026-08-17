; ****************************************************************************
; Jogo do Dino - Atari 2600
; Aceleração gradual do Cacto
; ****************************************************************************

	processor 6502
	include "includes/vcs.h"
	include "includes/macro.h"

	org $F000

; Variables	
DinoVerticalVelocity = $80
DinoVerticalPos = $81
DinoVerticalDelay = $82
DinoBitmapBuffer = $83
DinoLineBeingDraw = $84
DinoBitmapLocation = $85 ; ocupa 2 bytes
VarButtonLock = $87
DinoAnimateSpriteBitmap = $88
DinoAnimateSpriteDelay = $89
CactusBitmapBuffer = $8A
CactusLineBeingDraw = $8B
Seed = $8C 
Helper = $8D                    
CactusHorizontalPos = $8E
CactusActivePattern = $8F
CactusDesiredPattern = $90
PrevResetSwitch = $91

; -------------------------------------------------------------------------
; VELOCIDADE DO CACTO
;
; CactusSpeed é armazenado em QUARTOS de pixel por frame:
;
;   4  = 1,00 pixel/frame
;   5  = 1,25 pixel/frame
;   6  = 1,50 pixel/frame
;   7  = 1,75 pixel/frame
;   8  = 2,00 pixel/frame
;   ...
;   16 = 4,00 pixels/frame
;
; CactusMoveAccumulator acumula a parte fracionária.
; CactusFrameMovement guarda quantos pixels serão percorridos
; naquele frame específico.
; -------------------------------------------------------------------------

CactusSpeed = $92
SpeedTimer = $93
CactusMoveAccumulator = $94
CactusFrameMovement = $95
CollisionState = $96
CollisionTimer = $97
SoundCounter = $98

; Constants
GroundVerticalPos = 65
DinoAnimateSpriteFramesDelay = 8
GameStartedFlag = %00000010     ; Bit 1 do Helper:
                                ; 0 = jogo parado
                                ; 1 = jogo rodando

MaxCactusSpeed = 64             ; 24 quartos = 4,00 pixels/frame

SpeedUpInterval = 255           ; A cada 255 frames (4 segundos)
                                ; aumenta 0,25 pixel/frame

FramesToSkipMovement = 16

CollisionSoundFrames = 30


Start
	CLEAN_START
	
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
        sta CollisionState
        sta CollisionTimer
        sta SoundCounter

        sta CXCLR

        sta AUDC0
        sta AUDF0
        sta AUDV0
        sta AUDC1
        sta AUDF1
        sta AUDV1

	lda #GroundVerticalPos
	sta DinoVerticalPos
	
	lda #DinoAnimateSpriteFramesDelay
	sta DinoAnimateSpriteDelay

	lda #0
	sta DinoVerticalVelocity
	sta HMP0

        lda #6
        sta CactusDesiredPattern

        ; ---------------------------------------------------------------------
        ; VELOCIDADE INICIAL
        ;
        ; 4 = 1,00 pixel/frame
        ; ---------------------------------------------------------------------

        lda #FramesToSkipMovement
        sta CactusSpeed

        lda #0
        sta SpeedTimer

        sta CactusMoveAccumulator
        sta CactusFrameMovement
	
	lda #$97
	sta CactusHorizontalPos

	sta WSYNC
	lda #30
	ldx #0
	jsr SetHorizPos

        lda #01
        sta Helper

        jsr AnimateDinoSprite

        lda SWCHB
        and #%00000001
        sta PrevResetSwitch


FrameLoop

	VERTICAL_SYNC
	
	; -------------------------------------------------------------------------
	; INÍCIO DO VBLANK
	; -------------------------------------------------------------------------
	lda #43
	sta TIM64T
	
	lda #$00
	sta PF0
	sta PF1
	sta PF2
	
	inc Seed

        ; -------------------------------------------------------------------------
        ; BOTÃO RESET DO CONSOLE
        ; -------------------------------------------------------------------------
        lda SWCHB
        and #%00000001
        cmp PrevResetSwitch
        beq ResetSwitchNoChange

        sta PrevResetSwitch

        cmp #1
        beq ResetButtonReleased

        ; Foi pressionado: reinicia tudo
        jmp Start


ResetButtonReleased

        lda Helper
        ora #GameStartedFlag
        sta Helper


ResetSwitchNoChange

        ; -------------------------------------------------------------------------
        ; Enquanto o jogo não tiver sido iniciado,
        ; nada se move.
        ; -------------------------------------------------------------------------
        lda Helper
        and #GameStartedFlag
        bne GameIsRunning

        jmp SkipGameplayLogic


GameIsRunning

        ; -----------------------------------------------------------------
        ; Se estamos no estado de colisão, apenas atualiza o som.
        ; Nenhum movimento do jogo é executado.
        ; -----------------------------------------------------------------

        lda CollisionState
        beq NormalGameplay

        jsr UpdateCollisionSound
        jmp SkipGameplayLogic


NormalGameplay

        ; -----------------------------------------------------------------
        ; Verifica colisão P0-P1
        ;
        ; CXPPMM bit 7 = P0-P1
        ; -----------------------------------------------------------------

        lda CXPPMM
        and #%10000000
        beq NoCollision

        jsr HandleCollision

        jmp SkipGameplayLogic


NoCollision

        jsr AnimateDinoSprite
        jsr HandleDinoJump


        ; -------------------------------------------------------------------------
        ; ACELERAÇÃO GRADUAL
        ;
        ; A cada 180 frames aumenta apenas 0,25 pixel/frame.
        ;
        ; 4  = 1,00 px/frame
        ; 5  = 1,25 px/frame
        ; 6  = 1,50 px/frame
        ; ...
        ; 16 = 4,00 px/frame
        ; -------------------------------------------------------------------------

        inc SpeedTimer

        lda SpeedTimer
        cmp #SpeedUpInterval
        bne SpeedNotYet

        lda #0
        sta SpeedTimer

        lda CactusSpeed
        cmp #MaxCactusSpeed
        beq SpeedNotYet

        inc CactusSpeed


SpeedNotYet

        ; ---------------------------------------------------------------------
        ; MOVIMENTO GRADUAL DO CACTO
        ;
        ; CactusSpeed está em quartos de pixel.
        ;
        ; A cada frame:
        ;
        ;     acumulador += velocidade
        ;
        ; Cada 4 unidades acumuladas = 1 pixel.
        ;
        ; Exemplos:
        ;
        ; 4  (1,00 px/frame)
        ;   -> 1,1,1,1,1,1...
        ;
        ; 5  (1,25 px/frame)
        ;   -> 1,1,1,2,1,1,1,2...
        ;
        ; 6  (1,50 px/frame)
        ;   -> 1,2,1,2,1,2...
        ;
        ; 7  (1,75 px/frame)
        ;   -> 1,2,2,1,2,2,1...
        ;
        ; 8  (2,00 px/frame)
        ;   -> 2,2,2,2...
        ; ---------------------------------------------------------------------

        lda CactusMoveAccumulator
        clc
        adc CactusSpeed
        sta CactusMoveAccumulator

        ; ---------------------------------------------------------------------
        ; Descobre quantos pixels devem ser percorridos neste frame.
        ;
        ; Cada grupo de 4 no acumulador representa 1 pixel.
        ; ---------------------------------------------------------------------

        lda #0
        sta CactusFrameMovement


CactusMoveLoop

        lda CactusMoveAccumulator
        cmp #FramesToSkipMovement
        bcc CactusMoveDone

        sec
        sbc #FramesToSkipMovement
        sta CactusMoveAccumulator

        inc CactusFrameMovement

        jmp CactusMoveLoop


CactusMoveDone

        ; ---------------------------------------------------------------------
        ; Move o cacto a quantidade calculada neste frame.
        ; ---------------------------------------------------------------------

        lda CactusHorizontalPos
        sec
        sbc CactusFrameMovement
        bcs CactusPosOk

        lda #0


CactusPosOk

        sta CactusHorizontalPos


        ; -------------------------------------------------------------------------
        ; CHEGOU NO CANTO ESQUERDO?
        ; -------------------------------------------------------------------------

        bne DontResetCactusHorizontalPos

        lda #$97
        sta CactusHorizontalPos


        ; -------------------------------------------------------------------------
        ; O padrão ativo são 2 cópias média distância?
        ; -------------------------------------------------------------------------

        lda CactusActivePattern
        cmp #02
        bne Not2CopiesMediumLeaving

        lda #0
        sta CactusActivePattern
        sta CactusDesiredPattern

        lda #32
        sta CactusHorizontalPos

        jmp DontResetCactusHorizontalPos


Not2CopiesMediumLeaving

        ; -------------------------------------------------------------------------
        ; O padrão ativo são 3 cópias média distância?
        ; -------------------------------------------------------------------------

        lda CactusActivePattern
        cmp #06
        bne Not3CopiesMediumLeaving

        lda #02
        sta CactusActivePattern
        sta CactusDesiredPattern

        lda #32
        sta CactusHorizontalPos

        jmp DontResetCactusHorizontalPos


Not3CopiesMediumLeaving

        ; -------------------------------------------------------------------------
        ; O padrão ativo são 2 cópias distância longa?
        ; -------------------------------------------------------------------------

        lda CactusActivePattern
        cmp #04
        bne Not2CopiesLongLeaving

        lda #0
        sta CactusActivePattern
        sta CactusDesiredPattern

        lda #64
        sta CactusHorizontalPos

        jmp DontResetCactusHorizontalPos


Not2CopiesLongLeaving

        ; -------------------------------------------------------------------------
        ; O padrão ativo é o Cacto Grande?
        ; -------------------------------------------------------------------------

        lda CactusActivePattern
        cmp #05
        bne Not1BigCactusLeaving

        lda #0
        sta CactusActivePattern


Not1BigCactusLeaving

        jsr SelectCactusDesiredPattern

        ; ---------------------------------------------------------------------
        ; Se o padrão sorteado for o Cacto Grande,
        ; ativa imediatamente.
        ; ---------------------------------------------------------------------

        lda CactusDesiredPattern
        cmp #05
        bne NotBigCactusImmediate

        sta CactusActivePattern


NotBigCactusImmediate


DontResetCactusHorizontalPos

        ; -------------------------------------------------------------------------
        ; O padrão desejado do cacto é 2 cópias, média distância?
        ; -------------------------------------------------------------------------

        lda CactusDesiredPattern
        cmp #02
        bne Not2CopiesMedium

        lda CactusHorizontalPos
        cmp #$78
        bcs Not2CopiesMedium

        lda CactusDesiredPattern
        sta CactusActivePattern


Not2CopiesMedium

        ; -------------------------------------------------------------------------
        ; O padrão desejado do cacto é 2 cópias, distância longa?
        ; -------------------------------------------------------------------------

        lda CactusDesiredPattern
        cmp #04
        bne Not2CopiesLong

        lda CactusHorizontalPos
        cmp #$58
        bcs Not2CopiesLong

        lda CactusDesiredPattern
        sta CactusActivePattern


Not2CopiesLong

        ; -------------------------------------------------------------------------
        ; O padrão desejado são 3 cópias média distância?
        ; -------------------------------------------------------------------------

        lda CactusDesiredPattern
        cmp #06
        bne Not3CopiesMedium

        lda CactusActivePattern
        bne Not1Copy

        lda CactusHorizontalPos
        cmp #$78
        bcs NotReadyForSecondCopyIn3CopiesMedium

        lda #02
        sta CactusActivePattern


Not1Copy 
        
        ; ---------------------------------------------------------------------
        ; O padrão desejado são 3 cópias médias
        ; O padrão ativo são duas cópias?
        ; ---------------------------------------------------------------------

        lda CactusActivePattern
        cmp #02
        bne Not2CopiesMediumIn3CopiesMedium

        lda CactusHorizontalPos
        cmp #$58
        bcs NotReadyForThirdCopyIn3CopiesMedium

        lda #06
        sta CactusActivePattern


Not2CopiesMediumIn3CopiesMedium
NotReadyForSecondCopyIn3CopiesMedium
NotReadyForThirdCopyIn3CopiesMedium
Not3CopiesMedium


SkipGameplayLogic

        ; -------------------------------------------------------------------------
        ; NUSIZ1
        ; -------------------------------------------------------------------------

        lda CactusActivePattern
        sta NUSIZ1


        ; -------------------------------------------------------------------------
        ; POSICIONAMENTO HORIZONTAL DO CACTO
        ; -------------------------------------------------------------------------

	lda #0
	sta HMP0

	lda CactusHorizontalPos
	ldx #1
	jsr SetHorizPos

        sta WSYNC
	sta HMOVE


        ; -------------------------------------------------------------------------
        ; ESPERA O RESTANTE DO VBLANK
        ; -------------------------------------------------------------------------

WaitForVblankEnd

	lda INTIM
	bne WaitForVblankEnd

	lda #0
	sta WSYNC
	sta VBLANK


	; -------------------------------------------------------------------------
	; KERNEL
	; -------------------------------------------------------------------------

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


	; -------------------------------------------------------------------------
	; OVERSCAN
	; -------------------------------------------------------------------------

	lda #2
	sta WSYNC
	sta VBLANK

	ldx #30


OverScanWait

	sta WSYNC
	dex

	bne OverScanWait
	
	jmp FrameLoop


; ============================================================================
; COLISÃO DINO x CACTO
; ============================================================================

HandleCollision

        ; Já está no estado de colisão?
        lda CollisionState
        bne CollisionAlreadyActive

        lda #1
        sta CollisionState

        lda #CollisionSoundFrames
        sta CollisionTimer

        ; Inicializa o som
        lda #%0010
        sta AUDC0

        lda #20
        sta AUDF0

        lda #15
        sta AUDV0

        ; Para o movimento do cacto
        lda #0
        sta CactusFrameMovement
        sta CactusMoveAccumulator

        rts


CollisionAlreadyActive

        rts


UpdateCollisionSound

        lda CollisionTimer
        beq CollisionSoundFinished

        ; -------------------------------------------------------------
        ; Frequência variável
        ; -------------------------------------------------------------

        lda CollisionTimer
        and #%00000111
        clc
        adc #16
        sta AUDF0

        ; -------------------------------------------------------------
        ; Volume
        ; -------------------------------------------------------------

        lda CollisionTimer
        cmp #20
        bcs SoundVolumeHigh

        lda #8
        sta AUDV0
        jmp SoundVolumeDone


SoundVolumeHigh

        lda #15
        sta AUDV0


SoundVolumeDone

        dec CollisionTimer

        rts


CollisionSoundFinished

        ; -------------------------------------------------------------
        ; DESLIGA O SOM
        ; -------------------------------------------------------------

        lda #0
        sta AUDV0
        sta AUDC0

        ; -------------------------------------------------------------
        ; LIMPA O LATCH DE COLISÃO
        ; -------------------------------------------------------------

        lda CXCLR

        ; -------------------------------------------------------------
        ; VOLTA AO ESTADO INICIAL
        ; -------------------------------------------------------------

        lda #0
        sta CollisionState
        sta CollisionTimer
        sta CactusMoveAccumulator
        sta CactusFrameMovement

        ; Velocidade inicial
        lda #8
        sta CactusSpeed

        lda #0
        sta SpeedTimer

        ; Posição inicial do cacto
        lda #$97
        sta CactusHorizontalPos

        ; Padrão inicial
        lda #6
        sta CactusDesiredPattern

        lda #0
        sta CactusActivePattern

        ; -------------------------------------------------------------
        ; IMPORTANTE:
        ; remove o estado "jogo rodando".
        ; O jogo volta para a tela inicial.
        ; -------------------------------------------------------------

        lda Helper
        and #%11111101
        sta Helper

        ; Limpa novamente o latch depois de reposicionar o jogo
        lda CXCLR

        rts        

; ============================================================================
; SUBROTINA: Posicionamento Horizontal
; ============================================================================

SetHorizPos

	sta WSYNC

	sec

SetHorizPosLoop

	sbc #15
	bcs SetHorizPosLoop
	
	eor #7

	asl
	asl
	asl
	asl
	
	sta HMP0,X
	sta RESP0,X

	rts


; ============================================================================
; SELEÇÃO DO PADRÃO DO CACTO
; ============================================================================

SelectCactusDesiredPattern

    inc Seed

    lda Seed
    and #$07

    tax

    lda CactusPatternTable,X

    sta CactusDesiredPattern

    rts


; ============================================================================
; TABELA DE PADRÕES PERMITIDOS PARA O CACTO
; ============================================================================

CactusPatternTable

	.byte $00    ; Opção 0: 1 Cacto normal
	.byte $02    ; Opção 1: 2 Cactos distância média
	.byte $05    ; Opção 3: 1 Cacto Grande
	.byte $04    ; Opção 5: 2 Cactos distância longa
	.byte $06    ; Opção 6: 3 Cactos distância média
	.byte $06    ; Opção 6: 3 Cactos distância média
	.byte $00    ; Opção 0 repetida
	.byte $02    ; Opção 1 repetida


	include "dino.asm"
	include "data/bitmaps.asm"


	org $FFFC

	.word Start
	.word Start