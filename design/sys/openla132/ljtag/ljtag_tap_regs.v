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

module ljtag_tap_regs (
    input  wire           tck_in,
    input  wire           trst_in,
    input  wire           tdi_in,
    output wire           tdo_out,

    input  wire           capture_dr,
    input  wire           shift_dr,
    input  wire           update_d_fsm,
    input  wire [ 13: 0]  select,
    input  wire           normalboot,

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

    output reg            pr_out,
    output wire           pen_out,
    output reg            ljtagbrk_out,

    input  wire           pr_enable
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg          buffer_1_ctl_rc;
reg          buffer_2_ctl_rc;
reg          buffer_1_ctl_dm;
reg          buffer_2_ctl_dm;
reg          buffer_1_ctl_pr;
reg          buffer_2_ctl_pr;

reg [ 31: 0] ctl_in;

reg          tdo_pr;
reg          tdo_bypass;

reg          tdo;

reg [ 31: 0] dbmem_addr;

reg [ 31: 0] dbmem_data;

reg [  4: 0] ctl2;
reg [  4: 0] sctl2;

reg          tdo_brk;

reg [ 40: 0] pc_extend;

//============================================================//
//                     Wire Declarations
//============================================================//

wire          tck_in_tap_idreg;
wire          trst_in_tap_idreg;
wire          enable_tap_idreg;
wire          cap_tap_idreg;
wire          shift_tap_idreg;
wire          si_tap_idreg;
wire          so_tap_idreg;
wire          tck_in_tap_impreg;
wire          trst_in_tap_impreg;
wire          enable_tap_impreg;
wire          cap_tap_impreg;
wire          shift_tap_impreg;
wire          si_tap_impreg;
wire          so_tap_impreg;
wire          tck_in_tap_zero0;
wire          trst_in_tap_zero0;
wire          enable_tap_zero0;
wire          cap_tap_zero0;
wire          shift_tap_zero0;
wire          si_tap_zero0;
wire [ 31: 0] pi_tap_zero0;
wire          so_tap_zero0;
wire          tck_in_tap_zero1;
wire          trst_in_tap_zero1;
wire          enable_tap_zero1;
wire          cap_tap_zero1;
wire          shift_tap_zero1;
wire          si_tap_zero1;
wire [ 31: 0] pi_tap_zero1;
wire          so_tap_zero1;
wire [ 31: 0] po_tap_zero1;
wire          tck_in_tap_ctl31;
wire          trst_in_tap_ctl31;
wire          enable_tap_ctl31;
wire          cap_tap_ctl31;
wire          shift_tap_ctl31;
wire          update_tap_ctl31;
wire          si_tap_ctl31;
wire [ 12: 0] pi_tap_ctl31;
wire          so_tap_ctl31;
wire          clear_rc_tap_ctl31;
wire          tck_in_tap_ctl11;
wire          trst_in_tap_ctl11;
wire          enable_tap_ctl11;
wire          cap_tap_ctl11;
wire          shift_tap_ctl11;
wire          si_tap_ctl11;
wire [  2: 0] pi_tap_ctl11;
wire          so_tap_ctl11;
wire          tck_in_tap_ctl8;
wire          trst_in_tap_ctl8;
wire          enable_tap_ctl8;
wire          cap_tap_ctl8;
wire          shift_tap_ctl8;
wire          si_tap_ctl8;
wire [  4: 0] pi_tap_ctl8;
wire          so_tap_ctl8;
wire          tck_in_tap_ctl3;
wire          trst_in_tap_ctl3;
wire          enable_tap_ctl3;
wire          cap_tap_ctl3;
wire          shift_tap_ctl3;
wire          si_tap_ctl3;
wire [  3: 0] pi_tap_ctl3;
wire          so_tap_ctl3;
wire          tck_in_tap_pcreg;
wire          trst_in_tap_pcreg;
wire          enable_tap_pcreg;
wire          cap_tap_pcreg;
wire          shift_tap_pcreg;
wire          si_tap_pcreg;
wire [ 40: 0] pi_tap_pcreg;
wire          so_tap_pcreg;
wire          sr0_tap_pcreg;

wire          clear_rc;

wire          pr_will_set;

wire          update_dr;

wire          tdo_id;
wire          tdo_imp;
wire          tdo_addr;
wire          tdo_data;
wire          tdo_ctl;

wire          tdo_pc;

wire          tdi_data;

wire [ 31: 0] data_pi;
wire [ 31: 0] data_po;

wire          tdo_ctl1;
wire          tdi_ctl;

wire          pr_sin;

wire          tdo_ctl2;

wire          tdo_ctl3;

wire          tdo_ctl4;

wire          new_pc_po;

//============================================================//
//                    Module Implementation
//============================================================//

// Instance Boundary Alias Mapping
// x_jtag_tap_idreg

assign tck_in_tap_idreg   =  tck_in;
assign trst_in_tap_idreg  =  trst_in;
assign enable_tap_idreg   =  select[0];
assign cap_tap_idreg      =  capture_dr;
assign shift_tap_idreg    =  shift_dr;
assign si_tap_idreg       =  tdi_in;
assign tdo_id             =  so_tap_idreg;
// x_jtag_tap_impreg
assign tck_in_tap_impreg   =  tck_in;
assign trst_in_tap_impreg  =  trst_in;
assign enable_tap_impreg   =  select[1];
assign cap_tap_impreg      =  capture_dr;
assign shift_tap_impreg    =  shift_dr;
assign si_tap_impreg       =  tdi_in;
assign tdo_imp             =  so_tap_impreg;
// x_jtag_tap_zero_0
assign tck_in_tap_zero0   =  tck_in;
assign trst_in_tap_zero0  =  trst_in;
assign enable_tap_zero0   =  select[2];
assign cap_tap_zero0      =  capture_dr;
assign shift_tap_zero0    =  shift_dr;
assign si_tap_zero0       =  tdi_in;
assign pi_tap_zero0       =  dbmem_addr[31:0];
assign tdo_addr           =  so_tap_zero0;
// x_jtag_tap_zero_1
assign tck_in_tap_zero1   =  tck_in;
assign trst_in_tap_zero1  =  trst_in;
assign enable_tap_zero1   =  select[3];
assign cap_tap_zero1      =  capture_dr;
assign shift_tap_zero1    =  shift_dr;
assign si_tap_zero1       =  tdi_data;
assign pi_tap_zero1       =  data_pi[31:0];
assign tdo_data           =  so_tap_zero1;
assign data_po            =  po_tap_zero1;
// x_jtag_tap_ctl_31_19
assign tck_in_tap_ctl31   =  tck_in;
assign trst_in_tap_ctl31  =  trst_in;
assign enable_tap_ctl31   =  select[4];
assign cap_tap_ctl31      =  capture_dr;
assign shift_tap_ctl31    =  shift_dr;
assign update_tap_ctl31   =  update_d_fsm;
assign si_tap_ctl31       =  tdi_ctl;
assign pi_tap_ctl31       =  ctl_in[31:19];
assign tdo_ctl1           =  so_tap_ctl31;
assign clear_rc           =  clear_rc_tap_ctl31;
// x_jtag_tap_ctl_11_9
assign tck_in_tap_ctl11   =  tck_in;
assign trst_in_tap_ctl11  =  trst_in;
assign enable_tap_ctl11   =  select[4];
assign cap_tap_ctl11      =  capture_dr;
assign shift_tap_ctl11    =  shift_dr;
assign si_tap_ctl11       =  tdo_brk;
assign pi_tap_ctl11       =  ctl_in[11:9];
assign tdo_ctl3           =  so_tap_ctl11;
// x_jtag_tap_ctl_8_4
assign tck_in_tap_ctl8   =  tck_in;
assign trst_in_tap_ctl8  =  trst_in;
assign enable_tap_ctl8   =  select[4];
assign cap_tap_ctl8      =  capture_dr;
assign shift_tap_ctl8    =  shift_dr;
assign si_tap_ctl8       =  tdo_ctl3;
assign pi_tap_ctl8       =  ctl_in[8:4];
assign tdo_ctl4          =  so_tap_ctl8;
// x_jtag_tap_ctl_3_0
assign tck_in_tap_ctl3   =  tck_in;
assign trst_in_tap_ctl3  =  trst_in;
assign enable_tap_ctl3   =  select[4];
assign cap_tap_ctl3      =  capture_dr;
assign shift_tap_ctl3    =  shift_dr;
assign si_tap_ctl3       =  tdo_ctl4;
assign pi_tap_ctl3       =  ctl_in[3:0];
assign tdo_ctl           =  so_tap_ctl3;
// x_jtag_tap_pcreg
assign tck_in_tap_pcreg   =  tck_in;
assign trst_in_tap_pcreg  =  trst_in;
assign enable_tap_pcreg   =  select[10];
assign cap_tap_pcreg      =  capture_dr;
assign shift_tap_pcreg    =  shift_dr;
assign si_tap_pcreg       =  tdi_in;
assign pi_tap_pcreg       =  pc_extend;
assign tdo_pc             =  so_tap_pcreg;
assign new_pc_po          =  sr0_tap_pcreg;

assign update_dr  =  update_d_fsm && (clear_rc || !ctl_in[31]);

assign tdo_out  =  tdo;
always @ ( select
           or tdo_id
           or tdo_imp
           or tdo_bypass
           or tdo_addr
           or tdo_data
           or tdo_ctl
           or tdo_pr
           or tdo_pc
         )
begin
    case(select[11:0])
        12'b0000_0000_0001   :  tdo = tdo_id;
        12'b0000_0000_0010   :  tdo = tdo_imp;
        12'b0000_0100_0000   :  tdo = tdo_bypass;
        12'b0000_0000_0100   :  tdo = tdo_addr;
        12'b0000_0000_1000   :  tdo = tdo_data;
        12'b0000_0001_0000   :  tdo = tdo_ctl;
        12'b0000_0001_1100   :  tdo = tdo_ctl;
        12'b0000_0010_1000   :  tdo = tdo_pr;
        12'b0100_0000_0000   :  tdo = tdo_pc;
        default              :  tdo = 1'b0;
    endcase
end

ljtag_tap_idreg x_jtag_tap_idreg (
    .tck_in  (tck_in_tap_idreg ),
    .trst_in (trst_in_tap_idreg),
    .enable  (enable_tap_idreg ),
    .cap     (cap_tap_idreg    ),
    .shift   (shift_tap_idreg  ),
    .si      (si_tap_idreg     ),
    .so      (so_tap_idreg     )
);

ljtag_tap_impreg x_jtag_tap_impreg (
    .tck_in  (tck_in_tap_impreg ),
    .trst_in (trst_in_tap_impreg),
    .enable  (enable_tap_impreg ),
    .cap     (cap_tap_impreg    ),
    .shift   (shift_tap_impreg  ),
    .si      (si_tap_impreg     ),
    .so      (so_tap_impreg     )
);

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        dbmem_addr <= 32'h0000_0000;
    end
    else if(pr_will_set) begin
        dbmem_addr <= dbmem_addr_in;
    end
end
ljtag_tap_zero x_jtag_tap_zero_0 (
    .tck_in  (tck_in_tap_zero0 ),
    .trst_in (trst_in_tap_zero0),
    .enable  (enable_tap_zero0 ),
    .cap     (cap_tap_zero0    ),
    .shift   (shift_tap_zero0  ),
    .si      (si_tap_zero0     ),
    .pi      (pi_tap_zero0     ),
    .so      (so_tap_zero0     ),
    .po      (                 )
);

assign tdi_data         =  select[12] ? tdo_addr : tdi_in;
assign data_pi          =  dbmem_data;
assign dbmem_wdata_out  =  dbmem_data;
`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        dbmem_data <= 32'h0000_0000;
    end
    else if(pr_will_set && pw_in) begin
        dbmem_data <= dbmem_rdata_in;
    end
    else if(update_dr && select[3]) begin
        dbmem_data <= data_po;
    end
end

ljtag_tap_zero x_jtag_tap_zero_1 (
    .tck_in  (tck_in_tap_zero1 ),
    .trst_in (trst_in_tap_zero1),
    .enable  (enable_tap_zero1 ),
    .cap     (cap_tap_zero1    ),
    .shift   (shift_tap_zero1  ),
    .si      (si_tap_zero1     ),
    .pi      (pi_tap_zero1     ),
    .so      (so_tap_zero1     ),
    .po      (po_tap_zero1     )
);

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        buffer_1_ctl_rc <= 1'b0;
        buffer_1_ctl_dm <= 1'b0;
        buffer_1_ctl_pr <= 1'b0;
        buffer_2_ctl_rc <= 1'b0;
        buffer_2_ctl_dm <= 1'b0;
        buffer_2_ctl_pr <= 1'b0;
    end
    else begin
        buffer_1_ctl_rc <= rc_in;
        buffer_1_ctl_dm <= dm_in;
        buffer_1_ctl_pr <= pr_in;

        buffer_2_ctl_rc <= buffer_1_ctl_rc;
        buffer_2_ctl_dm <= buffer_1_ctl_dm;
        buffer_2_ctl_pr <= buffer_1_ctl_pr;
    end
end
assign pr_will_set  =  buffer_2_ctl_pr && pr_enable;

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        ctl_in <= 32'h0000_0000;
    end
    else begin
        if(buffer_2_ctl_rc) begin
            ctl_in[31] <= 1'b1;
        end
        else if(clear_rc && ctl_in[31]) begin
            ctl_in[31] <= 1'b0;
        end

        if(pr_will_set) begin
            ctl_in[30:19] <= {size_in, 9'b0_0000_0000, pw_in};
            ctl_in[18]    <= 1'b1;
        end
        else if(update_dr && (select[4] || select[5]) && !tdo_pr) begin
            ctl_in[18] <= 1'b0;
        end

        ctl_in[17:9] <= {1'b0, 1'b0, pen_out, 1'b0,1'b0, ljtagbrk_in, 3'b000};
        ctl_in[ 8:4] <= 5'h0;
        ctl_in[   3] <= buffer_2_ctl_dm;
        ctl_in[ 2:0] <= 3'b000;
    end
end

assign tdi_ctl  =  select[12] ? tdo_data : tdi_in;
ljtag_tap_ctl_31_19 x_jtag_tap_ctl_31_19 (
    .tck_in   (tck_in_tap_ctl31  ),
    .trst_in  (trst_in_tap_ctl31 ),
    .enable   (enable_tap_ctl31  ),
    .cap      (cap_tap_ctl31     ),
    .shift    (shift_tap_ctl31   ),
    .update   (update_tap_ctl31  ),
    .si       (si_tap_ctl31      ),
    .pi       (pi_tap_ctl31      ),
    .so       (so_tap_ctl31      ),
    .clear_rc (clear_rc_tap_ctl31)
);

assign pr_sin  =  select[5] ? tdo_data : tdo_ctl1;
`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        tdo_pr <= 1'b0;
    end
    else if(capture_dr && (select[4] || select[5])) begin
        tdo_pr <= ctl_in[18];
    end
    else if(shift_dr && (select[4] || select[5])) begin
        tdo_pr <= pr_sin;
    end
end

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        pr_out <= 1'b0;
    end
    else if(update_dr && (select[4] || select[5])) begin
        if(!tdo_pr) begin
            pr_out <= 1'b0;
        end
    end
    else if(ctl_in[18]) begin
        pr_out <= 1'b1;
    end
end

assign pen_out   =  ctl2[2];
assign tdo_ctl2  =  sctl2[0];
`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        sctl2 <= 5'b0_0100;
    end
    else if(normalboot) begin
        sctl2 <= {1'b0,sctl2[3],3'b000};
    end
    else if(capture_dr && select[4]) begin
        sctl2 <= ctl2;
    end
    else if(shift_dr && select[4]) begin
        sctl2 <= {tdo_pr, sctl2[4:1]};
    end
end

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        ctl2 <= 5'b0_0000;
    end
    else if(normalboot) begin
        ctl2 <= {1'b0,ctl2[3],3'b000};
    end
    else if(update_dr && select[4]) begin
        ctl2 <= sctl2;
    end
end

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        tdo_brk <= 1'b0;
    end
    else if(normalboot) begin
        tdo_brk <= 1'b0;
    end
    else if(capture_dr && select[4]) begin
        tdo_brk <= ljtagbrk_out;
    end
    else if(shift_dr && select[4]) begin
        tdo_brk <= tdo_ctl2;
    end
end

always @ ( posedge tck_in or negedge trst_in )
begin
    if(!trst_in) begin
        ljtagbrk_out <= 1'b0;
    end
    else if(normalboot) begin
        ljtagbrk_out <= 1'b0;
    end
    else if(update_dr && select[4]) begin
        if(tdo_brk) begin
            ljtagbrk_out <= 1'b1;
        end
    end
    else if(ctl_in[3]) begin
        ljtagbrk_out <= 1'b0;
    end
end

ljtag_tap_ctl_11_9 x_jtag_tap_ctl_11_9 (
    .tck_in  (tck_in_tap_ctl11 ),
    .trst_in (trst_in_tap_ctl11),
    .enable  (enable_tap_ctl11 ),
    .cap     (cap_tap_ctl11    ),
    .shift   (shift_tap_ctl11  ),
    .si      (si_tap_ctl11     ),
    .pi      (pi_tap_ctl11     ),
    .so      (so_tap_ctl11     )
);

ljtag_tap_ctl_8_4 x_jtag_tap_ctl_8_4 (
    .tck_in  (tck_in_tap_ctl8 ),
    .trst_in (trst_in_tap_ctl8),
    .enable  (enable_tap_ctl8 ),
    .cap     (cap_tap_ctl8    ),
    .shift   (shift_tap_ctl8  ),
    .si      (si_tap_ctl8     ),
    .pi      (pi_tap_ctl8     ),
    .so      (so_tap_ctl8     )
);

ljtag_tap_ctl_3_0 x_jtag_tap_ctl_3_0 (
    .tck_in  (tck_in_tap_ctl3 ),
    .trst_in (trst_in_tap_ctl3),
    .enable  (enable_tap_ctl3 ),
    .cap     (cap_tap_ctl3    ),
    .shift   (shift_tap_ctl3  ),
    .si      (si_tap_ctl3     ),
    .pi      (pi_tap_ctl3     ),
    .so      (so_tap_ctl3     )
);

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        tdo_bypass <= 1'b0;
    end
    else if(shift_dr && select[6]) begin
        tdo_bypass <= tdi_in;
    end
end

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        pc_extend <= 41'd0;
    end
    else if(pc_new_in) begin
        pc_extend <= {asid_in,pc_in,1'b1};
    end
    else if(update_dr && select[10] && !new_pc_po) begin
        pc_extend[0] <= 1'b0;
    end
end
ljtag_tap_pcreg x_jtag_tap_pcreg (
    .tck_in  (tck_in_tap_pcreg ),
    .trst_in (trst_in_tap_pcreg),
    .enable  (enable_tap_pcreg ),
    .cap     (cap_tap_pcreg    ),
    .shift   (shift_tap_pcreg  ),
    .si      (si_tap_pcreg     ),
    .pi      (pi_tap_pcreg     ),
    .so      (so_tap_pcreg     ),
    .sr0     (sr0_tap_pcreg    )
);
endmodule

`endif  // OPEN132_HAS_LJTAG
