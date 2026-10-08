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

module exu_qdiv (
    input  wire           clk,
    input  wire           reset,
    input  wire           data_reset,
    input  wire           de_cancel,
    input  wire           mem_cancel,

    input  wire           de_validout,
    input  wire [ 31: 0]  de_opa_abs,
    input  wire           de_quot_neg,
    input  wire           de_rem_neg,

    input  wire           mem_opb_neg,
    input  wire [ 31: 0]  mem_opb,
    input  wire           rtu_lsu_allowin,
    output wire           mem_valid,
    output wire           mem_complete,
    output wire [ 31: 0]  mem_quot_abs,
    output wire [ 31: 0]  mem_rem_abs,
    output reg            mem_quot_neg,
    output reg            mem_rem_neg
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg [  5: 0] cnt;

reg [ 32: 0] mem_r;
reg [ 30: 0] mem_q;

//============================================================//
//                     Wire Declarations
//============================================================//

wire [  5: 0] cnt_init;
wire [  5: 0] cnt_nxt;
wire          cnt_en;
wire          fsm_idle;
wire          fsm_last;

wire [ 32: 0] mem_r_nxt;
wire [ 31: 0] mem_q_nxt;
wire [ 31: 0] mem_q_rst;

wire [  3: 0] opa_zero;
wire          opa_clz_0;
wire          opa_clz_8;
wire          opa_clz_16;
wire          opa_clz_24;
wire          opa_clz_32;

wire [ 32: 0] adder_a;
wire [ 32: 0] adder_b;
wire          adder_cin;
wire [ 32: 0] adder_res;

//============================================================//
//                    Module Implementation
//============================================================//

// synopsys sync_set_reset "reset"
// the divider algol: absolute(opa)/complement(opb)
//                   alternate division

always @ ( posedge clk )
begin
    if(data_reset) begin
        mem_r        <= 33'd0;
        mem_q        <= 31'd0;
        mem_quot_neg <= 1'd0;
        mem_rem_neg  <= 1'd0;
    end
    else if(de_validout) begin
        mem_r        <= {32'd0, mem_q_rst[31]};
        mem_q        <= mem_q_rst[30:0];
        mem_quot_neg <= de_quot_neg;
        mem_rem_neg  <= de_rem_neg;
    end
    else if(!fsm_idle && !fsm_last) begin
        mem_r <= mem_r_nxt;
        mem_q <= mem_q_nxt[30:0];
    end
end

// quicky slide to the first effective bit.
assign opa_zero[3]  =  (de_opa_abs[31:24] == 8'b0);
assign opa_zero[2]  =  (de_opa_abs[23:16] == 8'b0);
assign opa_zero[1]  =  (de_opa_abs[15:8] == 8'b0);
assign opa_zero[0]  =  (de_opa_abs[7:0] == 8'b0);

assign opa_clz_0   =  (~opa_zero[3]);
assign opa_clz_8   =  (&opa_zero[3:3]) & (~opa_zero[2]);
assign opa_clz_16  =  (&opa_zero[3:2]) & (~opa_zero[1]);
assign opa_clz_24  =  (&opa_zero[3:1]) & (~opa_zero[0]);
assign opa_clz_32  =  (&opa_zero[3:0]);

assign mem_q_rst      =  {32{opa_clz_0}} & {de_opa_abs[31:0]} | {32{opa_clz_8}} & {de_opa_abs[23:0], 8'b0} |
                           {32{opa_clz_16}} & {de_opa_abs[15:0], 16'b0} | {32{opa_clz_24}} & {de_opa_abs[7:0], 24'b0};
assign adder_a        =  mem_r;
assign adder_b[32]    =  1'b1;
assign adder_b[31:0]  =  mem_opb[31:0] ^ {32{adder_cin}};
assign adder_cin      =  (!mem_opb_neg);
assign adder_res      =  adder_a + adder_b + adder_cin;

assign mem_r_nxt[32:1]  =  adder_res[32] ? mem_r[31:0] : adder_res[31:0];
assign mem_r_nxt[0]     =  mem_q[30];
assign mem_q_nxt        =  {mem_q[30:0], ~adder_res[32]};

// fsm for divide iteration
assign cnt_init  =  (opa_clz_32) ? 6'd31 : (opa_clz_24) ? 6'd24 : (opa_clz_16) ? 6'd16 : (opa_clz_8) ? 6'd8 : 6'd0;
assign cnt_nxt   =  cnt + 6'd1;
assign cnt_en    =  de_validout || !fsm_idle && !mem_complete;

always @ ( posedge clk )
begin
    if(reset || de_validout && de_cancel || mem_cancel) begin
        cnt <= 6'h3f;
    end
    else if(cnt_en) begin
        cnt <= (de_validout) ? cnt_init : cnt_nxt;
    end
    else if(mem_complete && rtu_lsu_allowin) begin
        cnt <= 6'h3f;
    end
end

assign fsm_idle  =  cnt[5];
assign fsm_last  =  cnt == 6'd31;

// output gen
assign mem_valid     =  !fsm_idle;
assign mem_complete  =  fsm_last;
assign mem_quot_abs  =  mem_q_nxt[31:0];
assign mem_rem_abs   =  mem_r_nxt[32:1];

endmodule  // exu_qdiv
