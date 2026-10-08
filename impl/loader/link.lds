/* See LICENSE for license details. */

OUTPUT_FORMAT("elf32-loongarch", "elf32-loongarch", "elf32-loongarch")
OUTPUT_ARCH(loongarch)
ENTRY(_start)

SECTIONS
{

  /*--------------------------------------------------------------------*/
  /* Code and read-only segment                                         */
  /*--------------------------------------------------------------------*/

  /* Begining of code and text segment */
  . = MEM_START;

  .text :
  {
    *(.text.init)
  }

  /* text: Program code section */
  .text :
  {
    *(.text)
    *(.text.*)
    *(.gnu.linkonce.t.*)
  }

  /* rodata: Read-only data */
  .rodata :
  {
    *(.rdata)
    *(.rodata)
    *(.rodata.*)
    *(.gnu.linkonce.r.*)
  }


  /* bss: Uninitialized writeable data section */
  . = .;
  _bss_start = .;
  .bss :
  {
    *(.bss)
    *(.bss.*)
    *(.sbss*)
    *(.gnu.linkonce.b.*)
    *(COMMON)
  }

  _end = .;

  ASSERT(_end <= LOADER_LIMIT, "loader overlaps the board status area")

  /*. = MEM_START + 0x400;*/
  .payload :
  {
    *(.payload)
  }
}
