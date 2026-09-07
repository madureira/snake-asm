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
SQUARE_SIZE     equ 10              ; snake segment size, in pixels
STEP            equ 8               ; movement step per keypress, in pixels
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
; Start
; ============================================================================

start:
    ; Set VGA mode 13h: 320x200, 256 colors
    mov ax, VGA_MODE_13H
    int 0x10

    ; Set VGA video memory segment
    mov ax, VIDEO_SEGMENT
    mov es, ax

    ; Draw border
    mov bl, BORDER_COLOR
    call draw_border

; ============================================================================
; Main game loop
; ============================================================================

main_loop:
    ; Draw snake box at current position
    mov bl, SNAKE_COLOR
    call draw_box                   ; draw box at current position

    ; Wait for a key
    mov ah, 0x00                    ; BIOS keyboard: block until key pressed
    int 0x16                        ; AH=scan code, AL=ASCII (0 if extended)

    ; Esc -> exit
    cmp ah, KEY_ESC
    je finish

    ; Erase current position
    mov bl, BG_COLOR
    call draw_box

    ; Convert keyboard scan code into movement delta.
    call get_key_delta

    ; If the key is not mapped, the current position remains unchanged
    js .no_movement

    ; Apply movement
    add word [pos_x], ax
    add word [pos_y], bx

    ; Keep the snake inside the play area
    call clamp_position

.no_movement:
    jmp main_loop

finish:
    ; Return to text mode 03h
    mov ax, 0x0003
    int 0x10

    ; Exit to DOS
    mov ax, 0x4C00
    int 0x21

; ============================================================================
; Keyboard -> movement delta table
;
; Each entry has the following format:
;
;   db scan_code
;   dw delta_x
;   dw delta_y
;
; Entry size = 5 bytes.
; ============================================================================

key_delta_table:
    ; Up
    db KEY_UP
    dw 0
    dw -STEP

    ; W
    db KEY_W
    dw 0
    dw -STEP

    ; Down
    db KEY_DOWN
    dw 0
    dw STEP

    ; S
    db KEY_S
    dw 0
    dw STEP

    ; Left
    db KEY_LEFT
    dw -STEP
    dw 0

    ; A
    db KEY_A
    dw -STEP
    dw 0

    ; Right
    db KEY_RIGHT
    dw STEP
    dw 0

    ; D
    db KEY_D
    dw STEP
    dw 0

    ; End of table
    db 0x00

; ============================================================================
; get_key_delta
;
; Converts a keyboard scan code into a movement delta.
;
; Input:
;   AH = keyboard scan code
;
; Output:
;   CF = 0 -> key found
;       AX = delta X
;       BX = delta Y
;
;   CF = 1 -> key not found
;       AX and BX are zero
;
; Preserves:
;   DX
;   SI
; ============================================================================

get_key_delta:
    ; Save registers that we use
    push dx
    push si

    ; ------------------------------------------------------------------------
    ; Save scan code in DH.
    ;
    ; We use DH instead of DL so that the low byte of DX is never
    ; accidentally confused with the return value in AX.
    ; ------------------------------------------------------------------------

    mov dh, ah

    ; SI points to the beginning of the table
    mov si, key_delta_table

.loop:
    ; Check for end of table
    cmp byte [si], 0x00
    je .not_found

    ; Compare scan code
    cmp byte [si], dh
    je .found

    ; ------------------------------------------------------------------------
    ; Each table entry is:
    ;
    ;   1 byte  scan code
    ;   2 bytes delta X
    ;   2 bytes delta Y
    ;
    ; Total = 5 bytes.
    ; ------------------------------------------------------------------------

    add si, 5
    jmp .loop

.found:

    ; ------------------------------------------------------------------------
    ; Entry layout:
    ;
    ;   [SI + 0] = scan code
    ;   [SI + 1] = delta X
    ;   [SI + 3] = delta Y
    ; ------------------------------------------------------------------------

    mov ax, [si + 1]
    mov bx, [si + 3]

    ; Key found
    clc

    pop si
    pop dx

    ret

.not_found:

    ; ------------------------------------------------------------------------
    ; Key not mapped.
    ;
    ; Return zero movement and set CF.
    ; ------------------------------------------------------------------------

    xor ax, ax
    xor bx, bx

    ; Key not found
    stc

    pop si
    pop dx

    ret

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
    push cx
    push di

    ; ------------------------------------------------------------------------
    ; Calculate framebuffer offset:
    ;
    ; offset = pos_y * SCREEN_W + pos_x
    ; ------------------------------------------------------------------------

    mov ax, [pos_y]

    mov cx, SCREEN_W
    mul cx                          ; ax = pos_y * SCREEN_W

    add ax, [pos_x]                 ; ax = pos_y * SCREEN_W + pos_x

    mov di, ax                      ; di = offset of the box's top-left pixel

    ; Draw rows
    mov cx, SQUARE_SIZE             ; row counter

.row:
    push cx

    ; Draw columns
    mov cx, SQUARE_SIZE             ; pixel counter for this row

.col:
    mov [es:di], bl                 ; write one pixel
    inc di

    loop .col

    ; Move DI to the beginning of the next row.
    add di, SCREEN_W - SQUARE_SIZE  ; skip to the start of the next row

    pop cx

    loop .row

    pop di
    pop cx
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

