# oruaM OS

Italiano

Un piccolo sistema operativo x86 a 16 bit in modalità reale, scritto in assembly NASM, che si avvia da floppy o da CD.
È bilingue: all'avvio chiede di scegliere **English** o **Italiano**, e ogni comando funziona in entrambe le lingue.


## Struttura
- `boot.asm` – bootloader (512 byte, settore 1): carica il kernel a `0x1000:0000` e ci salta.
- `kernel.asm` – kernel (8 KB, settori 2–17) con shell bilingue a riga di comando.
- `Makefile` – compila il codice e crea l'immagine floppy `os.img` (1,44 MB) e la ISO.
- `web/` – pagina dell'anteprima nel browser con l'emulatore [v86](https://github.com/copy/v86).
- `.github/workflows/pages.yml` – a ogni push compila il sistema e aggiorna l'anteprima su GitHub Pages.

## Compilare ed eseguire
```
sudo apt install nasm qemu-system-x86 xorriso
make          # crea os.img
make run      # avvia in QEMU
make iso      # crea la ISO avviabile oruam-os.iso
qemu-system-i386 -cdrom oruam-os.iso
```
Su Windows: installa NASM e QEMU e lancia `qemu-system-i386 -fda os.img`.
Per un PC reale: scrivi `os.img` su chiavetta USB (es. con `dd` o Rufus, modalità DD) e avvia in modalità BIOS/Legacy.

## Comandi della shell
| Italiano | English | Descrizione |
|---|---|---|
| `aiuto` | `help` | elenco comandi |
| `lindo` | `clear` | pulisce lo schermo |
| `versione` | `version` | info sistema e disco di avvio |
| `eco <testo>` | `echo <text>` | ripete il testo |
| `ora` | `time` | ora dall'orologio RTC |
| `data` | `date` | data dall'orologio RTC |
| `memoria` | `memory` | memoria convenzionale (KB) |
| `calc <a> <op> <b>` | `calc` | calcolatrice intera 16 bit (+ - * /) |
| `colore` | `color` | cambia colore del prompt |
| `tastiera [it\|us]` | `keyboard [it\|us]` | layout tastiera (predefinito italiano) |
| `lingua [en\|it]` | `language [en\|it]` | cambia lingua |
| `riavvia` | `reboot` | riavvia il computer |
| `spegni` | `shutdown` | spegnimento via APM |

## Mappa della memoria
| Indirizzo | Contenuto |
|---|---|
| `0x07C00` | bootloader (stack sotto di esso) |
| `0x10000` | kernel |

## Come estenderlo
Per aggiungere un comando: scrivi la routine `cmd_xxx`, i nomi `s_xxx` (inglese e italiano) e le righe in `cmd_table`.
I messaggi stanno in tabelle di lingua (`t_xxx: dw m_xxx_en, m_xxx_it`) e si stampano con `print_t`.
Passi successivi: lettura del file system FAT12, caricamento di programmi `.COM`, gestore di interrupt proprio (`int 21h`).
