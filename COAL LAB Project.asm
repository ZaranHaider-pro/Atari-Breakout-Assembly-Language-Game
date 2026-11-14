[org 0x0100]

jmp start

; Data
score: dw 0
lives: db 3
ballX: dw 40
ballY: dw 12
ballDirX: db 1
ballDirY: db 1
paddleX: db 32
paddleWidth: db 12
gameActive: db 0
bricksRemaining: dw 40
gameSpeed: db 5

; Brick Array - 4 rows x 10 columns = 40 bricks
bricks: times 40 db 1

; Brick colors and points for each row
brickColors: db 0x4E, 0x6E, 0x2E, 0x5E
brickPoints: dw 50, 40, 30, 20

; Messages
welcomeMsg: db ' ATARI BREAKOUT GAME ', 0
rulesTitle: db 'RULES:', 0
rule1: db 'LEFT/RIGHT arrows = Move paddle', 0
rule2: db 'Break all bricks to win!', 0
rule3: db 'You have 3 lives', 0
rule4: db 'Red=50 | Yellow=40 | Green=30 | Pink=20', 0
rule5: db 'Dont let ball fall!', 0
startMsg: db 'Press ENTER to Start', 0
exitMsg: db 'Press ESC to Exit', 0
scoreLabel: db 'SCORE: ', 0
livesLabel: db 'LIVES: ', 0
gameOverMsg: db '*** GAME OVER ***', 0
winMsg: db '*** YOU WIN! ***', 0
finalScoreMsg: db 'FINAL SCORE: ', 0
playAgainMsg: db 'ENTER=Play Again | ESC=Exit', 0

; Keyboard ISR variables
oldKbdISR: dd 0
keyPressed: db 0
leftKey: db 0
rightKey: db 0

; START 
start:
    mov ax, 0x0003
    int 0x10
    
    call showWelcome
    call waitForStart
    
    cmp al, 27
    je exit_program

mainGameStart:
    call initGame
    call hookKeyboard
    
gameLoop:
    cmp byte [gameActive], 0
    je gameEnd
    
    call delay
    call moveBall
    call movePaddle
    call drawGame
    
    cmp byte [keyPressed], 27
    je gameEnd
    
    jmp gameLoop

gameEnd:
    call unhookKeyboard
    call showGameOver
    call waitForStart
    
    cmp al, 27
    je exit_program
    jmp mainGameStart

exit_program:
    call unhookKeyboard
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4C00
    int 0x21

;  INITIALIZE
initGame:
    pusha
    
    mov word [score], 0
    mov byte [lives], 3
    mov word [ballX], 40
    mov word [ballY], 18
    mov byte [ballDirX], 1
    mov byte [ballDirY], -1
    mov byte [paddleX], 32
    mov byte [gameActive], 1
    mov byte [gameSpeed], 5
    mov word [bricksRemaining], 40
    
    ; Reset all bricks
    mov cx, 40
    mov di, bricks
.resetLoop:
    mov byte [di], 1
    inc di
    loop .resetLoop
    
    popa
    ret

;  KEYBOARD ISR 
hookKeyboard:
    pusha
    
    ; Get old ISR
    mov ax, 0x3509
    int 0x21
    mov word [oldKbdISR], bx
    mov word [oldKbdISR+2], es
    
    ; Set new ISR
    push ds
    mov ax, cs
    mov ds, ax
    mov dx, kbdISR
    mov ax, 0x2509
    int 0x21
    pop ds
    
    popa
    ret

unhookKeyboard:
    pusha
    
    cmp word [oldKbdISR], 0
    je .done
    
    ; Restore old ISR
    push ds
    mov dx, word [oldKbdISR]
    mov ax, word [oldKbdISR+2]
    mov ds, ax
    mov ax, 0x2509
    int 0x21
    pop ds
    
    mov word [oldKbdISR], 0
    
.done:
    popa
    ret

kbdISR:
    pusha
    push ds
    
    mov ax, cs
    mov ds, ax
    
    in al, 0x60
    mov byte [keyPressed], al
    
    cmp al, 0x4B          ; Left arrow pressed
    je .setLeft
    cmp al, 0xCB          ; Left arrow released
    je .clearLeft
    cmp al, 0x4D          ; Right arrow pressed
    je .setRight
    cmp al, 0xCD          ; Right arrow released
    je .clearRight
    jmp .done

.setLeft:
    mov byte [leftKey], 1
    jmp .done
.clearLeft:
    mov byte [leftKey], 0
    jmp .done
.setRight:
    mov byte [rightKey], 1
    jmp .done
.clearRight:
    mov byte [rightKey], 0

.done:
    mov al, 0x20
    out 0x20, al
    
    pop ds
    popa
    iret

;  MOVE PADDLE 
movePaddle:
    pusha
    
    cmp byte [leftKey], 1
    jne .checkRight
    
    mov al, [paddleX]
    cmp al, 2
    jle .checkRight
    sub byte [paddleX], 2      ; Move 2 positions left (faster!)
    
.checkRight:
    cmp byte [rightKey], 1
    jne .done
    
    mov al, [paddleX]
    add al, [paddleWidth]
    cmp al, 77
    jge .done
    add byte [paddleX], 2      ; Move 2 positions right (faster!)
    
.done:
    popa
    ret

;  MOVE BALL 
moveBall:
    pusha
    
    ; Update X position
    mov al, [ballDirX]
    cbw
    add [ballX], ax
    
    ; Update Y position
    mov al, [ballDirY]
    cbw
    add [ballY], ax
    
    ; Check left/right walls
    mov ax, [ballX]
    cmp ax, 1
    jle .bounceX
    cmp ax, 78
    jge .bounceX
    jmp .checkY

.bounceX:
    neg byte [ballDirX]
    cmp word [ballX], 1
    jle .fixLeft
    mov word [ballX], 77
    jmp .fixDone
.fixLeft:
    mov word [ballX], 2
.fixDone:
    call playBounceSound
    
.checkY:
    ; Check top wall
    mov ax, [ballY]
    cmp ax, 3
    jle .bounceTop
    jmp .checkPaddle

.bounceTop:
    neg byte [ballDirY]
    mov word [ballY], 4
    call playBounceSound

.checkPaddle:
    ; Check paddle collision
    mov ax, [ballY]
    cmp ax, 22
    jne .checkBricks
    
    mov ax, [ballX]
    mov bl, [paddleX]
    mov bh, 0
    cmp ax, bx
    jl .checkBricks
    
    add bl, [paddleWidth]
    cmp ax, bx
    jge .checkBricks
    
    neg byte [ballDirY]
    mov word [ballY], 21
    call playPaddleSound
    jmp .checkBottom

.checkBricks:
    ; Check if ball in brick area
    mov ax, [ballY]
    cmp ax, 5
    jl .checkBottom
    cmp ax, 8
    jg .checkBottom
    
    ; Calculate brick row
    sub ax, 5
    mov si, ax
    mov bx, ax
    shl bx, 3              ; row * 8
    add bx, ax             ; row * 9
    add bx, ax             ; row * 10
    
    ; Calculate brick column
    mov ax, [ballX]
    sub ax, 2
    cmp ax, 0
    jl .checkBottom
    
    mov dx, 0
    mov cx, 8
    div cx
    
    cmp ax, 10
    jge .checkBottom
    
    ; Get brick index
    add bx, ax
    
    ; Check if brick exists
    push bx
    mov di, bricks
    add di, bx
    cmp byte [di], 0
    pop bx
    je .checkBottom
    
    ; Destroy brick
    mov di, bricks
    add di, bx
    mov byte [di], 0
    dec word [bricksRemaining]
    
    ; Add points based on row
    mov bx, si
    shl bx, 1
    add bx, brickPoints
    mov ax, [bx]
    add word [score], ax
    
    neg byte [ballDirY]
    call playBrickSound
    
    ; Check win condition
    cmp word [bricksRemaining], 0
    jne .checkBottom
    mov byte [gameActive], 0
    jmp .done

.checkBottom:
    ; Check if ball fell
    mov ax, [ballY]
    cmp ax, 23
    jl .done
    
    dec byte [lives]
    call playLifeLostSound
    
    ; Reset ball
    mov word [ballX], 40
    mov word [ballY], 18
    mov byte [ballDirX], 1
    mov byte [ballDirY], -1
    
    ; Pause
    mov cx, 10
.pauseLoop:
    push cx
    call delay
    pop cx
    loop .pauseLoop
    
    cmp byte [lives], 0
    jne .done
    mov byte [gameActive], 0

.done:
    popa
    ret

;  DRAW GAME
drawGame:
    pusha
    
    ; Clear screen
    mov ax, 0x0600
    mov bh, 0x00
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    
    ; Draw SCORE label
    mov dh, 0
    mov dl, 1
    call setCursor
    mov si, scoreLabel
.printScoreLabel:
    lodsb
    cmp al, 0
    je .printScoreValue
    mov ah, 0x09
    mov bh, 0
    mov bl, 0x0F
    mov cx, 1
    int 0x10
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    jmp .printScoreLabel
    
.printScoreValue:
    mov ax, [score]
    call printNumberWhite
    
    ; Draw LIVES label
    mov dh, 0
    mov dl, 55
    call setCursor
    mov si, livesLabel
.printLivesLabel:
    lodsb
    cmp al, 0
    je .printLivesValue
    mov ah, 0x09
    mov bh, 0
    mov bl, 0x0F
    mov cx, 1
    int 0x10
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    jmp .printLivesLabel
    
.printLivesValue:
    mov al, [lives]
    mov ah, 0
    call printNumberWhite
    
    ; Draw top border
    mov dh, 2
    mov dl, 0
    call setCursor
    mov ah, 0x09
    mov al, 196
    mov bh, 0
    mov bl, 0x0F
    mov cx, 80
    int 0x10
    
    ; Draw bricks (4 rows x 10 columns)
    mov byte [.currentRow], 0
    
.drawRows:
    mov al, [.currentRow]
    cmp al, 4
    jge .doneBricks
    
    mov dh, al
    add dh, 5              ; Start at row 5
    
    ; Calculate brick index for this row
    mov al, [.currentRow]
    mov bl, 10
    mul bl
    mov si, ax
    
    mov cx, 10             ; 10 columns
    mov dl, 2
    
.drawCols:
    push cx
    push dx
    
    ; Check if brick exists
    mov bx, si
    add bx, bricks
    cmp byte [bx], 0
    je .skipBrick
    
    call setCursor
    
    ; Get color for this row
    mov al, [.currentRow]
    cmp al, 0
    je .color0
    cmp al, 1
    je .color1
    cmp al, 2
    je .color2
    jmp .color3
    
.color0:
    mov bl, 0x4E           ; Bright Red
    jmp .drawIt
.color1:
    mov bl, 0x6E           ; Bright Yellow/Orange
    jmp .drawIt
.color2:
    mov bl, 0x2E           ; Bright Green
    jmp .drawIt
.color3:
    mov bl, 0x5E           ; Bright Magenta

.drawIt:
    mov ah, 0x09
    mov al, ' '
    mov bh, 0
    push cx
    mov cx, 7              ; 7 characters wide
    int 0x10
    pop cx
    
.skipBrick:
    pop dx
    add dl, 8              ; Move to next brick
    inc si
    pop cx
    loop .drawCols
    
    inc byte [.currentRow]
    jmp .drawRows

.doneBricks:
    ; Draw paddle
    mov dh, 22
    mov dl, [paddleX]
    call setCursor
    
    mov ah, 0x09
    mov al, 219
    mov bh, 0
    mov bl, 0x19
    mov cl, [paddleWidth]
    mov ch, 0
    int 0x10
    
    ; Draw ball
    mov ax, [ballY]
    mov dh, al
    mov ax, [ballX]
    mov dl, al
    call setCursor
    
    mov ah, 0x09
    mov al, 'O'
    mov bh, 0
    mov bl, 0x0E
    mov cx, 1
    int 0x10
    
    ; Draw bottom border
    mov dh, 23
    mov dl, 0
    call setCursor
    mov cx, 80
    mov ah, 0x09
    mov al, 196
    mov bh, 0
    mov bl, 0x0F
    int 0x10
    
    popa
    ret

.currentRow: db 0

;  WELCOME SCREEN 
showWelcome:
    pusha
    
    mov ax, 0x0600
    mov bh, 0x00
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    
    ; Draw border box
    mov dh, 5
    mov dl, 12
    call setCursor
    mov ah, 0x09
    mov al, 218
    mov bh, 0
    mov bl, 0x0B
    mov cx, 1
    int 0x10
    
    mov dl, 13
    call setCursor
    mov al, 196
    mov cx, 54
    int 0x10
    
    mov dl, 67
    call setCursor
    mov al, 191
    mov cx, 1
    int 0x10
    
    ; Side borders
    mov cx, 17
    mov dh, 6
.sideLoop:
    push cx
    mov dl, 12
    call setCursor
    mov ah, 0x09
    mov al, 179
    mov bh, 0
    mov bl, 0x0B
    mov cx, 1
    int 0x10
    
    mov dl, 67
    call setCursor
    int 0x10
    
    inc dh
    pop cx
    loop .sideLoop
    
    ; Bottom border
    mov dh, 23
    mov dl, 12
    call setCursor
    mov ah, 0x09
    mov al, 192
    mov bh, 0
    mov bl, 0x0B
    mov cx, 1
    int 0x10
    
    mov dl, 13
    call setCursor
    mov al, 196
    mov cx, 54
    int 0x10
    
    mov dl, 67
    call setCursor
    mov al, 217
    mov cx, 1
    int 0x10
    
    ; Print title and rules
    mov dh, 8
    mov dl, 24
    call setCursor
    mov si, welcomeMsg
    mov bl, 0x0E
    call printStringColor
    
    mov dh, 11
    mov dl, 37
    call setCursor
    mov si, rulesTitle
    mov bl, 0x0F
    call printStringColor
    
    mov dh, 13
    mov dl, 17
    call setCursor
    mov si, rule1
    mov bl, 0x07
    call printStringColor
    
    mov dh, 14
    mov dl, 21
    call setCursor
    mov si, rule2
    mov bl, 0x07
    call printStringColor
    
    mov dh, 15
    mov dl, 16
    call setCursor
    mov si, rule3
    mov bl, 0x07
    call printStringColor
    
    mov dh, 16
    mov dl, 16
    call setCursor
    mov si, rule4
    mov bl, 0x07
    call printStringColor
    
    mov dh, 17
    mov dl, 14
    call setCursor
    mov si, rule5
    mov bl, 0x07
    call printStringColor
    
    mov dh, 20
    mov dl, 27
    call setCursor
    mov si, startMsg
    mov bl, 0x0A
    call printStringColor
    
    mov dh, 21
    mov dl, 27
    call setCursor
    mov si, exitMsg
    mov bl, 0x0C
    call printStringColor
    
    popa
    ret

;  GAME OVER SCREEN 
showGameOver:
    pusha
    
    mov ax, 0x0600
    mov bh, 0x00
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    
    ; Draw border
    mov dh, 7
    mov dl, 15
    call setCursor
    mov ah, 0x09
    mov al, 218
    mov bh, 0
    mov bl, 0x0B
    mov cx, 1
    int 0x10
    
    mov dh, 7
    mov dl, 16
    call setCursor
    mov al, 196
    mov cx, 48
    int 0x10
    
    mov dh, 7
    mov dl, 64
    call setCursor
    mov al, 191
    mov cx, 1
    int 0x10
    
    mov dh, 8
.loopVert:
    cmp dh, 16
    jge .drawBottom
    
    mov dl, 15
    call setCursor
    mov ah, 0x09
    mov al, 179
    mov bh, 0
    mov bl, 0x0B
    mov cx, 1
    int 0x10
    
    mov dl, 64
    call setCursor
    int 0x10
    
    inc dh
    jmp .loopVert
    
.drawBottom:
    mov dh, 16
    mov dl, 15
    call setCursor
    mov ah, 0x09
    mov al, 192
    mov bh, 0
    mov bl, 0x0B
    mov cx, 1
    int 0x10
    
    mov dl, 16
    call setCursor
    mov al, 196
    mov cx, 48
    int 0x10
    
    mov dl, 64
    call setCursor
    mov al, 217
    mov cx, 1
    int 0x10
    
    ; Check win or game over
    cmp word [bricksRemaining], 0
    je .printWin
    
    ; Print GAME OVER
    mov dh, 10
    mov dl, 30
    call setCursor
    mov si, gameOverMsg
    mov bl, 0x0C
    call printStringColor
    jmp .printScore
    
.printWin:
    mov dh, 10
    mov dl, 32
    call setCursor
    mov si, winMsg
    mov bl, 0x0E
    call printStringColor
    
.printScore:
    mov dh, 12
    mov dl, 29
    call setCursor
    mov si, finalScoreMsg
    mov bl, 0x0F
    call printStringColor
    
    mov ax, [score]
    call printNumberWhite
    
    mov dh, 14
    mov dl, 21
    call setCursor
    mov si, playAgainMsg
    mov bl, 0x0F
    call printStringColor
    
    popa
    ret

;  UTILITIES 
setCursor:
    pusha
    mov ah, 0x02
    mov bh, 0
    int 0x10
    popa
    ret

printStringColor:
    pusha
    mov bh, 0
.loop:
    lodsb
    cmp al, 0
    je .done
    mov ah, 0x09
    mov cx, 1
    int 0x10
    
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    
    jmp .loop
.done:
    popa
    ret

printNumberWhite:
    pusha
    mov bx, 10
    mov cx, 0
    
.convert:
    mov dx, 0
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne .convert
    
.print:
    pop dx
    add dl, '0'
    mov al, dl
    mov ah, 0x09
    mov bh, 0
    mov bl, 0x0F
    push cx
    mov cx, 1
    int 0x10
    pop cx
    
    push cx
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    pop cx
    
    loop .print
    
    popa
    ret

waitForStart:
    mov ah, 0x00
    int 0x16
    ret

delay:
    pusha
    movzx ax, byte [gameSpeed]
    mov cx, ax
.outer:
    push cx
    mov cx, 0xFFFF
.loop:
    nop
    nop
    loop .loop
    pop cx
    loop .outer
    popa
    ret

;  SOUND 
playPaddleSound:
    pusha
    mov al, 0xB6
    out 0x43, al
    mov ax, 1193
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 0x03
    out 0x61, al
    call soundDelay
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    popa
    ret

playBounceSound:
    pusha
    mov al, 0xB6
    out 0x43, al
    mov ax, 796
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 0x03
    out 0x61, al
    call soundDelay
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    popa
    ret

playBrickSound:
    pusha
    mov al, 0xB6
    out 0x43, al
    mov ax, 1491
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 0x03
    out 0x61, al
    call soundDelay
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    popa
    ret

playLifeLostSound:
    pusha
    mov al, 0xB6
    out 0x43, al
    mov ax, 2386
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 0x03
    out 0x61, al
    mov cx, 3
.loop:
    push cx
    call soundDelay
    pop cx
    loop .loop
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    popa
    ret

soundDelay:
    push cx
    mov cx, 0x1FFF
.loop:
    nop
    loop .loop
    pop cx
    ret