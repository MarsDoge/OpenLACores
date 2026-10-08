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

module lsu_mq_bqueue #(
    parameter N = 8 //N <=8;
)(
    input         clk        ,
    input         reset      ,
    //enter
    input         in_en      ,
    input  [26:0] in_addr31_5, //addr[31:5]

    //quit
    input         axi_b_ok   ,
    input  [2 :0] axi_bid    ,

    //check conflict
    input  [26:0] ck_addr31_5,
    output        ck_hit     ,

    //full
    output [2 :0] empty_id   ,
    output        bq_full    ,
    output        bq_null
);
reg [N-1 :0] valid;
reg [14  :0] outs_addr [N-1:0];

genvar i;

//find write id
wire [7:0] valid8  = {{(8-N){1'b1}},valid};
wire [7:0] enter_dec;
wire [3:0] enter_enc; //{no-find, site}

wire [7:0] valid8_   ;
wire [7:0] enter_dec_;
wire [3:0] enter_enc_; //{no-find, site}
assign valid8_   = {valid8[0],valid8[1],valid8[2],valid8[3],
                    valid8[4],valid8[5],valid8[6],valid8[7]};
assign enter_dec = {enter_dec_[0],enter_dec_[1],enter_dec_[2],enter_dec_[3],
                    enter_dec_[4],enter_dec_[5],enter_dec_[6],enter_dec_[7]};
assign enter_enc = {enter_enc_[3],~enter_enc_[2:0]};
lsu_find1_8 #(1) find_empty(
    .a   (valid8_   ),
    .dec (enter_dec_),
    .enc (enter_enc_)
);
//full
assign empty_id = enter_enc[2:0];
assign bq_full  = enter_enc[3]; //no find empty
assign bq_null  = ~(|valid);

//fold address
wire [14:0] in_addr_fold;
assign in_addr_fold = {in_addr31_5[26:15]^in_addr31_5[14:3],in_addr31_5[2:0]};

//valid && outstanding-address
generate for(i=0; i<N; i=i+1)
begin: gen_valid
    always @(posedge clk)
    begin
        if(reset)
        begin
            valid[i] <= 1'd0;
        end
        else if(in_en||axi_b_ok)
        begin
            if(in_en && enter_dec[i])
            begin
                outs_addr[i] <= in_addr_fold;
            end

            if(in_en && enter_dec[i])
            begin
                valid[i] <= 1'b1;
            end
            else if(axi_b_ok && axi_bid==i[2:0])
            begin
                valid[i] <= 1'b0;
            end
        end
    end
end
endgenerate

//check conflict
wire [14:0] ck_addr_fold;
assign ck_addr_fold = {ck_addr31_5[26:15]^ck_addr31_5[14:3],ck_addr31_5[2:0]};

//check
wire [N-1:0] ck_cmp;
generate for(i=0; i<N; i=i+1)
begin: gen_addr_cmp
    assign ck_cmp[i] = valid[i] && (outs_addr[i]==ck_addr_fold);
end
endgenerate
assign ck_hit = |ck_cmp;

endmodule
