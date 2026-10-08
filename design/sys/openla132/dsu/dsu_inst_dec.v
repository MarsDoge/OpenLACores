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

module dsu_inst_dec (
    input  wire [                               31: 0]  inst,
    output wire [    `OPEN132_IDU_DECODE_BUS_WIDTH-1: 0]  lisa_inst_decode,
    output wire [`OPEN132_IDU_FPU_DECODE_BUS_WIDTH-1: 0]  lisa_fpu_inst_decode
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire [  2: 0] decode_index_dec3_lane0;
wire [  7: 0] decode_onehot_dec3_lane0;
wire [  1: 0] decode_index_dec2_lane0;
wire [  3: 0] decode_onehot_dec2_lane0;
wire [  2: 0] decode_index_dec3_lane1;
wire [  7: 0] decode_onehot_dec3_lane1;
wire [  1: 0] decode_index_dec2_lane1;
wire [  3: 0] decode_onehot_dec2_lane1;
wire [  2: 0] decode_index_dec3_lane2;
wire [  7: 0] decode_onehot_dec3_lane2;
wire [  1: 0] decode_index_dec2_lane2;
wire [  3: 0] decode_onehot_dec2_lane2;
wire [  2: 0] decode_index_dec3_lane3;
wire [  7: 0] decode_onehot_dec3_lane3;
wire [  1: 0] decode_index_dec2_lane3;
wire [  3: 0] decode_onehot_dec2_lane3;
wire [  1: 0] decode_index_dec2_lane4;
wire [  3: 0] decode_onehot_dec2_lane4;
wire [  1: 0] decode_index_dec2_lane5;
wire [  3: 0] decode_onehot_dec2_lane5;
wire [  1: 0] decode_index_dec2_lane6;
wire [  3: 0] decode_onehot_dec2_lane6;
wire [  2: 0] decode_index_dec3_lane4;
wire [  7: 0] decode_onehot_dec3_lane4;
wire [  2: 0] decode_index_dec3_lane5;
wire [  7: 0] decode_onehot_dec3_lane5;

// decode inst[2:0]
wire [  2: 0] inst_lv1seg0;
wire [  7: 0] inst_lv1seg0_dec;

// decode inst[4:3]
wire [  1: 0] inst_lv1seg1;
wire [  3: 0] inst_lv1seg1_dec;

// decode inst[7:5]
wire [  2: 0] inst_lv1seg2;
wire [  7: 0] inst_lv1seg2_dec;

// decode inst[9:8]
wire [  1: 0] inst_lv1seg3;
wire [  3: 0] inst_lv1seg3_dec;

// decode inst[12:10]
wire [  2: 0] inst_lv1seg4;
wire [  7: 0] inst_lv1seg4_dec;

// decode inst[14:13]
wire [  1: 0] inst_lv1seg5;
wire [  3: 0] inst_lv1seg5_dec;

// decode inst[17:15]
wire [  2: 0] inst_lv1seg6;
wire [  7: 0] inst_lv1seg6_dec;

// decode inst[19:18]
wire [  1: 0] inst_lv1seg7;
wire [  3: 0] inst_lv1seg7_dec;

// decode inst[21:20]
wire [  1: 0] inst_lv1seg8;
wire [  3: 0] inst_lv1seg8_dec;

// decode inst[23:22]
wire [  1: 0] inst_lv1seg9;
wire [  3: 0] inst_lv1seg9_dec;

// decode inst[25:24]
wire [  1: 0] inst_lv1seg10;
wire [  3: 0] inst_lv1seg10_dec;

// decode inst[28:26]
wire [  2: 0] inst_lv1seg11;
wire [  7: 0] inst_lv1seg11_dec;

// decode inst[31:29]
wire [  2: 0] inst_lv1seg12;
wire [  7: 0] inst_lv1seg12_dec;

// decode inst[4:0]
wire [ 31: 0] inst_lv2seg0_dec;

// decode inst[9:5]
wire [ 31: 0] inst_lv2seg1_dec;

// decode inst[14:10]
wire [ 31: 0] inst_lv2seg2_dec;

// decode inst[19:15]
wire [ 31: 0] inst_lv2seg3_dec;

// decode inst[25:20]
wire [ 63: 0] inst_lv2seg4_dec;

// decode inst[31:26]
wire [ 63: 0] inst_lv2seg5_dec;

wire          l_CLO_W;
wire          l_CLZ_W;
wire          l_CTO_W;
wire          l_CTZ_W;
wire          l_REVB_2H;
wire          l_BITREV_4B;
wire          l_BITREV_W;
wire          l_EXT_W_H;
wire          l_EXT_W_B;
wire          l_RDTIMEL_W;
wire          l_RDTIMEH_W;
wire          l_CPUCFG;
wire          l_ALSL_W;
wire          l_BYTEPICK_W;
wire          l_ADD_W;
wire          l_SUB_W;
wire          l_SLT;
wire          l_SLTU;
wire          l_MASKEQZ;
wire          l_MASKNEZ;
wire          l_NOR;
wire          l_AND;
wire          l_OR;
wire          l_XOR;
wire          l_ORN;
wire          l_ANDN;
wire          l_SLL_W;
wire          l_SRL_W;
wire          l_SRA_W;
wire          l_ROTR_W;
wire          l_MUL_W;
wire          l_MULH_W;
wire          l_MULH_WU;
wire          l_DIV_W;
wire          l_MOD_W;
wire          l_DIV_WU;
wire          l_MOD_WU;
wire          l_ADDU12I_W;
wire          l_BREAK;
wire          l_DBGCALL;
wire          l_SYSCALL;
wire          l_SLLI_W;
wire          l_SRLI_W;
wire          l_SRAI_W;
wire          l_ROTRI_W;
wire          l_BSTRINS_W;
wire          l_BSTRPICK_W;
wire          l_SLTI;
wire          l_SLTUI;
wire          l_ADDI_W;
wire          l_ANDI;

// wire l_NOP = inst_lv2seg5_dec[0] && inst_lv1seg10_dec[3]
//              && inst_lv1seg9_dec[1] && (rj==5'b0 && rd==5'b0);
wire          l_ORI;
wire          l_XORI;
wire          l_CSRRD;
wire          l_CSRWR;
wire          l_CSRXCHG;
wire          l_CACOP;
wire          l_ERTN;
wire          l_IDLE;
wire          l_LU12I_W;
wire          l_PCADDI;
wire          l_PCALAU12I;
wire          l_PCADDU12I;
wire          l_LL_W;
wire          l_SC_W;
wire          l_LD_B;
wire          l_LD_H;
wire          l_LD_W;
wire          l_ST_B;
wire          l_ST_H;
wire          l_ST_W;
wire          l_LD_BU;
wire          l_LD_HU;
wire          l_PRELD;
wire          l_LDL_W;
wire          l_LDR_W;
wire          l_STL_W;
wire          l_STR_W;
wire          l_DBAR;
wire          l_IBAR;
wire          l_BEQZ;
wire          l_BNEZ;
wire          l_JIRL;       // rd==5'b0 is nor link
wire          l_B;
wire          l_BL;
wire          l_BEQ;
wire          l_BNE;
wire          l_BLT;
wire          l_BGE;
wire          l_BLTU;
wire          l_BGEU;

//============================================================//
//                    Module Implementation
//============================================================//

//------------------------------------------------------------//
//                        Inst Decode
//------------------------------------------------------------//
// Instance Boundary Alias Mapping
// x_dsu_dec_n_m_8_0

assign decode_index_dec3_lane0  =  inst_lv1seg0;
assign inst_lv1seg0_dec         =  decode_onehot_dec3_lane0;
// x_dsu_dec_n_m_4_0
assign decode_index_dec2_lane0  =  inst_lv1seg1;
assign inst_lv1seg1_dec         =  decode_onehot_dec2_lane0;
// x_dsu_dec_n_m_8_1
assign decode_index_dec3_lane1  =  inst_lv1seg2;
assign inst_lv1seg2_dec         =  decode_onehot_dec3_lane1;
// x_dsu_dec_n_m_4_1
assign decode_index_dec2_lane1  =  inst_lv1seg3;
assign inst_lv1seg3_dec         =  decode_onehot_dec2_lane1;
// x_dsu_dec_n_m_8_2
assign decode_index_dec3_lane2  =  inst_lv1seg4;
assign inst_lv1seg4_dec         =  decode_onehot_dec3_lane2;
// x_dsu_dec_n_m_4_2
assign decode_index_dec2_lane2  =  inst_lv1seg5;
assign inst_lv1seg5_dec         =  decode_onehot_dec2_lane2;
// x_dsu_dec_n_m_8_3
assign decode_index_dec3_lane3  =  inst_lv1seg6;
assign inst_lv1seg6_dec         =  decode_onehot_dec3_lane3;
// x_dsu_dec_n_m_4_3
assign decode_index_dec2_lane3  =  inst_lv1seg7;
assign inst_lv1seg7_dec         =  decode_onehot_dec2_lane3;
// x_dsu_dec_n_m_4_4
assign decode_index_dec2_lane4  =  inst_lv1seg8;
assign inst_lv1seg8_dec         =  decode_onehot_dec2_lane4;
// x_dsu_dec_n_m_4_5
assign decode_index_dec2_lane5  =  inst_lv1seg9;
assign inst_lv1seg9_dec         =  decode_onehot_dec2_lane5;
// x_dsu_dec_n_m_4_6
assign decode_index_dec2_lane6  =  inst_lv1seg10;
assign inst_lv1seg10_dec        =  decode_onehot_dec2_lane6;
// x_dsu_dec_n_m_8_4
assign decode_index_dec3_lane4  =  inst_lv1seg11;
assign inst_lv1seg11_dec        =  decode_onehot_dec3_lane4;
// x_dsu_dec_n_m_8_5
assign decode_index_dec3_lane5  =  inst_lv1seg12;
assign inst_lv1seg12_dec        =  decode_onehot_dec3_lane5;

assign inst_lv1seg0   =  inst[2:0];
assign inst_lv1seg1   =  inst[4:3];
assign inst_lv1seg2   =  inst[7:5];
assign inst_lv1seg3   =  inst[9:8];
assign inst_lv1seg4   =  inst[12:10];
assign inst_lv1seg5   =  inst[14:13];
assign inst_lv1seg6   =  inst[17:15];
assign inst_lv1seg7   =  inst[19:18];
assign inst_lv1seg8   =  inst[21:20];
assign inst_lv1seg9   =  inst[23:22];
assign inst_lv1seg10  =  inst[25:24];
assign inst_lv1seg11  =  inst[28:26];
assign inst_lv1seg12  =  inst[31:29];
dsu_dec_n_m #(.M(8)) x_dsu_dec_n_m_8_0 (
    .decode_index  (decode_index_dec3_lane0 ),
    .decode_onehot (decode_onehot_dec3_lane0)
);
dsu_dec_n_m #(.M(4)) x_dsu_dec_n_m_4_0 (
    .decode_index  (decode_index_dec2_lane0 ),
    .decode_onehot (decode_onehot_dec2_lane0)
);
dsu_dec_n_m #(.M(8)) x_dsu_dec_n_m_8_1 (
    .decode_index  (decode_index_dec3_lane1 ),
    .decode_onehot (decode_onehot_dec3_lane1)
);
dsu_dec_n_m #(.M(4)) x_dsu_dec_n_m_4_1 (
    .decode_index  (decode_index_dec2_lane1 ),
    .decode_onehot (decode_onehot_dec2_lane1)
);
dsu_dec_n_m #(.M(8)) x_dsu_dec_n_m_8_2 (
    .decode_index  (decode_index_dec3_lane2 ),
    .decode_onehot (decode_onehot_dec3_lane2)
);
dsu_dec_n_m #(.M(4)) x_dsu_dec_n_m_4_2 (
    .decode_index  (decode_index_dec2_lane2 ),
    .decode_onehot (decode_onehot_dec2_lane2)
);
dsu_dec_n_m #(.M(8)) x_dsu_dec_n_m_8_3 (
    .decode_index  (decode_index_dec3_lane3 ),
    .decode_onehot (decode_onehot_dec3_lane3)
);
dsu_dec_n_m #(.M(4)) x_dsu_dec_n_m_4_3 (
    .decode_index  (decode_index_dec2_lane3 ),
    .decode_onehot (decode_onehot_dec2_lane3)
);
dsu_dec_n_m #(.M(4)) x_dsu_dec_n_m_4_4 (
    .decode_index  (decode_index_dec2_lane4 ),
    .decode_onehot (decode_onehot_dec2_lane4)
);
dsu_dec_n_m #(.M(4)) x_dsu_dec_n_m_4_5 (
    .decode_index  (decode_index_dec2_lane5 ),
    .decode_onehot (decode_onehot_dec2_lane5)
);
dsu_dec_n_m #(.M(4)) x_dsu_dec_n_m_4_6 (
    .decode_index  (decode_index_dec2_lane6 ),
    .decode_onehot (decode_onehot_dec2_lane6)
);
dsu_dec_n_m #(.M(8)) x_dsu_dec_n_m_8_4 (
    .decode_index  (decode_index_dec3_lane4 ),
    .decode_onehot (decode_onehot_dec3_lane4)
);
dsu_dec_n_m #(.M(8)) x_dsu_dec_n_m_8_5 (
    .decode_index  (decode_index_dec3_lane5 ),
    .decode_onehot (decode_onehot_dec3_lane5)
);

assign inst_lv2seg0_dec[0]   =  inst_lv1seg0_dec[0] && inst_lv1seg1_dec[0];
assign inst_lv2seg0_dec[1]   =  inst_lv1seg0_dec[1] && inst_lv1seg1_dec[0];
assign inst_lv2seg0_dec[2]   =  inst_lv1seg0_dec[2] && inst_lv1seg1_dec[0];
assign inst_lv2seg0_dec[3]   =  inst_lv1seg0_dec[3] && inst_lv1seg1_dec[0];
assign inst_lv2seg0_dec[4]   =  inst_lv1seg0_dec[4] && inst_lv1seg1_dec[0];
assign inst_lv2seg0_dec[5]   =  inst_lv1seg0_dec[5] && inst_lv1seg1_dec[0];
assign inst_lv2seg0_dec[6]   =  inst_lv1seg0_dec[6] && inst_lv1seg1_dec[0];
assign inst_lv2seg0_dec[7]   =  inst_lv1seg0_dec[7] && inst_lv1seg1_dec[0];
assign inst_lv2seg0_dec[8]   =  inst_lv1seg0_dec[0] && inst_lv1seg1_dec[1];
assign inst_lv2seg0_dec[9]   =  inst_lv1seg0_dec[1] && inst_lv1seg1_dec[1];
assign inst_lv2seg0_dec[10]  =  inst_lv1seg0_dec[2] && inst_lv1seg1_dec[1];
assign inst_lv2seg0_dec[11]  =  inst_lv1seg0_dec[3] && inst_lv1seg1_dec[1];
assign inst_lv2seg0_dec[12]  =  inst_lv1seg0_dec[4] && inst_lv1seg1_dec[1];
assign inst_lv2seg0_dec[13]  =  inst_lv1seg0_dec[5] && inst_lv1seg1_dec[1];
assign inst_lv2seg0_dec[14]  =  inst_lv1seg0_dec[6] && inst_lv1seg1_dec[1];
assign inst_lv2seg0_dec[15]  =  inst_lv1seg0_dec[7] && inst_lv1seg1_dec[1];
assign inst_lv2seg0_dec[16]  =  inst_lv1seg0_dec[0] && inst_lv1seg1_dec[2];
assign inst_lv2seg0_dec[17]  =  inst_lv1seg0_dec[1] && inst_lv1seg1_dec[2];
assign inst_lv2seg0_dec[18]  =  inst_lv1seg0_dec[2] && inst_lv1seg1_dec[2];
assign inst_lv2seg0_dec[19]  =  inst_lv1seg0_dec[3] && inst_lv1seg1_dec[2];
assign inst_lv2seg0_dec[20]  =  inst_lv1seg0_dec[4] && inst_lv1seg1_dec[2];
assign inst_lv2seg0_dec[21]  =  inst_lv1seg0_dec[5] && inst_lv1seg1_dec[2];
assign inst_lv2seg0_dec[22]  =  inst_lv1seg0_dec[6] && inst_lv1seg1_dec[2];
assign inst_lv2seg0_dec[23]  =  inst_lv1seg0_dec[7] && inst_lv1seg1_dec[2];
assign inst_lv2seg0_dec[24]  =  inst_lv1seg0_dec[0] && inst_lv1seg1_dec[3];
assign inst_lv2seg0_dec[25]  =  inst_lv1seg0_dec[1] && inst_lv1seg1_dec[3];
assign inst_lv2seg0_dec[26]  =  inst_lv1seg0_dec[2] && inst_lv1seg1_dec[3];
assign inst_lv2seg0_dec[27]  =  inst_lv1seg0_dec[3] && inst_lv1seg1_dec[3];
assign inst_lv2seg0_dec[28]  =  inst_lv1seg0_dec[4] && inst_lv1seg1_dec[3];
assign inst_lv2seg0_dec[29]  =  inst_lv1seg0_dec[5] && inst_lv1seg1_dec[3];
assign inst_lv2seg0_dec[30]  =  inst_lv1seg0_dec[6] && inst_lv1seg1_dec[3];
assign inst_lv2seg0_dec[31]  =  inst_lv1seg0_dec[7] && inst_lv1seg1_dec[3];

assign inst_lv2seg1_dec[0]   =  inst_lv1seg2_dec[0] && inst_lv1seg3_dec[0];
assign inst_lv2seg1_dec[1]   =  inst_lv1seg2_dec[1] && inst_lv1seg3_dec[0];
assign inst_lv2seg1_dec[2]   =  inst_lv1seg2_dec[2] && inst_lv1seg3_dec[0];
assign inst_lv2seg1_dec[3]   =  inst_lv1seg2_dec[3] && inst_lv1seg3_dec[0];
assign inst_lv2seg1_dec[4]   =  inst_lv1seg2_dec[4] && inst_lv1seg3_dec[0];
assign inst_lv2seg1_dec[5]   =  inst_lv1seg2_dec[5] && inst_lv1seg3_dec[0];
assign inst_lv2seg1_dec[6]   =  inst_lv1seg2_dec[6] && inst_lv1seg3_dec[0];
assign inst_lv2seg1_dec[7]   =  inst_lv1seg2_dec[7] && inst_lv1seg3_dec[0];
assign inst_lv2seg1_dec[8]   =  inst_lv1seg2_dec[0] && inst_lv1seg3_dec[1];
assign inst_lv2seg1_dec[9]   =  inst_lv1seg2_dec[1] && inst_lv1seg3_dec[1];
assign inst_lv2seg1_dec[10]  =  inst_lv1seg2_dec[2] && inst_lv1seg3_dec[1];
assign inst_lv2seg1_dec[11]  =  inst_lv1seg2_dec[3] && inst_lv1seg3_dec[1];
assign inst_lv2seg1_dec[12]  =  inst_lv1seg2_dec[4] && inst_lv1seg3_dec[1];
assign inst_lv2seg1_dec[13]  =  inst_lv1seg2_dec[5] && inst_lv1seg3_dec[1];
assign inst_lv2seg1_dec[14]  =  inst_lv1seg2_dec[6] && inst_lv1seg3_dec[1];
assign inst_lv2seg1_dec[15]  =  inst_lv1seg2_dec[7] && inst_lv1seg3_dec[1];
assign inst_lv2seg1_dec[16]  =  inst_lv1seg2_dec[0] && inst_lv1seg3_dec[2];
assign inst_lv2seg1_dec[17]  =  inst_lv1seg2_dec[1] && inst_lv1seg3_dec[2];
assign inst_lv2seg1_dec[18]  =  inst_lv1seg2_dec[2] && inst_lv1seg3_dec[2];
assign inst_lv2seg1_dec[19]  =  inst_lv1seg2_dec[3] && inst_lv1seg3_dec[2];
assign inst_lv2seg1_dec[20]  =  inst_lv1seg2_dec[4] && inst_lv1seg3_dec[2];
assign inst_lv2seg1_dec[21]  =  inst_lv1seg2_dec[5] && inst_lv1seg3_dec[2];
assign inst_lv2seg1_dec[22]  =  inst_lv1seg2_dec[6] && inst_lv1seg3_dec[2];
assign inst_lv2seg1_dec[23]  =  inst_lv1seg2_dec[7] && inst_lv1seg3_dec[2];
assign inst_lv2seg1_dec[24]  =  inst_lv1seg2_dec[0] && inst_lv1seg3_dec[3];
assign inst_lv2seg1_dec[25]  =  inst_lv1seg2_dec[1] && inst_lv1seg3_dec[3];
assign inst_lv2seg1_dec[26]  =  inst_lv1seg2_dec[2] && inst_lv1seg3_dec[3];
assign inst_lv2seg1_dec[27]  =  inst_lv1seg2_dec[3] && inst_lv1seg3_dec[3];
assign inst_lv2seg1_dec[28]  =  inst_lv1seg2_dec[4] && inst_lv1seg3_dec[3];
assign inst_lv2seg1_dec[29]  =  inst_lv1seg2_dec[5] && inst_lv1seg3_dec[3];
assign inst_lv2seg1_dec[30]  =  inst_lv1seg2_dec[6] && inst_lv1seg3_dec[3];
assign inst_lv2seg1_dec[31]  =  inst_lv1seg2_dec[7] && inst_lv1seg3_dec[3];

assign inst_lv2seg2_dec[0]   =  inst_lv1seg4_dec[0] && inst_lv1seg5_dec[0];
assign inst_lv2seg2_dec[1]   =  inst_lv1seg4_dec[1] && inst_lv1seg5_dec[0];
assign inst_lv2seg2_dec[2]   =  inst_lv1seg4_dec[2] && inst_lv1seg5_dec[0];
assign inst_lv2seg2_dec[3]   =  inst_lv1seg4_dec[3] && inst_lv1seg5_dec[0];
assign inst_lv2seg2_dec[4]   =  inst_lv1seg4_dec[4] && inst_lv1seg5_dec[0];
assign inst_lv2seg2_dec[5]   =  inst_lv1seg4_dec[5] && inst_lv1seg5_dec[0];
assign inst_lv2seg2_dec[6]   =  inst_lv1seg4_dec[6] && inst_lv1seg5_dec[0];
assign inst_lv2seg2_dec[7]   =  inst_lv1seg4_dec[7] && inst_lv1seg5_dec[0];
assign inst_lv2seg2_dec[8]   =  inst_lv1seg4_dec[0] && inst_lv1seg5_dec[1];
assign inst_lv2seg2_dec[9]   =  inst_lv1seg4_dec[1] && inst_lv1seg5_dec[1];
assign inst_lv2seg2_dec[10]  =  inst_lv1seg4_dec[2] && inst_lv1seg5_dec[1];
assign inst_lv2seg2_dec[11]  =  inst_lv1seg4_dec[3] && inst_lv1seg5_dec[1];
assign inst_lv2seg2_dec[12]  =  inst_lv1seg4_dec[4] && inst_lv1seg5_dec[1];
assign inst_lv2seg2_dec[13]  =  inst_lv1seg4_dec[5] && inst_lv1seg5_dec[1];
assign inst_lv2seg2_dec[14]  =  inst_lv1seg4_dec[6] && inst_lv1seg5_dec[1];
assign inst_lv2seg2_dec[15]  =  inst_lv1seg4_dec[7] && inst_lv1seg5_dec[1];
assign inst_lv2seg2_dec[16]  =  inst_lv1seg4_dec[0] && inst_lv1seg5_dec[2];
assign inst_lv2seg2_dec[17]  =  inst_lv1seg4_dec[1] && inst_lv1seg5_dec[2];
assign inst_lv2seg2_dec[18]  =  inst_lv1seg4_dec[2] && inst_lv1seg5_dec[2];
assign inst_lv2seg2_dec[19]  =  inst_lv1seg4_dec[3] && inst_lv1seg5_dec[2];
assign inst_lv2seg2_dec[20]  =  inst_lv1seg4_dec[4] && inst_lv1seg5_dec[2];
assign inst_lv2seg2_dec[21]  =  inst_lv1seg4_dec[5] && inst_lv1seg5_dec[2];
assign inst_lv2seg2_dec[22]  =  inst_lv1seg4_dec[6] && inst_lv1seg5_dec[2];
assign inst_lv2seg2_dec[23]  =  inst_lv1seg4_dec[7] && inst_lv1seg5_dec[2];
assign inst_lv2seg2_dec[24]  =  inst_lv1seg4_dec[0] && inst_lv1seg5_dec[3];
assign inst_lv2seg2_dec[25]  =  inst_lv1seg4_dec[1] && inst_lv1seg5_dec[3];
assign inst_lv2seg2_dec[26]  =  inst_lv1seg4_dec[2] && inst_lv1seg5_dec[3];
assign inst_lv2seg2_dec[27]  =  inst_lv1seg4_dec[3] && inst_lv1seg5_dec[3];
assign inst_lv2seg2_dec[28]  =  inst_lv1seg4_dec[4] && inst_lv1seg5_dec[3];
assign inst_lv2seg2_dec[29]  =  inst_lv1seg4_dec[5] && inst_lv1seg5_dec[3];
assign inst_lv2seg2_dec[30]  =  inst_lv1seg4_dec[6] && inst_lv1seg5_dec[3];
assign inst_lv2seg2_dec[31]  =  inst_lv1seg4_dec[7] && inst_lv1seg5_dec[3];

assign inst_lv2seg3_dec[0]   =  inst_lv1seg6_dec[0] && inst_lv1seg7_dec[0];
assign inst_lv2seg3_dec[1]   =  inst_lv1seg6_dec[1] && inst_lv1seg7_dec[0];
assign inst_lv2seg3_dec[2]   =  inst_lv1seg6_dec[2] && inst_lv1seg7_dec[0];
assign inst_lv2seg3_dec[3]   =  inst_lv1seg6_dec[3] && inst_lv1seg7_dec[0];
assign inst_lv2seg3_dec[4]   =  inst_lv1seg6_dec[4] && inst_lv1seg7_dec[0];
assign inst_lv2seg3_dec[5]   =  inst_lv1seg6_dec[5] && inst_lv1seg7_dec[0];
assign inst_lv2seg3_dec[6]   =  inst_lv1seg6_dec[6] && inst_lv1seg7_dec[0];
assign inst_lv2seg3_dec[7]   =  inst_lv1seg6_dec[7] && inst_lv1seg7_dec[0];
assign inst_lv2seg3_dec[8]   =  inst_lv1seg6_dec[0] && inst_lv1seg7_dec[1];
assign inst_lv2seg3_dec[9]   =  inst_lv1seg6_dec[1] && inst_lv1seg7_dec[1];
assign inst_lv2seg3_dec[10]  =  inst_lv1seg6_dec[2] && inst_lv1seg7_dec[1];
assign inst_lv2seg3_dec[11]  =  inst_lv1seg6_dec[3] && inst_lv1seg7_dec[1];
assign inst_lv2seg3_dec[12]  =  inst_lv1seg6_dec[4] && inst_lv1seg7_dec[1];
assign inst_lv2seg3_dec[13]  =  inst_lv1seg6_dec[5] && inst_lv1seg7_dec[1];
assign inst_lv2seg3_dec[14]  =  inst_lv1seg6_dec[6] && inst_lv1seg7_dec[1];
assign inst_lv2seg3_dec[15]  =  inst_lv1seg6_dec[7] && inst_lv1seg7_dec[1];
assign inst_lv2seg3_dec[16]  =  inst_lv1seg6_dec[0] && inst_lv1seg7_dec[2];
assign inst_lv2seg3_dec[17]  =  inst_lv1seg6_dec[1] && inst_lv1seg7_dec[2];
assign inst_lv2seg3_dec[18]  =  inst_lv1seg6_dec[2] && inst_lv1seg7_dec[2];
assign inst_lv2seg3_dec[19]  =  inst_lv1seg6_dec[3] && inst_lv1seg7_dec[2];
assign inst_lv2seg3_dec[20]  =  inst_lv1seg6_dec[4] && inst_lv1seg7_dec[2];
assign inst_lv2seg3_dec[21]  =  inst_lv1seg6_dec[5] && inst_lv1seg7_dec[2];
assign inst_lv2seg3_dec[22]  =  inst_lv1seg6_dec[6] && inst_lv1seg7_dec[2];
assign inst_lv2seg3_dec[23]  =  inst_lv1seg6_dec[7] && inst_lv1seg7_dec[2];
assign inst_lv2seg3_dec[24]  =  inst_lv1seg6_dec[0] && inst_lv1seg7_dec[3];
assign inst_lv2seg3_dec[25]  =  inst_lv1seg6_dec[1] && inst_lv1seg7_dec[3];
assign inst_lv2seg3_dec[26]  =  inst_lv1seg6_dec[2] && inst_lv1seg7_dec[3];
assign inst_lv2seg3_dec[27]  =  inst_lv1seg6_dec[3] && inst_lv1seg7_dec[3];
assign inst_lv2seg3_dec[28]  =  inst_lv1seg6_dec[4] && inst_lv1seg7_dec[3];
assign inst_lv2seg3_dec[29]  =  inst_lv1seg6_dec[5] && inst_lv1seg7_dec[3];
assign inst_lv2seg3_dec[30]  =  inst_lv1seg6_dec[6] && inst_lv1seg7_dec[3];
assign inst_lv2seg3_dec[31]  =  inst_lv1seg6_dec[7] && inst_lv1seg7_dec[3];

assign inst_lv2seg4_dec[0]   =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[1]   =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[2]   =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[3]   =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[4]   =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[5]   =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[6]   =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[7]   =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[8]   =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[9]   =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[10]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[11]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[12]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[13]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[14]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[15]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[0];
assign inst_lv2seg4_dec[16]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[17]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[18]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[19]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[20]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[21]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[22]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[23]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[24]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[25]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[26]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[27]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[28]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[29]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[30]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[31]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[1];
assign inst_lv2seg4_dec[32]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[33]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[34]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[35]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[36]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[37]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[38]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[39]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[40]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[41]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[42]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[43]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[44]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[45]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[46]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[47]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[2];
assign inst_lv2seg4_dec[48]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[49]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[50]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[51]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[0] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[52]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[53]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[54]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[55]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[1] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[56]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[57]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[58]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[59]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[2] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[60]  =  inst_lv1seg8_dec[0] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[61]  =  inst_lv1seg8_dec[1] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[62]  =  inst_lv1seg8_dec[2] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[3];
assign inst_lv2seg4_dec[63]  =  inst_lv1seg8_dec[3] && inst_lv1seg9_dec[3] && inst_lv1seg10_dec[3];

assign inst_lv2seg5_dec[0]   =  inst_lv1seg11_dec[0] && inst_lv1seg12_dec[0];
assign inst_lv2seg5_dec[1]   =  inst_lv1seg11_dec[1] && inst_lv1seg12_dec[0];
assign inst_lv2seg5_dec[2]   =  inst_lv1seg11_dec[2] && inst_lv1seg12_dec[0];
assign inst_lv2seg5_dec[3]   =  inst_lv1seg11_dec[3] && inst_lv1seg12_dec[0];
assign inst_lv2seg5_dec[4]   =  inst_lv1seg11_dec[4] && inst_lv1seg12_dec[0];
assign inst_lv2seg5_dec[5]   =  inst_lv1seg11_dec[5] && inst_lv1seg12_dec[0];
assign inst_lv2seg5_dec[6]   =  inst_lv1seg11_dec[6] && inst_lv1seg12_dec[0];
assign inst_lv2seg5_dec[7]   =  inst_lv1seg11_dec[7] && inst_lv1seg12_dec[0];
assign inst_lv2seg5_dec[8]   =  inst_lv1seg11_dec[0] && inst_lv1seg12_dec[1];
assign inst_lv2seg5_dec[9]   =  inst_lv1seg11_dec[1] && inst_lv1seg12_dec[1];
assign inst_lv2seg5_dec[10]  =  inst_lv1seg11_dec[2] && inst_lv1seg12_dec[1];
assign inst_lv2seg5_dec[11]  =  inst_lv1seg11_dec[3] && inst_lv1seg12_dec[1];
assign inst_lv2seg5_dec[12]  =  inst_lv1seg11_dec[4] && inst_lv1seg12_dec[1];
assign inst_lv2seg5_dec[13]  =  inst_lv1seg11_dec[5] && inst_lv1seg12_dec[1];
assign inst_lv2seg5_dec[14]  =  inst_lv1seg11_dec[6] && inst_lv1seg12_dec[1];
assign inst_lv2seg5_dec[15]  =  inst_lv1seg11_dec[7] && inst_lv1seg12_dec[1];
assign inst_lv2seg5_dec[16]  =  inst_lv1seg11_dec[0] && inst_lv1seg12_dec[2];
assign inst_lv2seg5_dec[17]  =  inst_lv1seg11_dec[1] && inst_lv1seg12_dec[2];
assign inst_lv2seg5_dec[18]  =  inst_lv1seg11_dec[2] && inst_lv1seg12_dec[2];
assign inst_lv2seg5_dec[19]  =  inst_lv1seg11_dec[3] && inst_lv1seg12_dec[2];
assign inst_lv2seg5_dec[20]  =  inst_lv1seg11_dec[4] && inst_lv1seg12_dec[2];
assign inst_lv2seg5_dec[21]  =  inst_lv1seg11_dec[5] && inst_lv1seg12_dec[2];
assign inst_lv2seg5_dec[22]  =  inst_lv1seg11_dec[6] && inst_lv1seg12_dec[2];
assign inst_lv2seg5_dec[23]  =  inst_lv1seg11_dec[7] && inst_lv1seg12_dec[2];
assign inst_lv2seg5_dec[24]  =  inst_lv1seg11_dec[0] && inst_lv1seg12_dec[3];
assign inst_lv2seg5_dec[25]  =  inst_lv1seg11_dec[1] && inst_lv1seg12_dec[3];
assign inst_lv2seg5_dec[26]  =  inst_lv1seg11_dec[2] && inst_lv1seg12_dec[3];
assign inst_lv2seg5_dec[27]  =  inst_lv1seg11_dec[3] && inst_lv1seg12_dec[3];
assign inst_lv2seg5_dec[28]  =  inst_lv1seg11_dec[4] && inst_lv1seg12_dec[3];
assign inst_lv2seg5_dec[29]  =  inst_lv1seg11_dec[5] && inst_lv1seg12_dec[3];
assign inst_lv2seg5_dec[30]  =  inst_lv1seg11_dec[6] && inst_lv1seg12_dec[3];
assign inst_lv2seg5_dec[31]  =  inst_lv1seg11_dec[7] && inst_lv1seg12_dec[3];
assign inst_lv2seg5_dec[32]  =  inst_lv1seg11_dec[0] && inst_lv1seg12_dec[4];
assign inst_lv2seg5_dec[33]  =  inst_lv1seg11_dec[1] && inst_lv1seg12_dec[4];
assign inst_lv2seg5_dec[34]  =  inst_lv1seg11_dec[2] && inst_lv1seg12_dec[4];
assign inst_lv2seg5_dec[35]  =  inst_lv1seg11_dec[3] && inst_lv1seg12_dec[4];
assign inst_lv2seg5_dec[36]  =  inst_lv1seg11_dec[4] && inst_lv1seg12_dec[4];
assign inst_lv2seg5_dec[37]  =  inst_lv1seg11_dec[5] && inst_lv1seg12_dec[4];
assign inst_lv2seg5_dec[38]  =  inst_lv1seg11_dec[6] && inst_lv1seg12_dec[4];
assign inst_lv2seg5_dec[39]  =  inst_lv1seg11_dec[7] && inst_lv1seg12_dec[4];
assign inst_lv2seg5_dec[40]  =  inst_lv1seg11_dec[0] && inst_lv1seg12_dec[5];
assign inst_lv2seg5_dec[41]  =  inst_lv1seg11_dec[1] && inst_lv1seg12_dec[5];
assign inst_lv2seg5_dec[42]  =  inst_lv1seg11_dec[2] && inst_lv1seg12_dec[5];
assign inst_lv2seg5_dec[43]  =  inst_lv1seg11_dec[3] && inst_lv1seg12_dec[5];
assign inst_lv2seg5_dec[44]  =  inst_lv1seg11_dec[4] && inst_lv1seg12_dec[5];
assign inst_lv2seg5_dec[45]  =  inst_lv1seg11_dec[5] && inst_lv1seg12_dec[5];
assign inst_lv2seg5_dec[46]  =  inst_lv1seg11_dec[6] && inst_lv1seg12_dec[5];
assign inst_lv2seg5_dec[47]  =  inst_lv1seg11_dec[7] && inst_lv1seg12_dec[5];
assign inst_lv2seg5_dec[48]  =  inst_lv1seg11_dec[0] && inst_lv1seg12_dec[6];
assign inst_lv2seg5_dec[49]  =  inst_lv1seg11_dec[1] && inst_lv1seg12_dec[6];
assign inst_lv2seg5_dec[50]  =  inst_lv1seg11_dec[2] && inst_lv1seg12_dec[6];
assign inst_lv2seg5_dec[51]  =  inst_lv1seg11_dec[3] && inst_lv1seg12_dec[6];
assign inst_lv2seg5_dec[52]  =  inst_lv1seg11_dec[4] && inst_lv1seg12_dec[6];
assign inst_lv2seg5_dec[53]  =  inst_lv1seg11_dec[5] && inst_lv1seg12_dec[6];
assign inst_lv2seg5_dec[54]  =  inst_lv1seg11_dec[6] && inst_lv1seg12_dec[6];
assign inst_lv2seg5_dec[55]  =  inst_lv1seg11_dec[7] && inst_lv1seg12_dec[6];
assign inst_lv2seg5_dec[56]  =  inst_lv1seg11_dec[0] && inst_lv1seg12_dec[7];
assign inst_lv2seg5_dec[57]  =  inst_lv1seg11_dec[1] && inst_lv1seg12_dec[7];
assign inst_lv2seg5_dec[58]  =  inst_lv1seg11_dec[2] && inst_lv1seg12_dec[7];
assign inst_lv2seg5_dec[59]  =  inst_lv1seg11_dec[3] && inst_lv1seg12_dec[7];
assign inst_lv2seg5_dec[60]  =  inst_lv1seg11_dec[4] && inst_lv1seg12_dec[7];
assign inst_lv2seg5_dec[61]  =  inst_lv1seg11_dec[5] && inst_lv1seg12_dec[7];
assign inst_lv2seg5_dec[62]  =  inst_lv1seg11_dec[6] && inst_lv1seg12_dec[7];
assign inst_lv2seg5_dec[63]  =  inst_lv1seg11_dec[7] && inst_lv1seg12_dec[7];

assign l_CLO_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[4];
assign l_CLZ_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[5];
assign l_CTO_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[6];
assign l_CTZ_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[7];
assign l_REVB_2H     =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[12];
assign l_BITREV_4B   =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[18];
assign l_BITREV_W    =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[20];
assign l_EXT_W_H     =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[22];
assign l_EXT_W_B     =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[23];
assign l_RDTIMEL_W   =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[24];
assign l_RDTIMEH_W   =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[25];
assign l_CPUCFG      =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv2seg3_dec[0] && inst_lv2seg2_dec[27];
assign l_ALSL_W      =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv1seg7_dec[1] && !inst[17];
assign l_BYTEPICK_W  =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[0] && inst_lv1seg7_dec[2] && !inst[17];
assign l_ADD_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[0];
assign l_SUB_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[2];
assign l_SLT         =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[4];
assign l_SLTU        =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[5];
assign l_MASKEQZ     =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[6];
assign l_MASKNEZ     =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[7];
assign l_NOR         =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[8];
assign l_AND         =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[9];
assign l_OR          =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[10];
assign l_XOR         =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[11];
assign l_ORN         =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[12];
assign l_ANDN        =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[13];
assign l_SLL_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[14];
assign l_SRL_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[15];
assign l_SRA_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[16];
assign l_ROTR_W      =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[22];
assign l_MUL_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[24];
assign l_MULH_W      =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[25];
assign l_MULH_WU     =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[1] && inst_lv2seg3_dec[26];
assign l_DIV_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[2] && inst_lv2seg3_dec[0];
assign l_MOD_W       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[2] && inst_lv2seg3_dec[1];
assign l_DIV_WU      =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[2] && inst_lv2seg3_dec[2];
assign l_MOD_WU      =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[2] && inst_lv2seg3_dec[3];
assign l_ADDU12I_W   =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[2] && inst_lv2seg3_dec[18];
assign l_BREAK       =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[2] && inst_lv2seg3_dec[20];
assign l_DBGCALL     =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[2] && inst_lv2seg3_dec[21];
assign l_SYSCALL     =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[2] && inst_lv2seg3_dec[22];
assign l_SLLI_W      =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[4] && inst_lv2seg3_dec[1];
assign l_SRLI_W      =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[4] && inst_lv2seg3_dec[9];
assign l_SRAI_W      =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[4] && inst_lv2seg3_dec[17];
assign l_ROTRI_W     =  inst_lv2seg5_dec[0] && inst_lv2seg4_dec[4] && inst_lv2seg3_dec[25];
assign l_BSTRINS_W   =  inst_lv2seg5_dec[0] && inst_lv1seg10_dec[0] && inst_lv1seg9_dec[1] && !inst[15] && inst[21];
assign l_BSTRPICK_W  =  inst_lv2seg5_dec[0] && inst_lv1seg10_dec[0] && inst_lv1seg9_dec[1] && inst[15] && inst[21];
assign l_SLTI        =  inst_lv2seg5_dec[0] && inst_lv1seg10_dec[2] && inst_lv1seg9_dec[0];
assign l_SLTUI       =  inst_lv2seg5_dec[0] && inst_lv1seg10_dec[2] && inst_lv1seg9_dec[1];
assign l_ADDI_W      =  inst_lv2seg5_dec[0] && inst_lv1seg10_dec[2] && inst_lv1seg9_dec[2];
assign l_ANDI        =  inst_lv2seg5_dec[0] && inst_lv1seg10_dec[3] && inst_lv1seg9_dec[1];
assign l_ORI         =  inst_lv2seg5_dec[0] && inst_lv1seg10_dec[3] && inst_lv1seg9_dec[2];
assign l_XORI        =  inst_lv2seg5_dec[0] && inst_lv1seg10_dec[3] && inst_lv1seg9_dec[3];
assign l_CSRRD       =  inst_lv2seg5_dec[1] && inst_lv2seg1_dec[0] && inst_lv1seg10_dec[0];
assign l_CSRWR       =  inst_lv2seg5_dec[1] && inst_lv2seg1_dec[1] && inst_lv1seg10_dec[0];
assign l_CSRXCHG     =  inst_lv2seg5_dec[1] && inst_lv1seg10_dec[0] && inst[9:6] != 4'h0;
assign l_CACOP       =  inst_lv2seg5_dec[1] && inst_lv1seg10_dec[2] && inst_lv1seg9_dec[0];
assign l_ERTN        =  inst_lv2seg5_dec[1] && inst_lv2seg4_dec[36] && inst_lv2seg3_dec[16] && inst_lv2seg2_dec[14] &&
                          inst_lv2seg1_dec[0] && inst_lv2seg0_dec[0];
assign l_IDLE        =  inst_lv2seg5_dec[1] && inst_lv2seg4_dec[36] && inst_lv2seg3_dec[17];
assign l_LU12I_W     =  inst_lv2seg5_dec[5] && !inst[25];
assign l_PCADDI      =  inst_lv2seg5_dec[6] && !inst[25];
assign l_PCALAU12I   =  inst_lv2seg5_dec[6] && inst[25];
assign l_PCADDU12I   =  inst_lv2seg5_dec[7] && !inst[25];
assign l_LL_W        =  inst_lv2seg5_dec[8] && inst_lv1seg10_dec[0];
assign l_SC_W        =  inst_lv2seg5_dec[8] && inst_lv1seg10_dec[1];
assign l_LD_B        =  inst_lv2seg5_dec[10] && inst_lv1seg10_dec[0] && inst_lv1seg9_dec[0];
assign l_LD_H        =  inst_lv2seg5_dec[10] && inst_lv1seg10_dec[0] && inst_lv1seg9_dec[1];
assign l_LD_W        =  inst_lv2seg5_dec[10] && inst_lv1seg10_dec[0] && inst_lv1seg9_dec[2];
assign l_ST_B        =  inst_lv2seg5_dec[10] && inst_lv1seg10_dec[1] && inst_lv1seg9_dec[0];
assign l_ST_H        =  inst_lv2seg5_dec[10] && inst_lv1seg10_dec[1] && inst_lv1seg9_dec[1];
assign l_ST_W        =  inst_lv2seg5_dec[10] && inst_lv1seg10_dec[1] && inst_lv1seg9_dec[2];
assign l_LD_BU       =  inst_lv2seg5_dec[10] && inst_lv1seg10_dec[2] && inst_lv1seg9_dec[0];
assign l_LD_HU       =  inst_lv2seg5_dec[10] && inst_lv1seg10_dec[2] && inst_lv1seg9_dec[1];
assign l_PRELD       =  inst_lv2seg5_dec[10] && inst_lv1seg10_dec[2] && inst_lv1seg9_dec[3];
assign l_LDL_W       =  inst_lv2seg5_dec[11] && inst_lv1seg10_dec[2] && inst_lv1seg9_dec[0];
assign l_LDR_W       =  inst_lv2seg5_dec[11] && inst_lv1seg10_dec[2] && inst_lv1seg9_dec[1];
assign l_STL_W       =  inst_lv2seg5_dec[11] && inst_lv1seg10_dec[3] && inst_lv1seg9_dec[0];
assign l_STR_W       =  inst_lv2seg5_dec[11] && inst_lv1seg10_dec[3] && inst_lv1seg9_dec[1];
assign l_DBAR        =  inst_lv2seg5_dec[14] && inst_lv2seg4_dec[7] && inst_lv2seg3_dec[4];
assign l_IBAR        =  inst_lv2seg5_dec[14] && inst_lv2seg4_dec[7] && inst_lv2seg3_dec[5];
assign l_BEQZ        =  inst_lv2seg5_dec[16];
assign l_BNEZ        =  inst_lv2seg5_dec[17];
assign l_JIRL        =  inst_lv2seg5_dec[19];
assign l_B           =  inst_lv2seg5_dec[20];
assign l_BL          =  inst_lv2seg5_dec[21];
assign l_BEQ         =  inst_lv2seg5_dec[22];
assign l_BNE         =  inst_lv2seg5_dec[23];
assign l_BLT         =  inst_lv2seg5_dec[24];
assign l_BGE         =  inst_lv2seg5_dec[25];
assign l_BLTU        =  inst_lv2seg5_dec[26];
assign l_BGEU        =  inst_lv2seg5_dec[27];

assign lisa_inst_decode  =  {
                              l_ADD_W,
                              l_ADDI_W,
                              l_ADDU12I_W,
                              l_ALSL_W,
                              l_SUB_W,
                              l_PCADDI,
                              l_PCALAU12I,
                              l_PCADDU12I,
                              l_SLT,
                              l_SLTU,
                              l_SLTI,
                              l_SLTUI,
                              l_CLO_W,
                              l_CLZ_W,
                              l_CTO_W,
                              l_CTZ_W,
                              l_EXT_W_H,
                              l_EXT_W_B,
                              l_LU12I_W,
                              l_AND,
                              l_OR,
                              l_XOR,
                              l_ANDI,
                              l_ORI,
                              l_XORI,
                              l_ANDN,
                              l_ORN,
                              l_NOR,
                              l_SLL_W,
                              l_SRL_W,
                              l_SRA_W,
                              l_ROTR_W,
                              l_SLLI_W,
                              l_SRLI_W,
                              l_SRAI_W,
                              l_ROTRI_W,
                              l_BSTRINS_W,
                              l_BSTRPICK_W,
                              l_REVB_2H,
                              l_BITREV_4B,
                              l_BITREV_W,
                              l_MASKEQZ,
                              l_MASKNEZ,
                              l_BYTEPICK_W,
                              l_MUL_W,
                              l_MULH_W,
                              l_MULH_WU,
                              l_DIV_W,
                              l_MOD_W,
                              l_DIV_WU,
                              l_MOD_WU,
                              l_BREAK,
                              l_DBGCALL,
                              l_SYSCALL,
                              l_RDTIMEL_W,
                              l_RDTIMEH_W,
                              l_CPUCFG,
                              l_CSRRD,
                              l_CSRWR,
                              l_CSRXCHG,
                              l_ERTN,
                              l_IDLE,
                              l_CACOP,
                              l_LL_W,
                              l_SC_W,
                              l_LD_B,
                              l_LD_H,
                              l_LD_W,
                              l_LD_BU,
                              l_LD_HU,
                              l_ST_B,
                              l_ST_H,
                              l_ST_W,
                              l_PRELD,
                              l_LDL_W,
                              l_LDR_W,
                              l_STL_W,
                              l_STR_W,
                              l_DBAR,
                              l_IBAR,
                              l_BEQZ,
                              l_BNEZ,
                              l_BEQ,
                              l_BNE,
                              l_BLT,
                              l_BGE,
                              l_BLTU,
                              l_BGEU,
                              l_B,
                              l_BL,
                              l_JIRL
                            };

// no_fpu
assign lisa_fpu_inst_decode  =  {`OPEN132_IDU_FPU_DECODE_BUS_WIDTH{1'b0}};
// End Inst Decode
endmodule  // dsu_inst_dec
