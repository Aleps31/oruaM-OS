all: os.img

boot.bin: boot.asm
	nasm -f bin boot.asm -o boot.bin

kernel.bin: kernel.asm
	nasm -f bin kernel.asm -o kernel.bin

os.img: boot.bin kernel.bin
	dd if=/dev/zero of=os.img bs=512 count=2880 status=none
	dd if=boot.bin of=os.img conv=notrunc status=none
	dd if=kernel.bin of=os.img bs=512 seek=1 conv=notrunc status=none

iso: os.img
	mkdir -p iso && cp os.img iso/
	xorriso -as mkisofs -quiet -V ORUAM_OS -o oruam-os.iso -b os.img -c boot.cat iso

run: os.img
	qemu-system-i386 -fda os.img

clean:
	rm -rf boot.bin kernel.bin os.img oruam-os.iso iso

.PHONY: all iso run clean
