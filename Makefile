ARCH = $(shell uname -m | sed s,i[3456789]86,ia32,)

#CC = gcc
#LD = ld

#LIB					= /usr/lib64
GNU_EFI_EFI_LIB		= gnu-efi/$(ARCH)/lib
GNU_EFI_GNUEFI_LIB	= gnu-efi/$(ARCH)/gnuefi
GNU_EFI_INCLUDE		= gnu-efi/inc
GNU_EFI_CRT_OBJS	= $(GNU_EFI_EFI_LIB)/crt0-efi-$(ARCH).o
GNU_EFI_LDS			= gnu-efi/gnuefi/elf_$(ARCH)_efi.lds
GNU_EFI_APPS		= gnu-efi/$(ARCH)/apps

OVMF_FD = /usr/share/edk2-ovmf/OVMF.fd

WARNING_FLAGS = -Wall \
		 		-Wextra \
				-Werror

INCLUDE_FLAGS = -I$(GNU_EFI_INCLUDE) \
		 		-I$(GNU_EFI_INCLUDE)/$(ARCH) \
		 		-I$(GNU_EFI_INCLUDE)/protocol

LINK_LIB_FLAGS = -L$(GNU_EFI_EFI_LIB) -L$(GNU_EFI_GNUEFI_LIB) -lefi -lgnuefi

CFLAGS = -std=c11 \
		 -fno-stack-protector \
		 -fpic \
		 -fshort-wchar \
		 -mno-red-zone \
		 $(WARNING_FLAGS) \
		 $(INCLUDE_FLAGS)
# -fno-stack-protector -- Stack protection is not supported by EFI
# -fpic                -- EFI requires that code be position-independent
# -fshort-wchar        -- EFI requires 16 bits strings
# -mno-red-zone        -- It is not safe to use red zone in EFI

ifeq ($(ARCH), x86_64)
CFLAGS += -DEFI_FUNCTION_WRAPPER
endif

LDFLAGS = -nostdlib \
		  -znocombreloc \
		  -shared \
		  -Bsymbolic \
		  -T $(GNU_EFI_LDS) \
		  $(LINK_LIB_FLAGS)

# -nostdlib 	-- No stdlib will be linked
# -znocombreloc -- Not combine relocation sections
# -shared 		-- LD can not create the final .efi file, create
#				   shared library instead
# -Bsymbolic 	-- Let references to global symbols to be bound to
#				   the definitions within the shared library
# -T $(EFI_LDS) -- EFI non-standard linker script

.PHONY: clean efi-shell all

all: hello.efi

clean:
	$(RM) *.o *.so *.efi
	$(RM) -r gnu-efi
	$(RM) gnu-efi.tar.bz2

gnu-efi.tar.bz2:
	$(RM) gnu-efi.tar.bz2
	wget --content-disposition \
		'https://sourceforge.net/projects/gnu-efi/files/latest/download'
	mv gnu-efi-*.tar.bz2 gnu-efi.tar.bz2

gnu-efi: gnu-efi.tar.bz2
	tar -xf gnu-efi.tar.bz2
	$(RM) -r gnu-efi
	mv gnu-efi-* gnu-efi
	make -C gnu-efi all || $(RM) -r gnu-efi

gnu-efi-readme: gnu-efi
	less ./gnu-efi/README.gnuefi

hello.o: hello.c gnu-efi
	$(CC) -c $(CFLAGS) hello.c -o $@

hello.so: hello.o gnu-efi
	$(LD) $(LDFLAGS) hello.o $(EFI_CRT_OBJS) -o $@

hello.efi: hello.so
	objcopy -j .text -j .sdata -j .data -j .dynamic \
	        -j .dynsym -j .rel -j .rela -j .reloc \
			--target=efi-app-$(ARCH) $^ $@

efi-shell: hello.efi
	cp -f $^ $(GNU_EFI_APPS)
	qemu-system-$(ARCH) -snapshot -net none -L . --bios $(OVMF_FD) \
					   -hda fat:$(GNU_EFI_APPS)
