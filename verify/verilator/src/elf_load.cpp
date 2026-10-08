// ------------------------------------------------------------------------------------//
//  Copyright (c) 2026 Loongson Technology Corporation Limited.
//
//  OpenLACores is licensed under Mulan PSL v2.
// 
//  You can use this software according to the terms and conditions of the Mulan PSL v2.
//
//  You may obtain a copy of Mulan PSL v2 at:
//           http://license.coscl.org.cn/MulanPSL2
// 
//  THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
//  KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
//  NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// 
//  See the Mulan PSL v2 for more details.
// ------------------------------------------------------------------------------------//

#include "sim.h"
#include <cstring>
#include <elf.h>
#include <fstream>
#include <limits>
#include <stdexcept>

#ifndef EM_LOONGARCH
#define EM_LOONGARCH 258
#endif

namespace openla132::sim {
namespace {

// Reads the complete binary contents of an image file.
std::vector<uint8_t> read_file(const std::string &file) {
  std::ifstream in(file, std::ios::binary | std::ios::ate);
  if (!in) {
    throw std::runtime_error("cannot open image: " + file);
  }
  std::streamsize size = in.tellg();
  if (size < 0) {
    throw std::runtime_error("cannot determine image size: " + file);
  }
  in.seekg(0, std::ios::beg);
  std::vector<uint8_t> data(static_cast<size_t>(size));
  if (size && !in.read(reinterpret_cast<char *>(data.data()), size)) {
    throw std::runtime_error("cannot read image: " + file);
  }
  return data;
}

// Safely reads one ELF object from the image buffer.
template <typename T> T read_obj(const std::vector<uint8_t> &file, size_t offset, const char *what) {
  if (offset > file.size() || sizeof(T) > file.size() - offset) {
    throw std::runtime_error(std::string("truncated ELF ") + what);
  }
  T obj{};
  std::memcpy(&obj, file.data() + offset, sizeof(obj));
  return obj;
}

// Parses an ELF image into loadable memory segments.
template <typename Ehdr, typename Phdr> Image load_elf(const std::vector<uint8_t> &file, bool elf64) {
  Ehdr ehdr = read_obj<Ehdr>(file, 0, "header");
  if (ehdr.e_ident[EI_DATA] != ELFDATA2LSB || ehdr.e_ident[EI_VERSION] != EV_CURRENT) {
    throw std::runtime_error("only little-endian ELF version 1 images are supported");
  }
  if (ehdr.e_machine != EM_LOONGARCH) {
    throw std::runtime_error("ELF image is not for LoongArch");
  }
  if (ehdr.e_phentsize != sizeof(Phdr)) {
    throw std::runtime_error("unexpected ELF program-header size");
  }

  Image image;
  image.entry = static_cast<uint32_t>(ehdr.e_entry);
  for (uint16_t index = 0; index < ehdr.e_phnum; index++) {
    uint64_t offset = static_cast<uint64_t>(ehdr.e_phoff) + static_cast<uint64_t>(index) * ehdr.e_phentsize;
    if (offset > std::numeric_limits<size_t>::max()) {
      throw std::runtime_error("ELF program-header offset is too large");
    }

    Phdr phdr = read_obj<Phdr>(file, static_cast<size_t>(offset), "program header");
    if (phdr.p_type != PT_LOAD || phdr.p_memsz == 0) {
      continue;
    }
    if (phdr.p_filesz > phdr.p_memsz) {
      throw std::runtime_error("ELF load segment has file size larger than memory size");
    }

    uint64_t file_offset = phdr.p_offset;
    uint64_t file_size = phdr.p_filesz;
    if (file_offset > file.size() || file_size > file.size() - file_offset) {
      throw std::runtime_error("ELF load segment exceeds file bounds");
    }

    uint64_t addr = phdr.p_paddr ? phdr.p_paddr : phdr.p_vaddr;
    if (elf64) {
      addr &= UINT32_MAX;
    }
    uint64_t mem_size = phdr.p_memsz;
    if (addr > UINT32_MAX || mem_size > (1ULL << 32) - addr) {
      throw std::runtime_error("ELF load segment exceeds the 32-bit address space");
    }

    Segment seg;
    seg.addr = static_cast<uint32_t>(addr);
    seg.data.resize(static_cast<size_t>(mem_size), 0);
    if (file_size) {
      std::memcpy(seg.data.data(), file.data() + static_cast<size_t>(file_offset), static_cast<size_t>(file_size));
    }
    image.segments.push_back(std::move(seg));
  }
  if (image.segments.empty()) {
    throw std::runtime_error("ELF image contains no loadable segment");
  }
  return image;
}

} // namespace

// Loads an ELF or raw binary program image.
Image load_image(const std::string &path, uint32_t raw_addr) {
  std::vector<uint8_t> file = read_file(path);
  bool elf = file.size() >= SELFMAG && std::memcmp(file.data(), ELFMAG, SELFMAG) == 0;
  if (elf) {
    if (file.size() <= EI_CLASS) {
      throw std::runtime_error("truncated ELF identification");
    }
    if (file[EI_CLASS] == ELFCLASS32) {
      return load_elf<Elf32_Ehdr, Elf32_Phdr>(file, false);
    }
    if (file[EI_CLASS] == ELFCLASS64) {
      return load_elf<Elf64_Ehdr, Elf64_Phdr>(file, true);
    }
    throw std::runtime_error("unsupported ELF class");
  }

  if (static_cast<uint64_t>(raw_addr) + file.size() > (1ULL << 32)) {
    throw std::runtime_error("raw image exceeds the 32-bit address space");
  }
  Image image;
  image.entry = raw_addr;
  image.segments.push_back({raw_addr, std::move(file)});
  return image;
}

} // namespace openla132::sim
