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

module exu_smdu_mem (
    input  wire           clk,
    input  wire           reset,
    input  wire           data_reset,

    input  wire           mem_begin,
    input  wire           mem_do_div,

    input  wire [ 31: 0]  de_opa_abs,  // mul:abs(multiplier);   div:abs(divident)
    input  wire [ 31: 0]  de_opb_abs,  // mul:abs(multiplicant); div:~abs(divisor)+1
    input  wire           de_do_div,
    input  wire           de_res_h_neg,
    input  wire           de_res_l_neg,

    output wire [ 31: 0]  mem_res_h,  // mul:product[63:32];    div:remainer
    output wire [ 31: 0]  mem_res_l,  // mul:product[31: 0];    div:quotient
    output wire           mem_complete
);

//============================================================//
//                     Regs Declarations
//============================================================//

// mem-satge
reg          mem_res_h_neg;
reg          mem_res_l_neg;
reg [  3: 0] mem_opb_f1;
reg [ 64: 0] a_r;
reg [ 31: 0] b_r;

// count
reg [  5: 0] cnt;

//============================================================//
//                     Wire Declarations
//============================================================//

wire [  4: 0] in_lmask_dec;
wire [ 31: 0] out_lmask_dec;

// de-stage, count leading zeros in de_opb
wire [  3: 0] de_opb_f1;
wire [  3: 0] de_opb_p_f1;
wire [  3: 0] de_opb_n_f0;

wire [ 64: 0] div_a_r_init;
wire [ 64: 0] mul_a_r_init;

wire [ 33: 0] add33_res;
wire          iter_complete;
wire          cnt_acc_lo;
wire          cnt_acc_hi;
wire [ 32: 0] cnt_dec;        // see cnt

wire          new_quot;
wire [ 31: 0] div_new_a_h;

// div: count leading zeros in a_r[63:32]
wire          b_r_clo_4;
wire [ 32: 0] a_r_h;
wire [  4: 0] a_r_h_f1;
wire [  3: 0] div_shift_zero;

// mul: count leading zeros in a_r[31: 0]
wire [ 31: 0] a_r_l;
wire [  3: 0] a_r_l_f1;

wire [ 64: 0] div_update_a;
wire [ 64: 0] mul_update_a;

// 32 adder
wire [ 31: 0] adder_2;
wire [ 32: 0] adder_sum;

wire [  5: 0] next_cnt;
wire [  5: 0] cnt_step;
wire [  5: 0] div_cnt_step;
wire [  5: 0] mul_cnt_step;

// res abs
wire [ 63: 0] a_r_res;

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
// |        _\|/_________ :a_r[64:0]
// |       |__32__|__33__|
// |          |   |            for mul           /   for div
// |          |   |init:{0,seperator,multiplier} /   {0,divident,seperator}
// |          |          shift-->                /     <--shift
// |__________|  update:{sum[32:0],a_r[32:1]}    / {(new_quot?sum[31:0]:a_r[63:32]),a_r[31:0],new_quot}
//               result:{product}                / {remainder,quotient}
//

// Instance Boundary Alias Mapping
// x_exu_dec_lmask_5_32

assign in_lmask_dec   =  cnt[4:0];
assign cnt_dec[31:0]  =  out_lmask_dec;

assign de_opb_f1       =  de_do_div ? de_opb_n_f0 : de_opb_p_f1;
assign de_opb_p_f1[3]  =  (|de_opb_abs[31:24]);
assign de_opb_p_f1[2]  =  (|de_opb_abs[23:16]);
assign de_opb_p_f1[1]  =  (|de_opb_abs[15:8]);
assign de_opb_p_f1[0]  =  (|de_opb_abs[7:0]);
assign de_opb_n_f0[3]  =  ~(&de_opb_abs[31:23]);  // [24]==1'b1,[23:0]==0, [24] is 1
assign de_opb_n_f0[2]  =  ~(&de_opb_abs[22:15]);
assign de_opb_n_f0[1]  =  ~(&de_opb_abs[14:7]);
assign de_opb_n_f0[0]  =  1'b1;  // divident won't be zero
assign div_a_r_init    =  de_opb_f1[3] ? {32'd0, de_opa_abs, 1'b0} :
                            de_opb_f1[2] ? {24'd0, de_opa_abs, 1'b0, 8'h0} : de_opb_f1[1] ? {16'd0, de_opa_abs, 1'b0, 16'h0} :
                            de_opb_f1[0] ? {8'd0, de_opa_abs, 1'b0, 24'h0} : {de_opa_abs, 1'b0, 32'h0};
assign mul_a_r_init    =  {32'h0000_0000, 1'b1, de_opa_abs};

assign b_r_clo_4          =  &b_r[31:27];
assign a_r_h              =  a_r[64:32] | {9'd0, cnt_dec[32:9]} | {5'd0, cnt_dec[32:5] & {28{~b_r_clo_4}}};
assign a_r_h_f1[4]        =  (|a_r_h[32:26]);  // 1bit+6bit
assign a_r_h_f1[3]        =  (|a_r_h[25:22]);  // 4bit
assign a_r_h_f1[2]        =  (|a_r_h[21:18]);  // 4bit
assign a_r_h_f1[1]        =  (|a_r_h[17:14]);  // 4bit
assign a_r_h_f1[0]        =  (|a_r_h[13:10]);  // 4bit
assign div_shift_zero[3]  =  a_r_h_f1[4] || a_r_h_f1[3] && b_r_clo_4;  // no shift
assign div_shift_zero[2]  =  b_r_clo_4 ? a_r_h_f1[2] : a_r_h_f1[3];  // shift 2  bits;
assign div_shift_zero[1]  =  b_r_clo_4 ? a_r_h_f1[1] : a_r_h_f1[2];  // shift 6  bits;
assign div_shift_zero[0]  =  b_r_clo_4 ? a_r_h_f1[0] : a_r_h_f1[1];  // shift 10 bits;

assign a_r_l        =  a_r[31:0];
assign a_r_l_f1[3]  =  (|a_r_l[13:10]);  // 4bit
assign a_r_l_f1[2]  =  (|a_r_l[9 : 6]);  // 4bit
assign a_r_l_f1[1]  =  (|a_r_l[5 : 2]);  // 4bit
assign a_r_l_f1[0]  =  (|a_r_l[1 : 0]);  // 2bit

assign div_update_a  =  div_shift_zero[3] ? {div_new_a_h, a_r[31:0], new_quot} : div_shift_zero[2] ? {a_r[62:0], 2'd0} :
                          div_shift_zero[1] ? {a_r[58:0], 6'd0} : div_shift_zero[0] ? {a_r[54:0], 10'd0} : {a_r[50:0], 14'd0};
assign mul_update_a  =  a_r_l_f1[0] ? {add33_res[32:0], a_r[32:1]} : a_r_l_f1[1] ? {2'd0, a_r[64:2]} :
                          a_r_l_f1[2] ? {6'd0, a_r[64:6]} : a_r_l_f1[3] ? {10'd0, a_r[64:10]} : {14'd0, a_r[64:14]};
always @ ( posedge clk )
begin
    // a_r
    if(data_reset) begin
        a_r <= 65'd0;
    end
    else if(mem_begin) begin
        a_r <= de_do_div ? div_a_r_init : mul_a_r_init;
    end
    else if(!iter_complete) begin
        if(mem_do_div) begin
            a_r <= div_update_a;
        end
        else begin
            a_r <= mul_update_a;
        end
    end

    // b_r
    if(data_reset) begin
        b_r <= 32'd0;
    end
    else if(mem_begin) begin
        b_r <= de_opb_f1[3] ? de_opb_abs : de_opb_f1[2] ? {de_opb_abs[23:0], 8'd0} :
        de_opb_f1[1] ? {de_opb_abs[15:0], 16'd0} : {de_opb_abs[7:0], 24'd0};
    end
    else if(cnt_acc_lo) begin
        b_r <= add33_res[31:0];
    end
    // res_neg
    if(data_reset) begin
        mem_res_h_neg <= 1'd0;
        mem_res_l_neg <= 1'd0;
        mem_opb_f1    <= 4'd0;
    end
    else if(mem_begin) begin
        mem_res_h_neg <= de_res_h_neg;
        mem_res_l_neg <= de_res_l_neg;
        mem_opb_f1    <= de_opb_f1;
    end
    else if(cnt_acc_lo) begin  // register lo-adder cout for hi-adder
        mem_res_l_neg <= add33_res[32];
    end
end

// assign adder_1       = {1'd0,a_r[63:32]};
assign adder_2[31:0]  =  (a_r[0] || mem_do_div) ? b_r : 32'd0;
// assign adder_sum     = adder_1 + adder_2;
assign adder_sum  =  add33_res[32:0];

assign new_quot     =  ~adder_sum[32];
assign div_new_a_h  =  adder_sum[32] ? a_r[63:32] : adder_sum[31:0];

assign cnt_dec[32]  =  cnt[5];
exu_dec_lmask_5_32 x_exu_dec_lmask_5_32 (
    .in  (in_lmask_dec ),
    .out (out_lmask_dec)
);

assign cnt_step      =  mem_do_div ? div_cnt_step : mul_cnt_step;
assign div_cnt_step  =  div_shift_zero[3] ? 6'd1 :
                          div_shift_zero[2] ? 6'd2 : div_shift_zero[1] ? 6'd6 : div_shift_zero[0] ? 6'd10 : 6'd14;
assign mul_cnt_step  =  a_r_l_f1[0] ? 6'd1 : a_r_l_f1[1] ? 6'd2 : a_r_l_f1[2] ? 6'd6 : a_r_l_f1[3] ? 6'd10 : 6'd14;
assign next_cnt      =  cnt + cnt_step;
always @ ( posedge clk )
begin
    if(data_reset) begin
        cnt <= 6'b10_0001;  // to set iter_complete/mem_complete
    end
    else if(mem_begin) begin
        cnt <= 6'd0;
    end
    else if(!mem_complete) begin
        cnt <= next_cnt;
    end
end
assign iter_complete  =  cnt[5];
assign cnt_acc_lo     =  iter_complete & ~cnt[0];
assign cnt_acc_hi     =  iter_complete & cnt[0];
assign mem_complete   =  cnt_acc_hi;
assign a_r_res        =  mem_opb_f1[3] ? a_r[64:1] : mem_opb_f1[2] ? {8'd0, a_r[64:9]} :
                           mem_opb_f1[1] ? {16'd0, a_r[64:17]} : mem_opb_f1[0] ? {24'd0, a_r[64:25]} : {32'd0, a_r[64:33]};
assign h_abs          =  a_r_res[63:32];
assign l_abs          =  mem_do_div ? a_r[31:0] : a_r_res[31:0];

assign h_abs_not  =  {32{mem_res_h_neg}} ^ h_abs;
assign l_abs_not  =  {32{mem_res_l_neg}} ^ l_abs;

assign add33_a[32]    =  mem_do_div ? a_r[64] : 1'b0;
assign add33_a[31:0]  =  iter_complete ? (cnt[0] ? h_abs_not : l_abs_not) : mem_do_div ? a_r[63:32] : a_r[64:33];
assign add33_b[32]    =  mem_do_div;
assign add33_b[31:0]  =  iter_complete ? 32'h0 : adder_2[31:0];
assign add33_cin_t    =  mem_do_div & cnt[0] ? mem_res_h_neg : mem_res_l_neg;
assign add33_cin      =  iter_complete & add33_cin_t;

assign add33_res  =  add33_a + add33_b + add33_cin;

assign mem_res_h  =  add33_res[31:0];
assign mem_res_l  =  b_r;
endmodule  // exu_smdu_mem
