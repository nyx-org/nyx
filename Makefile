override IMAGE_NAME := nyx

HOST_CC=gcc
SMP_CORES ?= 2

.PHONY: all
all: $(IMAGE_NAME).iso


.PHONY: run
run: run-$(ARCH)

.PHONY: run-x86_64
run-x86_64: ovmf $(IMAGE_NAME).iso
	qemu-system-x86_64 -M q35 -m 2G -enable-kvm -bios ovmf-x86_64/OVMF.fd -cpu host -cdrom $(IMAGE_NAME).iso -boot d -serial stdio -no-shutdown -no-reboot -cpu host -smp $(SMP_CORES)

.PHONY: run-aarch64
run-aarch64: ovmf $(IMAGE_NAME).iso
	qemu-system-aarch64 -M virt -cpu cortex-a72 -device ramfb -device qemu-xhci -device usb-kbd -m 2G -bios ovmf-aarch64/OVMF.fd -cdrom $(IMAGE_NAME).iso -boot d -serial stdio

.PHONY: run-riscv64
run-riscv64: ovmf $(IMAGE_NAME).iso
	qemu-system-riscv64 -M virt -cpu rv64 -device ramfb -device qemu-xhci -device usb-kbd -m 2G -drive if=pflash,unit=1,format=raw,file=ovmf-riscv64/OVMF.fd -device virtio-scsi-pci,id=scsi -device scsi-cd,drive=cd0 -drive id=cd0,format=raw,file=$(IMAGE_NAME).iso -serial stdio

.PHONY: run-bios
run-bios: $(IMAGE_NAME).iso
	qemu-system-x86_64 -M q35 -m 2G -cdrom $(IMAGE_NAME).iso -boot d

.PHONY: ovmf
ovmf: ovmf-$(ARCH)

ovmf-x86_64:
	mkdir -p ovmf-x86_64
	cd ovmf-x86_64 && curl -o OVMF.fd https://retrage.github.io/edk2-nightly/bin/RELEASEX64_OVMF.fd

ovmf-aarch64:
	mkdir -p ovmf-aarch64
	cd ovmf-aarch64 && curl -o OVMF.fd https://retrage.github.io/edk2-nightly/bin/RELEASEAARCH64_QEMU_EFI.fd

ovmf-riscv64:
	mkdir -p ovmf-riscv64
	cd ovmf-riscv64 && curl -o OVMF.fd https://retrage.github.io/edk2-nightly/bin/RELEASERISCV64_VIRT.fd && dd if=/dev/zero of=OVMF.fd bs=1 count=0 seek=33554432

limine:
	git clone https://github.com/limine-bootloader/limine.git --branch=v8.x-binary --depth=1
	$(MAKE) -C limine CC="$(HOST_CC)"


build/gaia.elf:

$(IMAGE_NAME).iso: build/gaia.elf limine
	rm -rf iso_root
	mkdir -p iso_root
	cp -r boot/boot/* iso_root/
	mkdir -p iso_root/EFI/BOOT
ifeq ($(ARCH),x86_64)
	cp -v limine/limine-bios.sys limine/limine-bios-cd.bin limine/limine-uefi-cd.bin iso_root/
	cp -v limine/BOOTX64.EFI iso_root/EFI/BOOT/
	cp -v limine/BOOTIA32.EFI iso_root/EFI/BOOT/
	xorriso -as mkisofs -b limine-bios-cd.bin \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		--efi-boot limine-uefi-cd.bin \
		-efi-boot-part --efi-boot-image --protective-msdos-label \
		iso_root -o $(IMAGE_NAME).iso
	./limine/limine bios-install $(IMAGE_NAME).iso
else ifeq ($(ARCH),aarch64)
	cp -v limine/limine-uefi-cd.bin iso_root/
	cp -v limine/BOOTAA64.EFI iso_root/EFI/BOOT/
	xorriso -as mkisofs \
		--efi-boot limine-uefi-cd.bin \
		-efi-boot-part --efi-boot-image --protective-msdos-label \
		iso_root -o $(IMAGE_NAME).iso
else ifeq ($(ARCH),riscv64)
	cp -v limine/limine-uefi-cd.bin iso_root/
	cp -v limine/BOOTRISCV64.EFI iso_root/EFI/BOOT/
	xorriso -as mkisofs \
		--efi-boot limine-uefi-cd.bin \
		-efi-boot-part --efi-boot-image --protective-msdos-label \
		iso_root -o $(IMAGE_NAME).iso
endif
	rm -rf iso_root

.PHONY: clean
clean:
	rm -rf iso_root $(IMAGE_NAME).iso $(IMAGE_NAME).hdd
