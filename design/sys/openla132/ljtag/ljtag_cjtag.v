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

module ljtag_cjtag (
    input  wire           clk,  // always exists clk

    input  wire           reset_in,  // power on reset

    input  wire           tckc,
    input  wire           tmsc_i,
    output reg            tmsc_o,
    output wire           tmsc_oe,  // high active

    output wire           ljtag_trstn,
    output reg            ljtag_tck,
    output reg            ljtag_tms,
    output reg            ljtag_tdi,
    input  wire           ljtag_tdo
);

localparam MODE_OFFLINE    = 2'b00;
localparam MODE_ONLINE     = 2'b01;
localparam MODE_ACTIVATION = 2'b10;
localparam TRAN_TDI        = 2'b00;
localparam TRAN_TMS        = 2'b01;
localparam TRAN_TDO        = 2'b10;

//============================================================//
//                     Regs Declarations
//============================================================//

reg [  1: 0] mode;

reg [  3: 0] edge_counter;
reg [  3: 0] edge_counter_r;

reg [ 11: 0] acti_code;
reg [  3: 0] code_counter;

reg [  1: 0] tmsc_split;

reg          tckc_r1;
reg          tmsc_r1;
reg          tckc_r2;
reg          tmsc_r2;
reg          tckc_r3;
reg          tmsc_r3;

//============================================================//
//                     Wire Declarations
//============================================================//

wire          code_rec_finish;

wire          oac_match;
wire          ec_match;
wire          cp_match;
wire          acti_code_match;

wire          pos_tckc;
wire          neg_tckc;
wire          pos_tmsc;
wire          neg_tmsc;

//============================================================//
//                    Module Implementation
//============================================================//

// sync io

always @ ( posedge clk or posedge reset_in )
begin
    if(reset_in) begin
        tckc_r1 <= 1'b0;
        tckc_r2 <= 1'b0;
        tckc_r3 <= 1'b0;
        tmsc_r1 <= 1'b0;
        tmsc_r2 <= 1'b0;
        tmsc_r3 <= 1'b0;
    end
    else begin
        tckc_r1 <= tckc;
        tmsc_r1 <= tmsc_i;
        tckc_r2 <= tckc_r1;
        tmsc_r2 <= tmsc_r1;
        tckc_r3 <= tckc_r2;
        tmsc_r3 <= tmsc_r2;
    end
end

assign pos_tckc  =  !tckc_r3 && tckc_r2;
assign neg_tckc  =  tckc_r3 && !tckc_r2;
assign pos_tmsc  =  !tmsc_r3 && tmsc_r2;
assign neg_tmsc  =  tmsc_r3 && !tmsc_r2;

always @ ( posedge clk or posedge reset_in )
begin
    if(reset_in) begin
        edge_counter <= 4'b0;
    end
    else if(!tckc_r2) begin
        edge_counter <= 4'b0;
    end
    else if((tmsc_r3 != tmsc_r2) && !edge_counter[3]) begin
        edge_counter <= edge_counter + 1'b1;
    end
end

always @ ( posedge clk or posedge reset_in )
begin
    if(reset_in) begin
        edge_counter_r <= 4'b0;
    end
    else if(neg_tckc) begin
        edge_counter_r <= edge_counter;
    end
end

// mode trans
always @ ( posedge clk or posedge reset_in )
begin
    if(reset_in) begin
        mode <= MODE_OFFLINE;
    end
    else if(pos_tckc) begin
        if(mode == MODE_OFFLINE && edge_counter_r[3:1] == 3'b11) begin
            mode <= MODE_ONLINE;
        end
        else if(mode == MODE_ONLINE && code_rec_finish && acti_code_match) begin
            mode <= MODE_ACTIVATION;
        end
        else if((mode == MODE_ACTIVATION && |edge_counter_r[3:1]) ||
                (mode == MODE_ONLINE && code_rec_finish && !acti_code_match)) begin
            mode <= MODE_OFFLINE;
        end
    end
end

// Receive the 12-bit activation code, LSB first.
always @ ( posedge clk )
begin
    if(pos_tckc) begin
        if(mode != MODE_ONLINE) begin
            code_counter <= 4'b1;
            acti_code    <= {11'b0, tmsc_r2};
        end
        else begin
            acti_code    <= {acti_code[10:0], tmsc_r2};
            code_counter <= code_counter + 1'b1;
        end
    end
end
assign code_rec_finish  =  code_counter == 4'd12;

// Online Activation Code:
assign oac_match  =  acti_code[11:8] == 4'b11;

// Extension Code:
assign ec_match  =  acti_code[7:4] == 4'b1;

// Check Packet:
assign cp_match         =  acti_code[3:0] == 4'b0;
assign acti_code_match  =  oac_match && ec_match && cp_match;
// actually activition code is meanless in this design. only one working mode can choose.

// oscan 1 / normal working
always @ ( posedge clk )
begin
    if(pos_tckc) begin
        if(tmsc_split == TRAN_TDI || mode != MODE_ACTIVATION ||
                mode == MODE_ACTIVATION && |edge_counter_r[3:1]) begin
            ljtag_tdi  <= ~tmsc_r2;
            tmsc_split <= TRAN_TMS;
        end
        else if(tmsc_split == TRAN_TDO) begin
            tmsc_split <= TRAN_TDI;
        end
        else if(tmsc_split == TRAN_TMS) begin
            ljtag_tms  <= tmsc_r2;
            tmsc_split <= TRAN_TDO;
        end
    end
end

assign tmsc_oe      =  tmsc_split == TRAN_TDO && !tckc_r2;
assign ljtag_trstn  =  ~(mode == MODE_OFFLINE);

always @ ( posedge clk )
begin
    tmsc_o <= ljtag_tdo;
end

always @ ( posedge clk )
begin
    if((tmsc_split == TRAN_TDO) && (!tckc_r3 && tckc_r2)) begin
        ljtag_tck <= 1'b1;
    end
    else begin
        ljtag_tck <= 1'b0;
    end
end

endmodule
