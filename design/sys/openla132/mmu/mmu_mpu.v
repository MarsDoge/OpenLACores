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

module mmu_mpu #(
    parameter TOTAL_NUM = 2, //MPU_NUM
    parameter THIS_NUM  = 1
)(
    input         clk              ,
    input         reset            ,
    input         data_reset       ,

    input         lisa_kernel_mode ,

    input         mpuhi_wen        ,
    input         mpulo_wen        ,
    input  [31:0] ctrl_wrdata      ,
    input  [31:0] ctrl_wrmask      ,

    output [31:0] csr_mpuhi        ,
    output [31:0] csr_mpulo        ,
    output        ctrl_mpuhi_valid ,
    output [19:0] ctrl_mpuhi_base  ,
    output [19:0] ctrl_mpulo_mask  ,
    output [3 :0] ctrl_mpulo_calg
);
generate if(TOTAL_NUM >= THIS_NUM)
begin: gen_has_this_mpu
    reg        mpuhi_p0_r     ; //mpu valid
    reg        mpuhi_p3_r     ;
    reg [19:0] mpuhi_base_r   ;
    reg [19:0] mpulo_mask_r   ;
    reg [3 :0] mpulo_calg_r   ;//0010: uncached          ; 0011: cached, all-alloc
                               //1011: cached, read-alloc; 1111: cached, write-alloc
                               //others: reserved.
    always @(posedge clk)
    begin
        if(reset)
        begin
            mpuhi_p0_r <=  1'b0;
        end
        else if(mpuhi_wen)
        begin
            mpuhi_p0_r <= ctrl_wrmask[0]&ctrl_wrdata[0]
                        |~ctrl_wrmask[0]&mpuhi_p0_r;
        end

        if(reset)
        begin
            mpuhi_p3_r <=  1'b0;
        end
        else if(mpuhi_wen)
        begin
            mpuhi_p3_r <= ctrl_wrmask[3]&ctrl_wrdata[3]
                        |~ctrl_wrmask[3]&mpuhi_p3_r;
        end

        if(data_reset)
        begin
            mpuhi_base_r  <= 20'd0;
        end
        else if(mpuhi_wen)
        begin
            mpuhi_base_r  <= ctrl_wrmask[31:12]&ctrl_wrdata[31:12]
                           |~ctrl_wrmask[31:12]&mpuhi_base_r;
        end

        if(data_reset)
        begin
            mpulo_mask_r  <= 20'd0;
        end
        else if(mpulo_wen)
        begin
            mpulo_mask_r  <= ctrl_wrmask[31:12]&ctrl_wrdata[31:12]
                           |~ctrl_wrmask[31:12]&mpulo_mask_r;
        end
        if(data_reset)
        begin
            mpulo_calg_r  <= 4'd0;
        end
        else if(mpuhi_wen) //calg is in mpuhi[7:4] for lisa
        begin
            mpulo_calg_r  <= ctrl_wrmask[7 : 4]&ctrl_wrdata[7 : 4]
                           |~ctrl_wrmask[7 : 4]&mpulo_calg_r;
        end
    end
    assign csr_mpuhi  = {mpuhi_base_r , //31:12, base
                         4'd0         , //11: 8 is 0
                         mpulo_calg_r , //7 : 4, calg is in mpuhi for lisa_mode
                         mpuhi_p3_r   , //3, valid
                         2'd0         , //2 : 1 is 0
                         mpuhi_p0_r     //0, valid
                        };
    assign csr_mpulo  = {mpulo_mask_r , //31:12, mask
                         12'd0          //11: 0 is 0
                        };

    assign ctrl_mpuhi_valid = (mpuhi_p0_r&& lisa_kernel_mode||
                               mpuhi_p3_r&&!lisa_kernel_mode); //mpu valid
    assign ctrl_mpuhi_base  = mpuhi_base_r;
    assign ctrl_mpulo_mask  = mpulo_mask_r;
    assign ctrl_mpulo_calg  = mpulo_calg_r;
end
else
begin: gen_no_this_mpu
    assign csr_mpuhi        = 32'd0;
    assign csr_mpulo        = 32'd0;
    assign ctrl_mpuhi_valid =  1'd0;
    assign ctrl_mpuhi_base  = 20'd0;
    assign ctrl_mpulo_mask  = 20'd0;
    assign ctrl_mpulo_calg  =  4'd0;

    wire nc_clk       =  clk;
    wire nc_reset     =  reset;
    wire nc_data_reset=  data_reset;
    wire nc_mpuhi_wen =  mpuhi_wen;
    wire nc_mpulo_wen =  mpulo_wen;
    wire nc_ctrl_wrmask= |ctrl_wrmask;
    wire nc_ctrl_wrdata= |ctrl_wrdata;
end
endgenerate

endmodule
