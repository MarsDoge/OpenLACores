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
module rtu_stage (
    input  wire                                          clk_g,
    input  wire                                          reset,
    input  wire                                          data_reset,

    input  wire [                                31: 0]  idu_lsu_follow_pc,  // lisa stall-fetch

    input  wire                                          lsu_rtu_inst_valid,
    input  wire [   `OPEN132_LSU_RTU_INST_BUS_WIDTH-1: 0]  lsu_rtu_inst_bus,
    input  wire [                                32: 0]  exu_rtu_result_bus,

    output wire                                          rtu_lsu_allowin,
    output wire [                                 5: 0]  rtu_exu_ctrl_bus,
    output wire                                          ex_cancel,
    output wire [                                31: 0]  rtu_lsu_cancel_pc,
    output wire                                          rtu_lsu_commit,
    output wire [                                32: 0]  rtu_ifu_redirect_bus,
    output wire                                          rtu_idu_forward_valid,
    output wire [`OPEN132_RTU_IDU_FORWARD_BUS_WIDTH-1: 0]  rtu_idu_forward_bus,
    // for GPR-cg
    output wire                                          rtu_clk_gpr_enable,

    input  wire [    `OPEN132_LSU_RTU_APP_BUS_WIDTH-1: 0]  lsu_rtu_app_bus,
    output wire [    `OPEN132_RTU_EXU_APP_BUS_WIDTH-1: 0]  rtu_exu_app_bus

`ifdef OPEN132_OUTPUT_WB_STATE
    ,
    output wire [                                31: 0]  wb_pc,
    output wire [                                 4: 0]  wb_rf_dest,
    output wire                                          wb_rf_wen,  // open132 regfile is word enable
    output wire [                                31: 0]  wb_rf_value
`endif

    ,
    output wire [        `OPEN132_RTU_FPU_BUS_WIDTH-1: 0]  rtu_fpu_bus
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg                                      valid;
reg [`OPEN132_LSU_RTU_INST_BUS_WIDTH-1: 0] wb_bus;

reg [`OPEN132_LSU_RTU_APP_BUS_WIDTH-1: 0] lsu_rtu_app_bus_r;

//============================================================//
//                     Wire Declarations
//============================================================//

wire          mem_validout;

wire          stallf;
wire          mdu;         // 1:inst is mdu
wire          roll;
wire          lbh;         // lb/lbu/lh/lhu
wire          lbhsign;     // lb/lh
wire          lb;          // lb/lbu
wire          ld_rotr_0;
wire          ld_rotr_1;   // load result need rotr
wire          ld_rotr_2;
wire          ld_rotr_3;
wire [  4: 0] dest;
wire [ 31: 0] result;
wire          order_flag;
wire [ 31: 0] pc;

wire [ 31: 0] exu_rtu_value;
wire          exu_rtu_valid;

wire [  4: 0] wb_dest;
wire [ 31: 0] wb_result;
wire [ 31: 0] wb_fd_result;  // wb2de forward data
wire          wb_mdu_stall;  // mdu instruction can't be forward
wire          wb_stall;      // wb is stalled
wire          wb_validout;

wire [ 31: 0] ex_pc;
wire          ex_valid;

wire          rtu_exu_valid;
wire          rtu_exu_validout;
wire          rtu_exu_mdu;       // mdu instruction wait data in wb stage
wire          rtu_exu_flag;
wire          rtu_exu_allowin;
wire          rtu_exu_excancel;

wire [ 31: 0] result_from_mem;  // see {align}segement

wire          lbh_sign;
wire [ 31: 0] result_after_rotr;

`ifndef OPEN132_OUTPUT_WB_STATE
wire [ 31: 0] wb_pc;
wire [  4: 0] wb_rf_dest;
wire          wb_rf_wen;    // open132 regfile is word enable
wire [ 31: 0] wb_rf_value;
`endif


//============================================================//
//                    Module Implementation
//============================================================//

//------------------------------------------------------------//
//                      Bus Connections
//------------------------------------------------------------//
//------------------------------------------------------------//
//                           wb_bus
//------------------------------------------------------------//

assign mem_validout  =  lsu_rtu_inst_valid;

always @ ( posedge clk_g )
begin
    if(reset || ex_cancel) begin
        valid <= 1'b0;
    end
    else if(rtu_lsu_allowin) begin
        valid <= mem_validout;
    end

    if(data_reset) begin
        wb_bus <= {`OPEN132_LSU_RTU_INST_BUS_WIDTH{1'b0}};
    end
    else if(mem_validout && rtu_lsu_allowin) begin
        wb_bus <= lsu_rtu_inst_bus;
    end
end

assign {stallf,
        mdu,
        roll,
        lbh,
        lbhsign,
        lb,
        ld_rotr_0,
        ld_rotr_1,
        ld_rotr_2,
        ld_rotr_3,
        dest,
        result,
        order_flag,
        pc       }  =  wb_bus;
// End wb_bus

//------------------------------------------------------------//
//                     exu_rtu_result_bus
//------------------------------------------------------------//
assign {exu_rtu_value,exu_rtu_valid}  =  exu_rtu_result_bus;
// End exu_rtu_result_bus

//------------------------------------------------------------//
//                    rtu_idu_forward_bus
//------------------------------------------------------------//
assign rtu_idu_forward_valid  =  wb_validout & ~roll;
assign rtu_idu_forward_bus    =  {wb_dest,
                                   wb_result,
                                   wb_fd_result,
                                   wb_mdu_stall,
                                   wb_stall    };
// End rtu_idu_forward_bus
// GPR cg
assign rtu_clk_gpr_enable  =  valid && wb_dest!=5'd0;

//------------------------------------------------------------//
//                rtu_ifu_redirect_bus Signals
//------------------------------------------------------------//
assign rtu_ifu_redirect_bus  =  {ex_pc, ex_valid};
// End rtu_ifu_redirect_bus Signals

//------------------------------------------------------------//
//                       wb2mem Signals
//------------------------------------------------------------//
assign rtu_lsu_cancel_pc  =  ex_pc;
assign rtu_lsu_commit     =  wb_validout;
// End wb2mem Signals

//------------------------------------------------------------//
//                      rtu_exu_ctrl_bus
//------------------------------------------------------------//
assign rtu_exu_ctrl_bus  =  {rtu_exu_valid,
                              rtu_exu_validout,
                              rtu_exu_mdu,
                              rtu_exu_flag,
                              rtu_exu_allowin,
                              rtu_exu_excancel};
// End rtu_exu_ctrl_bus
// End Bus Connections

//------------------------------------------------------------//
//                      Pipeline Control
//------------------------------------------------------------//
assign wb_stall         =  valid & mdu & ~exu_rtu_valid;
assign wb_validout      =  (valid & ~wb_stall) | ex_cancel;
assign rtu_lsu_allowin  =  ~valid | ex_cancel | wb_validout;
// End Pipeline Control

//------------------------------------------------------------//
//                rtu_idu_forward_bus Signals
//------------------------------------------------------------//
assign wb_result     =  mdu ? exu_rtu_value : result_from_mem;
assign wb_fd_result  =  result_from_mem;
assign wb_mdu_stall  =  mdu & valid;
assign wb_dest       =  dest;
// End rtu_idu_forward_bus Signals

//------------------------------------------------------------//
//                  rtu_exu_ctrl_bus Signals
//------------------------------------------------------------//
assign rtu_exu_valid     =  valid;
assign rtu_exu_validout  =  wb_validout;
assign rtu_exu_mdu       =  mdu;
assign rtu_exu_flag      =  order_flag;
assign rtu_exu_allowin   =  rtu_lsu_allowin;
assign rtu_exu_excancel  =  ex_cancel;
// End rtu_exu_ctrl_bus Signals

//------------------------------------------------------------//
//                           Align
//------------------------------------------------------------//
assign result_after_rotr  =  {32{ld_rotr_1}} &{result[7:0],result[31:24],result[23:16],result[15:8]}
                             |{32{ld_rotr_2}} &{result[15:8],result[7:0],result[31:24],result[23:16]}
                             |{32{ld_rotr_3}} &{result[23:16],result[15:8],result[7:0],result[31:24]}
                             |{32{ld_rotr_0}} & result;

assign lbh_sign  =  lbhsign & ( ( (~lb&ld_rotr_2 | ld_rotr_3) & result[31] )
                    |( ( lb&ld_rotr_2            ) & result[23] )
                    |( (~lb&ld_rotr_0 | ld_rotr_1) & result[15] )
                    |( ( lb&ld_rotr_0            ) & result[7 ] )
                      );

assign result_from_mem[31:16]  =  {16{lbh & lbh_sign}} | ({16{~lbh}} & result_after_rotr[31:16]);
assign result_from_mem[15: 8]  =  {8{lb & lbh_sign}} | ({8{~lb}} & result_after_rotr[15:8]);
assign result_from_mem[7 : 0]  =  result_after_rotr[7:0];
// End Align

//------------------------------------------------------------//
//                    Exception Processing
//------------------------------------------------------------//
// flush pipeline
assign ex_cancel  =  valid && roll || valid&&stallf;

// rtu_ifu_redirect_bus signals
assign ex_valid  =  ex_cancel;
// while roll pipeline, the roll_pc is stored in result.
assign ex_pc  =  valid&&roll ? result : idu_lsu_follow_pc;
// for lisa_stallf, result maybe is csrrd-value, ex_pc will be idu_lsu_follow_pc.
// End Exception Processing

//------------------------------------------------------------//
//                      Writeback State
//------------------------------------------------------------//
assign wb_pc        =  pc;
assign wb_rf_dest   =  wb_dest;
assign wb_rf_wen    =  wb_dest!=5'd0 && rtu_idu_forward_valid;
assign wb_rf_value  =  wb_dest==5'd0 ? 32'd0 : wb_result;
// End Writeback State

//------------------------------------------------------------//
//                            FPU
//------------------------------------------------------------//
// wb2fpu bus
assign rtu_fpu_bus  =  {`OPEN132_RTU_FPU_BUS_WIDTH{1'b0}};
// End FPU

//------------------------------------------------------------//
//                 Application-Specific Logic
//------------------------------------------------------------//
always @ ( posedge clk_g )
begin
    if(data_reset) begin
        lsu_rtu_app_bus_r <= {`OPEN132_LSU_RTU_APP_BUS_WIDTH{1'b0}};
    end
    else if(mem_validout && rtu_lsu_allowin) begin
        lsu_rtu_app_bus_r <= lsu_rtu_app_bus;
    end
end

`ifndef OPEN132_APP_SPEC
assign rtu_exu_app_bus  =  {`OPEN132_RTU_EXU_APP_BUS_WIDTH{1'b0}};
`endif
// End Application-Specific Logic
endmodule
