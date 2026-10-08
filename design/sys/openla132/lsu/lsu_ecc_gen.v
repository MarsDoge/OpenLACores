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
`include "openla132_ecc_define.h"

module lsu_ecc_gen #(
    parameter ECC_WAY  = 4 , //1/2/4
    parameter DATA_BITS= 32, //<=32
    parameter ECC_BITS = 8   //1/7/8/9
)(
    input  [ECC_WAY   -1:0] way    , //one-hot
    input  [DATA_BITS -1:0] data_in,
    output [ECC_BITS  -1:0] ecc_out
);
//4 way, data 32bits
wire [4 :0] way5;
wire [32:0] data_in33;
wire [3 :0] way4;
wire [31:0] data_in32;
assign way5      = {{(5-ECC_WAY   ){1'b0}},way    };
assign data_in33 = {{(33-DATA_BITS){1'b0}},data_in};
assign way4      = way5[3:0];
assign data_in32 = data_in33[31:0];
wire [31:0] mask [6:0];
wire [31:0] mask_all1;
assign mask[0]   = `OPEN132_ECC_MASK0;
assign mask[1]   = `OPEN132_ECC_MASK1;
assign mask[2]   = `OPEN132_ECC_MASK2;
assign mask[3]   = `OPEN132_ECC_MASK3;
assign mask[4]   = `OPEN132_ECC_MASK4;
assign mask[5]   = `OPEN132_ECC_MASK5;
assign mask[6]   = `OPEN132_ECC_MASK6;
assign mask_all1 = 32'b1111_1111_1111_1111_1111_1111_1111_1111;

wire [6 :0] ecc;
wire        ecc_all;
assign ecc[0]  = (^(data_in32 & mask[0]));
assign ecc[1]  = (^(data_in32 & mask[1]));
assign ecc[2]  = (^(data_in32 & mask[2]));
assign ecc[3]  = (^(data_in32 & mask[3]));
assign ecc[4]  = (^(data_in32 & mask[4]));
assign ecc[5]  = (^(data_in32 & mask[5]));
assign ecc[6]  = (^(data_in32 & mask[6]));
assign ecc_all = (^(data_in32 & mask_all1));

generate if(ECC_BITS>=7)
begin: gen_cache_has_ecc
    assign ecc_out[1] = ecc[1];
    assign ecc_out[2] = ecc[2];
    assign ecc_out[3] = ecc[3];
    assign ecc_out[4] = ecc[4];
    assign ecc_out[5] = ecc[5];
    assign ecc_out[6] = ecc[6];
end
else
begin: gen_cache_no_ecc
    assign ecc_out = {ECC_BITS{1'b0}};
end
endgenerate

generate
    if(ECC_BITS==7)
    begin: gen_ecc_1way_to_1eccset
        assign ecc_out[0] = ecc[0];
    end
    else if(ECC_BITS==8)
    begin: gen_ecc_2way_to_1eccset
        assign ecc_out[0] = ecc[0] ^ ( ecc_all && way4[1] ); //way[1] need ~
        assign ecc_out[7] = ecc_all && way4[1];              //way[1] need all1
    end
    else if(ECC_BITS==9)
    begin: gen_ecc_4way_to_1eccset
        assign ecc_out[0] = ecc[0] ^ ( ecc_all && (way4[1]||way4[2]) ); //way[1],way[2] need ~
        assign ecc_out[7] = ecc_all && (way4[1]||way4[3]);              //way[1],way[3] need all1
        assign ecc_out[8] = ecc_all && (way4[2]||way4[3]);              //way[2],way[3] need all1
    end
endgenerate

endmodule
