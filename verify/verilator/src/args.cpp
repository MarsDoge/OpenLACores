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
#include <filesystem>
#include <sstream>
#include <stdexcept>

namespace openla132::sim {
namespace {

// Locates the repository root for the default reference-model path.
std::filesystem::path repo_root() {
  const std::filesystem::path source = __FILE__;
  if (source.is_absolute()) {
    return source.parent_path().parent_path().parent_path().parent_path();
  }

  std::error_code error;
  auto exe = std::filesystem::read_symlink("/proc/self/exe", error);
  if (!error) {
    return exe.parent_path().parent_path().parent_path().parent_path();
  }
  return std::filesystem::current_path();
}

// Parses a numeric command-line value with optional K, M, or G suffixes.
uint64_t parse_num(const std::string &text, const char *opt) {
  if (text.empty()) {
    throw std::runtime_error(std::string(opt) + " requires a value");
  }

  std::string num = text;
  uint64_t scale = 1;
  switch (num.back()) {
    case 'k':
    case 'K': scale = 1024ULL; break;
    case 'm':
    case 'M': scale = 1024ULL * 1024ULL; break;
    case 'g':
    case 'G': scale = 1024ULL * 1024ULL * 1024ULL; break;
    default: break;
  }
  if (scale != 1) {
    num.pop_back();
  }

  size_t end = 0;
  uint64_t value = std::stoull(num, &end, 0);
  if (end != num.size() || value > UINT64_MAX / scale) {
    throw std::runtime_error(std::string("invalid value for ") + opt + ": " + text);
  }
  return value * scale;
}

// Returns the required value following a command-line option.
std::string next_arg(int argc, char **argv, int &index, const char *opt) {
  if (++index >= argc) {
    throw std::runtime_error(std::string(opt) + " requires a value");
  }
  return argv[index];
}

// Parses an additional image load specification in FILE@ADDRESS form.
LoadSpec parse_load(const std::string &text) {
  size_t pos = text.rfind('@');
  if (pos == std::string::npos || pos == 0 || pos + 1 == text.size()) {
    throw std::runtime_error("--load expects FILE@ADDRESS");
  }
  uint64_t addr = parse_num(text.substr(pos + 1), "--load");
  if (addr > UINT32_MAX) {
    throw std::runtime_error("overlay load address exceeds the 32-bit physical address space");
  }
  return {text.substr(0, pos), static_cast<uint32_t>(addr)};
}

} // namespace

// Builds the simulator command-line help text.
std::string usage(const char *program) {
  std::ostringstream out;
  out << "Usage: " << program << " [options] -i IMAGE\n\n"
      << "Core options:\n"
      << "  -i, --image FILE       ELF32, ELF64 or raw program image\n"
      << "      --diff             enable reference comparison (default)\n"
      << "      --no-diff          run RTL without reference comparison\n"
      << "  -r, --ref FILE         reference shared library\n"
      << "      --ref-arch NAME    reference CPU profile (default: loongarch32s)\n"
      << "      --cpu-model NAME   microarchitecture Diff policy (default: la132)\n"
      << "      --ram-size SIZE    physical RAM aperture (default: 512M)\n"
      << "      --load-address N   raw image load address (default: 0x1c000000)\n"
      << "      --load FILE@ADDR   preload an additional ELF/raw image (repeatable)\n"
      << "      --boot-pc N        override reset PC instead of ELF entry\n\n"
      << "Run control:\n"
      << "      --max-cycles N     timeout in full clock cycles\n"
      << "      --max-commits N    stop successfully after N commits (0: unlimited)\n"
      << "      --reset-cycles N   reset duration (default: 32)\n"
      << "      --commit-log       print every retired instruction\n"
      << "      --quiet-uart       capture UART output without echoing it\n"
      << "      --trace FILE       write a VCD waveform\n"
      << "      --checkpoint FILE  periodically save resumable simulator state\n"
      << "      --checkpoint-interval N\n"
      << "                         checkpoint period in cycles (default: 10M)\n"
      << "      --restore FILE     resume from a saved checkpoint\n"
      << "  -h, --help             show this help\n\n"
      << "SIZE accepts decimal/hex values and K, M, or G suffixes.\n";
  return out.str();
}

// Parses and validates the simulator command-line configuration.
SimArgs parse_args(int argc, char **argv) {
  SimArgs args;
  args.ref = (repo_root() / "verify/loong-emu/build/la_emu_ref.so").string();

  for (int index = 1; index < argc; index++) {
    std::string arg = argv[index];
    if (arg == "-h" || arg == "--help") {
      args.help = true;
    } else if (arg == "-i" || arg == "--image") {
      args.image = next_arg(argc, argv, index, arg.c_str());
    } else if (arg == "-r" || arg == "--ref") {
      args.ref = next_arg(argc, argv, index, arg.c_str());
    } else if (arg == "--ref-arch") {
      args.ref_arch = next_arg(argc, argv, index, arg.c_str());
    } else if (arg == "--cpu-model") {
      args.cpu = next_arg(argc, argv, index, arg.c_str());
    } else if (arg == "--diff") {
      args.diff = true;
    } else if (arg == "--no-diff") {
      args.diff = false;
    } else if (arg == "--commit-log") {
      args.commit_log = true;
    } else if (arg == "--quiet-uart") {
      args.quiet_uart = true;
    } else if (arg == "--trace") {
      args.wave = next_arg(argc, argv, index, arg.c_str());
    } else if (arg == "--checkpoint") {
      args.checkpoint = next_arg(argc, argv, index, arg.c_str());
    } else if (arg == "--checkpoint-interval") {
      args.checkpoint_interval = parse_num(next_arg(argc, argv, index, arg.c_str()), arg.c_str());
    } else if (arg == "--restore") {
      args.restore = next_arg(argc, argv, index, arg.c_str());
    } else if (arg == "--max-cycles") {
      args.max_cycles = parse_num(next_arg(argc, argv, index, arg.c_str()), arg.c_str());
    } else if (arg == "--max-commits") {
      args.max_commits = parse_num(next_arg(argc, argv, index, arg.c_str()), arg.c_str());
    } else if (arg == "--reset-cycles") {
      uint64_t value = parse_num(next_arg(argc, argv, index, arg.c_str()), arg.c_str());
      if (value > UINT32_MAX) {
        throw std::runtime_error("reset cycle count exceeds 32 bits");
      }
      args.reset_cycles = static_cast<uint32_t>(value);
    } else if (arg == "--ram-size") {
      args.ram_size = parse_num(next_arg(argc, argv, index, arg.c_str()), arg.c_str());
    } else if (arg == "--load-address") {
      uint64_t value = parse_num(next_arg(argc, argv, index, arg.c_str()), arg.c_str());
      if (value > UINT32_MAX) {
        throw std::runtime_error("load address exceeds the 32-bit physical address space");
      }
      args.load_addr = static_cast<uint32_t>(value);
    } else if (arg == "--load") {
      args.loads.push_back(parse_load(next_arg(argc, argv, index, arg.c_str())));
    } else if (arg == "--boot-pc") {
      uint64_t value = parse_num(next_arg(argc, argv, index, arg.c_str()), arg.c_str());
      if (value > UINT32_MAX) {
        throw std::runtime_error("boot PC exceeds the 32-bit address space");
      }
      args.boot_pc = static_cast<uint32_t>(value);
      args.boot_pc_set = true;
    } else if (!arg.empty() && arg.front() == '-') {
      throw std::runtime_error("unknown option: " + arg);
    } else if (args.image.empty()) {
      args.image = arg;
    } else {
      throw std::runtime_error("unexpected positional argument: " + arg);
    }
  }

  if (!args.help && args.image.empty() && args.restore.empty()) {
    throw std::runtime_error("no program image or checkpoint specified");
  }
  if (args.ram_size == 0 || args.ram_size > (1ULL << 32)) {
    throw std::runtime_error("RAM size must be between 1 byte and 4 GiB");
  }
  if (args.max_cycles == 0) {
    throw std::runtime_error("max cycle count must be non-zero");
  }
  if (args.checkpoint.empty() && args.checkpoint_interval != 0) {
    throw std::runtime_error("--checkpoint-interval requires --checkpoint");
  }
  if (!args.checkpoint.empty() && args.checkpoint_interval == 0) {
    args.checkpoint_interval = 10ULL * 1000ULL * 1000ULL;
  }
  return args;
}

} // namespace openla132::sim
