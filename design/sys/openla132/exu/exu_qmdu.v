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

module exu_qmdu (
    input  wire                                      clk,
    input  wire                                      reset,
    input  wire                                      data_reset,
    input  wire [                             5: 0]  rtu_exu_ctrl_bus,
    input  wire [                             2: 0]  lsu_exu_ctrl_bus,
    input  wire [`OPEN132_IDU_EXU_MDU_BUS_WIDTH-1: 0]  idu_exu_mdu_bus,
    output wire                                      exu_idu_allowin,
    output wire [                             0: 0]  exu_lsu_ctrl_bus,
    output wire [                            32: 0]  exu_rtu_result_bus,
    input  wire [`OPEN132_RTU_EXU_APP_BUS_WIDTH-1: 0]  rtu_exu_app_bus
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire [ 31: 0] dec_opa;
wire [ 31: 0] dec_opb;
wire          dec_multiply;
wire          dec_divide;
wire          dec_signmdu;
wire          dec_togpr;
wire          dec_flag;
wire          dec_selhl;
wire          idu_exu_valid;

wire          mdu_is_run;

wire [ 31: 0] exu_rtu_value;
wire          exu_rtu_valid;

wire          de_validout;
wire          de_cancel;
wire          de_multiply;
wire          de_divide;
wire [ 32: 0] de_opa_ext_abs;
wire [ 31: 0] de_opb;
wire [  8: 0] de_mul_pp_neg;
wire [  8: 0] de_mul_pp_e;
wire [  8: 0] de_mul_sel_m;
wire [  8: 0] de_mul_sel_2m;
wire          de_mul_half_size;
wire          de_opb_neg;
wire          de_div_quot_neg;
wire          de_div_rem_neg;

wire          mem_validout;
wire          mem_cancel;
wire          mem_mul_complete;
wire          mem_div_complete;
wire          mem_opb_neg;
wire [ 31: 0] mem_opb;
wire          mem_mul_full_1st;
wire          mem_mul_opa_msb;
wire          mem_divide_op;
wire          mem_mul_half;
wire          mem_mul_full_2nd;
wire          mem_mul_full_1st_out;
wire [ 51: 0] mem_res_0;
wire [ 51: 0] mem_res_1;
wire          mem_div_quot_neg;
wire          mem_div_rem_neg;
wire          sel_hl;
wire          rtu_lsu_allowin;
wire          wb_dest_gpr;
wire [ 36: 0] wb_acc_res_52_16;

//============================================================//
//                    Module Implementation
//============================================================//

// quick mdu, 2.5 stages:exe, mem and wb stages.

assign {dec_opa, dec_opb, dec_multiply, dec_divide, dec_signmdu, dec_togpr, dec_selhl, dec_flag, idu_exu_valid}  =  idu_exu_mdu_bus;

assign exu_lsu_ctrl_bus  =  {mdu_is_run};

assign exu_rtu_result_bus  =  {exu_rtu_value, exu_rtu_valid};

exu_qmdu_pipe x_exu_qmdu_pipe (
    .clk              (clk             ),  // I
    .reset            (reset           ),  // I
    .data_reset       (data_reset      ),  // I

    .dec_togpr        (dec_togpr       ),  // I
    .dec_selhl        (dec_selhl       ),  // I
    .dec_flag         (dec_flag        ),  // I
    .idu_exu_valid    (idu_exu_valid   ),  // I
    .exu_idu_allowin  (exu_idu_allowin ),  // O
    .de_validout      (de_validout     ),  // O
    .de_cancel        (de_cancel       ),  // O

    .lsu_exu_ctrl_bus (lsu_exu_ctrl_bus),  // I
    .mem_mul_complete (mem_mul_complete),  // I
    .mem_div_complete (mem_div_complete),  // I
    .mem_validout     (mem_validout    ),  // O
    .mem_cancel       (mem_cancel      ),  // O

    .rtu_exu_ctrl_bus (rtu_exu_ctrl_bus),  // I
    .rtu_lsu_allowin  (rtu_lsu_allowin ),  // O
    .wb_dest_gpr      (wb_dest_gpr     ),  // O
    .mdu_is_run       (mdu_is_run      ),  // O
    .exu_rtu_valid    (exu_rtu_valid   ),  // O
    .sel_hl           (sel_hl          )   // O
);

exu_qmdu_dec x_exu_qmdu_dec (
    .dec_opa          (dec_opa         ),  // I
    .dec_opb          (dec_opb         ),  // I
    .dec_multiply     (dec_multiply    ),  // I
    .dec_divide       (dec_divide      ),  // I
    .dec_signmdu      (dec_signmdu     ),  // I

    .mem_mul_full_1st (mem_mul_full_1st),  // I
    .mem_mul_opa_msb  (mem_mul_opa_msb ),  // I
    .mem_opb_neg      (mem_opb_neg     ),  // I
    .mem_opb          (mem_opb         ),  // I

    .de_multiply      (de_multiply     ),  // O
    .de_divide        (de_divide       ),  // O
    .de_opa_ext_abs   (de_opa_ext_abs  ),  // O
    .de_opb           (de_opb          ),  // O
    .de_mul_pp_neg    (de_mul_pp_neg   ),  // O
    .de_mul_pp_e      (de_mul_pp_e     ),  // O
    .de_mul_sel_m     (de_mul_sel_m    ),  // O
    .de_mul_sel_2m    (de_mul_sel_2m   ),  // O
    .de_mul_half_size (de_mul_half_size),  // O
    .de_opb_neg       (de_opb_neg      ),  // O
    .de_div_quot_neg  (de_div_quot_neg ),  // O
    .de_div_rem_neg   (de_div_rem_neg  )   // O
);

exu_qmdu_mem x_exu_qmdu_mem (
    .clk                  (clk                 ),  // I
    .reset                (reset               ),  // I
    .data_reset           (data_reset          ),  // I
    .de_cancel            (de_cancel           ),  // I
    .mem_cancel           (mem_cancel          ),  // I

    .de_validout          (de_validout         ),  // I
    .de_multiply          (de_multiply         ),  // I
    .de_divide            (de_divide           ),  // I
    .de_opa_ext_abs       (de_opa_ext_abs      ),  // I
    .de_opb               (de_opb              ),  // I
    .de_mul_pp_neg        (de_mul_pp_neg       ),  // I
    .de_mul_pp_e          (de_mul_pp_e         ),  // I
    .de_mul_sel_m         (de_mul_sel_m        ),  // I
    .de_mul_sel_2m        (de_mul_sel_2m       ),  // I
    .de_mul_half_size     (de_mul_half_size    ),  // I
    .de_opb_neg           (de_opb_neg          ),  // I
    .de_div_quot_neg      (de_div_quot_neg     ),  // I
    .de_div_rem_neg       (de_div_rem_neg      ),  // I
    .mem_opb_neg          (mem_opb_neg         ),  // O
    .mem_opb              (mem_opb             ),  // O
    .mem_mul_full_1st     (mem_mul_full_1st    ),  // O
    .mem_mul_opa_msb      (mem_mul_opa_msb     ),  // O

    .rtu_lsu_allowin      (rtu_lsu_allowin     ),  // I
    .wb_acc_res_52_16     (wb_acc_res_52_16    ),  // I
    .mem_mul_complete     (mem_mul_complete    ),  // O
    .mem_div_complete     (mem_div_complete    ),  // O
    .mem_divide_op        (mem_divide_op       ),  // O
    .mem_mul_half         (mem_mul_half        ),  // O
    .mem_mul_full_2nd     (mem_mul_full_2nd    ),  // O
    .mem_mul_full_1st_out (mem_mul_full_1st_out),  // O
    .mem_res_0            (mem_res_0           ),  // O
    .mem_res_1            (mem_res_1           ),  // O
    .mem_div_quot_neg     (mem_div_quot_neg    ),  // O
    .mem_div_rem_neg      (mem_div_rem_neg     )   // O
);

exu_qmdu_wb x_exu_qmdu_wb (
    .clk                  (clk                 ),  // I
    .data_reset           (data_reset          ),  // I

    .rtu_lsu_allowin      (rtu_lsu_allowin     ),  // I
    .mem_validout         (mem_validout        ),  // I
    .mem_divide_op        (mem_divide_op       ),  // I
    .mem_mul_half         (mem_mul_half        ),  // I
    .mem_mul_full_2nd     (mem_mul_full_2nd    ),  // I
    .mem_mul_full_1st_out (mem_mul_full_1st_out),  // I
    .mem_res_0            (mem_res_0           ),  // I
    .mem_res_1            (mem_res_1           ),  // I
    .mem_div_quot_neg     (mem_div_quot_neg    ),  // I
    .mem_div_rem_neg      (mem_div_rem_neg     ),  // I
    .sel_hl               (sel_hl              ),  // I

    .wb_dest_gpr          (wb_dest_gpr         ),  // I
    .wb_acc_res_52_16     (wb_acc_res_52_16    ),  // O
    .exu_rtu_value        (exu_rtu_value       ),  // O
    .rtu_exu_app_bus      (rtu_exu_app_bus     )   // I
);

endmodule  // open132_mdu_module
