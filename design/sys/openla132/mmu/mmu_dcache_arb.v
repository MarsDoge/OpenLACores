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

`ifdef CONFIG_MMU
`include "openla132_global.h"

module mmu_dcache_arb (
    input  wire           clk,
    input  wire           reset,

    input  wire           cpu_req_vld,
    input  wire           cpu_req_wait,
    input  wire           cpu_req_replay,
    input  wire           cpu_req_rd,
    input  wire           cpu_req_exc,
    input  wire           cpu_req_pre_err,
    input  wire           cpu_req_dbgm,
    input  wire [  1: 0]  cpu_req_size,
    input  wire [ 31: 0]  cpu_req_vaddr,
    input  wire [ 31: 0]  cpu_req_paddr,
    input  wire [  1: 0]  cpu_req_mat,
    input  wire [  2: 0]  cpu_req_bank,
    input  wire [ 31: 0]  cpu_req_wdata,

    input  wire           ptw_req_vld,
    input  wire [ 31: 0]  ptw_req_paddr,

    input  wire           cache_req_rdy,
    input  wire           cache_resp_vld,
    input  wire [ 31: 0]  cache_resp_data,
    input  wire           cache_resp_exok,
    input  wire           cache_resp_err,
    input  wire           cache_idle,

    output wire           cpu_req_rdy,
    output wire           cpu_resp_vld,
    output wire [ 31: 0]  cpu_resp_data,
    output wire           cpu_resp_exok,
    output wire           cpu_resp_err,

    output wire           ptw_req_rdy,
    output wire           ptw_busy,
    output wire           ptw_resp_vld,
    output wire [ 31: 0]  ptw_resp_data,
    output wire           ptw_resp_err,

    output wire           cache_req_vld,
    output wire           cache_req_wait,
    output wire           cache_req_rd,
    output wire           cache_req_exc,
    output wire           cache_req_pre_err,
    output wire           cache_req_dbgm,
    output wire [  1: 0]  cache_req_size,
    output wire [ 31: 0]  cache_req_vaddr,
    output wire [ 31: 0]  cache_req_paddr,
    output wire [  1: 0]  cache_req_mat,
    output wire [  2: 0]  cache_req_bank,
    output wire [ 31: 0]  cache_req_wdata
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg          ptw_active_r;
reg          cpu_hold_rd_r;
reg          cpu_hold_exc_r;
reg          cpu_hold_pre_err_r;
reg          cpu_hold_dbgm_r;
reg [  1: 0] cpu_hold_size_r;
reg [  2: 0] cpu_hold_bank_r;
reg [ 31: 0] cpu_hold_wdata_r;

//============================================================//
//                     Wire Declarations
//============================================================//

wire          ptw_select;
wire          cpu_select;
wire          ptw_req_fire;
wire          cpu_req_fire;
wire          cpu_rd;
wire          cpu_exc;
wire          cpu_pre_err;
wire          cpu_dbgm;
wire [  1: 0] cpu_size;
wire [  2: 0] cpu_bank;
wire [ 31: 0] cpu_wdata;


//============================================================//
//                   Module Implementation
//============================================================//

//------------------------------------------------------------//
//                     Request Selection
//------------------------------------------------------------//

assign ptw_select             =  !ptw_active_r && ptw_req_vld && cache_idle;
assign cpu_select             =  !ptw_active_r && !ptw_req_vld;
assign cache_req_vld          =  ptw_select || (cpu_select && cpu_req_vld);

//------------------------------------------------------------//
//                     Request Handshakes
//------------------------------------------------------------//

assign ptw_req_rdy            =  ptw_select && cache_req_rdy;
assign cpu_req_rdy            =  cpu_select && cache_req_rdy;
assign ptw_req_fire           =  ptw_req_vld && ptw_req_rdy;
assign cpu_req_fire           =  cpu_req_vld && cpu_req_rdy;

//------------------------------------------------------------//
//                  Replay Payload Selection
//------------------------------------------------------------//

// The MMU owns a replay after the original LSU address handshake. Retain the
// Cache payload here so a later pipeline request cannot alter that replay.
// These payload registers need no reset: cpu_req_replay is reachable only
// after cpu_req_fire has captured every field below.
assign cpu_rd                 =  cpu_req_replay ? cpu_hold_rd_r      : cpu_req_rd;
assign cpu_exc                =  cpu_req_replay ? cpu_hold_exc_r     : cpu_req_exc;
assign cpu_pre_err            =  cpu_req_replay ? cpu_hold_pre_err_r : cpu_req_pre_err;
assign cpu_dbgm               =  cpu_req_replay ? cpu_hold_dbgm_r    : cpu_req_dbgm;
assign cpu_size               =  cpu_req_replay ? cpu_hold_size_r    : cpu_req_size;
assign cpu_bank               =  cpu_req_replay ? cpu_hold_bank_r    : cpu_req_bank;
assign cpu_wdata              =  cpu_req_replay ? cpu_hold_wdata_r   : cpu_req_wdata;

//------------------------------------------------------------//
//                 DCache Request Projection
//------------------------------------------------------------//

assign cache_req_wait         =  ptw_select ? 1'b0 : cpu_req_wait;
assign cache_req_rd           =  ptw_select ? 1'b1 : cpu_rd;
assign cache_req_exc          =  ptw_select ? 1'b0 : cpu_exc;
assign cache_req_pre_err      =  ptw_select ? 1'b0 : cpu_pre_err;
assign cache_req_dbgm         =  ptw_select ? 1'b0 : cpu_dbgm;
assign cache_req_size         =  ptw_select ? 2'b10 : cpu_size;
assign cache_req_vaddr        =  ptw_select ? ptw_req_paddr : cpu_req_vaddr;
assign cache_req_paddr        =  ptw_select ? ptw_req_paddr : cpu_req_paddr;
assign cache_req_mat          =  ptw_select ? 2'b01 : cpu_req_mat;
assign cache_req_bank         =  ptw_select ? ptw_req_paddr[4:2] : cpu_bank;
assign cache_req_wdata        =  ptw_select ? 32'd0 : cpu_wdata;

//------------------------------------------------------------//
//                     Response Ownership
//------------------------------------------------------------//

assign ptw_resp_vld           =  cache_resp_vld && ptw_active_r;
assign ptw_resp_data          =  cache_resp_data;
assign ptw_resp_err           =  cache_resp_err;
// Include the acceptance cycle so a simultaneous pipeline cancel cannot turn
// an accepted PTW read into a response-less Cache request.
assign ptw_busy               =  ptw_active_r || ptw_select;

assign cpu_resp_vld           =  cache_resp_vld && !ptw_active_r;
assign cpu_resp_data          =  cache_resp_data;
assign cpu_resp_exok          =  cache_resp_exok;
assign cpu_resp_err           =  cache_resp_err;

always @ ( posedge clk )
begin
    if(reset) begin
        ptw_active_r <= 1'b0;
    end
    else if(ptw_resp_vld) begin
        ptw_active_r <= 1'b0;
    end
    else if(ptw_req_fire) begin
        ptw_active_r <= 1'b1;
    end
end

//------------------------------------------------------------//
//                     CPU Replay Payload
//------------------------------------------------------------//

always @ ( posedge clk )
begin
    if(cpu_req_fire && !cpu_req_replay) begin
        cpu_hold_rd_r      <= cpu_req_rd;
        cpu_hold_exc_r     <= cpu_req_exc;
        cpu_hold_pre_err_r <= cpu_req_pre_err;
        cpu_hold_dbgm_r    <= cpu_req_dbgm;
        cpu_hold_size_r    <= cpu_req_size;
        cpu_hold_bank_r    <= cpu_req_bank;
        cpu_hold_wdata_r   <= cpu_req_wdata;
    end
end


endmodule
`endif
