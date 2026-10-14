; =====================================================================
;  Kernel of "oruaM OS", my first 16-bit operating system
;  x86 real mode, uses BIOS services.
;  Bilingual: English / Italiano (choose at boot or with "language").
;  Keyboard layout selectable: IT or US.
; =====================================================================
[org 0]
[bits 16]

KERNEL_SECTORS  equ 16
MAX_INPUT       equ 63

start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov [boot_drive], dl

    call cmd_clear
    mov si, msg_choose
    call print
.ask:
    xor ah, ah
    int 0x16
    cmp al, '1'
    je .en
    cmp al, '2'
    je .it
    jmp .ask
.en:
    mov byte [lang], 0
    jmp .go
.it:
    mov byte [lang], 1
.go:
    call cmd_clear
    mov si, banner
    call print_color
    mov si, t_subtitle
    call print_t_color

; ---------------------------------------------------------------------
;  Shell
; ---------------------------------------------------------------------
main_loop:
    mov si, prompt
    call print_color
    mov di, buffer
    call read_line

    mov si, buffer
    call skip_spaces
    cmp byte [si], 0
    je main_loop                ; empty line

    mov bx, cmd_table
.next:
    mov di, [bx]
    test di, di
    jz .unknown                 ; end of table
    push si
    call match_word
    pop si
    jnc .found
    add bx, 4
    jmp .next
.found:
    call [bx + 2]               ; SI = start of the command line
    jmp main_loop
.unknown:
    mov si, t_unknown
    call print_t
    jmp main_loop

; Command table: pointer to the name, pointer to the routine
cmd_table:
    dw s_help,       cmd_help
    dw s_aiuto,      cmd_help
    dw s_clear,      cmd_clear
    dw s_lindo,      cmd_clear
    dw s_version,    cmd_version
    dw s_versione,   cmd_version
    dw s_echo,       cmd_echo
    dw s_eco,        cmd_echo
    dw s_time,       cmd_time
    dw s_ora,        cmd_time
    dw s_date,       cmd_date
    dw s_data,       cmd_date
    dw s_memory,     cmd_memory
    dw s_memoria,    cmd_memory
    dw s_calc,       cmd_calc
    dw s_color,      cmd_color
    dw s_colore,     cmd_color
    dw s_keyboard,   cmd_keyboard
    dw s_tastiera,   cmd_keyboard
    dw s_language,   cmd_language
    dw s_lingua,     cmd_language
    dw s_reboot,     cmd_reboot
    dw s_riavvia,    cmd_reboot
    dw s_shutdown,   cmd_shutdown
    dw s_spegni,     cmd_shutdown
    dw 0

; =====================================================================
;  Commands
; =====================================================================
cmd_help:
    mov si, t_help
    call print_t
    ret

cmd_clear:
    mov ax, 0x0003              ; 80x25 text mode, clears the screen
    int 0x10
    ret

cmd_version:
    mov si, t_ver
    call print_t
    mov si, t_drive
    call print_t
    xor ah, ah
    mov al, [boot_drive]
    call print_hex8
    call newline
    ret

cmd_echo:
    call get_args
    call print
    call newline
    ret

cmd_time:
    mov ah, 0x02                ; RTC: CH=hours CL=minutes DH=seconds (BCD)
    int 0x1A
    jc rtc_error
    mov al, ch
    call print_hex8
    mov al, ':'
    call putc
    mov al, cl
    call print_hex8
    mov al, ':'
    call putc
    mov al, dh
    call print_hex8
    call newline
    ret

cmd_date:
    mov ah, 0x04                ; RTC: CH=century CL=year DH=month DL=day (BCD)
    int 0x1A
    jc rtc_error
    mov al, dl
    call print_hex8
    mov al, '/'
    call putc
    mov al, dh
    call print_hex8
    mov al, '/'
    call putc
    mov al, ch
    call print_hex8
    mov al, cl
    call print_hex8
    call newline
    ret

rtc_error:
    mov si, t_rtc_err
    call print_t
    ret

cmd_memory:
    int 0x12                    ; AX = KB of conventional memory
    call print_dec
    mov si, t_kb
    call print_t
    ret

; calc <a> <op> <b>   with op = + - * /
cmd_calc:
    call get_args
    call parse_num
    jc .syntax
    mov [num_a], ax
    call skip_spaces
    lodsb
    mov [calc_op], al
    call skip_spaces
    call parse_num
    jc .syntax
    mov bx, ax                  ; BX = b
    mov ax, [num_a]             ; AX = a
    cmp byte [calc_op], '+'
    je .add
    cmp byte [calc_op], '-'
    je .sub
    cmp byte [calc_op], '*'
    je .mul
    cmp byte [calc_op], '/'
    je .div
.syntax:
    mov si, t_calc_use
    call print_t
    ret
.add:
    add ax, bx
    jc .overflow
    jmp .result
.sub:
    cmp ax, bx
    jae .sub_pos
    xchg ax, bx
    push ax
    mov al, '-'
    call putc
    pop ax
.sub_pos:
    sub ax, bx
    jmp .result
.mul:
    mul bx
    test dx, dx
    jnz .overflow
    jmp .result
.div:
    test bx, bx
    jz .divzero
    xor dx, dx
    div bx
    push dx
    call print_dec
    mov si, t_remainder
    call print_t
    pop ax
.result:
    call print_dec
    call newline
    ret
.overflow:
    mov si, t_overflow
    call print_t
    ret
.divzero:
    mov si, t_divzero
    call print_t
    ret

cmd_color:
    mov al, [text_color]
    inc al
    and al, 0x0F
    jnz .set
    inc al                      ; skip black
.set:
    mov [text_color], al
    mov si, t_color
    call print_t_color
    ret

; keyboard [it|us] : changes or shows the keyboard layout
cmd_keyboard:
    call get_args
    cmp byte [si], 0
    je .show
    mov di, s_it
    push si
    call match_word
    pop si
    jnc .set_it
    mov di, s_us
    call match_word
    jnc .set_us
    mov si, t_kbd_use
    call print_t
    ret
.set_it:
    mov byte [kbd_layout], 0
    jmp .show
.set_us:
    mov byte [kbd_layout], 1
.show:
    mov si, t_kbd
    call print_t
    mov si, s_it
    cmp byte [kbd_layout], 0
    je .p
    mov si, s_us
.p:
    call print
    call newline
    ret

; language [en|it] : changes or shows the language
cmd_language:
    call get_args
    cmp byte [si], 0
    je .show
    mov di, s_en
    push si
    call match_word
    pop si
    jnc .set_en
    mov di, s_it
    call match_word
    jnc .set_it
    mov si, t_lang_use
    call print_t
    ret
.set_en:
    mov byte [lang], 0
    jmp .show
.set_it:
    mov byte [lang], 1
.show:
    mov si, t_lang
    call print_t
    mov si, s_en
    cmp byte [lang], 0
    je .p
    mov si, s_it
.p:
    call print
    call newline
    ret

cmd_reboot:
    mov si, t_reboot
    call print_t
    xor ah, ah
    int 0x16                    ; wait for a key
    jmp 0xFFFF:0x0000           ; jump to the BIOS reset vector

cmd_shutdown:
    mov si, t_halt
    call print_t
    ; Power off via APM (works on QEMU, Bochs and many real PCs)
    mov ax, 0x5301              ; connect APM real-mode interface
    xor bx, bx
    int 0x15
    mov ax, 0x530E              ; request APM driver version 1.2
    xor bx, bx
    mov cx, 0x0102
    int 0x15
    mov ax, 0x5307              ; set power state: off
    mov bx, 0x0001              ; all devices
    mov cx, 0x0003
    int 0x15
    ; if APM is not available, halt the CPU
    mov si, t_safe
    call print_t
.hang:
    cli
    hlt
    jmp .hang

; =====================================================================
;  Library
; =====================================================================

; putc: prints the character in AL (BIOS teletype)
putc:
    push ax
    push bx
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    pop bx
    pop ax
    ret

; pick_t: SI = table {English, Italian} -> SI = string in the current language
pick_t:
    push bx
    xor bh, bh
    mov bl, [lang]
    shl bx, 1
    mov si, [si + bx]
    pop bx
    ret

; print_t / print_t_color: print the string of a language table
print_t:
    call pick_t
    jmp print

print_t_color:
    call pick_t
    jmp print_color

; print: prints the zero-terminated string at DS:SI
print:
    push ax
    push si
.l:
    lodsb
    or al, al
    jz .d
    call putc
    jmp .l
.d:
    pop si
    pop ax
    ret

; print_color: prints DS:SI in the current color (int 10h AH=09h)
print_color:
    push ax
    push bx
    push cx
    push si
.l:
    lodsb
    or al, al
    jz .d
    cmp al, 13
    je .raw
    cmp al, 10
    je .raw
    mov ah, 0x09                ; writes character+attribute...
    xor bh, bh
    mov bl, [text_color]
    mov cx, 1
    int 0x10
.raw:
    call putc                   ; ...then advances the cursor
    jmp .l
.d:
    pop si
    pop cx
    pop bx
    pop ax
    ret

newline:
    push ax
    mov al, 13
    call putc
    mov al, 10
    call putc
    pop ax
    ret

; print_hex8: prints AL as 2 hex digits (also works for BCD values)
print_hex8:
    push ax
    push ax
    shr al, 4
    call .nib
    pop ax
    and al, 0x0F
    call .nib
    pop ax
    ret
.nib:
    add al, '0'
    cmp al, '9'
    jbe .p
    add al, 7
.p:
    call putc
    ret

; print_dec: prints AX as an unsigned decimal number
print_dec:
    push ax
    push bx
    push cx
    push dx
    mov bx, 10
    xor cx, cx
.div:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div
.out:
    pop ax
    add al, '0'
    call putc
    loop .out
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; read_line: reads a line from the keyboard into ES:DI (max MAX_INPUT chars)
read_line:
    xor cx, cx
.key:
    mov ah, 0x10
    int 0x16                    ; AH = scancode, AL = character (US layout)
    call translate_key          ; converts to the active layout (Italian)
    cmp al, 13
    je .enter
    cmp al, 8
    je .bs
    cmp al, 32
    jb .key
    cmp cx, MAX_INPUT
    jae .key
    stosb
    inc cx
    call putc
    jmp .key
.bs:
    jcxz .key
    dec di
    dec cx
    mov al, 8
    call putc
    mov al, ' '
    call putc
    mov al, 8
    call putc
    jmp .key
.enter:
    mov byte [di], 0
    call newline
    ret

; translate_key: AH=scancode, AL=BIOS ASCII (US layout).
;   If the layout is Italian, returns the Italian character in AL
;   (codepage 437, so accented letters are included).
;   kbd_it table: 8 bytes per scancode =
;   normal, Shift, AltGr, AltGr+Shift, US Shift character, 3 padding
translate_key:
    cmp byte [kbd_layout], 0
    jne .ret
    push bx
    push dx
    mov dx, ax                  ; DH = scancode, DL = BIOS ASCII
    cmp dh, 0x82                ; Alt + US "-" key  -> Italian ' key
    jne .c1
    mov dh, 0x0C
    jmp .altgr
.c1:
    cmp dh, 0x83                ; Alt + US "=" key  -> Italian i-grave key
    jne .c2
    mov dh, 0x0D
    jmp .altgr
.c2:
    cmp dh, 0x57
    jae .keep
    xor bh, bh
    mov bl, dh
    shl bx, 3                   ; BX = scancode * 8
    test dl, dl
    jz .altgr_idx               ; AL=0 -> key pressed with Alt/AltGr
    cmp dl, [kbd_it + bx + 4]
    jne .look                   ; not the US "shifted" character -> normal
    inc bx                      ; Shift column
    jmp .look
.altgr:
    xor bh, bh
    mov bl, dh
    shl bx, 3
.altgr_idx:
    add bx, 2                   ; AltGr column
    mov ah, 0x02
    int 0x16                    ; AL = Shift state
    test al, 0x03
    jz .look
    cmp byte [kbd_it + bx + 1], 0   ; AltGr+Shift: only { and }
    je .look
    mov al, [kbd_it + bx + 1]
    jmp .done
.look:
    mov al, [kbd_it + bx]
    test al, al
    jnz .done
.keep:
    mov al, dl                  ; no conversion: BIOS character
.done:
    mov ah, dh
    pop dx
    pop bx
.ret:
    ret

; skip_spaces: advances SI past spaces
skip_spaces:
    cmp byte [si], ' '
    jne .d
    inc si
    jmp skip_spaces
.d:
    ret

; get_args: from SI (start of command) skips the word and spaces -> arguments
get_args:
    cmp byte [si], 0
    je .d
    cmp byte [si], ' '
    je .sp
    inc si
    jmp get_args
.sp:
    call skip_spaces
.d:
    ret

; match_word: compares the word at SI (up to space/0, case-insensitive)
;             with the string at DI. CF=0 if equal, CF=1 otherwise.
match_word:
    mov al, [si]
    mov ah, [di]
    cmp al, 'A'
    jb .nc
    cmp al, 'Z'
    ja .nc
    add al, 32                  ; uppercase -> lowercase
.nc:
    test ah, ah
    jz .end
    cmp al, ah
    jne .no
    inc si
    inc di
    jmp match_word
.end:
    test al, al
    jz .yes
    cmp al, ' '
    je .yes
.no:
    stc
    ret
.yes:
    clc
    ret

; parse_num: reads a decimal number from SI -> AX. CF=1 if no digits.
parse_num:
    push bx
    push cx
    push dx
    xor ax, ax
    xor cx, cx
.l:
    mov bl, [si]
    cmp bl, '0'
    jb .end
    cmp bl, '9'
    ja .end
    sub bl, '0'
    mov dx, 10
    mul dx
    xor bh, bh
    add ax, bx
    inc si
    inc cx
    jmp .l
.end:
    cmp cx, 1                   ; CF=1 if CX=0
    pop dx
    pop cx
    pop bx
    ret

; =====================================================================
;  Data
; =====================================================================
boot_drive  db 0
text_color  db 0x0B             ; light cyan
num_a       dw 0
calc_op     db 0
kbd_layout  db 0                ; 0 = Italian, 1 = US
lang        db 0                ; 0 = English, 1 = Italiano

; Italian layout (scancode set 1 -> codepage 437)
kbd_it:
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x31, 0x21, 0x00, 0x00, 0x21, 0, 0, 0   ; sc 0x02
    db 0x32, 0x22, 0x00, 0x00, 0x40, 0, 0, 0   ; sc 0x03
    db 0x33, 0x9C, 0x00, 0x00, 0x23, 0, 0, 0   ; sc 0x04
    db 0x34, 0x24, 0x00, 0x00, 0x24, 0, 0, 0   ; sc 0x05
    db 0x35, 0x25, 0x00, 0x00, 0x25, 0, 0, 0   ; sc 0x06
    db 0x36, 0x26, 0x00, 0x00, 0x5E, 0, 0, 0   ; sc 0x07
    db 0x37, 0x2F, 0x00, 0x00, 0x26, 0, 0, 0   ; sc 0x08
    db 0x38, 0x28, 0x00, 0x00, 0x2A, 0, 0, 0   ; sc 0x09
    db 0x39, 0x29, 0x00, 0x00, 0x28, 0, 0, 0   ; sc 0x0A
    db 0x30, 0x3D, 0x00, 0x00, 0x29, 0, 0, 0   ; sc 0x0B
    db 0x27, 0x3F, 0x60, 0x00, 0x5F, 0, 0, 0   ; sc 0x0C
    db 0x8D, 0x5E, 0x7E, 0x00, 0x2B, 0, 0, 0   ; sc 0x0D
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x8A, 0x82, 0x5B, 0x7B, 0x7B, 0, 0, 0   ; sc 0x1A
    db 0x2B, 0x2A, 0x5D, 0x7D, 0x7D, 0, 0, 0   ; sc 0x1B
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x95, 0x87, 0x40, 0x00, 0x3A, 0, 0, 0   ; sc 0x27
    db 0x85, 0xF8, 0x23, 0x00, 0x22, 0, 0, 0   ; sc 0x28
    db 0x5C, 0x7C, 0x00, 0x00, 0x7E, 0, 0, 0   ; sc 0x29
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x97, 0x15, 0x00, 0x00, 0x7C, 0, 0, 0   ; sc 0x2B
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x2C, 0x3B, 0x00, 0x00, 0x3C, 0, 0, 0   ; sc 0x33
    db 0x2E, 0x3A, 0x00, 0x00, 0x3E, 0, 0, 0   ; sc 0x34
    db 0x2D, 0x5F, 0x00, 0x00, 0x3F, 0, 0, 0   ; sc 0x35
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0, 0, 0
    db 0x3C, 0x3E, 0x00, 0x00, 0x7C, 0, 0, 0   ; sc 0x56

s_help      db "help", 0
s_aiuto     db "aiuto", 0
s_clear     db "clear", 0
s_lindo     db "lindo", 0
s_version   db "version", 0
s_versione  db "versione", 0
s_echo      db "echo", 0
s_eco       db "eco", 0
s_time      db "time", 0
s_ora       db "ora", 0
s_date      db "date", 0
s_data      db "data", 0
s_memory    db "memory", 0
s_memoria   db "memoria", 0
s_calc      db "calc", 0
s_color     db "color", 0
s_colore    db "colore", 0
s_keyboard  db "keyboard", 0
s_tastiera  db "tastiera", 0
s_language  db "language", 0
s_lingua    db "lingua", 0
s_reboot    db "reboot", 0
s_riavvia   db "riavvia", 0
s_shutdown  db "shutdown", 0
s_spegni    db "spegni", 0
s_it        db "it", 0
s_us        db "us", 0
s_en        db "en", 0

msg_choose  db "oruaM OS 1.0", 13, 10, 13, 10
            db "  Select language / Seleziona la lingua:", 13, 10, 13, 10
            db "    [1] English", 13, 10
            db "    [2] Italiano", 13, 10, 0

banner      db "                         __  __         ___    ____", 13, 10
            db "   ___  _ __ _   _  __ _|  \/  |   *    / _ \  / __|", 13, 10
            db "  / _ \| '__| | | |/ _` | |\/| |   ^   |  | | \___ \", 13, 10
            db " | (_) | |  | |_| | (_| | |  | |  | |  ||_|  |___) |", 13, 10
            db "  \___/|_|   \__,_|\__,_|_|  |_|  \|   \___/ | ____/", 13, 10, 13, 10, 0
prompt      db "oruaM> ", 0

; ---------------------------------------------------------------------
;  Language tables: English string, Italian string
; ---------------------------------------------------------------------
t_subtitle  dw m_subtitle_en, m_subtitle_it
t_ver       dw m_ver_en, m_ver_it
t_drive     dw m_drive_en, m_drive_it
t_unknown   dw m_unknown_en, m_unknown_it
t_rtc_err   dw m_rtc_err_en, m_rtc_err_it
t_kb        dw m_kb_en, m_kb_it
t_calc_use  dw m_calc_use_en, m_calc_use_it
t_overflow  dw m_overflow_en, m_overflow_it
t_divzero   dw m_divzero_en, m_divzero_it
t_remainder dw m_remainder_en, m_remainder_it
t_kbd       dw m_kbd_en, m_kbd_it
t_kbd_use   dw m_kbd_use_en, m_kbd_use_it
t_lang      dw m_lang_en, m_lang_it
t_lang_use  dw m_lang_use_en, m_lang_use_it
t_color     dw m_color_en, m_color_it
t_reboot    dw m_reboot_en, m_reboot_it
t_halt      dw m_halt_en, m_halt_it
t_safe      dw m_safe_en, m_safe_it

m_subtitle_en   db " 16-bit operating system - type 'help'", 13, 10, 13, 10, 0
m_subtitle_it   db " Sistema operativo a 16 bit - digita 'aiuto'", 13, 10, 13, 10, 0
m_ver_en        db "oruaM OS 1.0 - x86 real mode, 16-bit", 13, 10, 0
m_ver_it        db "oruaM OS 1.0 - x86 modalita' reale, 16 bit", 13, 10, 0
m_drive_en      db "Boot drive: 0x", 0
m_drive_it      db "Disco di avvio: 0x", 0
m_unknown_en    db "Unknown command. Type 'help'.", 13, 10, 0
m_unknown_it    db "Comando sconosciuto. Digita 'aiuto'.", 13, 10, 0
m_rtc_err_en    db "RTC clock not available.", 13, 10, 0
m_rtc_err_it    db "Orologio RTC non disponibile.", 13, 10, 0
m_kb_en         db " KB of conventional memory", 13, 10, 0
m_kb_it         db " KB di memoria convenzionale", 13, 10, 0
m_calc_use_en   db "Usage: calc <a> <op> <b>   e.g. calc 12 * 7", 13, 10, 0
m_calc_use_it   db "Uso: calc <a> <op> <b>   es. calc 12 * 7", 13, 10, 0
m_overflow_en   db "Overflow (max 65535)", 13, 10, 0
m_overflow_it   db "Overflow (max 65535)", 13, 10, 0
m_divzero_en    db "Division by zero!", 13, 10, 0
m_divzero_it    db "Divisione per zero!", 13, 10, 0
m_remainder_en  db " remainder ", 0
m_remainder_it  db " resto ", 0
m_kbd_en        db "Keyboard layout: ", 0
m_kbd_it        db "Layout tastiera: ", 0
m_kbd_use_en    db "Usage: keyboard it  or  keyboard us", 13, 10, 0
m_kbd_use_it    db "Uso: tastiera it  oppure  tastiera us", 13, 10, 0
m_lang_en       db "Language: ", 0
m_lang_it       db "Lingua: ", 0
m_lang_use_en   db "Usage: language en  or  language it", 13, 10, 0
m_lang_use_it   db "Uso: lingua en  oppure  lingua it", 13, 10, 0
m_color_en      db "New color set.", 13, 10, 0
m_color_it      db "Nuovo colore impostato.", 13, 10, 0
m_reboot_en     db "Press any key to restart...", 13, 10, 0
m_reboot_it     db "Premi un tasto per riavviare...", 13, 10, 0
m_halt_en       db "Shutting down...", 13, 10, 0
m_halt_it       db "Arresto del sistema...", 13, 10, 0
m_safe_en       db "It is now safe to turn off your computer.", 13, 10, 0
m_safe_it       db "Ora puoi spegnere il computer in sicurezza.", 13, 10, 0

t_help      dw help_en, help_it
help_en     db "Available commands (Italian names work too):", 13, 10
            db "  help              show this list", 13, 10
            db "  clear             clear the screen", 13, 10
            db "  version           system information", 13, 10
            db "  echo <text>       repeat the text", 13, 10
            db "  time              time from the RTC clock", 13, 10
            db "  date              date from the RTC clock", 13, 10
            db "  memory            conventional memory", 13, 10
            db "  calc <a> <op> <b> calculator (+ - * /)", 13, 10
            db "  color             change the prompt color", 13, 10
            db "  keyboard [it|us]  keyboard layout (default: it)", 13, 10
            db "  language [en|it]  change language", 13, 10
            db "  reboot            restart the computer", 13, 10
            db "  shutdown          power off the computer (APM)", 13, 10, 0
help_it     db "Comandi disponibili (anche in inglese):", 13, 10
            db "  aiuto             mostra questo elenco", 13, 10
            db "  lindo             pulisce lo schermo", 13, 10
            db "  versione          informazioni sul sistema", 13, 10
            db "  eco <testo>       ripete il testo", 13, 10
            db "  ora               ora dall'orologio RTC", 13, 10
            db "  data              data dall'orologio RTC", 13, 10
            db "  memoria           memoria convenzionale", 13, 10
            db "  calc <a> <op> <b> calcolatrice (+ - * /)", 13, 10
            db "  colore            cambia il colore del prompt", 13, 10
            db "  tastiera [it|us]  layout tastiera (predefinito: it)", 13, 10
            db "  lingua [en|it]    cambia lingua", 13, 10
            db "  riavvia           riavvia il computer", 13, 10
            db "  spegni            spegne il computer (APM)", 13, 10, 0

buffer      times MAX_INPUT + 1 db 0

times KERNEL_SECTORS * 512 - ($ - $$) db 0
