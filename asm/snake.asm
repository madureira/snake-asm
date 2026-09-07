; ============================================================================
; Snake Assembly
;
; A classic Snake game written in x86 16-bit Assembly (NASM), assembled into
; a flat MS-DOS .COM executable (org 0x100).
;
; Controls:
;   W / Up Arrow    - Move up
;   S / Down Arrow  - Move down
;   A / Left Arrow  - Move left
;   D / Right Arrow - Move right
;   Esc             - Quit
; ============================================================================

bits 16                             ; real mode: 16-bit instructions
org 0x100                           ; COM exec: PSP occupies the first 256 bytes

; ============================================================================
; BIOS / hardware constants
; ============================================================================

VGA_MODE_13H    equ 0x0013          ; 320x200, 256 colors
VIDEO_SEGMENT   equ 0xA000          ; VGA framebuffer segment

; ============================================================================
; Screen configuration
; ============================================================================

SCREEN_W        equ 320             ; screen width, in pixels
SCREEN_H        equ 200             ; screen height, in pixels
SQUARE_SIZE     equ 8               ; snake segment size, in pixels
STEP            equ SQUARE_SIZE     ; movement step per keypress, in pixels
THICKNESS       equ 8               ; border wall thickness, in pixels

; ============================================================================
; VGA colors (default palette)
; ============================================================================

BG_COLOR        equ 0               ; black
BORDER_COLOR    equ 1               ; blue
SNAKE_COLOR     equ 15              ; white

; ============================================================================
; Keyboard scan codes
;
; BIOS int 16h, AH=00h returns:
;   AH = keyboard scan code
;   AL = ASCII character
; ============================================================================

KEY_ESC         equ 0x01
KEY_UP          equ 0x48
KEY_DOWN        equ 0x50
KEY_LEFT        equ 0x4B
KEY_RIGHT       equ 0x4D
KEY_W           equ 0x11
KEY_S           equ 0x1F
KEY_A           equ 0x1E
KEY_D           equ 0x20

; ============================================================================
; Movement directions
; ============================================================================

DIR_NONE        equ 0
DIR_UP          equ 1
DIR_DOWN        equ 2
DIR_LEFT        equ 3
DIR_RIGHT       equ 4

; ============================================================================
; Start
; ============================================================================

start:
    ; Initialize data segment
    push cs
    pop ds

    ; Set VGA mode 13h: 320x200, 256 colors
    mov ax, VGA_MODE_13H
    int 0x10

    ; Set VGA video memory segment
    mov ax, VIDEO_SEGMENT
    mov es, ax

    ; Draw border
    mov bl, BORDER_COLOR
    call draw_border

    ; Draw snake at initial position
    mov bl, SNAKE_COLOR
    call draw_box

; ============================================================================
; Main game loop
; ============================================================================

main_loop:
    ; Wait for key input
    mov ah, 0x00                    ; BIOS keyboard: block until key pressed
    int 0x16                        ; AH=scan code, AL=ASCII (0 if extended)

    ; Esc -> exit
    cmp ah, KEY_ESC
    je finish

    ; ------------------------------------------------------------------------
    ; Convert scan code into direction.
    ;
    ; Input:
    ;   AH = scan code
    ;
    ; Output:
    ;   AL = direction
    ; ------------------------------------------------------------------------

    call get_key_direction

    ; Ignore unmapped keys
    cmp al, DIR_NONE
    je main_loop

    ; Ignore values outside the valid direction range
    cmp al, DIR_UP
    jb main_loop

    cmp al, DIR_RIGHT
    ja main_loop

    ; Erase current square
    mov bl, BG_COLOR
    call draw_box

    ; Move according to the requested direction
    cmp al, DIR_UP
    je .move_up

    cmp al, DIR_DOWN
    je .move_down

    cmp al, DIR_LEFT
    je .move_left

    ; AL must be DIR_RIGHT here
    add word [pos_x], STEP
    jmp .movement_done

.move_up:
    sub word [pos_y], STEP
    jmp .movement_done

.move_down:
    add word [pos_y], STEP
    jmp .movement_done

.move_left:
    sub word [pos_x], STEP
    jmp .movement_done

.movement_done:
    ; Keep the square inside the screen
    call clamp_position

    ; Draw the square at the new position
    mov bl, SNAKE_COLOR
    call draw_box

    jmp main_loop

finish:
    ; Return to text mode 03h
    mov ax, 0x0003
    int 0x10

    ; Exit to DOS
    mov ax, 0x4C00
    int 0x21

; ============================================================================
; get_key_direction
;
; Converts a keyboard scan code into a movement direction using direct
; indexed memory access.
;
; Input:
;   AH = keyboard scan code
;
; Output:
;   AL = direction
;
; Example:
;   AH = 0x11 (W)
;   AL = DIR_UP
;
;   AH = 0x48 (Up Arrow)
;   AL = DIR_UP
;
;   AH = 0x30 (unmapped)
;   AL = DIR_NONE
; ============================================================================

get_key_direction:
    push bx

    ; ------------------------------------------------------------------------
    ; Move scan code from AH to BL.
    ;
    ; BX will be used as the table index.
    ; ------------------------------------------------------------------------

    mov bl, ah
    xor bh, bh

    ; ------------------------------------------------------------------------
    ; Direct indexed lookup:
    ;
    ;   AL = key_direction_table[BX]
    ; ------------------------------------------------------------------------

    mov al, [key_direction_table + bx]
    pop bx
    ret

; ============================================================================
; Keyboard lookup table
;
; Exactly 128 bytes.
;
; Index = keyboard scan code
; Value = movement direction
;
; Every entry defaults to DIR_NONE.
; Only W/A/S/D and arrow keys are mapped.
; ============================================================================

key_direction_table:
    ; Fill indexes 00h-10h with DIR_NONE
    times KEY_W db DIR_NONE

    ; Index 11h (W) -> DIR_UP
    db DIR_UP

    ; Fill indexes 12h-1Dh with DIR_NONE
    times KEY_A - KEY_W - 1 db DIR_NONE

    ; Index 1Eh (A) -> DIR_LEFT
    db DIR_LEFT

    ; Index 1Fh (S) -> DIR_DOWN
    db DIR_DOWN

    ; Index 20h (D) -> DIR_RIGHT
    db DIR_RIGHT

    ; Fill indexes 21h-47h with DIR_NONE
    times KEY_UP - KEY_D - 1 db DIR_NONE

    ; Index 48h (UP arrow) -> DIR_UP
    db DIR_UP

    ; Fill indexes 49h-4Ah with DIR_NONE
    times KEY_LEFT - KEY_UP - 1 db DIR_NONE

    ; Index 4Bh (LEFT arrow) -> DIR_LEFT
    db DIR_LEFT

    ; Index 4Ch -> DIR_NONE
    db DIR_NONE

    ; Index 4Dh (RIGHT arrow) -> DIR_RIGHT
    db DIR_RIGHT

    ; Fill indexes 4Eh-4Fh with DIR_NONE
    times KEY_DOWN - KEY_RIGHT - 1 db DIR_NONE

    ; Index 50h (DOWN arrow) -> DIR_DOWN
    db DIR_DOWN

    ; Fill indexes 51h-7Fh with DIR_NONE
    times 128 - KEY_DOWN - 1 db DIR_NONE

; ============================================================================
; draw_box
;
; Draws a SQUARE_SIZE x SQUARE_SIZE box in color BL at (pos_x, pos_y).
;
; Input:
;   BL = color
;
; Uses:
;   ES = VGA video segment
; ============================================================================

draw_box:
    push ax
    push bx
    push cx
    push dx
    push di

    ; ------------------------------------------------------------------------
    ; Calculate framebuffer offset:
    ;
    ; offset = pos_y * SCREEN_W + pos_x
    ;
    ; SCREEN_W = 320 = 256 + 64
    ; Therefore:
    ;
    ; pos_y * 320 = pos_y * 256 + pos_y * 64
    ; ------------------------------------------------------------------------

    mov ax, [pos_y]
    mov dx, ax

    shl ax, 8                       ; AX = pos_y * 256
    shl dx, 6                       ; DX = pos_y * 64

    add ax, dx                      ; AX = pos_y * 320
    add ax, [pos_x]                 ; AX = pos_y * 320 + pos_x

    mov di, ax

    ; ------------------------------------------------------------------------
    ; Prepare color for STOSB.
    ;
    ; STOSB writes AL to ES:[DI] and increments DI.
    ; ------------------------------------------------------------------------

    mov al, bl

    ; ------------------------------------------------------------------------
    ; Draw SQUARE_SIZE rows.
    ; ------------------------------------------------------------------------

    mov cx, SQUARE_SIZE

.row:
    push cx

    ; Draw one complete row
    mov cx, SQUARE_SIZE
    rep stosb

    ; Move DI to the beginning of the next row.
    add di, SCREEN_W - SQUARE_SIZE

    pop cx
    loop .row

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================================
; draw_border
;
; Draws a THICKNESS-pixel border around the screen in color BL,
; delimiting the play area. Called once, before the main loop.
;
; Input:
;   BL = color
;
; Uses:
;   ES = VGA video segment
; ============================================================================

draw_border:
    push ax
    push cx
    push di

    ; ------------------------------------------------------------------------
    ; Prepare color for STOSB.
    ;
    ; STOSB writes AL to ES:[DI] and increments DI.
    ; ------------------------------------------------------------------------

    mov al, bl

    ; ------------------------------------------------------------------------
    ; Top strip: SCREEN_W x THICKNESS
    ; ------------------------------------------------------------------------

    mov di, 0
    mov cx, SCREEN_W * THICKNESS
    rep stosb

    ; ------------------------------------------------------------------------
    ; Bottom strip: SCREEN_W x THICKNESS
    ; ------------------------------------------------------------------------

    mov ax, SCREEN_H - THICKNESS
    mov cx, SCREEN_W
    mul cx                          ; AX = (SCREEN_H - THICKNESS) * SCREEN_W

    mov di, ax
    mov al, bl
    mov cx, SCREEN_W * THICKNESS
    rep stosb

    ; ------------------------------------------------------------------------
    ; Left strip: THICKNESS x SCREEN_H
    ; ------------------------------------------------------------------------

    mov al, bl
    mov di, 0
    mov cx, SCREEN_H

.left_row:
    push cx

    mov cx, THICKNESS
    rep stosb

    add di, SCREEN_W - THICKNESS

    pop cx
    loop .left_row


    ; ------------------------------------------------------------------------
    ; Right strip: THICKNESS x SCREEN_H
    ; ------------------------------------------------------------------------

    mov al, bl
    mov di, SCREEN_W - THICKNESS
    mov cx, SCREEN_H

.right_row:
    push cx

    mov cx, THICKNESS
    rep stosb

    add di, SCREEN_W - THICKNESS

    pop cx
    loop .right_row

    pop di
    pop cx
    pop ax
    ret

; ============================================================================
; clamp_position
;
; Keeps pos_x and pos_y within the playable area.
; ============================================================================

clamp_position:
    push ax
    ; Clamp X to left border
    cmp word [pos_x], THICKNESS
    jge .x_not_neg
    mov word [pos_x], THICKNESS     ; clamp to left edge (inside the border)

.x_not_neg:
    ; Clamp X to right border
    mov ax, SCREEN_W - SQUARE_SIZE - THICKNESS
    cmp word [pos_x], ax
    jle .x_not_over
    mov word [pos_x], ax            ; clamp to right edge (inside the border)

.x_not_over:
    ; Clamp Y to top border
    cmp word [pos_y], THICKNESS
    jge .y_not_neg
    mov word [pos_y], THICKNESS     ; clamp to top edge (inside the border)

.y_not_neg:
    ; Clamp Y to bottom border
    mov ax, SCREEN_H - SQUARE_SIZE - THICKNESS
    cmp word [pos_y], ax
    jle .y_not_over
    mov word [pos_y], ax            ; clamp to bottom edge (inside the border)

.y_not_over:
    pop ax
    ret

; ============================================================================
; Game state
; ============================================================================

pos_x: dw 100                       ; box's top-left X position
pos_y: dw 80                        ; box's top-left Y position

