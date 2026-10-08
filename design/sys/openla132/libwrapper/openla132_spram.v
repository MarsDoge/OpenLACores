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

module openla132_spram #(
    parameter Words = 1024,
    parameter Bits  = 40
) (
    output wire [         Bits-1: 0]  Q,
    input  wire                       CLK,
    input  wire                       CEN,
    input  wire                       LS,
    input  wire                       WEN,
    input  wire [$clog2(Words)-1: 0]  A,
    input  wire [         Bits-1: 0]  D
);

//============================================================//
//                     Regs Declarations
//============================================================//


(* ram_style = "distributed" *) reg [Bits-1: 0] mem [Words-1: 0];
reg [Bits-1: 0] rdata_r;

//============================================================//
//                   Module Implementation
//============================================================//

//------------------------------------------------------------//
//                  Simulation Memory Model
//------------------------------------------------------------//

always @ ( posedge CLK )
begin
    if(!CEN && !LS) begin
        if(!WEN) begin
            mem[A] <= D;
        end
        else begin
            rdata_r <= mem[A];
        end
    end
end

assign Q  =  rdata_r;


endmodule  // openla132_spram
