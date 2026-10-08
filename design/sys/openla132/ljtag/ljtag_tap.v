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

module ljtag_tap (
    input  wire           tap_lock,
    input  wire           tck_in,
    input  wire           trst_in,
    input  wire           tms_in,
    input  wire           tdi_in,
    output reg            tdo_out,

    input  wire [ 31: 0]  dbmem_addr_in,
    input  wire           pc_new_in,
    input  wire [ 31: 0]  pc_in,
    input  wire [  7: 0]  asid_in,
    input  wire [ 31: 0]  dbmem_rdata_in,

    output wire [ 31: 0]  dbmem_wdata_out,

    input  wire           rc_in,
    input  wire [  1: 0]  size_in,
    input  wire           pw_in,
    input  wire           pr_in,
    input  wire           ljtagbrk_in,
    input  wire           dm_in,

    output wire           pr_out,
    output wire           pen_out,
    output wire           ljtagbrk_out,
    output wire           idle
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire          tck_in_tap_fsm;
wire          trst_in_tap_fsm;
wire          tms_in_tap_fsm;
wire          ind_tap_fsm;
wire          capture_ir_tap_fsm;
wire          shift_ir_tap_fsm;
wire          update_ir_tap_fsm;
wire          capture_dr_tap_fsm;
wire          shift_dr_tap_fsm;
wire          update_dr_tap_fsm;
wire          tlr_tap_fsm;
wire          pr_enable_tap_fsm;
wire          idle_tap_fsm;
wire [  3: 0] curr_state_out_tap_fsm;
wire          tck_in_tap_ir;
wire          trst_in_tap_ir;
wire          s_rst_tap_ir;
wire          enable_tap_ir;
wire          cap_tap_ir;
wire          shift_tap_ir;
wire          update_tap_ir;
wire          si_tap_ir;
wire          so_tap_ir;
wire [  3: 0] pi_tap_ir;
wire [  3: 0] po_tap_ir;
wire          tap_lock_tap_dec;
wire          tck_in_tap_dec;
wire          trst_in_tap_dec;
wire [  3: 0] inst_in_tap_dec;
wire [  3: 0] curr_state_tap_dec;
wire [ 13: 0] select_tap_dec;
wire          tck_in_tap_regs;
wire          trst_in_tap_regs;
wire          tdi_in_tap_regs;
wire          tdo_out_tap_regs;
wire          capture_dr_tap_regs;
wire          shift_dr_tap_regs;
wire          update_d_fsm_tap_regs;
wire [ 13: 0] select_tap_regs;
wire          normalboot_tap_regs;
wire [ 31: 0] dbmem_addr_in_tap_regs;
wire          pc_new_in_tap_regs;
wire [ 31: 0] pc_in_tap_regs;
wire [  7: 0] asid_in_tap_regs;
wire [ 31: 0] dbmem_rdata_in_tap_regs;
wire [ 31: 0] dbmem_wdata_out_tap_regs;
wire          rc_in_tap_regs;
wire [  1: 0] size_in_tap_regs;
wire          pw_in_tap_regs;
wire          pr_in_tap_regs;
wire          ljtagbrk_in_tap_regs;
wire          dm_in_tap_regs;
wire          pr_out_tap_regs;
wire          pen_out_tap_regs;
wire          ljtagbrk_out_tap_regs;
wire          pr_enable_tap_regs;

wire          ind_sig;
wire          cap_i;
wire          shift_i;
wire          update_i;
wire          cap_d;
wire          shift_d;
wire          update_d;
wire          tlr_sig;
wire          tdo_i;
wire          tdo_d;

wire [  3: 0] inst;

wire [ 13: 0] sel;
wire          pr_en;

wire [  3: 0] curr_state;

wire          tdo_tmp;

//============================================================//
//                    Module Implementation
//============================================================//

// Instance Boundary Alias Mapping
// x_jtag_tap_fsm

assign tck_in_tap_fsm   =  tck_in;
assign trst_in_tap_fsm  =  trst_in;
assign tms_in_tap_fsm   =  tms_in;
assign ind_sig          =  ind_tap_fsm;
assign cap_i            =  capture_ir_tap_fsm;
assign shift_i          =  shift_ir_tap_fsm;
assign update_i         =  update_ir_tap_fsm;
assign cap_d            =  capture_dr_tap_fsm;
assign shift_d          =  shift_dr_tap_fsm;
assign update_d         =  update_dr_tap_fsm;
assign tlr_sig          =  tlr_tap_fsm;
assign pr_en            =  pr_enable_tap_fsm;
assign idle             =  idle_tap_fsm;
assign curr_state       =  curr_state_out_tap_fsm;
// x_jtag_tap_ir
assign tck_in_tap_ir   =  tck_in;
assign trst_in_tap_ir  =  trst_in;
assign s_rst_tap_ir    =  tlr_sig;
assign enable_tap_ir   =  1'b1;
assign cap_tap_ir      =  cap_i;
assign shift_tap_ir    =  shift_i;
assign update_tap_ir   =  update_i;
assign si_tap_ir       =  tdi_in;
assign tdo_i           =  so_tap_ir;
assign pi_tap_ir       =  inst;
assign inst            =  po_tap_ir;
// x_jtag_tap_dec
assign tap_lock_tap_dec    =  tap_lock;
assign tck_in_tap_dec      =  tck_in;
assign trst_in_tap_dec     =  trst_in;
assign inst_in_tap_dec     =  inst;
assign curr_state_tap_dec  =  curr_state;
assign sel                 =  select_tap_dec;
// x_jtag_tap_regs
assign tck_in_tap_regs          =  tck_in;
assign trst_in_tap_regs         =  trst_in;
assign tdi_in_tap_regs          =  tdi_in;
assign tdo_d                    =  tdo_out_tap_regs;
assign capture_dr_tap_regs      =  cap_d;
assign shift_dr_tap_regs        =  shift_d;
assign update_d_fsm_tap_regs    =  update_d;
assign select_tap_regs          =  sel;
assign normalboot_tap_regs      =  tlr_sig;
assign dbmem_addr_in_tap_regs   =  dbmem_addr_in;
assign pc_new_in_tap_regs       =  pc_new_in;
assign pc_in_tap_regs           =  pc_in;
assign asid_in_tap_regs         =  asid_in;
assign dbmem_rdata_in_tap_regs  =  dbmem_rdata_in;
assign dbmem_wdata_out          =  dbmem_wdata_out_tap_regs;
assign rc_in_tap_regs           =  rc_in;
assign size_in_tap_regs         =  size_in;
assign pw_in_tap_regs           =  pw_in;
assign pr_in_tap_regs           =  pr_in;
assign ljtagbrk_in_tap_regs     =  ljtagbrk_in;
assign dm_in_tap_regs           =  dm_in;
assign pr_out                   =  pr_out_tap_regs;
assign pen_out                  =  pen_out_tap_regs;
assign ljtagbrk_out             =  ljtagbrk_out_tap_regs;
assign pr_enable_tap_regs       =  pr_en;

assign tdo_tmp  =  ind_sig ? tdo_i : tdo_d;

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( negedge tck_in )
`else
always @ ( negedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        tdo_out <= 1'b0;
    end
    else begin
        tdo_out <= tdo_tmp;
    end
end

ljtag_tap_fsm x_jtag_tap_fsm (
    .tck_in         (tck_in_tap_fsm        ),
    .trst_in        (trst_in_tap_fsm       ),
    .tms_in         (tms_in_tap_fsm        ),
    .ind            (ind_tap_fsm           ),
    .capture_ir     (capture_ir_tap_fsm    ),
    .shift_ir       (shift_ir_tap_fsm      ),
    .update_ir      (update_ir_tap_fsm     ),
    .capture_dr     (capture_dr_tap_fsm    ),
    .shift_dr       (shift_dr_tap_fsm      ),
    .update_dr      (update_dr_tap_fsm     ),
    .tlr            (tlr_tap_fsm           ),
    .pr_enable      (pr_enable_tap_fsm     ),
    .idle           (idle_tap_fsm          ),
    .curr_state_out (curr_state_out_tap_fsm)
);

ljtag_tap_ir x_jtag_tap_ir (
    .tck_in  (tck_in_tap_ir ),
    .trst_in (trst_in_tap_ir),
    .s_rst   (s_rst_tap_ir  ),
    .enable  (enable_tap_ir ),
    .cap     (cap_tap_ir    ),
    .shift   (shift_tap_ir  ),
    .update  (update_tap_ir ),
    .si      (si_tap_ir     ),
    .so      (so_tap_ir     ),
    .pi      (pi_tap_ir     ),
    .po      (po_tap_ir     )
);

ljtag_tap_dec x_jtag_tap_dec (
    .tap_lock   (tap_lock_tap_dec  ),
    .tck_in     (tck_in_tap_dec    ),
    .trst_in    (trst_in_tap_dec   ),
    .inst_in    (inst_in_tap_dec   ),
    .curr_state (curr_state_tap_dec),
    .select     (select_tap_dec    )
);

ljtag_tap_regs x_jtag_tap_regs (
    .tck_in          (tck_in_tap_regs         ),
    .trst_in         (trst_in_tap_regs        ),
    .tdi_in          (tdi_in_tap_regs         ),
    .tdo_out         (tdo_out_tap_regs        ),
    .capture_dr      (capture_dr_tap_regs     ),
    .shift_dr        (shift_dr_tap_regs       ),
    .update_d_fsm    (update_d_fsm_tap_regs   ),
    .select          (select_tap_regs         ),
    .normalboot      (normalboot_tap_regs     ),
    .dbmem_addr_in   (dbmem_addr_in_tap_regs  ),
    .pc_new_in       (pc_new_in_tap_regs      ),
    .pc_in           (pc_in_tap_regs          ),
    .asid_in         (asid_in_tap_regs        ),
    .dbmem_rdata_in  (dbmem_rdata_in_tap_regs ),
    .dbmem_wdata_out (dbmem_wdata_out_tap_regs),
    .rc_in           (rc_in_tap_regs          ),
    .size_in         (size_in_tap_regs        ),
    .pw_in           (pw_in_tap_regs          ),
    .pr_in           (pr_in_tap_regs          ),
    .ljtagbrk_in     (ljtagbrk_in_tap_regs    ),
    .dm_in           (dm_in_tap_regs          ),
    .pr_out          (pr_out_tap_regs         ),
    .pen_out         (pen_out_tap_regs        ),
    .ljtagbrk_out    (ljtagbrk_out_tap_regs   ),
    .pr_enable       (pr_enable_tap_regs      )
);
endmodule

`endif  // OPEN132_HAS_LJTAG
