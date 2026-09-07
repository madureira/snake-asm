; ============================================================================
; Snake Assembly
;
; A classic Snake game written in x86 16-bit Assembly (NASM), assembled into
; a flat MS-DOS .COM executable (org 0x100).
;
; Controls: Arrow keys to move, Esc to quit.
; ============================================================================

bits 16                             ; real mode: 16-bit instructions
org 0x100                           ; COM executable: PSP occupies the first 256 bytes

; BIOS video (int 0x10)
VGA_MODE_13H    equ 0x0013          ; 320x200, 256 colors
VIDEO_SEGMENT   equ 0xA000          ; VGA framebuffer segment

; Game constants
SCREEN_W        equ 320             ; screen width, in pixels (VGA mode 13h)
SCREEN_H        equ 200             ; screen height, in pixels (VGA mode 13h)
SQUARE_SIZE     equ 10              ; snake segment size, in pixels
STEP            equ 8               ; movement step per keypress, in pixels
THICKNESS       equ 8               ; border wall thickness, in pixels

; VGA (default palette)
BG_COLOR        equ 0               ; black
BORDER_COLOR    equ 1               ; blue
SNAKE_COLOR     equ 15              ; white

; BIOS scan codes returned in AH by int 0x16, ah=0x00
KEY_ESC         equ 0x01
KEY_UP          equ 0x48
KEY_DOWN        equ 0x50
KEY_LEFT        equ 0x4B
KEY_RIGHT       equ 0x4D
KEY_W           equ 0x11
KEY_S           equ 0x1F
KEY_A           equ 0x1E
KEY_D           equ 0x20

start:
    ; Set VGA mode 13h: 320x200, 256 colors
    mov ax, VGA_MODE_13H
    int 0x10

    ; Video memory segment
    mov ax, VIDEO_SEGMENT
    mov es, ax

    mov bl, BORDER_COLOR
    call draw_border                ; draw border only once

main_loop:
    mov bl, SNAKE_COLOR
    call draw_box                   ; draw box at current position

    mov ah, 0x00                    ; BIOS keyboard: block until key pressed
    int 0x16                        ; AH=scan code, AL=ASCII (0 if extended)

    cmp ah, KEY_ESC
    je finish                       ; Esc exits the program

    mov bl, BG_COLOR
    call draw_box                   ; erase old position

    ; Capture keyboard input
    cmp ah, KEY_UP
    je  .move_up

    cmp ah, KEY_W
    jne .skip_move_up

.move_up:
    sub word [pos_y], STEP          ; decrease Y

.skip_move_up:
    cmp ah, KEY_DOWN
    je .move_down

    cmp ah, KEY_S
    jne .skip_move_down

.move_down:
    add word [pos_y], STEP          ; increase Y

.skip_move_down:
    cmp ah, KEY_LEFT
    je .move_left

    cmp ah, KEY_A
    jne .skip_move_left

.move_left:
    sub word [pos_x], STEP          ; decrease X

.skip_move_left:
    cmp ah, KEY_RIGHT
    je .move_right

    cmp ah, KEY_D
    jne .skip_move_right

.move_right:
    add word [pos_x], STEP          ; increase X

.skip_move_right:
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

; Draws a THICKNESS-px border wall around the screen in color BL,
; delimiting the play area. Called once, before the main loop.
draw_border:
    push ax
    push cx
    push di

    ; Top strip: SCREEN_W x THICKNESS, contiguous from offset 0
    mov di, 0
    mov cx, SCREEN_W * THICKNESS

.top:
    mov [es:di], bl
    inc di
    loop .top

    ; Bottom strip: SCREEN_W x THICKNESS, contiguos from the last THICKNESS rows
    mov ax, SCREEN_H - THICKNESS
    mov cx, SCREEN_W
    mul cx                          ; ax = (SCREEN_H - THICKNESS) * SCREEN_W
    mov di, ax
    mov cx, SCREEN_W * THICKNESS

.bottom:
    mov [es:di], bl
    inc di
    loop .bottom

    ; Left strip: THICKNESS x SCREEN_H
    mov di, 0
    mov cx, SCREEN_H                ; row counter

.left_row:
    push cx
    mov cx, THICKNESS               ; pixel counter for this row
.left_col:
    mov [es:di], bl
    inc di
    loop .left_col

    add di, SCREEN_W - THICKNESS    ; skip to the start of the next row
    pop cx
    loop .left_row

    ; Right strip: THICKNESS x SCRREN_H
    mov di, SCREEN_W - THICKNESS
    mov cx, SCREEN_H                ; row counter

.right_row:
    push cx
    mov cx, THICKNESS               ; pixel counter for this row
.right_col:
    mov [es:di], bl
    inc di
    loop .right_col

    add di, SCREEN_W - THICKNESS    ; skip to the start of the next row
    pop cx
    loop .right_row

    pop di
    pop cx
    pop ax
    ret

; Keeps pos_x/pos_y within screen bounds
clamp_position:
    push ax

    cmp word [pos_x], THICKNESS
    jge .x_not_neg
    mov word [pos_x], THICKNESS     ; clamp to left edge (inside the border)

.x_not_neg:
    mov ax, SCREEN_W - SQUARE_SIZE - THICKNESS
    cmp word [pos_x], ax
    jle .x_not_over
    mov word [pos_x], ax            ; clamp to right edge (inside the border)

.x_not_over:
    cmp word [pos_y], THICKNESS
    jge .y_not_neg
    mov word [pos_y], THICKNESS     ; clamp to top edge (inside the border)

.y_not_neg:
    mov ax, SCREEN_H - SQUARE_SIZE - THICKNESS
    cmp word [pos_y], ax
    jle .y_not_over
    mov word [pos_y], ax            ; clamp to bottom edge (inside the border)

.y_not_over:
    pop ax
    ret

pos_x: dw 100                       ; box's top-left X position
pos_y: dw 80                        ; box's top-left Y position
