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

module mmu_ptw (
    input  wire           clk,
    input  wire           reset,

    input  wire           ptw_req_vld,
    input  wire           ptw_req_port,
    input  wire           ptw_req_write,
    input  wire [ 31: 0]  ptw_req_vaddr,
    input  wire [  9: 0]  ptw_req_asid,

    input  wire           ptw_resp_rdy,

    input  wire [ 31: 0]  csr_pgdl,
    input  wire [ 31: 0]  csr_pgdh,
    input  wire [ 31: 0]  csr_dmw0,
    input  wire [ 31: 0]  csr_dmw1,

    input  wire           ptw_mem_req_rdy,
    input  wire           ptw_mem_resp_vld,
    input  wire [ 31: 0]  ptw_mem_resp_data,
    input  wire           ptw_mem_resp_err,

    output wire           ptw_req_rdy,

    output wire           ptw_resp_vld,
    output wire           ptw_resp_port,
    output wire [ 31: 0]  ptw_resp_vaddr,
    output wire [  9: 0]  ptw_resp_asid,
    output wire [ 19: 0]  ptw_resp_ppn,
    output wire           ptw_resp_global,
    output wire           ptw_resp_dirty,
    output wire [  1: 0]  ptw_resp_plv,
    output wire [  1: 0]  ptw_resp_mat,
    output wire           ptw_resp_page_vld,
    output wire           ptw_resp_bus_err,

    output wire           ptw_mem_req_vld,
    output wire [ 31: 0]  ptw_mem_req_paddr
);

//============================================================//
//                Local Parameter Declarations
//============================================================//

localparam PTW_IDLE      = 3'd0;
localparam PTW_DIR_REQ   = 3'd1;
localparam PTW_DIR_WAIT  = 3'd2;
localparam PTW_PTE_REQ   = 3'd3;
localparam PTW_PTE_WAIT  = 3'd4;
localparam PTW_RESP      = 3'd5;

//============================================================//
//                     Regs Declarations
//============================================================//

reg [  2: 0] state_r;
reg [  2: 0] state_nxt;
reg          port_r;
reg          write_r;
reg [ 31: 0] vaddr_r;
reg [  9: 0] asid_r;
reg [ 31: 0] dir_addr_r;
reg [ 31: 0] pte_addr_r;
reg [ 31: 0] pte_r;
reg          bus_err_r;

//============================================================//
//                     Wire Declarations
//============================================================//

wire          req_fire;
wire          mem_req_fire;
wire [ 31: 0] selected_pgd;
wire [  2: 0] selected_pgd_vseg;
wire          selected_pgd_dmw0_hit;
wire          selected_pgd_dmw1_hit;
wire [ 31: 0] selected_pgd_paddr;
wire [ 31: 0] req_dir_addr;

wire [  2: 0] dir_entry_vseg;
wire          dir_entry_dmw0_hit;
wire          dir_entry_dmw1_hit;
wire [ 31: 0] dir_entry_paddr;
wire [ 31: 0] resp_pte_addr;
wire          dir_entry_empty;
wire          dir_entry_huge;
wire          pte_present;
wire          pte_write_ok;


//------------------------------------------------------------//
//                 Request Address Formation
//------------------------------------------------------------//

assign selected_pgd           =  ptw_req_vaddr[31] ? csr_pgdh : csr_pgdl;
assign selected_pgd_vseg      =  selected_pgd[31:29];
assign selected_pgd_dmw0_hit  =  csr_dmw0[0]
                                 && (selected_pgd_vseg == csr_dmw0[31:29]);
assign selected_pgd_dmw1_hit  =  csr_dmw1[0]
                                 && (selected_pgd_vseg == csr_dmw1[31:29]);
assign selected_pgd_paddr     =  selected_pgd_dmw0_hit
                                 ? {csr_dmw0[27:25], selected_pgd[28:0]}
                                 : selected_pgd_dmw1_hit
                                 ? {csr_dmw1[27:25], selected_pgd[28:0]}
                                 : selected_pgd;
assign req_dir_addr           =  (selected_pgd_paddr & 32'hffff_f000)
                                 | {20'd0, ptw_req_vaddr[31:22], 2'b0};

assign dir_entry_vseg         =  ptw_mem_resp_data[31:29];
assign dir_entry_dmw0_hit     =  csr_dmw0[0]
                                 && (dir_entry_vseg == csr_dmw0[31:29]);
assign dir_entry_dmw1_hit     =  csr_dmw1[0]
                                 && (dir_entry_vseg == csr_dmw1[31:29]);
assign dir_entry_paddr        =  dir_entry_dmw0_hit
                                 ? {csr_dmw0[27:25], ptw_mem_resp_data[28:0]}
                                 : dir_entry_dmw1_hit
                                 ? {csr_dmw1[27:25], ptw_mem_resp_data[28:0]}
                                 : ptw_mem_resp_data;
assign resp_pte_addr          =  (dir_entry_paddr & 32'hffff_f000)
                              | {20'd0, vaddr_r[21:12], 2'b0};
assign dir_entry_empty        =  ptw_mem_resp_data[31:12] == 20'd0;
assign dir_entry_huge         =  ptw_mem_resp_data[6];

//------------------------------------------------------------//
//                         Handshakes
//------------------------------------------------------------//

assign ptw_req_rdy            =  state_r == PTW_IDLE;
assign req_fire               =  ptw_req_vld && ptw_req_rdy;
assign ptw_mem_req_vld        =  (state_r == PTW_DIR_REQ)
                                 || (state_r == PTW_PTE_REQ);
assign ptw_mem_req_paddr      =  state_r == PTW_DIR_REQ ? dir_addr_r : pte_addr_r;
assign mem_req_fire           =  ptw_mem_req_vld && ptw_mem_req_rdy;

//------------------------------------------------------------//
//                    Response Projection
//------------------------------------------------------------//

assign ptw_resp_vld           =  state_r == PTW_RESP;
assign ptw_resp_port          =  port_r;
assign ptw_resp_vaddr         =  vaddr_r;
assign ptw_resp_asid          =  asid_r;
assign ptw_resp_ppn           =  pte_r[27:8];
assign ptw_resp_global        =  pte_r[6];
assign pte_present            =  pte_r[7] || pte_r[0];
assign pte_write_ok           =  pte_r[29];
assign ptw_resp_dirty         =  pte_r[1]
                                 || (write_r && pte_present && pte_write_ok);
assign ptw_resp_plv           =  pte_r[3:2];
assign ptw_resp_mat           =  pte_r[5:4];
assign ptw_resp_page_vld      =  pte_present;
assign ptw_resp_bus_err       =  bus_err_r;

//------------------------------------------------------------//
//                       State Machine
//------------------------------------------------------------//

always @ ( state_r
           or req_fire
           or mem_req_fire
           or ptw_mem_resp_vld
           or ptw_mem_resp_err
           or dir_entry_empty
           or dir_entry_huge
           or ptw_resp_rdy
         )
begin
    state_nxt = PTW_IDLE;

    case(state_r)
        PTW_IDLE: begin
            if(req_fire) begin
                state_nxt = PTW_DIR_REQ;
            end
            else begin
                state_nxt = PTW_IDLE;
            end
        end
        PTW_DIR_REQ: begin
            if(mem_req_fire) begin
                state_nxt = PTW_DIR_WAIT;
            end
            else begin
                state_nxt = PTW_DIR_REQ;
            end
        end
        PTW_DIR_WAIT: begin
            if(ptw_mem_resp_vld) begin
                if(ptw_mem_resp_err || dir_entry_empty || dir_entry_huge) begin
                    state_nxt = PTW_RESP;
                end
                else begin
                    state_nxt = PTW_PTE_REQ;
                end
            end
            else begin
                state_nxt = PTW_DIR_WAIT;
            end
        end
        PTW_PTE_REQ: begin
            if(mem_req_fire) begin
                state_nxt = PTW_PTE_WAIT;
            end
            else begin
                state_nxt = PTW_PTE_REQ;
            end
        end
        PTW_PTE_WAIT: begin
            if(ptw_mem_resp_vld) begin
                state_nxt = PTW_RESP;
            end
            else begin
                state_nxt = PTW_PTE_WAIT;
            end
        end
        PTW_RESP: begin
            if(ptw_resp_rdy) begin
                state_nxt = PTW_IDLE;
            end
            else begin
                state_nxt = PTW_RESP;
            end
        end
        default: begin
            state_nxt = PTW_IDLE;
        end
    endcase
end

//------------------------------------------------------------//
//                  Sequential State Update
//------------------------------------------------------------//
always @ ( posedge clk )
begin
    if(reset) begin
        state_r <= PTW_IDLE;
    end
    else begin
        state_r   <= state_nxt;
    end
end

//------------------------------------------------------------//
//                       Payload State
//------------------------------------------------------------//

always @ ( posedge clk )
begin
    if(req_fire) begin
        port_r     <= ptw_req_port;
        write_r    <= ptw_req_write;
        vaddr_r    <= ptw_req_vaddr;
        asid_r     <= ptw_req_asid;
        dir_addr_r <= req_dir_addr;
    end

    if((state_r == PTW_DIR_WAIT) && ptw_mem_resp_vld) begin
        if(ptw_mem_resp_err || dir_entry_empty || dir_entry_huge) begin
            pte_r      <= 32'd0;
        end
        else begin
            pte_addr_r <= resp_pte_addr;
        end
    end

    if((state_r == PTW_PTE_WAIT) && ptw_mem_resp_vld) begin
        pte_r     <= ptw_mem_resp_err ? 32'd0 : ptw_mem_resp_data;
    end

    if(req_fire) begin
        bus_err_r <= 1'b0;
    end
    else if((state_r == PTW_DIR_WAIT) && ptw_mem_resp_vld) begin
        bus_err_r <= ptw_mem_resp_err;
    end
    else if((state_r == PTW_PTE_WAIT) && ptw_mem_resp_vld) begin
        bus_err_r <= ptw_mem_resp_err;
    end
end

endmodule
`endif
