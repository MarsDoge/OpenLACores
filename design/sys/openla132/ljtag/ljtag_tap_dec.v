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

`include "openla132_global.h"

`ifdef OPEN132_HAS_LJTAG

module ljtag_tap_dec (
    input  wire           tap_lock,
    input  wire           tck_in,
    input  wire           trst_in,
    input  wire [  3: 0]  inst_in,
    input  wire [  3: 0]  curr_state,
    output reg  [ 13: 0]  select
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg          buffer_1_tap_lock;
reg          buffer_2_tap_lock;

reg          updateir_en;

//============================================================//
//                    Module Implementation
//============================================================//

`ifdef OPEN132_LJTAG_SYNC_RESET

always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        buffer_1_tap_lock <= 1'b0;
        buffer_2_tap_lock <= 1'b0;
    end
    else begin
        buffer_1_tap_lock <= tap_lock;
        buffer_2_tap_lock <= buffer_1_tap_lock;
    end
end

always @ ( posedge tck_in )
begin
    if(curr_state == 4'd15) begin
        updateir_en <= 1'b1;
    end
    else begin
        updateir_en <= 1'b0;
    end
end

always @ ( buffer_2_tap_lock
           or inst_in
         )
begin
    if(buffer_2_tap_lock) begin
        case(inst_in[3:0])
            4'd1 :   select = 14'b00_0000_0000_0001;
            4'd2 :   select = 14'b00_0000_0000_0000;
            4'd4 :   select = 14'b00_0000_0000_1000;
            default: select = 14'b00_0000_0100_0000;
        endcase
    end
    else begin
        case(inst_in[3:0])
            4'd0 :   select = 14'b00_0000_0100_0000;
            4'd1 :   select = 14'b00_0000_0000_0001;
            4'd2 :   select = 14'b00_0000_0000_0010;
            4'd3 :   select = 14'b00_0000_0000_0100;
            4'd4 :   select = 14'b00_0000_0000_1000;
            4'd5 :   select = 14'b00_0000_0001_0000;
            4'd6 :   select = 14'b00_0100_0000_0000;
            4'd7 :   select = 14'b01_0000_0001_1100;
            4'd8 :   select = 14'b00_0000_0010_1000;
            default: select = 14'b00_0000_0100_0000;
        endcase
    end
end

endmodule

`endif  // OPEN132_HAS_LJTAG
