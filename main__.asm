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
CactusSpeed = $8F         ; Guarda a velocidade atual do cacto
CactusSpeedFraction = $90 ; Acumulador de fração de pixel para o movimento
CactusPattern = $91       ; Padrão sorteado/desejado (NUSIZ1 é write-only)
CactusPatternActive = $92 ; Padrão atualmente aplicado ao NUSIZ1
CactusPatternDelay = $93  ; 1 = padrão acabou de nascer; espera 1 frame antes de ativar cópias


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
	sta CactusSpeedFraction  ; Garante que a fração começa zerada
	sta CactusPattern        ; Padrão desejado começa como 1 cópia
	sta CactusPatternActive  ; NUSIZ1 começa como 1 cópia
	sta CactusPatternDelay   ; Nenhuma espera pendente
	
	lda #$00                 ; Velocidade inicial (Em ponto fixo negativo. Perto de $FF = lento)
	sta CactusSpeed
	
	lda #140                 ; Posição X inicial do Cacto
	sta CactusHorizontalPos

	sta WSYNC
	lda #30                  ; Posição X fixa que você deseja para o Dino (ajuste se precisar)
	ldx #0                   ; Seleciona Player 0
	jsr SetHorizPos          ; Posiciona o Dino na marra antes do jogo começar

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

    ; -------------------------------------------------------------------------
	; MOVIMENTAÇÃO DO CACTO COM PONTO FIXO (CORRIGIDO COM ADC)
	; -------------------------------------------------------------------------
	clc
	lda CactusSpeedFraction
	adc CactusSpeed          ; Soma a velocidade negativa na fração
	sta CactusSpeedFraction  ; Salva o novo acumulador de fração
	
	lda CactusHorizontalPos
	adc #$FF                 ; Soma -1 se o Carry NÃO foi ativado (matemática correta do ADC negativo)
	sta CactusHorizontalPos
	
	; Verifica se o cacto chegou na borda esquerda da tela (0 ou passou de 0)
	cmp #0
	bne DontChangeCactusPattern  ; Não chegou no fim do trajeto: nada de padrão a decidir agora

	; -------------------------------------------------------------------------
	; CHEGOU AO FIM DO TRAJETO (WRAP EM 0) - este bloco só roda nesse instante,
	; nunca em outro momento do frame, evitando reprocessar o mesmo evento.
	; -------------------------------------------------------------------------

	; ACELERAÇÃO PROGRESSIVA (Aumenta a velocidade real a cada reset)
	lda CactusSpeed
	cmp #$00                 ; Limite máximo de velocidade para não ficar impossível ($80 = muito rápido)
	bcc MaxSpeedReached      ; Se já for menor/mais negativo que $80, não acelera mais
	
	sec
	sbc #$04                 ; Subtrai 4 para tornar o número MAIS negativo (ou seja, mais rápido para a esquerda)
	sta CactusSpeed
MaxSpeedReached

	; -------------------------------------------------------------------------
	; VERIFICA O PADRÃO ATUALMENTE ATIVO (NUSIZ1) E TRATA A REMOÇÃO
	; DE UMA CÓPIA, SE PRECISO.
	;
	; CactusPattern       = padrão sorteado/desejado para o próximo grupo
	; CactusPatternActive = padrão que está efetivamente no NUSIZ1
	;
	; O padrão novo NÃO é aplicado aqui. No nascimento o NUSIZ1 fica em $00
	; por pelo menos um frame; a rotina UpdateCactusPattern, executada a cada
	; frame, só ativa as cópias quando a posição X já for segura.
	; -------------------------------------------------------------------------
	lda CactusPatternActive
	and #$07                    ; Isola os bits 0-2 do NUSIZ1 atualmente ativo

	cmp #$02
	beq RemoveCopyMedium2       ; 2 cópias/média distância -> vira 1 cópia
	cmp #$04
	beq RemoveCopyWide2         ; 2 cópias/longa distância -> vira 1 cópia
	cmp #$06
	beq RemoveCopyMedium3       ; 3 cópias/média distância -> vira 2 cópias/média distância

	; Já está em cópia única: sorteia um padrão novo.
	jmp SorteiaNovamente

	; -------------------------------------------------------------------------
	; REMOÇÃO DE UMA CÓPIA DO PADRÃO MÚLTIPLO
	; Em vez de sortear um padrão novo (e em vez de resetar para 140!), "consome"
	; uma cópia do padrão atual: ajusta o NUSIZ1 e as sombras para o padrão
	; com uma cópia a menos e posiciona o Cacto a partir do wrap real (posição 0).
	; -------------------------------------------------------------------------
RemoveCopyMedium2
	lda #$00                    ; Sobra 1 cópia
	sta CactusPattern
	sta CactusPatternActive
	sta NUSIZ1
	lda #31                     ; Distância entre cópias (32 clocks) - 1, a partir de 0
	jmp ApplyCactusShift

RemoveCopyWide2
	lda #$00                    ; Sobra 1 cópia
	sta CactusPattern
	sta CactusPatternActive
	sta NUSIZ1
	lda #63                     ; Distância entre cópias (64 clocks) - 1, a partir de 0
	jmp ApplyCactusShift

RemoveCopyMedium3
	lda #$02                    ; Sobram 2 cópias, ainda em distância média
	sta CactusPattern
	sta CactusPatternActive
	sta NUSIZ1
	lda #31                     ; Distância entre cópias (32 clocks) - 1, a partir de 0
	; segue direto para ApplyCactusShift

ApplyCactusShift
	sta CactusHorizontalPos     ; A posição real do wrap é 0, então o novo valor É o próprio deslocamento
	jmp DontChangeCactusPattern

	; -------------------------------------------------------------------------
	; SORTEIO DO PADRÃO DO CACTO (Garante 1 de 7 opções seguras)
	; -------------------------------------------------------------------------
SorteiaNovamente
	inc Seed                 ; Avança a seed para garantir variação
	lda Seed                 ; Pega o valor atual da semente aleatória
	and #$07                 ; Limita o valor de 0 a 7 (máximo de 8 combinações)
	cmp #7                   ; Verifica se o número sorteado é menor que 7 (0 a 6 = válidos)
	beq SorteiaNovamente     ; Se for 7 (fora da tabela), refaz o sorteio rapidamente
	
	tax                      ; Transfere o índice válido (0 a 6) para X
	lda CactusPatternTable,X ; Busca a configuração na tabela
	sta CactusPattern         ; Guarda o padrão sorteado/desejado

	; -------------------------------------------------------------------------
	; NASCIMENTO SEM CÓPIAS:
	; O padrão sorteado é salvo, mas NÃO é aplicado ao NUSIZ1 ainda.
	; O primeiro frame visível do novo cacto sempre terá uma única cópia.
	; CactusPatternDelay impede que UpdateCactusPattern ative as cópias
	; ainda neste mesmo frame.
	; -------------------------------------------------------------------------
	lda #$00
	sta CactusPatternActive
	sta NUSIZ1
	lda #$01
	sta CactusPatternDelay

	; -------------------------------------------------------------------------
	; POSICIONAMENTO DE NASCIMENTO: recua a base o suficiente para que a cópia
	; MAIS À DIREITA do grupo, quando o NUSIZ1 for ativado, fique em X=140.
	; -------------------------------------------------------------------------
	lda #140
	sec
	sbc CactusSpawnOffsetTable,X ; Recuo necessário para esse padrão (0/32/64)
	sta CactusHorizontalPos

DontChangeCactusPattern

        ; -------------------------------------------------------------------------
        ; VERIFICA SE O PADRÃO PENDENTE JÁ PODE SER ATIVADO.
        ; Esta rotina roda a cada frame antes do posicionamento de P1.
        ; -------------------------------------------------------------------------
        jsr UpdateCactusPattern

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
; SUBROTINA: Atualiza o padrão do cacto com ativação atrasada e posição segura
; ============================================================================
; CactusPattern       = padrão sorteado/desejado
; CactusPatternActive = padrão atualmente aplicado ao NUSIZ1
; CactusPatternDelay  = garante que o primeiro frame do nascimento tenha 1 cópia
;
; A coordenada CactusHorizontalPos é a posição da cópia/base que será
; posicionada por RESP1. Para os padrões com cópias à direita, o NUSIZ1 só
; pode ser ativado quando essa base estiver suficientemente à esquerda para
; que a última cópia permaneça dentro da faixa segura.
;
; Limites usados:
;   $00/$05/$07 -> X <= 140
;   $02         -> X <= 108  (140 - 32)
;   $04/$06     -> X <= 76   (140 - 64)
;
; Como o spawn já é calculado exatamente nesses limites e o cacto se move
; para a esquerda, o primeiro frame após o nascimento já estaria em posição
; segura. O delay, porém, força pelo menos um frame com uma única cópia.
; ============================================================================
UpdateCactusPattern

	; O padrão acabou de nascer: consome a espera e NÃO ativa as cópias.
	lda CactusPatternDelay
	beq CheckCactusPatternSafe
	lda #$00
	sta CactusPatternDelay
	rts

CheckCactusPatternSafe
	; Se o padrão sorteado já é o padrão ativo, não há nada a fazer.
	lda CactusPattern
	cmp CactusPatternActive
	beq UpdateCactusPatternDone

	; Usa o próprio valor do NUSIZ1 como índice para a tabela de X seguro.
	; Os valores 1 e 3 não são usados pelos padrões do jogo.
	tax
	lda CactusActivationMaxXTable,X
	sta Helper

	; Testa se CactusHorizontalPos <= limite seguro.
	lda CactusHorizontalPos
	cmp Helper
	beq ActivateCactusPattern
	bcc ActivateCactusPattern

	; Ainda está muito à direita: mantém uma única cópia.
	lda #$00
	sta CactusPatternActive
	sta NUSIZ1
	rts

ActivateCactusPattern
	lda CactusPattern
	sta CactusPatternActive
	sta NUSIZ1

UpdateCactusPatternDone
	rts

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

; ============================================================================
; TABELA DE PADRÕES PERMITIDOS PARA O CACTO (Sem cópias próximas / Com cactos grandes)
; ============================================================================
CactusPatternTable
	.byte $00    ; Opção 0: 1 Cacto normal
	.byte $02    ; Opção 1: 2 Cactos distância média (32 clocks)
	.byte $02    ; Opção 2: 2 Cactos distância média (32 clocks)
	.byte $05    ; Opção 3: 1 Cacto Grande (Tamanho 2x)
	.byte $07    ; Opção 4: 1 Cacto Gigante (Tamanho 4x)
	.byte $04    ; Opção 5: 2 Cactos distância longa (64 clocks)
	.byte $06    ; Opção 6: 3 Cactos distância média (32 clocks)

; ============================================================================
; TABELA DE X MÁXIMO PARA ATIVAÇÃO DO NUSIZ1
; Índice = valor dos bits 0-2 do NUSIZ1.
; A ativação só ocorre quando CactusHorizontalPos <= este valor.
; ============================================================================
CactusActivationMaxXTable
	.byte 140     ; $00: 1 cópia normal
	.byte 140     ; $01: não usado
	.byte 108     ; $02: 2 cópias, distância média (140 - 32)
	.byte 140     ; $03: não usado
	.byte 76      ; $04: 2 cópias, distância longa (140 - 64)
	.byte 140     ; $05: 1 cópia, tamanho 2x
	.byte 76      ; $06: 3 cópias, distância média (140 - 64)
	.byte 140     ; $07: 1 cópia, tamanho 4x

; ============================================================================
; TABELA DE RECUO DE NASCIMENTO (mesma ordem/índice da CactusPatternTable)
; Quanto recuar a posição base de spawn (que seria 140) para que a cópia MAIS
; À DIREITA do grupo ainda caia em X=140. Isso evita que a(s) cópia(s) extra(s)
; do NUSIZ1 estourem a faixa segura do contador do TIA e deem "wrap" para o
; meio da tela - só a cópia base é reposicionada via RESP; as demais cópias
; são geradas pelo próprio hardware a partir dela, então quem precisa ficar
; dentro da faixa seguro é a base, calculada de trás para frente aqui.
; ============================================================================
CactusSpawnOffsetTable
	.byte 0      ; Opção 0: 1 Cacto normal          -> recuo 0
	.byte 32     ; Opção 1: 2 Cactos distância média -> recuo 32
	.byte 32     ; Opção 2: 2 Cactos distância média -> recuo 32
	.byte 0      ; Opção 3: 1 Cacto Grande           -> recuo 0
	.byte 0      ; Opção 4: 1 Cacto Gigante          -> recuo 0
	.byte 64     ; Opção 5: 2 Cactos distância longa -> recuo 64
	.byte 64     ; Opção 6: 3 Cactos distância média (span de 2x32=64) -> recuo 64



	include "dino.asm"
	include "data/bitmaps.asm"
	
	org $FFFC
	.word Start
	.word Start