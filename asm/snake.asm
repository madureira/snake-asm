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

VGA_MODE_13H        equ 0x0013      ; 320x200, 256 colors
VIDEO_SEGMENT       equ 0xA000      ; VGA framebuffer segment

PIC_MASTER_COMMAND  equ 0x20        ; master PIC command port
PIC_EOI             equ 0x20        ; End Of Interrupt command

IVT_INT08_OFFSET    equ 0x20        ; INT 08h vector offset in VT

; ============================================================================
; PIT (Programmable Interval Timer) constants
; ============================================================================

PIT_COMMAND         equ 0x43
PIT_CHANNEL_0       equ 0x40
PIT_DIVISOR         equ 1193        ; ~1000 Hz

; ============================================================================
; Game configuration
; ============================================================================

SCREEN_W            equ 320         ; screen width, in pixels
SCREEN_H            equ 200         ; screen height, in pixels
SQUARE_SIZE         equ 8           ; snake segment size, in pixels
STEP                equ SQUARE_SIZE ; movement step per keypress, in pixels
THICKNESS           equ 8           ; border wall thickness, in pixels
GAME_TICK_MS        equ 165         ; ~165 ms per movement

; ============================================================================
; VGA colors (default palette)
; ============================================================================

BG_COLOR            equ 0           ; black
BORDER_COLOR        equ 1           ; blue
SNAKE_COLOR         equ 15          ; white

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

    ; Install high-resolution game timer
    call install_timer

    ; Draw border
    mov bl, BORDER_COLOR
    call draw_border

    ; Draw snake at initial position
    mov bl, SNAKE_COLOR
    call draw_box

    ; Start the first movement interval after initialization is complete
    pushf
    cli
    mov word [timer_ticks], 0
    popf

; ============================================================================
; Main game loop
; ============================================================================

main_loop:
    ; Check if a key is available without blocking
    mov ah, 0x01                    ; BIOS keyboard: check for key
    int 0x16                        ; ZF=1 if no key is available

    ; No key available -> continue game loop
    jz .check_tick

    ; Read the available key
    mov ah, 0x00                    ; BIOS keyboard: read key
    int 0x16                        ; AH=scan code, AL=ASCII

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
    je .check_tick

    ; Ignore values outside the valid direction range
    cmp al, DIR_UP
    jb .check_tick

    cmp al, DIR_RIGHT
    ja .check_tick

    ; Store the new direction
    xor ah, ah
    mov [direction], ax

.check_tick:
    ; Check if it is time to move
    call game_tick

    ; No game tick yet
    cmp al, 0
    je main_loop

    ; Erase current square
    mov bl, BG_COLOR
    call draw_box

    ; Move according to the requested direction
    mov ax, [direction]

    cmp ax, DIR_UP
    je .move_up

    cmp ax, DIR_DOWN
    je .move_down

    cmp ax, DIR_LEFT
    je .move_left

    ; AX must be DIR_RIGHT here
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

.movement_done:
    ; Keep the square inside the screen
    call clamp_position

    ; Draw the square at the new position
    mov bl, SNAKE_COLOR
    call draw_box

    jmp main_loop

finish:
    ; Restore the original timer configuration
    call uninstall_timer

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
;
;   AH >= 0x80
;   AL = DIR_NONE
; ============================================================================

get_key_direction:
    push bx

    ; ------------------------------------------------------------------------
    ; Reject scan codes outside the lookup table.
    ;
    ; The table contains entries for scan codes 00h-7Fh.
    ; ------------------------------------------------------------------------

    cmp ah, 0x80
    jae .none

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
    jmp .done

.none:
    ; Scan code is outside the lookup table
    mov al, DIR_NONE

.done:
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
; game_tick
;
; Checks whether enough high-resolution timer ticks have elapsed to update
; the game.
;
; The PIT is configured to generate approximately 1000 interrupts per second.
; Therefore one timer tick is approximately 1 ms.
;
; Input:
;   [timer_ticks] = number of elapsed high-resolution timer ticks
;
; Output:
;   AL = 1 if a new game tick is ready
;   AL = 0 otherwise
;
; Side effects:
;   Subtracts GAME_TICK_MS from [timer_ticks] when a new game tick is ready.
;
; Notes:
;   Interrupts are temporarily disabled while reading and updating
;   timer_ticks so the PIT interrupt handler cannot modify the value
;   between the read and write operations.
;
;   The original interrupt flag state is restored before returning.
; ============================================================================

game_tick:
    push bx
    pushf

    ; ------------------------------------------------------------------------
    ; Disable interrupts to make the timer_ticks read/modify/write operation
    ; atomic with respect to timer_irq0.
    ; ------------------------------------------------------------------------

    cli

    ; Read elapsed high-resolution timer ticks
    mov bx, [timer_ticks]

    ; Check if enough time has elapsed
    cmp bx, GAME_TICK_MS
    jb .not_ready

    ; Consume one game interval
    sub bx, GAME_TICK_MS
    mov [timer_ticks], bx

    ; Game tick is ready
    mov al, 1
    jmp .restore_flags

.not_ready:
    ; No game tick yet
    xor al, al

.restore_flags:
    ; Restore the original interrupt flag state
    popf

    pop bx
    ret

; ============================================================================
; install_timer
;
; Installs a high-resolution PIT timer.
;
; The PIT is configured to generate approximately 1000 IRQ0 interrupts per
; second.
;
; The original INT 08h vector is read directly from the Interrupt Vector
; Table and saved so it can be restored later.
;
; No DOS interrupt services are used while interrupts are disabled.
; ============================================================================

install_timer:
    push ax
    push bx
    push es
    pushf

    ; ------------------------------------------------------------------------
    ; Disable hardware interrupts while modifying the IVT and PIT.
    ; ------------------------------------------------------------------------

    cli

    ; ------------------------------------------------------------------------
    ; Point ES to the Interrupt Vector Table.
    ;
    ; The IVT starts at physical address 00000h.
    ; Each interrupt vector occupies 4 bytes:
    ;
    ;   offset at +0
    ;   segment at +2
    ;
    ; INT 08h therefore starts at offset 08h * 4 = 20h.
    ; ------------------------------------------------------------------------

    xor ax, ax
    mov es, ax

    mov bx, IVT_INT08_OFFSET

    ; Save original INT 08h offset
    mov ax, [es:bx]
    mov [old_int08_offset], ax

    ; Save original INT 08h segment
    mov ax, [es:bx + 2]
    mov [old_int08_segment], ax

    ; ------------------------------------------------------------------------
    ; Install our INT 08h handler.
    ;
    ; The vector must contain:
    ;
    ;   offset = timer_irq0
    ;   segment = current CS
    ; ------------------------------------------------------------------------

    mov ax, timer_irq0
    mov [es:bx], ax

    mov ax, cs
    mov [es:bx + 2], ax

    ; ------------------------------------------------------------------------
    ; Configure PIT channel 0.
    ;
    ; Command:
    ;   00 = channel 0
    ;   11 = access low byte then high byte
    ;   010 = mode 2 (rate generator)
    ;   0 = binary mode
    ;
    ; 00110100b = 0x34
    ; ------------------------------------------------------------------------

    mov al, 0x34
    out PIT_COMMAND, al

    ; Send PIT divisor low byte
    mov ax, PIT_DIVISOR
    out PIT_CHANNEL_0, al

    ; Send PIT divisor high byte
    mov al, ah
    out PIT_CHANNEL_0, al

    ; ------------------------------------------------------------------------
    ; Reset timer state.
    ; ------------------------------------------------------------------------

    mov word [timer_ticks], 0
    mov word [bios_tick_accumulator], 0

    ; Restore the original interrupt flag state
    popf

    pop es
    pop bx
    pop ax
    ret

; ============================================================================
; uninstall_timer
;
; Restores the original INT 08h handler and restores the standard BIOS PIT
; configuration.
; ============================================================================

uninstall_timer:
    push ax
    push bx
    push es
    pushf

    ; ------------------------------------------------------------------------
    ; Disable hardware interrupts while restoring the IVT and PIT.
    ; ------------------------------------------------------------------------

    cli

    ; ------------------------------------------------------------------------
    ; Point ES to the Interrupt Vector Table.
    ; ------------------------------------------------------------------------

    xor ax, ax
    mov es, ax

    mov bx, IVT_INT08_OFFSET

    ; ------------------------------------------------------------------------
    ; Restore the original INT 08h vector.
    ; ------------------------------------------------------------------------

    mov ax, [old_int08_offset]
    mov [es:bx], ax

    mov ax, [old_int08_segment]
    mov [es:bx + 2], ax

    ; ------------------------------------------------------------------------
    ; Restore the standard BIOS PIT configuration.
    ;
    ; The standard BIOS configuration uses:
    ;
    ;   channel 0
    ;   low byte / high byte
    ;   mode 3 (square wave)
    ;   binary mode
    ;
    ; Command = 00110110b = 0x36
    ;
    ; A divisor of zero represents 65536.
    ; ------------------------------------------------------------------------

    mov al, 0x36
    out PIT_COMMAND, al

    ; Send divisor low byte
    xor ax, ax
    out PIT_CHANNEL_0, al

    ; Send divisor high byte
    mov al, ah
    out PIT_CHANNEL_0, al

    ; Restore the original interrupt flag state
    popf

    pop es
    pop bx
    pop ax
    ret

; ============================================================================
; timer_irq0
;
; IRQ0 handler called by PIT channel 0.
;
; The PIT runs at approximately 1000 Hz.
;
; Responsibilities:
;   1. Increment the high-resolution game timer.
;   2. Maintain a fractional accumulator for the BIOS timer.
;   3. Chain to the original BIOS INT 08h handler at the correct average rate.
;   4. Send an EOI to the PIC when the BIOS handler is not called.
;
; Register preservation:
;   AX, BX and DS are preserved.
; ============================================================================

timer_irq0:
    push ax
    push bx
    push ds

    ; ------------------------------------------------------------------------
    ; Use the program's data segment.
    ; ------------------------------------------------------------------------

    push cs
    pop ds

    ; ------------------------------------------------------------------------
    ; Increment the high-resolution game timer.
    ;
    ; PIT frequency is approximately 1000 Hz, so one tick is approximately
    ; one millisecond.
    ; ------------------------------------------------------------------------

    inc word [timer_ticks]

    ; ------------------------------------------------------------------------
    ; Maintain the BIOS timer accumulator.
    ;
    ; The BIOS normally receives IRQ0 at:
    ;
    ;   1193182 / 65536 = ~18.2065 Hz
    ;
    ; Our PIT runs at:
    ;
    ;   1193182 / PIT_DIVISOR
    ;
    ; Therefore the exact ratio between our IRQ rate and the original BIOS
    ; IRQ rate is:
    ;
    ;   PIT_DIVISOR / 65536
    ;
    ; Adding PIT_DIVISOR to a 16-bit accumulator and checking carry therefore
    ; produces the correct average BIOS timer frequency.
    ; ------------------------------------------------------------------------

    add word [bios_tick_accumulator], PIT_DIVISOR

    ; No BIOS tick yet
    jnc .send_eoi

    ; ------------------------------------------------------------------------
    ; Restore registers before chaining to the original BIOS handler.
    ;
    ; The original handler will execute IRET and return directly to the
    ; interrupted program.
    ; ------------------------------------------------------------------------

    pop ds
    pop bx
    pop ax

    ; ------------------------------------------------------------------------
    ; Chain to the original INT 08h handler.
    ;
    ; CS is used explicitly because DS has already been restored.
    ;
    ; A far JMP is required because the BIOS handler terminates with IRET.
    ; ------------------------------------------------------------------------

    jmp far [cs:old_int08_offset]

.send_eoi:
    ; ------------------------------------------------------------------------
    ; Send End Of Interrupt (EOI) to the master PIC.
    ;
    ; When chaining to the original BIOS handler, the BIOS handler is
    ; responsible for sending the EOI.
    ; ------------------------------------------------------------------------

    mov al, PIC_EOI
    out PIC_MASTER_COMMAND, al

    pop ds
    pop bx
    pop ax

    iret

; ============================================================================
; Game state
; ============================================================================

pos_x:                      dw 104  ; box's top-left X position
pos_y:                      dw 80   ; box's top-left Y position
direction:                  dw DIR_RIGHT

timer_ticks:                dw 0    ; High-resolution game timer

; Fractional accumulator used to reproduce the original BIOS timer rate
bios_tick_accumulator:      dw 0

; Original INT 08h vector
old_int08_offset:           dw 0
old_int08_segment:          dw 0
