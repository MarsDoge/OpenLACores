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


/***************************************************************
 * Notes:
 *   The following codes only for simulation and FPGA implementation.
 *   if you customize chips, Please add code here.
 *
 ***************************************************************/

module openla132_spram_bytemask #(
    parameter Words = 1024,
    parameter Bits  = 64
) (
    output wire [         Bits-1: 0]  Q,
    input  wire                       CLK,
    input  wire                       CEN,
    input  wire                       LS,
    input  wire                       WEN,
    input  wire [   (Bits+7)/8-1: 0]  M,
    input  wire [$clog2(Words)-1: 0]  A,
    input  wire [         Bits-1: 0]  D
);

//============================================================//
//                Local Parameter Declarations
//============================================================//

localparam BYTE_NUM = (Bits + 7) / 8;

//============================================================//
//                   Module Implementation
//============================================================//

//------------------------------------------------------------//
//                  Byte-Masked SRAM Access
//------------------------------------------------------------//

genvar byte_idx;
generate
for(byte_idx = 0; byte_idx < BYTE_NUM; byte_idx = byte_idx + 1) begin : gen_byte
    localparam BYTE_BITS = ((byte_idx + 1) * 8 <= Bits)
                         ? 8 : Bits - byte_idx * 8;

    (* ram_style = "distributed" *) reg [BYTE_BITS-1: 0] mem [0:Words-1];
    reg [BYTE_BITS-1: 0] rdata_r;

    always @ ( posedge CLK )
    begin
        if(!CEN && !LS) begin
            if(!WEN) begin
                if(!M[byte_idx]) begin
                    mem[A] <= D[8*byte_idx +: BYTE_BITS];
                end
            end
            else begin
                rdata_r <= mem[A];
            end
        end
    end

    assign Q[8*byte_idx +: BYTE_BITS]  =  rdata_r;
end
endgenerate


endmodule  // openla132_spram_bytemask
