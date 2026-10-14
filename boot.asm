; =====================================================================
;  Bootloader of the 16-bit operating system "oruaM OS"
;  Loaded by the BIOS at address 0x0000:0x7C00 (512 bytes).
; =====================================================================
[org 0x7C00]
[bits 16]

KERNEL_SEG      equ 0x1000      ; the kernel is loaded at 0x1000:0000 (=0x10000)
KERNEL_SECTORS  equ 16          ; 16 sectors = 8 KB

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00              ; the stack grows downward below the bootloader
    sti

    mov [boot_drive], dl        ; the BIOS passes the boot drive number in DL

    mov si, msg_load
    call print

    mov cx, 3                   ; up to 3 read attempts
.retry:
    push cx
    mov ax, KERNEL_SEG
    mov es, ax
    xor bx, bx                  ; ES:BX = destination
    mov ah, 0x02                ; BIOS: read sectors
    mov al, KERNEL_SECTORS
    mov ch, 0                   ; cylinder 0
    mov cl, 2                   ; from sector 2 (sector 1 is the bootloader)
    mov dh, 0                   ; head 0
    mov dl, [boot_drive]
    int 0x13
    pop cx
    jnc .ok

    xor ah, ah                  ; error: reset the disk and retry
    mov dl, [boot_drive]
    int 0x13
    loop .retry

    mov si, msg_err
    call print
.hang:
    cli
    hlt
    jmp .hang

.ok:
    mov dl, [boot_drive]        ; pass the boot drive to the kernel
    jmp KERNEL_SEG:0x0000       ; far jump to the kernel

; --- print zero-terminated string (DS:SI) ---
print:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    jmp print
.done:
    ret

boot_drive  db 0
msg_load    db "Loading kernel...", 13, 10, 0
msg_err     db "Disk read error!", 0

times 510 - ($ - $$) db 0
dw 0xAA55                       ; boot signature
