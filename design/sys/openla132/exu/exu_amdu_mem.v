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

module exu_amdu_mem (
    input  wire           clk,
    input  wire           reset,
    input  wire           data_reset,

    input  wire           mem_begin,
    input  wire           mem_do_div,

    input  wire [ 31: 0]  de_opa_abs,  // mul:abs(multiplier);   div:abs(divident)
    input  wire [ 31: 0]  de_opb_abs,  // mul:abs(multiplicant); div:~abs(divisor)+1
    input  wire           de_res_h_neg,
    input  wire           de_res_l_neg,

    output wire [ 31: 0]  mem_res_h,  // mul:product[63:32];    div:remainer
    output wire [ 31: 0]  mem_res_l,  // mul:product[31: 0];    div:quotient
    output wire           mem_complete
);

//============================================================//
//                     Regs Declarations
//============================================================//

// serial mul/div
//              ______ :b_r[31:0]: multiplicand/~divisor+1
//             |__32__|
//                |     32'd0
//            ____|_____|__
//            \___________/---sel: a_r[0]
// ________32      |
// |      |        |
// |   __\|/__  __\|/__
// |   \      \/      /
// |    \_____+______/
// |          |
// |        _\|/_________ :a_r[63:0]
// |       |__32__|__32__|
// |          |   |            for mul        /   for div
// |          |   |init:{0,multiplier}        /   {0,divident}
// |          |          shift-->             /     <--shift
// |__________|  update:{sum[32:0],a_r[31:1]} / {(new_quot?sum[31:0]:a_r[62:31]),a_r[30:0],new_quot}
//               result:{product}             / {remainder,quotient}
//
reg          mem_res_h_neg;
reg          mem_res_l_neg;
reg [ 63: 0] a_r;
reg [ 31: 0] b_r;

// count
reg [  5: 0] cnt;

//============================================================//
//                     Wire Declarations
//============================================================//

wire [ 63: 0] add33_res;
wire          iter_complete;
wire          cnt_acc_lo;
wire          cnt_acc_hi;

wire          new_quot;
wire [ 32: 0] update_a_h;

// 32 adder
wire [ 31: 0] adder_2;
wire [ 32: 0] adder_sum;

// res abs
wire [ 31: 0] h_abs;
wire [ 31: 0] l_abs;

// res abs
wire [ 31: 0] h_abs_not;
wire [ 31: 0] l_abs_not;

// 33bit-adder 32
wire [ 32: 0] add33_a;
wire [ 32: 0] add33_b;
wire          add33_cin;

wire          add33_cin_t;

//============================================================//
//                    Module Implementation
//============================================================//

always @ ( posedge clk )
begin
    // a_r
    if(data_reset) begin
        a_r[63:32] <= 32'd0;
        a_r[31:0]  <= 32'd0;
    end
    else if(mem_begin) begin
        a_r[63:32] <= 32'd0;
        a_r[31:0]  <= de_opa_abs;
    end
    else if(!iter_complete) begin
        if(mem_do_div) begin
            a_r <= {update_a_h[31:0], a_r[30:0], new_quot};
        end
        else begin
            a_r <= {update_a_h, a_r[31:1]};
        end
    end

    // b_r
    if(data_reset) begin
        b_r <= 32'd0;
    end
    else if(mem_begin) begin
        b_r <= de_opb_abs;
    end
    else if(cnt_acc_lo) begin
        b_r <= add33_res[31:0];
    end
    // res_neg
    if(data_reset) begin
        mem_res_h_neg <= 1'b0;
        mem_res_l_neg <= 1'b0;
    end
    else if(mem_begin) begin
        mem_res_h_neg <= de_res_h_neg;
        mem_res_l_neg <= de_res_l_neg;
    end
    else if(cnt_acc_lo) begin  // register lo-adder cout for hi-adder
        mem_res_l_neg <= add33_res[32];
    end
end

// assign adder_1       = {1'd0,a_r[63:32]};
assign adder_2[31:0]  =  (a_r[0] || mem_do_div) ? b_r : 32'd0;
// assign adder_sum     = adder_1 + adder_2;
assign adder_sum  =  add33_res[32:0];

assign new_quot          =  ~adder_sum[32];
assign update_a_h[32]    =  adder_sum[32];
assign update_a_h[31:0]  =  (mem_do_div && adder_sum[32]) ? a_r[62:31] : adder_sum[31:0];

always @ ( posedge clk )
begin
    if(reset) begin
        cnt <= 6'b10_0001;  // to set iter_complete/mem_complete
    end
    else if(mem_begin) begin
        cnt <= 6'b00_0000;
    end
    else if(!mem_complete) begin
        cnt <= cnt + 1'b1;
    end
end
assign iter_complete  =  cnt[5];
assign cnt_acc_lo     =  iter_complete & ~cnt[0];
assign cnt_acc_hi     =  iter_complete & cnt[0];
assign mem_complete   =  cnt_acc_hi;
assign h_abs          =  a_r[63:32];
assign l_abs          =  a_r[31:0];

assign h_abs_not  =  {32{mem_res_h_neg & iter_complete}} ^ h_abs;
assign l_abs_not  =  {32{mem_res_l_neg}} ^ l_abs;

assign add33_a[32]    =  1'b0;
assign add33_a[31:0]  =  cnt_acc_lo ? l_abs_not :
                           mem_do_div && !cnt[5] ? a_r[62:31] : h_abs_not;  // h_abs_not include adder_1
assign add33_b[32]    =  mem_do_div;
assign add33_b[31:0]  =  iter_complete ? 32'h0 : adder_2[31:0];
assign add33_cin_t    =  mem_do_div & cnt[0] ? mem_res_h_neg : mem_res_l_neg;
assign add33_cin      =  iter_complete & add33_cin_t;

assign add33_res  =  add33_a + add33_b + add33_cin;

assign mem_res_h  =  add33_res[31:0];
assign mem_res_l  =  b_r;
endmodule  // exu_amdu_mem
