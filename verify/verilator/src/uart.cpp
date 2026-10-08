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
#include <iostream>

namespace openla132::sim {

// Constructs the UART peripheral model.
Uart::Uart(bool quiet) : quiet(quiet) {}

// Handles a UART register read.
uint8_t Uart::read(uint32_t offset, bool consume_rx) {
  switch ((offset >> 2U) & 0x7U) {
    case 0:
      if (lcr & 0x80U) {
        return dll;
      }
      if (rx.empty()) {
        return 0;
      } else {
        uint8_t data = rx.front();
        if (consume_rx) {
          rx.pop_front();
        }
        return data;
      }
    case 1: return (lcr & 0x80U) ? dlm : ier;
    case 2: return 0x01U;
    case 3: return lcr;
    case 4: return mcr;
    case 5: return static_cast<uint8_t>(0x60U | (rx.empty() ? 0U : 0x01U));
    case 6: return 0xb0U;
    case 7: return scr;
    default: return 0;
  }
}

// Reports whether a register read removes data from the receive FIFO.
bool Uart::is_rx_data_read(uint32_t offset) const {
  return (((offset >> 2U) & 0x7U) == 0U) && !(lcr & 0x80U);
}

// Commits a previously deferred receive-data-register read.
void Uart::consume_rx_data(uint32_t offset) {
  if (is_rx_data_read(offset) && !rx.empty()) {
    rx.pop_front();
  }
}

// Handles a UART register write.
void Uart::write(uint32_t offset, uint8_t data) {
  switch ((offset >> 2U) & 0x7U) {
    case 0:
      if (lcr & 0x80U) {
        dll = data;
      } else {
        putchar(data);
      }
      break;
    case 1:
      if (lcr & 0x80U) {
        dlm = data;
      } else {
        ier = data;
      }
      break;
    case 3: lcr = data; break;
    case 4: mcr = data; break;
    case 7: scr = data; break;
    default: break;
  }
}

// Queues one host character for the receive-data register.
void Uart::receive(uint8_t data) {
  rx.push_back(data);
}

// Writes one character through the simulator's direct console aperture.
void Uart::write_console(uint8_t data) {
  putchar(data);
}

// Records a transmitted UART character and optionally echoes it to the host.
void Uart::putchar(uint8_t ch) {
  tx.push_back(static_cast<char>(ch));
  if (!quiet) {
    std::cout.put(static_cast<char>(ch));
    std::cout.flush();
  }
}

} // namespace openla132::sim
