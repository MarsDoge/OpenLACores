// See LICENSE for license details.

.section ".payload"

.globl _payload_start, _payload_end
_payload_start:
  .incbin BL_PAYLOAD
_payload_end:
