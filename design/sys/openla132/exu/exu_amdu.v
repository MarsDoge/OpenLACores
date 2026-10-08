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

module exu_amdu (
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

wire          clk_amdu_pipe;
wire          reset_amdu_pipe;
wire          data_reset_amdu_pipe;
wire          idu_exu_valid_amdu_pipe;
wire          de_multiply_amdu_pipe;
wire          de_divide_amdu_pipe;
wire          de_togpr_amdu_pipe;
wire          de_selhl_amdu_pipe;
wire          de_flag_amdu_pipe;
wire          mem_begin_amdu_pipe;
wire          mem_do_div_amdu_pipe;
wire          mem_complete_amdu_pipe;
wire [  2: 0] lsu_exu_ctrl_bus_amdu_pipe;
wire [  5: 0] rtu_exu_ctrl_bus_amdu_pipe;
wire          exu_idu_allowin_amdu_pipe;
wire          mdu_is_run_amdu_pipe;
wire          exu_rtu_valid_amdu_pipe;
wire          wb_selhl_amdu_pipe;

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

// serial mdu only 1.5 stages:exe and mem, no wb stage.

// Instance Boundary Alias Mapping
// x_exu_amdu_pipe

assign clk_amdu_pipe               =  clk;
assign reset_amdu_pipe             =  reset;
assign data_reset_amdu_pipe        =  data_reset;
assign idu_exu_valid_amdu_pipe     =  idu_exu_valid;
assign de_multiply_amdu_pipe       =  dec_multiply;
assign de_divide_amdu_pipe         =  dec_divide;
assign de_togpr_amdu_pipe          =  dec_togpr;
assign de_selhl_amdu_pipe          =  dec_selhl;
assign de_flag_amdu_pipe           =  dec_flag;
assign mem_begin                   =  mem_begin_amdu_pipe;
assign mem_do_div                  =  mem_do_div_amdu_pipe;
assign mem_complete_amdu_pipe      =  mem_complete;
assign lsu_exu_ctrl_bus_amdu_pipe  =  lsu_exu_ctrl_bus;
assign rtu_exu_ctrl_bus_amdu_pipe  =  rtu_exu_ctrl_bus;
assign exu_idu_allowin             =  exu_idu_allowin_amdu_pipe;
assign mdu_is_run                  =  mdu_is_run_amdu_pipe;
assign exu_rtu_valid               =  exu_rtu_valid_amdu_pipe;
assign wb_selhl                    =  wb_selhl_amdu_pipe;

assign {dec_opa, dec_opb, dec_multiply, dec_divide, dec_signmdu, dec_togpr, dec_selhl, dec_flag, idu_exu_valid}  =  idu_exu_mdu_bus;

// mdu2mem bus
assign exu_lsu_ctrl_bus  =  {mdu_is_run};

// mdu2wb bus for mul
assign exu_rtu_result_bus  =  {exu_rtu_value, exu_rtu_valid};

assign exu_rtu_value  =  wb_selhl ? mem_res_h : mem_res_l;

exu_amdu_pipe x_exu_amdu_pipe (
    .clk              (clk_amdu_pipe             ),  // I
    .reset            (reset_amdu_pipe           ),  // I
    .data_reset       (data_reset_amdu_pipe      ),  // I

    .idu_exu_valid    (idu_exu_valid_amdu_pipe   ),  // I
    .de_multiply      (de_multiply_amdu_pipe     ),  // I
    .de_divide        (de_divide_amdu_pipe       ),  // I
    .de_togpr         (de_togpr_amdu_pipe        ),  // I
    .de_selhl         (de_selhl_amdu_pipe        ),  // I
    .de_flag          (de_flag_amdu_pipe         ),  // I

    .mem_begin        (mem_begin_amdu_pipe       ),  // O
    .mem_do_div       (mem_do_div_amdu_pipe      ),  // O
    .mem_complete     (mem_complete_amdu_pipe    ),  // I

    .lsu_exu_ctrl_bus (lsu_exu_ctrl_bus_amdu_pipe),  // I
    .rtu_exu_ctrl_bus (rtu_exu_ctrl_bus_amdu_pipe),  // I
    .exu_idu_allowin  (exu_idu_allowin_amdu_pipe ),  // O
    .mdu_is_run       (mdu_is_run_amdu_pipe      ),  // O
    .exu_rtu_valid    (exu_rtu_valid_amdu_pipe   ),  // O
    .wb_selhl         (wb_selhl_amdu_pipe        )   // O
);

exu_amdu_dec x_exu_amdu_dec (
    .dec_signmdu  (dec_signmdu ),  // I
    .dec_divide   (dec_divide  ),  // I

    .dec_opa      (dec_opa     ),  // I
    .dec_opb      (dec_opb     ),  // I

    .de_opa_abs   (de_opa_abs  ),  // O
    .de_opb_abs   (de_opb_abs  ),  // O
    .de_res_h_neg (de_res_h_neg),  // O
    .de_res_l_neg (de_res_l_neg)   // O
);

exu_amdu_mem x_exu_amdu_mem (
    .clk          (clk         ),  // I
    .reset        (reset       ),  // I
    .data_reset   (data_reset  ),  // I

    .mem_begin    (mem_begin   ),  // I
    .mem_do_div   (mem_do_div  ),  // I

    .de_opa_abs   (de_opa_abs  ),  // I
    .de_opb_abs   (de_opb_abs  ),  // I
    .de_res_h_neg (de_res_h_neg),  // I
    .de_res_l_neg (de_res_l_neg),  // I

    .mem_res_h    (mem_res_h   ),  // O
    .mem_res_l    (mem_res_l   ),  // O
    .mem_complete (mem_complete)   // O
);

endmodule  // open132_mdu_module
