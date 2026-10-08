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

module mmu_vaddr_attribute #(
    parameter MPU_NUM    = 2,
    parameter CFGSEG_NUM = 4
)(
    input                      lisa_da     ,
    input [1               :0] lisa_dacf   ,
    input [1               :0] lisa_dacm   ,

    input  [1*MPU_NUM    -1:0] mpu_valid   ,
    input  [20*MPU_NUM   -1:0] mpu_base    ,
    input  [20*MPU_NUM   -1:0] mpu_mask    ,
    input  [4*MPU_NUM    -1:0] mpu_calg    ,

    input  [4*CFGSEG_NUM -1:0] cfgseg_calg ,

    //dcc
    input  [31             :0] dcc_vaddr       ,
    input                      dcc_read        ,
    input                      dcc_dbgm        ,

    output                     dcc_addr_sob    ,//only device-seg will set sob, now
    output                     dcc_addr_cached ,
    output                     dcc_addr_alloc  ,
    //dcc
    input  [31             :0] icc_vaddr       ,
    input                      icc_dbgm        ,

    output                     icc_addr_cached
);

//lisa calg:
//0000: uncached          ; 0001: cached, all-alloc
//0101: cached, read-alloc; 0111: cached, write-alloc
//1111: device-attribute
//others: reserved.

//mpu
wire [MPU_NUM    -1:0] mpu_cached   ;
wire [MPU_NUM    -1:0] mpu_rd_alloc ;
wire [MPU_NUM    -1:0] mpu_wr_alloc ;
wire [CFGSEG_NUM -1:0] seg_cached   ;
wire [CFGSEG_NUM -1:0] seg_rd_alloc ;
wire [CFGSEG_NUM -1:0] seg_wr_alloc ;
wire [CFGSEG_NUM -1:0] seg_device   ;
genvar i;
generate for(i=0; i<MPU_NUM; i=i+1)
begin: gen_mpu_attr
    assign mpu_cached  [i] = mpu_calg[4*i+:4]==4'b0001 || mpu_calg[4*i+:4]==4'b0101 ||
                             mpu_calg[4*i+:4]==4'b0111;
    assign mpu_rd_alloc[i] = mpu_calg[4*i+:4]==4'b0001 || mpu_calg[4*i+:4]==4'b0101;
    assign mpu_wr_alloc[i] = mpu_calg[4*i+:4]==4'b0001 || mpu_calg[4*i+:4]==4'b0111;
end
endgenerate
generate for(i=0; i<CFGSEG_NUM; i=i+1)
begin: gen_cfgseg_attr
    assign seg_cached  [i] = cfgseg_calg[4*i+:4]==4'b0001 || cfgseg_calg[4*i+:4]==4'b0101 ||
                             cfgseg_calg[4*i+:4]==4'b0111;
    assign seg_rd_alloc[i] = cfgseg_calg[4*i+:4]==4'b0001 || cfgseg_calg[4*i+:4]==4'b0101;
    assign seg_wr_alloc[i] = cfgseg_calg[4*i+:4]==4'b0001 || cfgseg_calg[4*i+:4]==4'b0111;
    assign seg_device  [i] = cfgseg_calg[4*i+:4]==4'b1111; //only lisa
end
endgenerate

//---{dcc}begin
wire [CFGSEG_NUM -1:0] dcc_cfgseg;
wire                   dcc_mpu_hit_valid;
wire [MPU_NUM    -1:0] dcc_mpu_hit      ;
mmu_vaddr_cfgseg #(CFGSEG_NUM) dcc_vaddr_cfgseg(
    .vaddr     (dcc_vaddr  ),
    .cfgseg    (dcc_cfgseg )
);
wire dcc_deviceseg = |(dcc_cfgseg&seg_device);
generate for(i=0; i<MPU_NUM; i=i+1)
begin: gen_dcc_mpu_hit
    assign dcc_mpu_hit[i] = ( (dcc_vaddr[31:12]&mpu_mask[20*i+:20]) == mpu_base[20*i+:20] ) && mpu_valid[i];
end
endgenerate
assign dcc_mpu_hit_valid = |dcc_mpu_hit;

wire [MPU_NUM    -1:0]mpu_alloc = dcc_read ? mpu_rd_alloc : mpu_wr_alloc;
wire [CFGSEG_NUM -1:0]seg_alloc = dcc_read ? seg_rd_alloc : seg_wr_alloc;

//cached shouldn't set sob.
assign dcc_addr_sob    = dcc_dbgm          ? 1'b1                      :
                         lisa_da           ? lisa_dacm!=2'b01          :
                         dcc_mpu_hit_valid ? 1'b0                      :   dcc_deviceseg         ;
assign dcc_addr_cached = dcc_dbgm          ? 1'b0                      :
                         lisa_da           ? lisa_dacm==2'b01          :
                         dcc_mpu_hit_valid ? |(dcc_mpu_hit&mpu_cached) : |(dcc_cfgseg&seg_cached);
assign dcc_addr_alloc  = lisa_da           ? lisa_dacm==2'b01          :
                         dcc_mpu_hit_valid ? |(dcc_mpu_hit&mpu_alloc ) : |(dcc_cfgseg&seg_alloc );
//---{dcc}end

//---{icc}begin
wire [CFGSEG_NUM -1:0] icc_cfgseg;
wire                   icc_mpu_hit_valid;
wire [MPU_NUM    -1:0] icc_mpu_hit      ;
mmu_vaddr_cfgseg #(CFGSEG_NUM) icc_vaddr_cfgseg(
    .vaddr     (icc_vaddr  ),
    .cfgseg    (icc_cfgseg )
);
generate for(i=0; i<MPU_NUM; i=i+1)
begin: gen_icc_mpu_hit
    assign icc_mpu_hit[i] = ( (icc_vaddr[31:12]&mpu_mask[20*i+:20]) == mpu_base[20*i+:20] ) && mpu_valid[i];
end
endgenerate
assign icc_mpu_hit_valid = |icc_mpu_hit;

assign icc_addr_cached = icc_dbgm          ? 1'b0                      :
                         lisa_da           ? lisa_dacf==2'b01          :
                         icc_mpu_hit_valid ? |(icc_mpu_hit&mpu_cached) : |(icc_cfgseg&seg_cached);
//---{icc}end
endmodule
