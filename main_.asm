; ****************************************************************************
; Jogo do Dino - Atari 2600 (Posição X do Dino Fixa)
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
CactusActivePattern = $8F       ; Cópia do padrão atual (NUSIZ1 é write-only, não dá pra ler de volta)
CactusDesiredPattern = $90      ; Padrão que foi sorteado (nem sempre é o que está sendo enviado ao TIA)

; Constants
GroundVerticalPos = 65
DinoAnimateSpriteFramesDelay = 8

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

	lda #GroundVerticalPos
	sta DinoVerticalPos
	
	lda #DinoAnimateSpriteFramesDelay
	sta DinoAnimateSpriteDelay

	lda #0
	sta DinoVerticalVelocity
	sta HMP0

        lda #6
        sta CactusDesiredPattern        ; Sombra do NUSIZ1, que o CLEAN_START já zerou
	
	lda #$97                 ; Posição X inicial do Cacto (151)
	sta CactusHorizontalPos

	sta WSYNC
	lda #30                  ; Posição X fixa que você deseja para o Dino (ajuste se precisar)
	ldx #0                   ; Seleciona Player 0
	jsr SetHorizPos          ; Posiciona o Dino na marra antes do jogo começar

        lda #01                 ; Permite trocar o padrão
        sta Helper

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
	
	jsr AnimateDinoSprite
	jsr HandleDinoJump

        ;jmp Not2CopiesClose

        ; MOVIMENTO DO CACTUS
        dec CactusHorizontalPos
        ; Chegou no canto esquerdo?
        bne DontResetCactusHorizontalPos

        lda #$97                       ; 119
        sta CactusHorizontalPos

        ;O padrão ativo são 2 cópias média distÂncia?
        lda CactusActivePattern
        cmp #02                 ; 
        bne Not2CopiesMediumLeaving

        ; Muda para 1 cópia apenas 
        lda #0
        sta CactusActivePattern

        ; Move o cacto para a esquerda a distancia media (32 clocks)
        lda #32
        sta CactusHorizontalPos
        jmp DontResetCactusHorizontalPos

Not2CopiesMediumLeaving

        ;O padrão ativo são 3 cópias média distÂncia?
        lda CactusActivePattern
        cmp #06                 ; 
        bne Not3CopiesMediumLeaving

        ; Muda para 2 cópias apenas 
        lda #02
        sta CactusActivePattern
        sta CactusDesiredPattern

        ; Move o cacto para a esquerda a distancia media (32 clocks)
        lda #32
        sta CactusHorizontalPos
        jmp DontResetCactusHorizontalPos        

Not3CopiesMediumLeaving

        ;O padrão ativo são 2 cópias distância longa (64 clocks)?
        lda CactusActivePattern
        cmp #04
        bne Not2CopiesLongLeaving

        ; Muda para 1 cópia apenas
        lda #0
        sta CactusActivePattern

        ; Move o cacto para a esquerda a distância longa (64 clocks)
        lda #64
        sta CactusHorizontalPos
        jmp DontResetCactusHorizontalPos

Not2CopiesLongLeaving

        ;O padrão ativo é o Cacto Grande (tamanho dobrado, cópia única)?
        lda CactusActivePattern
        cmp #05
        bne Not1BigCactusLeaving

        ; Volta para o cacto normal (1 cópia, tamanho padrão)
        lda #0
        sta CactusActivePattern

Not1BigCactusLeaving

        jsr SelectCactusDesiredPattern

        ; Se o padrão sorteado for o Cacto Grande (cópia única, tamanho dobrado),
        ; ativa imediatamente: não há cópias extras para esperar entrar em tela
        lda CactusDesiredPattern
        cmp #05
        bne NotBigCactusImmediate
        sta CactusActivePattern
NotBigCactusImmediate

DontResetCactusHorizontalPos

        ; O padrão desejado do cacto é 2 cópias, média distância?
        lda CactusDesiredPattern
        cmp #02                 ; é duas cópias, média distância?
        bne Not2CopiesMedium

        ; Sim? verifica se a posição horizontal do cacto já permite exibir a segunda cópia
        lda CactusHorizontalPos
        cmp #$77                        ; 119
        bne Not2CopiesMedium

        ; Sim, duplica o Player1
        lda CactusDesiredPattern
        sta CactusActivePattern

Not2CopiesMedium

        ; O padrão desejado do cacto é 2 cópias, distância longa (64 clocks)?
        lda CactusDesiredPattern
        cmp #04
        bne Not2CopiesLong

        ; Sim? verifica se a posição horizontal do cacto já permite exibir a segunda cópia
        ; (aqui a distância é o dobro da média, por isso o limiar é $57/87 em vez de $77/119)
        lda CactusHorizontalPos
        cmp #$57                        ; 87
        bne Not2CopiesLong

        ; Sim, duplica o Player1
        lda CactusDesiredPattern
        sta CactusActivePattern

Not2CopiesLong

        ; O Padrão desejado do cacto são 3 cópias, média distância?
        lda CactusDesiredPattern
        cmp #06                 
        bne Not3CopiesMedium

        ; O Padrão desejado do cacto são 3 cópias, média distância,
        ; O padrão ativo do cacto é 1 cópia?
        lda CactusActivePattern
        bne Not1Copy

        ; O Padrão desejado do cacto são 3 cópias, média distância, 
        ; O padrão ativo do cacto é uma cópia, 
        ; a posição horizontal já permite exibir a segunda cópia?
        lda CactusHorizontalPos
        cmp #$77                        ; 119
        bne NotReadyForSecondCopyIn3CopiesMedium

        ; Sim, duplica o Player1
        lda #02
        sta CactusActivePattern

Not1Copy 
        
        ; O padrão desejado são 3 cópias médias
        ; O padrão ativo do cacto são duas cópias?
        lda CactusActivePattern
        cmp #02
        bne Not2CopiesMediumIn3CopiesMedium

        ; O Padrão desejado do cacto são 3 cópias, média distância, 
        ; O padrão ativo do cacto são duas cópias, 
        ; a posição horizontal já permite exibir a terceira cópia?
        lda CactusHorizontalPos
        cmp #$57                        ; 151
        bne NotReadyForThirdCopyIn3CopiesMedium

        ; Sim, triplica o player1
        lda #06
        sta CactusActivePattern

Not2CopiesMediumIn3CopiesMedium
NotReadyForSecondCopyIn3CopiesMedium
NotReadyForThirdCopyIn3CopiesMedium
Not3CopiesMedium
        
        lda CactusActivePattern
        sta NUSIZ1

        ; -------------------------------------------------------------------------
	; EXECUÇÃO DO POSICIONAMENTO HORIZONTAL APENAS DO CACTO (P1)
	; -------------------------------------------------------------------------
	lda #0
	sta HMP0                 ; <--- EXTREMAMENTE IMPORTANTE: Zera o movimento do Dino 
	                         ;      para ele NÃO sair correndo junto com o cacto!

	lda CactusHorizontalPos  ; Carrega a coordenada X variável do Cacto
	ldx #1                   ; Informa que queremos posicionar o Player 1
	jsr SetHorizPos          ; Executa a rotina dinâmica para o cacto

	sta WSYNC
	sta HMOVE                ; Aplica o ajuste fino na tela com segurança!

; Espera o resto do tempo do VBLANK acabar com segurança
WaitForVblankEnd
	lda INTIM
	bne WaitForVblankEnd
	lda #0
	sta WSYNC
	sta VBLANK

	; -------------------------------------------------------------------------
	; KERNEL (Desenho da Tela Visível)
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
; SUBROTINA: Posicionamento Horizontal Clássico e Definitivo (Sem Tabela)
; ============================================================================
SetHorizPos
	sta WSYNC                ; Sincroniza no início de uma nova linha horizontal
	sec                      ; Garante carry setado para a subtração
SetHorizPosLoop
	sbc #15                  ; Subtrai 15 da coordenada X
	bcs SetHorizPosLoop      ; Repete o ajuste grosso até ficar negativo
	
	eor #7                   ; Converte matematicamente o resto bruto no ajuste fino
	asl                      ; Desloca o bit 1 vez para a esquerda...
	asl                      ; 2 vezes...
	asl                      ; 3 vezes...
	asl                      ; 4 vezes (coloca o valor no nibble alto exigido pelo TIA)
	
	sta HMP0,X               ; Define o ajuste fino no player correto
	sta RESP0,X              ; Ativa o Reset Coarse/Bruto
	rts


SelectCactusDesiredPattern
    inc Seed                 ; Avança a seed
    lda Seed                 ; Pega o novo valor da seed
    and #$07                 ; Mantém apenas os 3 bits menos significativos (0-7)
    tax                      ; Índice de 0 a 7
    lda CactusPatternTable,X ; Busca a configuração na tabela
    sta CactusDesiredPattern ; Guarda o padrão sorteado/desejado
    rts


; ============================================================================
; TABELA DE PADRÕES PERMITIDOS PARA O CACTO (Sem cópias próximas / Com cactos grandes)
; ============================================================================
CactusPatternTable
	.byte $00    ; Opção 0: 1 Cacto normal
	.byte $02    ; Opção 1: 2 Cactos distância média (32 clocks)
	.byte $05    ; Opção 3: 1 Cacto Grande (Tamanho 2x)
	.byte $04    ; Opção 5: 2 Cactos distância longa (64 clocks)
	.byte $06    ; Opção 6: 3 Cactos distância média (32 clocks)
	.byte $06    ; Opção 6: 3 Cactos distância média (32 clocks)
	.byte $00    ; Opção 0 (repetida - tabela ampliada para 8 entradas por causa do "and #$07")
	.byte $02    ; Opção 1 (repetida - tabela ampliada para 8 entradas por causa do "and #$07")

	include "dino.asm"
	include "data/bitmaps.asm"


	org $FFFC
	.word Start
	.word Start