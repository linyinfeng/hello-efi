ARCH = $(shell uname -m | sed s,i[3456789]86,ia32,)

GNU_EFI_ARCHIVE	    = gnu-efi.tar.bz2
GNU_EFI_DIR			= gnu-efi
GNU_EFI_APPS_SRC	= $(GNU_EFI_DIR)/apps
GNU_EFI_APPS		= $(GNU_EFI_DIR)/$(ARCH)/apps
OVMF_FD = /usr/share/edk2-ovmf/OVMF.fd

TARGETS = hello.efi

.PHONY: all clean efi-shell

all: $(TARGETS)

clean:
	$(RM) *.o *.so *.efi
	$(RM) -r gnu-efi
	$(RM) gnu-efi.tar.bz2

$(GNU_EFI_ARCHIVE):
	$(RM) $(GNU_EFI_ARCHIVE)
	wget 'https://sourceforge.net/projects/gnu-efi/files/latest/download' \
		 -O $(GNU_EFI_ARCHIVE)

$(GNU_EFI_DIR): $(GNU_EFI_ARCHIVE)
	tar -xf $<
	$(RM) -r $@
	mv gnu-efi-* $@
	cp $(GNU_EFI_APPS_SRC)/Makefile $(GNU_EFI_APPS_SRC)/Makefile.bak
	make -C $@ all || $(RM) -r $@

gnu-efi-readme: $(GNU_EFI_DIR)
	less ./gnu-efi/README.gnuefi

%.efi: %.c $(GNU_EFI_DIR)
	cp $< $(GNU_EFI_APPS_SRC)
	cp $(GNU_EFI_APPS_SRC)/Makefile.bak $(GNU_EFI_APPS_SRC)/Makefile
	sed --in-place "s/^TARGET_APPS = /TARGET_APPS = $@ /g" \
		$(GNU_EFI_APPS_SRC)/Makefile
	make -C $(GNU_EFI_DIR) apps

efi-shell: $(TARGETS)
	qemu-system-$(ARCH) -snapshot -net none -L . --bios $(OVMF_FD) \
					   -hda fat:$(GNU_EFI_APPS)
