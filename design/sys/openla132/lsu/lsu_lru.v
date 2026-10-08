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

module lsu_lru #(
    //cache configuration
    //Cache size in KB: SET_ASSC*WAYSIZE
    parameter SET_ASSOC    = 4        , //1/2/4 way set associative
    //parameter WAYSIZE      = 8*(2**10), //1/2/4/8/16 KB Size/way
    parameter INDEX_BITS   = 5        , //for waysize 1K
    parameter LRU_BITS     = 6        , //for 4 ways
    parameter RAM_LRUD_WD  = 10         //for 4 ways
)(
    //wrbuf update lru
    input                      wrbuf_lrud_wen     ,
    input                      wrbuf_lrud_lru_clr ,
    input  [INDEX_BITS   -1:0] wrbuf_lrud_indx    ,
    input  [SET_ASSOC    -1:0] wrbuf_lrud_wway    ,
    input  [SET_ASSOC    -1:0] wrbuf_lrud_wlock   ,
    input  [SET_ASSOC    -1:0] wrbuf_lrud_d_wen   ,
    input                      wrbuf_lrud_wdirty  ,
    //mq update lru
    input                      mq_lrud_ren        ,
    input  [INDEX_BITS   -1:0] mq_lrud_indx       ,

    //from lrud ram
    input  [RAM_LRUD_WD  -1:0] ram_lrud_rdata     ,
    //to lrud ram
    output                     ram_lrud_en        ,
    output [RAM_LRUD_WD  -1:0] ram_lrud_wen       ,
    output [INDEX_BITS   -1:0] ram_lrud_addr      ,
    output [RAM_LRUD_WD  -1:0] ram_lrud_wdata     ,
    //to mq
    output [SET_ASSOC    -1:0] lru_repl_way       ,
    output [SET_ASSOC    -1:0] lru_repl_way_d

);
//get lru&d
wire [LRU_BITS  -1:0] mq_lru_rdata;
wire [SET_ASSOC -1:0] mq_d_rdata;
assign mq_d_rdata    = ram_lrud_rdata[SET_ASSOC -1:0];
generate if(SET_ASSOC==2 || SET_ASSOC==4)
begin: gen_read_lru_2way_4way
    assign mq_lru_rdata = ram_lrud_rdata[RAM_LRUD_WD-1:SET_ASSOC];
end
else
begin: gen_read_lru_1way
    assign mq_lru_rdata = 2'd0;
end
endgenerate
assign lru_repl_way_d = mq_d_rdata;
//----------------{lru algorithm}begin---------------------//
wire [SET_ASSOC  -1:0]lru_new_way;
wire [SET_ASSOC  -1:0]lru_way_lock;
wire                  lru_new_wen;
wire                  lru_new_clr;
wire [LRU_BITS   -1:0]lru_new_wdata;
wire [LRU_BITS   -1:0]lru_new_bitmask;

wire [LRU_BITS   -1:0]lru_repl_rdata;

wire [RAM_LRUD_WD-1:0]lrud_wdata;   //dirty must be 0 when valid is 0
wire [RAM_LRUD_WD-1:0]lrud_bitmask;

//if ram_init after reset, wrbuf_lrud_wway need be all'1
assign lru_new_way    = wrbuf_lrud_wway;
assign lru_way_lock   = wrbuf_lrud_wlock;
assign lru_new_wen    = wrbuf_lrud_wen;
assign lru_new_clr    = wrbuf_lrud_lru_clr;

assign lru_repl_rdata = mq_lru_rdata;

generate if (SET_ASSOC==2 || SET_ASSOC==4)
begin: gen_lru_encode_2way_4way
    lsu_lru_repl #(
        .LRU_BITS(LRU_BITS ),
        .WAY_N   (SET_ASSOC)
    )u_lru_replacement(
        .new_way        (lru_new_way    ),
        .way_lock       (lru_way_lock   ),
        .new_wen        (lru_new_wen    ),
        .new_clr        (lru_new_clr    ),
        .new_lru        (lru_new_wdata  ),
        .new_lru_bitmask(lru_new_bitmask),
        .repl_lru       (lru_repl_rdata ),
        .repl_way       (lru_repl_way   )
     );
end
else
begin: gen_replaced_way_1way
    assign lru_repl_way = 1'b1;
end
endgenerate

//dirty
wire [SET_ASSOC  -1:0] dirty_new_wdata;
wire [SET_ASSOC  -1:0] dirty_new_bitmask;
assign dirty_new_wdata   = {SET_ASSOC{wrbuf_lrud_wdirty}};
assign dirty_new_bitmask = wrbuf_lrud_d_wen;
//lrud
generate
    if (SET_ASSOC==1)
    begin:gen_lrud_1way
        assign lrud_wdata    = {dirty_new_wdata  };
        assign lrud_bitmask  = {dirty_new_bitmask};
    end
    else
    begin:gen_lrud_2way_or_4way
        assign lrud_wdata    = {lru_new_wdata  ,dirty_new_wdata};
        assign lrud_bitmask  = {lru_new_bitmask,dirty_new_bitmask};
    end
endgenerate
//-----------------{lru algorithm}end----------------------//

//--------------------{LRU/D}begin-------------------------//
//3x1:
//miss-queue(r)  miss-queue(w)  wrbuf(w)  hardware-initial(w)
//    |______________|____________|_______________|
//                          |
//                        LRU/D
//4x1:
assign ram_lrud_en   = wrbuf_lrud_wen | mq_lrud_ren;
assign ram_lrud_wen  = lrud_bitmask;
assign ram_lrud_addr = wrbuf_lrud_wen ? wrbuf_lrud_indx : mq_lrud_indx;
assign ram_lrud_wdata= lrud_wdata;
//---------------------{LRU/D}end--------------------------//
endmodule
