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

module ljtag_tap_fsm (
    input  wire           tck_in,
    input  wire           trst_in,
    input  wire           tms_in,
    output reg            ind,
    output reg            capture_ir,
    output reg            capture_dr,
    output reg            shift_ir,
    output reg            shift_dr,
    output reg            update_ir,
    output reg            update_dr,
    output wire           tlr,
    output reg            pr_enable,
    output wire           idle,
    output wire [  3: 0]  curr_state_out
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg [  3: 0] curr_state;
reg [  3: 0] next_state;

//============================================================//
//                    Module Implementation
//============================================================//

assign curr_state_out  =  curr_state;

assign idle  =  1'b1;

assign tlr  =  (curr_state == 4'd0);

always @ ( curr_state
           or tms_in
         )
begin
    case(curr_state)
        4'd0  : next_state = (tms_in == 1'b1) ? 4'd0  : 4'd1  ;
        4'd1  : next_state = (tms_in == 1'b1) ? 4'd2  : 4'd1  ;
        4'd2  : next_state = (tms_in == 1'b1) ? 4'd9  : 4'd3  ;
        4'd3  : next_state = (tms_in == 1'b1) ? 4'd5  : 4'd4  ;
        4'd4  : next_state = (tms_in == 1'b1) ? 4'd5  : 4'd4  ;
        4'd5  : next_state = (tms_in == 1'b1) ? 4'd8  : 4'd6  ;
        4'd6  : next_state = (tms_in == 1'b1) ? 4'd7  : 4'd6  ;
        4'd7  : next_state = (tms_in == 1'b1) ? 4'd8  : 4'd4  ;
        4'd8  : next_state = (tms_in == 1'b1) ? 4'd2  : 4'd1  ;
        4'd9  : next_state = (tms_in == 1'b1) ? 4'd0  : 4'd10 ;
        4'd10 : next_state = (tms_in == 1'b1) ? 4'd12 : 4'd11 ;
        4'd11 : next_state = (tms_in == 1'b1) ? 4'd12 : 4'd11 ;
        4'd12 : next_state = (tms_in == 1'b1) ? 4'd15 : 4'd13 ;
        4'd13 : next_state = (tms_in == 1'b1) ? 4'd14 : 4'd13 ;
        4'd14 : next_state = (tms_in == 1'b1) ? 4'd15 : 4'd11 ;
        4'd15 : next_state = (tms_in == 1'b1) ? 4'd2  : 4'd1  ;
        default:next_state = 4'd0 ;
    endcase
end

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        curr_state <= 4'd0;
    end
    else begin
        curr_state <= next_state;
    end
end

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        pr_enable <= 1'b0;
    end
    else begin
        pr_enable <= !( (next_state == 4'd3) ||
                      (next_state == 4'd4) ||
                      (next_state == 4'd5) ||
                      (next_state == 4'd6) ||
                      (next_state == 4'd7) ||
                      (next_state == 4'd8) );
    end
end

always @ ( posedge tck_in )
begin
    if(next_state==4'd10) begin
        ind <= 1'b1;
    end
    else if(next_state==4'd1 || next_state==4'd0 || next_state==4'd2) begin
        ind <= 1'b0;
    end
end
always @ ( posedge tck_in )
begin
    if(next_state==4'd10) begin
        capture_ir <= 1'b1;
    end
    else begin
        capture_ir <= 1'b0;
    end
end
always @ ( posedge tck_in )
begin
    if(next_state==4'd11) begin
        shift_ir <= 1'b1;
    end
    else begin
        shift_ir <= 1'b0;
    end
end
always @ ( posedge tck_in )
begin
    if(next_state==4'd15) begin
        update_ir <= 1'b1;
    end
    else begin
        update_ir <= 1'b0;
    end
end
always @ ( posedge tck_in )
begin
    if(next_state==4'd3) begin
        capture_dr <= 1'b1;
    end
    else begin
        capture_dr <= 1'b0;
    end
end
always @ ( posedge tck_in )
begin
    if(next_state==4'd4) begin
        shift_dr <= 1'b1;
    end
    else begin
        shift_dr <= 1'b0;
    end
end
always @ ( posedge tck_in )
begin
    if(next_state==4'd8) begin
        update_dr <= 1'b1;
    end
    else begin
        update_dr <= 1'b0;
    end
end
endmodule

`endif  // OPEN132_HAS_LJTAG
