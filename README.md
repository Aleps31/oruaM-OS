# oruaM OS

English

A tiny 16-bit x86 real-mode operating system written in NASM assembly, booting from a floppy image or a CD.
It is bilingual: at boot it asks you to choose **English** or **Italiano**, and every command works in both languages.


## Structure
- `boot.asm` – bootloader (512 bytes, sector 1): loads the kernel at `0x1000:0000` and jumps to it.
- `kernel.asm` – kernel (8 KB, sectors 2–17) with a bilingual command-line shell.
- `Makefile` – assembles the code and builds the floppy image `os.img` (1.44 MB) and the ISO.
- `.github/workflows/pages.yml` – on every push, builds the OS and updates the preview on GitHub Pages.

## Build and run
```
sudo apt install nasm qemu-system-x86 xorriso
make          # builds os.img
make run      # runs it in QEMU
make iso      # builds the bootable ISO oruam-os.iso
qemu-system-i386 -cdrom oruam-os.iso
```
On Windows: install NASM and QEMU, then run `qemu-system-i386 -fda os.img`.
On a real PC: write `os.img` to a USB stick (e.g. with `dd` or Rufus in DD mode) and boot in BIOS/Legacy mode.

## Shell commands
| English | Italiano | Description |
|---|---|---|
| `help` | `aiuto` | list of commands |
| `clear` | `lindo` | clears the screen |
| `version` | `versione` | system info and boot drive |
| `echo <text>` | `eco <testo>` | repeats the text |
| `time` | `ora` | time from the RTC clock |
| `date` | `data` | date from the RTC clock |
| `memory` | `memoria` | conventional memory (KB) |
| `calc <a> <op> <b>` | `calc` | 16-bit integer calculator (+ - * /) |
| `color` | `colore` | changes the prompt color |
| `keyboard [it\|us]` | `tastiera [it\|us]` | keyboard layout (default: Italian) |
| `language [en\|it]` | `lingua [en\|it]` | switches the language |
| `reboot` | `riavvia` | restarts the computer |
| `shutdown` | `spegni` | powers off via APM |

## Memory map
| Address | Contents |
|---|---|
| `0x07C00` | bootloader (stack below it) |
| `0x10000` | kernel |

## Extending it
To add a command: write a `cmd_xxx` routine, its names `s_xxx` (English and Italian) and the lines in `cmd_table`.
Messages live in language tables (`t_xxx: dw m_xxx_en, m_xxx_it`) and are printed with `print_t`.
Next steps: reading a FAT12 file system, loading `.COM` programs, a custom interrupt handler (`int 21h`).

## Credits
- Browser emulator: [v86](https://github.com/copy/v86) (BSD-2-Clause).
- BIOS files in `web/bios/`: [SeaBIOS](https://www.seabios.org/) and VGABIOS (LGPL), from the v86 builds.
