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

module exu_smdu (
    input  wire                                      clk,
    input  wire                                      reset,
    input  wire                                      data_reset,
    input  wire [                             5: 0]  rtu_exu_ctrl_bus,
    input  wire [                             2: 0]  lsu_exu_ctrl_bus,
    input  wire [`OPEN132_IDU_EXU_MDU_BUS_WIDTH-1: 0]  idu_exu_mdu_bus,
    output wire                                      exu_idu_allowin,
    output wire [                             0: 0]  exu_lsu_ctrl_bus,
    output wire [                            32: 0]  exu_rtu_result_bus
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire          clk_smdu_pipe;
wire          reset_smdu_pipe;
wire          data_reset_smdu_pipe;
wire          idu_exu_valid_smdu_pipe;
wire          de_multiply_smdu_pipe;
wire          de_divide_smdu_pipe;
wire          de_togpr_smdu_pipe;
wire          de_selhl_smdu_pipe;
wire          de_flag_smdu_pipe;
wire          mem_begin_smdu_pipe;
wire          mem_do_div_smdu_pipe;
wire          mem_complete_smdu_pipe;
wire [  2: 0] lsu_exu_ctrl_bus_smdu_pipe;
wire [  5: 0] rtu_exu_ctrl_bus_smdu_pipe;
wire          exu_idu_allowin_smdu_pipe;
wire          mdu_is_run_smdu_pipe;
wire          exu_rtu_valid_smdu_pipe;
wire          wb_selhl_smdu_pipe;
wire          clk_smdu_mem;
wire          reset_smdu_mem;
wire          data_reset_smdu_mem;
wire          mem_begin_smdu_mem;
wire          mem_do_div_smdu_mem;
wire [ 31: 0] de_opa_abs_smdu_mem;
wire [ 31: 0] de_opb_abs_smdu_mem;
wire          de_do_div_smdu_mem;
wire          de_res_h_neg_smdu_mem;
wire          de_res_l_neg_smdu_mem;
wire [ 31: 0] mem_res_h_smdu_mem;
wire [ 31: 0] mem_res_l_smdu_mem;
wire          mem_complete_smdu_mem;

wire [ 31: 0] dec_opa;
wire [ 31: 0] dec_opb;
wire          dec_multiply;
wire          dec_divide;
wire          dec_signmdu;
wire          dec_togpr;
wire          dec_selhl;
wire          dec_flag;
wire          idu_exu_valid;

wire          mdu_is_run;

wire [ 31: 0] exu_rtu_value;
wire          exu_rtu_valid;
wire          wb_selhl;

// de
wire [ 31: 0] de_opa_abs;
wire [ 31: 0] de_opb_abs;
wire          de_res_h_neg;
wire          de_res_l_neg;

// mem
wire          mem_begin;
wire          mem_do_div;
wire [ 31: 0] mem_res_h;
wire [ 31: 0] mem_res_l;
wire          mem_complete;

//============================================================//
//                    Module Implementation
//============================================================//

// serila mdu only 1.5 stages:exe and mem, no wb stage.

// Instance Boundary Alias Mapping
// x_exu_smdu_pipe

assign clk_smdu_pipe               =  clk;
assign reset_smdu_pipe             =  reset;
assign data_reset_smdu_pipe        =  data_reset;
assign idu_exu_valid_smdu_pipe     =  idu_exu_valid;
assign de_multiply_smdu_pipe       =  dec_multiply;
assign de_divide_smdu_pipe         =  dec_divide;
assign de_togpr_smdu_pipe          =  dec_togpr;
assign de_selhl_smdu_pipe          =  dec_selhl;
assign de_flag_smdu_pipe           =  dec_flag;
assign mem_begin                   =  mem_begin_smdu_pipe;
assign mem_do_div                  =  mem_do_div_smdu_pipe;
assign mem_complete_smdu_pipe      =  mem_complete;
assign lsu_exu_ctrl_bus_smdu_pipe  =  lsu_exu_ctrl_bus;
assign rtu_exu_ctrl_bus_smdu_pipe  =  rtu_exu_ctrl_bus;
assign exu_idu_allowin             =  exu_idu_allowin_smdu_pipe;
assign mdu_is_run                  =  mdu_is_run_smdu_pipe;
assign exu_rtu_valid               =  exu_rtu_valid_smdu_pipe;
assign wb_selhl                    =  wb_selhl_smdu_pipe;
// x_exu_smdu_mem
assign clk_smdu_mem           =  clk;
assign reset_smdu_mem         =  reset;
assign data_reset_smdu_mem    =  data_reset;
assign mem_begin_smdu_mem     =  mem_begin;
assign mem_do_div_smdu_mem    =  mem_do_div;
assign de_opa_abs_smdu_mem    =  de_opa_abs;
assign de_opb_abs_smdu_mem    =  de_opb_abs;
assign de_do_div_smdu_mem     =  dec_divide;
assign de_res_h_neg_smdu_mem  =  de_res_h_neg;
assign de_res_l_neg_smdu_mem  =  de_res_l_neg;
assign mem_res_h              =  mem_res_h_smdu_mem;
assign mem_res_l              =  mem_res_l_smdu_mem;
assign mem_complete           =  mem_complete_smdu_mem;

assign {dec_opa, dec_opb, dec_multiply, dec_divide, dec_signmdu, dec_togpr, dec_selhl, dec_flag, idu_exu_valid}  =  idu_exu_mdu_bus;

// mdu2mem bus
assign exu_lsu_ctrl_bus  =  {mdu_is_run};

// mdu2wb bus for mul
assign exu_rtu_result_bus  =  {exu_rtu_value, exu_rtu_valid};

assign exu_rtu_value  =  wb_selhl ? mem_res_h : mem_res_l;

exu_smdu_pipe x_exu_smdu_pipe (
    .clk              (clk_smdu_pipe             ),  // I
    .reset            (reset_smdu_pipe           ),  // I
    .data_reset       (data_reset_smdu_pipe      ),  // I

    .idu_exu_valid    (idu_exu_valid_smdu_pipe   ),  // I
    .de_multiply      (de_multiply_smdu_pipe     ),  // I
    .de_divide        (de_divide_smdu_pipe       ),  // I
    .de_togpr         (de_togpr_smdu_pipe        ),  // I
    .de_selhl         (de_selhl_smdu_pipe        ),  // I
    .de_flag          (de_flag_smdu_pipe         ),  // I

    .mem_begin        (mem_begin_smdu_pipe       ),  // O
    .mem_do_div       (mem_do_div_smdu_pipe      ),  // O
    .mem_complete     (mem_complete_smdu_pipe    ),  // I

    .lsu_exu_ctrl_bus (lsu_exu_ctrl_bus_smdu_pipe),  // I
    .rtu_exu_ctrl_bus (rtu_exu_ctrl_bus_smdu_pipe),  // I
    .exu_idu_allowin  (exu_idu_allowin_smdu_pipe ),  // O
    .mdu_is_run       (mdu_is_run_smdu_pipe      ),  // O
    .exu_rtu_valid    (exu_rtu_valid_smdu_pipe   ),  // O
    .wb_selhl         (wb_selhl_smdu_pipe        )   // O
);

exu_smdu_dec x_exu_smdu_dec (
    .dec_signmdu  (dec_signmdu ),  // I
    .dec_divide   (dec_divide  ),  // I

    .dec_opa      (dec_opa     ),  // I
    .dec_opb      (dec_opb     ),  // I

    .de_opa_abs   (de_opa_abs  ),  // O
    .de_opb_abs   (de_opb_abs  ),  // O
    .de_res_h_neg (de_res_h_neg),  // O
    .de_res_l_neg (de_res_l_neg)   // O
);

exu_smdu_mem x_exu_smdu_mem (
    .clk          (clk_smdu_mem         ),  // I
    .reset        (reset_smdu_mem       ),  // I
    .data_reset   (data_reset_smdu_mem  ),  // I

    .mem_begin    (mem_begin_smdu_mem   ),  // I
    .mem_do_div   (mem_do_div_smdu_mem  ),  // I

    .de_opa_abs   (de_opa_abs_smdu_mem  ),  // I
    .de_opb_abs   (de_opb_abs_smdu_mem  ),  // I
    .de_do_div    (de_do_div_smdu_mem   ),  // I
    .de_res_h_neg (de_res_h_neg_smdu_mem),  // I
    .de_res_l_neg (de_res_l_neg_smdu_mem),  // I

    .mem_res_h    (mem_res_h_smdu_mem   ),  // O
    .mem_res_l    (mem_res_l_smdu_mem   ),  // O
    .mem_complete (mem_complete_smdu_mem)   // O
);

endmodule  // open132_mdu_module
