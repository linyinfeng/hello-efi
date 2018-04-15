#include <efi.h>
#include <efilib.h>

EFI_STATUS
efi_main (EFI_HANDLE image, EFI_SYSTEM_TABLE *systab)
{
    InitializeLib(image, systab);
	SIMPLE_TEXT_OUTPUT_INTERFACE *conout = systab->ConOut;
	uefi_call_wrapper(conout->OutputString, 2, conout, L"Hello, World!\n\r");
	return EFI_SUCCESS;
}
