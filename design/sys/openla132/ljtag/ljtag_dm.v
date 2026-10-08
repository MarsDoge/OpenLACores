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

module ljtag_dm (
    input  wire           clk_ljt,  // clock for ljtag
    input  wire           clk_ng,  // clock no gating
    input  wire           reset,
    input  wire [ 55: 0]  biu_jtag_debug_req_bus,
    input  wire           dm,  // debug mode
    input  wire [ 31: 0]  pc,
    input  wire [  7: 0]  asid,

    output reg            ljtag_ce,
    output wire [ 32: 0]  jtag_biu_debug_resp_bus,
    output wire           jtag_core_break,

    input  wire           ljtag_lock,
    input  wire           tck,
    input  wire           trstn,
    input  wire           tms,
    input  wire           tdi,
    output wire           tdo
);

localparam REQBUF_EMPTY  = 2'b00;
localparam REQBUF_ENTER  = 2'b01;
localparam REQBUF_ACCESS = 2'b10;
localparam REQBUF_RDY    = 2'b11;

//============================================================//
//                     Regs Declarations
//============================================================//

reg [ 31: 0] to_tap_pc;
reg [  7: 0] to_tap_asid;

reg          from_tap_reg0_pr;
reg          from_tap_reg1_pr;
reg          from_tap_reg0_ljtagbrk;
reg          from_tap_reg1_ljtagbrk;
reg          from_tap_reg0_pen;
reg          from_tap_reg1_pen;
reg          from_tap_reg0_idle;
reg          from_tap_reg1_idle;

reg [  1: 0] reqbuf_state;  // 00 empty, 01 enter, 10 access tap, 11 rdy
reg          reqbuf_write;
reg [  1: 0] reqbuf_size;
reg [ 19: 0] reqbuf_paddr;
reg [ 31: 0] reqbuf_data;

reg          trstn_r0;
reg          trstn_r1;
reg [ 11: 0] ticker;

reg          newpc;
reg          newpc_tck_r0;
reg          newpc_see_by_tck;

//============================================================//
//                     Wire Declarations
//============================================================//

wire          tap_lock_tap;
wire          tck_in_tap;
wire          trst_in_tap;
wire          tms_in_tap;
wire          tdi_in_tap;
wire          tdo_out_tap;
wire [ 31: 0] dbmem_addr_in_tap;
wire [ 31: 0] dbmem_rdata_in_tap;
wire [ 31: 0] dbmem_wdata_out_tap;
wire          rc_in_tap;
wire [  1: 0] size_in_tap;
wire          pc_new_in_tap;
wire [ 31: 0] pc_in_tap;
wire [  7: 0] asid_in_tap;
wire          pw_in_tap;
wire          pr_in_tap;
wire          ljtagbrk_in_tap;
wire          dm_in_tap;
wire          pr_out_tap;
wire          pen_out_tap;
wire          ljtagbrk_out_tap;
wire          idle_tap;

wire          dbmemcbus_valid;
wire          dbmemcbus_write;
wire [  1: 0] dbmemcbus_size;
wire [ 19: 0] dbmemcbus_paddr;
wire [ 31: 0] dbmemcbus_data;

wire          dbmemrbus_valid;
wire [ 31: 0] dbmemrbus_data;

wire [ 31: 0] to_tap_addr;
wire [ 31: 0] to_tap_data;
wire          to_tap_pw;
wire [  1: 0] to_tap_size;
wire          to_tap_pr;
wire          to_tap_dm;
wire          to_tap_rc;
wire          to_tap_newpc;

wire [ 31: 0] from_tap_data;
wire          from_tap_pr;
wire          from_tap_ljtagbrk;
wire          from_tap_pen;
wire          from_tap_idle;
wire          idle;

wire          reqbuf_empty;
wire          reqbuf_enter;
wire          reqbuf_access;
wire          reqbuf_rdy;

wire          pen;
wire          dbmem_allow;

wire          empty_en;
wire          enter_en;
wire          access_en;
wire          rdy_en;

wire          ticker_eq0;

//============================================================//
//                    Module Implementation
//============================================================//

// Instance Boundary Alias Mapping
// x_jtag_tap

assign tap_lock_tap        =  ljtag_lock;
assign tck_in_tap          =  tck;
assign trst_in_tap         =  trstn;
assign tms_in_tap          =  tms;
assign tdi_in_tap          =  tdi;
assign tdo                 =  tdo_out_tap;
assign dbmem_addr_in_tap   =  to_tap_addr;
assign dbmem_rdata_in_tap  =  to_tap_data;
assign from_tap_data       =  dbmem_wdata_out_tap;
assign rc_in_tap           =  to_tap_rc;
assign size_in_tap         =  to_tap_size;
assign pc_new_in_tap       =  to_tap_newpc;
assign pc_in_tap           =  to_tap_pc;
assign asid_in_tap         =  to_tap_asid;
assign pw_in_tap           =  to_tap_pw;
assign pr_in_tap           =  to_tap_pr;
assign ljtagbrk_in_tap     =  jtag_core_break;
assign dm_in_tap           =  to_tap_dm;
assign from_tap_pr         =  pr_out_tap;
assign from_tap_pen        =  pen_out_tap;
assign from_tap_ljtagbrk   =  ljtagbrk_out_tap;
assign from_tap_idle       =  idle_tap;

assign {dbmemcbus_valid, dbmemcbus_write, dbmemcbus_size, dbmemcbus_paddr, dbmemcbus_data}  =  biu_jtag_debug_req_bus;

assign jtag_biu_debug_resp_bus  =  {dbmemrbus_valid, dbmemrbus_data};

assign idle  =  from_tap_reg1_idle;

always @ ( posedge clk_ljt )
begin
    from_tap_reg0_pr       <= from_tap_pr;
    from_tap_reg0_ljtagbrk <= from_tap_ljtagbrk;
    from_tap_reg0_idle     <= from_tap_idle;
    from_tap_reg0_pen      <= from_tap_pen;

    from_tap_reg1_pr       <= from_tap_reg0_pr;
    from_tap_reg1_ljtagbrk <= from_tap_reg0_ljtagbrk;
    from_tap_reg1_pen      <= from_tap_reg0_pen;
    from_tap_reg1_idle     <= from_tap_reg0_idle;
end

assign reqbuf_empty   =  reqbuf_state == REQBUF_EMPTY;
assign reqbuf_enter   =  reqbuf_state == REQBUF_ENTER;
assign reqbuf_access  =  reqbuf_state == REQBUF_ACCESS;
assign reqbuf_rdy     =  reqbuf_state == REQBUF_RDY;

assign dbmemrbus_valid  =  reqbuf_rdy;  // load or store complete
assign dbmemrbus_data   =  reqbuf_data;

assign dbmem_allow      =  reqbuf_empty && pen && !from_tap_reg1_pr && idle;
assign jtag_core_break  =  !ljtag_lock && from_tap_reg1_ljtagbrk && !dm;
assign pen              =  !ljtag_lock && from_tap_reg1_pen;

assign empty_en   =  reqbuf_rdy;
assign enter_en   =  reqbuf_empty && dbmemcbus_valid && dbmem_allow;
assign access_en  =  reqbuf_enter && from_tap_reg1_pr;
assign rdy_en     =  reqbuf_access && !from_tap_reg1_pr;

always @ ( posedge clk_ljt )
begin
    if(reset || empty_en) begin
        reqbuf_state <= REQBUF_EMPTY;
    end
    else if(enter_en) begin
        reqbuf_state <= REQBUF_ENTER;
    end
    else if(access_en) begin
        reqbuf_state <= REQBUF_ACCESS;
    end
    else if(rdy_en) begin
        reqbuf_state <= REQBUF_RDY;
    end
end

always @ ( posedge clk_ljt )
begin
    if(reset) begin
        reqbuf_write <= 1'd0;
        reqbuf_size  <= 2'd0;
        reqbuf_paddr <= 20'd0;
        reqbuf_data  <= 32'd0;
    end
    else if(enter_en) begin
        reqbuf_write <= dbmemcbus_write;
        reqbuf_size  <= dbmemcbus_size;
        reqbuf_paddr <= dbmemcbus_paddr;
        reqbuf_data  <= dbmemcbus_data;
    end
    else if(rdy_en && !reqbuf_write) begin
        reqbuf_data <= from_tap_data;
    end
end

always @ ( posedge clk_ng )
begin
    trstn_r0 <= trstn;
    trstn_r1 <= trstn_r0;
    ljtag_ce <= trstn_r1;
end

assign ticker_eq0  =  (ticker == 12'b0);
always @ ( posedge clk_ljt )
begin
    if(reset) begin
        ticker <= 12'h7f;
    end
    else if(ticker != 12'b0) begin
        ticker <= ticker - 12'b1;
    end
    else begin
        ticker <= 12'h1f;
    end
end

always @ ( posedge clk_ljt )
begin
    if(reset) begin
        to_tap_pc   <= 32'd0;
        to_tap_asid <= 8'd0;
    end
    else if(ticker_eq0) begin
        to_tap_pc   <= pc[31:0];
        to_tap_asid <= asid;
    end

    if(reset) begin
        newpc <= 1'd0;
    end
    else if(ticker_eq0) begin
        newpc <= 1'b1;
    end
    else if(newpc_see_by_tck) begin
        newpc <= 1'b0;
    end
end

always @ ( posedge tck )
begin
    newpc_tck_r0     <= newpc;
    newpc_see_by_tck <= newpc_tck_r0;
end
assign to_tap_newpc  =  newpc_tck_r0;

assign to_tap_addr  =  {12'hdb0, reqbuf_paddr[19:0]};
assign to_tap_data  =  reqbuf_data;
assign to_tap_pw    =  reqbuf_write;
assign to_tap_size  =  reqbuf_size;
assign to_tap_pr    =  reqbuf_enter;
assign to_tap_dm    =  dm;
assign to_tap_rc    =  reset;

ljtag_tap x_jtag_tap (
    .tap_lock        (tap_lock_tap       ),
    .tck_in          (tck_in_tap         ),
    .trst_in         (trst_in_tap        ),
    .tms_in          (tms_in_tap         ),
    .tdi_in          (tdi_in_tap         ),
    .tdo_out         (tdo_out_tap        ),
    .dbmem_addr_in   (dbmem_addr_in_tap  ),
    .dbmem_rdata_in  (dbmem_rdata_in_tap ),
    .dbmem_wdata_out (dbmem_wdata_out_tap),
    .rc_in           (rc_in_tap          ),
    .size_in         (size_in_tap        ),
    .pc_new_in       (pc_new_in_tap      ),
    .pc_in           (pc_in_tap          ),
    .asid_in         (asid_in_tap        ),
    .pw_in           (pw_in_tap          ),
    .pr_in           (pr_in_tap          ),
    .ljtagbrk_in     (ljtagbrk_in_tap    ),
    .dm_in           (dm_in_tap          ),
    .pr_out          (pr_out_tap         ),
    .pen_out         (pen_out_tap        ),
    .ljtagbrk_out    (ljtagbrk_out_tap   ),
    .idle            (idle_tap           )
);
endmodule

`endif  // OPEN132_HAS_LJTAG
