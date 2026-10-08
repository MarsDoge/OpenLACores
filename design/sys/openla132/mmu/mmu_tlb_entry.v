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

module mmu_tlb_entry (
    input  wire           clk,
    input  wire           reset,

    input  wire           lookup0_vld,
    input  wire [ 19: 0]  lookup0_vpn,
    input  wire [  9: 0]  lookup0_asid,

    input  wire           lookup1_vld,
    input  wire [ 19: 0]  lookup1_vpn,
    input  wire [  9: 0]  lookup1_asid,

    input  wire           fill_vld,
    input  wire [ 19: 0]  fill_vpn,
    input  wire [ 19: 0]  fill_ppn,
    input  wire [  9: 0]  fill_asid,
    input  wire           fill_global,
    input  wire           fill_dirty,
    input  wire [  1: 0]  fill_plv,
    input  wire [  1: 0]  fill_mat,

    input  wire           inv_vld,
    input  wire [  4: 0]  inv_op,
    input  wire [  9: 0]  inv_asid,
    input  wire [ 19: 0]  inv_vpn,

    output wire           lookup0_hit,
    output wire           lookup1_hit,
    output wire [ 19: 0]  entry_ppn,
    output wire           entry_dirty,
    output wire [  1: 0]  entry_plv,
    output wire [  1: 0]  entry_mat
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg          vld_r;
reg [ 19: 0] vpn_r;
reg [ 19: 0] ppn_r;
reg [  9: 0] asid_r;
reg          global_r;
reg          dirty_r;
reg [  1: 0] plv_r;
reg [  1: 0] mat_r;

//============================================================//
//                     Wire Declarations
//============================================================//

wire         lookup0_asid_match;
wire         lookup1_asid_match;
wire         inv_asid_match;
wire         inv_vpn_match;
wire         inv_match;

//============================================================//
//                   Module Implementation
//============================================================//

//------------------------------------------------------------//
//                           Lookup
//------------------------------------------------------------//

assign lookup0_asid_match     =  global_r || (asid_r == lookup0_asid);
assign lookup1_asid_match     =  global_r || (asid_r == lookup1_asid);

assign lookup0_hit            =  lookup0_vld && vld_r && lookup0_asid_match
                                 && (vpn_r == lookup0_vpn);
assign lookup1_hit            =  lookup1_vld && vld_r && lookup1_asid_match
                                 && (vpn_r == lookup1_vpn);

//------------------------------------------------------------//
//                        Maintenance
//------------------------------------------------------------//

assign inv_asid_match         =  asid_r == inv_asid;
// LA32 INVTLB addresses a paired 8 KiB VPPN when the page size is 4 KiB.
// The internal L1TLB stores one 4 KiB page per entry, so ignore VPN bit 0
// during maintenance to invalidate both pages in the architected pair.
assign inv_vpn_match          =  vpn_r[19:1] == inv_vpn[19:1];

assign inv_match              =  (inv_op == 5'd0)
                                 || (inv_op == 5'd1)
                                 || ((inv_op == 5'd2) && global_r)
                                 || ((inv_op == 5'd3) && !global_r)
                                 || ((inv_op == 5'd4) && !global_r && inv_asid_match)
                                 || ((inv_op == 5'd5) && !global_r && inv_asid_match
                                     && inv_vpn_match)
                                 || ((inv_op == 5'd6) && inv_vpn_match
                                     && (global_r || inv_asid_match));

//------------------------------------------------------------//
//                        Entry State
//------------------------------------------------------------//

always @ ( posedge clk )
begin
    if(reset) begin
        vld_r <= 1'b0;
    end
    else if(inv_vld && inv_match) begin
        vld_r <= 1'b0;
    end
    else if(fill_vld) begin
        vld_r <= 1'b1;
    end
end

//------------------------------------------------------------//
//                       Entry Payload
//------------------------------------------------------------//
always @ ( posedge clk )
begin
    if(fill_vld) begin
        vpn_r    <= fill_vpn;
        ppn_r    <= fill_ppn;
        asid_r   <= fill_asid;
        global_r <= fill_global;
        dirty_r  <= fill_dirty;
        plv_r    <= fill_plv;
        mat_r    <= fill_mat;
    end
end

//------------------------------------------------------------//
//                      Entry Projection
//------------------------------------------------------------//

assign entry_ppn              =  ppn_r;
assign entry_dirty            =  dirty_r;
assign entry_plv              =  plv_r;
assign entry_mat              =  mat_r;

endmodule
`endif
