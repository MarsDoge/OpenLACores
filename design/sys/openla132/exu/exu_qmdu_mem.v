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

module exu_qmdu_mem (
    input  wire           clk,
    input  wire           reset,
    input  wire           data_reset,
    input  wire           de_cancel,
    input  wire           mem_cancel,

    input  wire           de_validout,
    input  wire           de_multiply,
    input  wire           de_divide,
    input  wire [ 32: 0]  de_opa_ext_abs,
    input  wire [ 31: 0]  de_opb,
    input  wire [  8: 0]  de_mul_pp_neg,
    input  wire [  8: 0]  de_mul_pp_e,
    input  wire [  8: 0]  de_mul_sel_m,
    input  wire [  8: 0]  de_mul_sel_2m,
    input  wire           de_mul_half_size,
    input  wire           de_opb_neg,
    input  wire           de_div_quot_neg,
    input  wire           de_div_rem_neg,
    output reg            mem_opb_neg,
    output reg  [ 31: 0]  mem_opb,
    output wire           mem_mul_full_1st,  // feedback to boothenc @de stage
    output wire           mem_mul_opa_msb,

    input  wire           rtu_lsu_allowin,
    input  wire [ 36: 0]  wb_acc_res_52_16,
    output wire           mem_mul_complete,
    output wire           mem_div_complete,
    output wire           mem_divide_op,
    output wire           mem_mul_half,
    output wire           mem_mul_full_2nd,
    output wire           mem_mul_full_1st_out,
    output wire [ 51: 0]  mem_res_0,
    output wire [ 51: 0]  mem_res_1,
    output wire           mem_div_quot_neg,
    output wire           mem_div_rem_neg
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg [ 32: 0] mem_opa_33b;

//============================================================//
//                     Wire Declarations
//============================================================//

wire          clk_qmul;
wire          reset_qmul;
wire          data_reset_qmul;
wire          de_cancel_qmul;
wire          mem_cancel_qmul;
wire          de_validout_qmul;
wire [  8: 0] de_pp_neg_qmul;
wire [  8: 0] de_pp_e_qmul;
wire [  8: 0] de_sel_m_qmul;
wire [  8: 0] de_sel_2m_qmul;
wire          de_half_size_qmul;
wire [ 32: 0] mem_opa_33b_qmul;
wire          mem_full_1st_qmul;
wire          mem_opa_msb_qmul;
wire          rtu_lsu_allowin_qmul;
wire          mem_valid_qmul;
wire          mem_complete_qmul;
wire          mem_half_qmul;
wire          mem_full_2nd_qmul;
wire [ 36: 0] wb_acc_res_52_16_qmul;
wire          mem_full_1st_out_qmul;
wire [ 51: 0] mem_wallace_s_qmul;
wire [ 51: 0] mem_wallace_c_qmul;
wire          clk_qdiv;
wire          reset_qdiv;
wire          data_reset_qdiv;
wire          de_cancel_qdiv;
wire          mem_cancel_qdiv;
wire          de_validout_qdiv;
wire [ 31: 0] de_opa_abs_qdiv;
wire          de_quot_neg_qdiv;
wire          de_rem_neg_qdiv;
wire          mem_opb_neg_qdiv;
wire [ 31: 0] mem_opb_qdiv;
wire          rtu_lsu_allowin_qdiv;
wire          mem_valid_qdiv;
wire          mem_complete_qdiv;
wire [ 31: 0] mem_quot_abs_qdiv;
wire [ 31: 0] mem_rem_abs_qdiv;
wire          mem_quot_neg_qdiv;
wire          mem_rem_neg_qdiv;

wire          de_mul_validout;
wire          de_div_validout;
wire [ 31: 0] de_div_opa_abs;

wire          mem_mul_half_t;
wire          mem_mul_full_2nd_t;
wire          mem_mul_valid;
wire          mem_div_valid;
wire [ 51: 0] mem_mul_wallace_s;
wire [ 51: 0] mem_mul_wallace_c;
wire [ 31: 0] mem_div_quot_abs;
wire [ 31: 0] mem_div_rem_abs;

//============================================================//
//                    Module Implementation
//============================================================//

// synopsys sync_set_reset "reset"

// Instance Boundary Alias Mapping
// x_exu_qmul

assign clk_qmul               =  clk;
assign reset_qmul             =  reset;
assign data_reset_qmul        =  data_reset;
assign de_cancel_qmul         =  de_cancel;
assign mem_cancel_qmul        =  mem_cancel;
assign de_validout_qmul       =  de_mul_validout;
assign de_pp_neg_qmul         =  de_mul_pp_neg;
assign de_pp_e_qmul           =  de_mul_pp_e;
assign de_sel_m_qmul          =  de_mul_sel_m;
assign de_sel_2m_qmul         =  de_mul_sel_2m;
assign de_half_size_qmul      =  de_mul_half_size;
assign mem_opa_33b_qmul       =  mem_opa_33b;
assign mem_mul_full_1st       =  mem_full_1st_qmul;
assign mem_mul_opa_msb        =  mem_opa_msb_qmul;
assign rtu_lsu_allowin_qmul   =  rtu_lsu_allowin;
assign mem_mul_valid          =  mem_valid_qmul;
assign mem_mul_complete       =  mem_complete_qmul;
assign mem_mul_half_t         =  mem_half_qmul;
assign mem_mul_full_2nd_t     =  mem_full_2nd_qmul;
assign wb_acc_res_52_16_qmul  =  wb_acc_res_52_16;
assign mem_mul_full_1st_out   =  mem_full_1st_out_qmul;
assign mem_mul_wallace_s      =  mem_wallace_s_qmul;
assign mem_mul_wallace_c      =  mem_wallace_c_qmul;
// x_exu_qdiv
assign clk_qdiv              =  clk;
assign reset_qdiv            =  reset;
assign data_reset_qdiv       =  data_reset;
assign de_cancel_qdiv        =  de_cancel;
assign mem_cancel_qdiv       =  mem_cancel;
assign de_validout_qdiv      =  de_div_validout;
assign de_opa_abs_qdiv       =  de_div_opa_abs;
assign de_quot_neg_qdiv      =  de_div_quot_neg;
assign de_rem_neg_qdiv       =  de_div_rem_neg;
assign mem_opb_neg_qdiv      =  mem_opb_neg;
assign mem_opb_qdiv          =  mem_opb;
assign rtu_lsu_allowin_qdiv  =  rtu_lsu_allowin;
assign mem_div_valid         =  mem_valid_qdiv;
assign mem_div_complete      =  mem_complete_qdiv;
assign mem_div_quot_abs      =  mem_quot_abs_qdiv;
assign mem_div_rem_abs       =  mem_rem_abs_qdiv;
assign mem_div_quot_neg      =  mem_quot_neg_qdiv;
assign mem_div_rem_neg       =  mem_rem_neg_qdiv;

assign de_mul_validout  =  de_validout & de_multiply;
assign de_div_validout  =  de_validout & de_divide;
assign de_div_opa_abs   =  de_opa_ext_abs[31:0] & {32{!de_multiply}};  // for low power

always @ ( posedge clk )
begin
    if(data_reset) begin
        mem_opb_neg <= 1'd0;
        mem_opb     <= 32'd0;
    end
    else if(de_validout) begin
        mem_opb_neg <= de_opb_neg;
        mem_opb     <= de_opb;
    end

    if(data_reset) begin
        mem_opa_33b <= 33'd0;
    end
    else if(de_mul_validout) begin  // for low power
        mem_opa_33b <= de_opa_ext_abs;
    end
end

exu_qmul x_exu_qmul (
    .clk              (clk_qmul             ),  // I
    .reset            (reset_qmul           ),  // I
    .data_reset       (data_reset_qmul      ),  // I
    .de_cancel        (de_cancel_qmul       ),  // I
    .mem_cancel       (mem_cancel_qmul      ),  // I

    .de_validout      (de_validout_qmul     ),  // I
    .de_pp_neg        (de_pp_neg_qmul       ),  // I
    .de_pp_e          (de_pp_e_qmul         ),  // I
    .de_sel_m         (de_sel_m_qmul        ),  // I
    .de_sel_2m        (de_sel_2m_qmul       ),  // I
    .de_half_size     (de_half_size_qmul    ),  // I
    .mem_opa_33b      (mem_opa_33b_qmul     ),  // I
    .mem_full_1st     (mem_full_1st_qmul    ),  // O
    .mem_opa_msb      (mem_opa_msb_qmul     ),  // O

    .rtu_lsu_allowin  (rtu_lsu_allowin_qmul ),  // I
    .mem_valid        (mem_valid_qmul       ),  // O
    .mem_complete     (mem_complete_qmul    ),  // O
    .mem_half         (mem_half_qmul        ),  // O
    .mem_full_2nd     (mem_full_2nd_qmul    ),  // O

    .wb_acc_res_52_16 (wb_acc_res_52_16_qmul),  // I
    .mem_full_1st_out (mem_full_1st_out_qmul),  // O
    .mem_wallace_s    (mem_wallace_s_qmul   ),  // O
    .mem_wallace_c    (mem_wallace_c_qmul   )   // O
);

exu_qdiv x_exu_qdiv (
    .clk             (clk_qdiv            ),  // I
    .reset           (reset_qdiv          ),  // I
    .data_reset      (data_reset_qdiv     ),  // I
    .de_cancel       (de_cancel_qdiv      ),  // I
    .mem_cancel      (mem_cancel_qdiv     ),  // I

    .de_validout     (de_validout_qdiv    ),  // I
    .de_opa_abs      (de_opa_abs_qdiv     ),  // I
    .de_quot_neg     (de_quot_neg_qdiv    ),  // I
    .de_rem_neg      (de_rem_neg_qdiv     ),  // I

    .mem_opb_neg     (mem_opb_neg_qdiv    ),  // I
    .mem_opb         (mem_opb_qdiv        ),  // I
    .rtu_lsu_allowin (rtu_lsu_allowin_qdiv),  // I
    .mem_valid       (mem_valid_qdiv      ),  // O
    .mem_complete    (mem_complete_qdiv   ),  // O
    .mem_quot_abs    (mem_quot_abs_qdiv   ),  // O
    .mem_rem_abs     (mem_rem_abs_qdiv    ),  // O
    .mem_quot_neg    (mem_quot_neg_qdiv   ),  // O
    .mem_rem_neg     (mem_rem_neg_qdiv    )   // O
);

assign mem_mul_half      =  mem_mul_valid && mem_mul_half_t;
assign mem_mul_full_2nd  =  mem_mul_valid && mem_mul_full_2nd_t;
assign mem_divide_op     =  mem_div_valid;
assign mem_res_0         =  mem_mul_valid ? mem_mul_wallace_s : {20'b0, ({32{mem_div_quot_neg}} ^ mem_div_quot_abs)};
assign mem_res_1         =  mem_mul_valid ? mem_mul_wallace_c : {5'b0, ({32{mem_div_rem_neg}} ^ mem_div_rem_abs), 15'b0};
endmodule  // exu_qmdu_mem
