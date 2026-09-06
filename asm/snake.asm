bits 16
org 0x100

SQUARE_SIZE equ 40
SCREEN_W    equ 320
SCREEN_H    equ 200
STEP        equ 8
COLOR       equ 15
BG          equ 0

; BIOS scan codes returned in AH by int 0x16, ah=0x00
KEY_ESC     equ 0x01
KEY_UP      equ 0x48
KEY_DOWN    equ 0x50
KEY_LEFT    equ 0x4B
KEY_RIGHT   equ 0x4D

start:
    ; Set VGA mode 13h: 320x200, 256 colors
    mov ax, 0x0013
    int 0x10

    ; Video memory segment
    mov ax, 0xA000
    mov es, ax

main_loop:
    mov bl, COLOR                   ; foreground color
    call draw_box                   ; draw box at current position

    mov ah, 0x00                    ; BIOS keyboard: block until key pressed
    int 0x16                        ; AH = scan code, AL = ASCII (0 if extended)

    cmp ah, KEY_ESC
    je finish                       ; Esc exits the program

    mov bl, BG                      ; background color
    call draw_box                   ; erase old position

    cmp ah, KEY_UP
    jne .skip_up
    sub word [pos_y], STEP          ; move up: decrease Y
.skip_up:
    cmp ah, KEY_DOWN
    jne .skip_down
    add word [pos_y], STEP          ; move down: increase Y
.skip_down:
    cmp ah, KEY_LEFT
    jne .skip_left
    sub word [pos_x], STEP          ; move left: decrease X
.skip_left:
    cmp ah, KEY_RIGHT
    jne .skip_right
    add word [pos_x], STEP          ; move right: increase X
.skip_right:

    call clamp_position             ; keep the box within the screen
    jmp main_loop

finish:
    ; Return to text mode
    mov ax, 0x0003
    int 0x10

    ; Exit to DOS
    mov ax, 0x4C00
    int 0x21

; Draws a SQUARE_SIZE x SQUARE_SIZE box in color BL at (pos_x, pos_y)
draw_box:
    push ax
    push cx
    push di

    mov ax, [pos_y]
    mov cx, SCREEN_W
    mul cx                          ; ax = pos_y * SCREEN_W
    add ax, [pos_x]                 ; ax = pos_y * SCREEN_W + pos_x
    mov di, ax                      ; di = offset of the box's top-left pixel

    mov cx, SQUARE_SIZE             ; row counter
.row:
    push cx
    mov cx, SQUARE_SIZE             ; pixel counter for this row
.col:
    mov [es:di], bl                 ; write one pixel
    inc di
    loop .col

    add di, SCREEN_W - SQUARE_SIZE  ; skip to the start of the next row
    pop cx
    loop .row

    pop di
    pop cx
    pop ax
    ret

; Keeps pos_x/pos_y within screen bounds
clamp_position:
    push ax

    cmp word [pos_x], 0
    jge .x_not_neg
    mov word [pos_x], 0             ; clamp to left edge
.x_not_neg:
    mov ax, SCREEN_W - SQUARE_SIZE
    cmp word [pos_x], ax
    jle .x_not_over
    mov word [pos_x], ax            ; clamp to right edge
.x_not_over:

    cmp word [pos_y], 0
    jge .y_not_neg
    mov word [pos_y], 0             ; clamp to top edge
.y_not_neg:
    mov ax, SCREEN_H - SQUARE_SIZE
    cmp word [pos_y], ax
    jle .y_not_over
    mov word [pos_y], ax            ; clamp to bottom edge
.y_not_over:

    pop ax
    ret

pos_x: dw 100                       ; box's top-left X position
pos_y: dw 80                        ; box's top-left Y position
