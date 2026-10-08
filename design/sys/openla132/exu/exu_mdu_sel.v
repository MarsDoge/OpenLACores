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

module exu_mdu_sel #(
    parameter MDU_TYPE = 2'd2
) (
    input  wire                                      clk_g,
    input  wire                                      reset,
    input  wire                                      data_reset,
    input  wire [                             5: 0]  rtu_exu_ctrl_bus,
    input  wire [                             2: 0]  lsu_exu_ctrl_bus,
    input  wire [`OPEN132_IDU_EXU_MDU_BUS_WIDTH-1: 0]  idu_exu_mdu_bus,
    input  wire [`OPEN132_RTU_EXU_APP_BUS_WIDTH-1: 0]  rtu_exu_app_bus,

    output wire                                      exu_idu_allowin,
    output wire [                             0: 0]  exu_lsu_ctrl_bus,
    output wire [                            32: 0]  exu_rtu_result_bus
);

//============================================================//
//                     Wire Declarations
//============================================================//

generate
    if (MDU_TYPE == 2'd0) begin: gen_quick_mdu
        exu_qmdu x_exu_mdu (
            .clk                (clk_g             ),
            .reset              (reset             ),
            .data_reset         (data_reset        ),
            .rtu_exu_ctrl_bus   (rtu_exu_ctrl_bus  ),
            .lsu_exu_ctrl_bus   (lsu_exu_ctrl_bus  ),
            .idu_exu_mdu_bus    (idu_exu_mdu_bus   ),
            .exu_idu_allowin    (exu_idu_allowin   ),
            .exu_lsu_ctrl_bus   (exu_lsu_ctrl_bus  ),
            .exu_rtu_result_bus (exu_rtu_result_bus),
            .rtu_exu_app_bus    (rtu_exu_app_bus   )
        );
    end
    else if (MDU_TYPE == 2'd1) begin: gen_smart_mdu
        exu_smdu x_exu_mdu (
            .clk                (clk_g             ),
            .reset              (reset             ),
            .data_reset         (data_reset        ),
            .rtu_exu_ctrl_bus   (rtu_exu_ctrl_bus  ),
            .lsu_exu_ctrl_bus   (lsu_exu_ctrl_bus  ),
            .idu_exu_mdu_bus    (idu_exu_mdu_bus   ),
            .exu_idu_allowin    (exu_idu_allowin   ),
            .exu_lsu_ctrl_bus   (exu_lsu_ctrl_bus  ),
            .exu_rtu_result_bus (exu_rtu_result_bus)
        );
    end
    else if (MDU_TYPE == 2'd2) begin: gen_area_mdu
        exu_amdu x_exu_mdu (
            .clk                (clk_g             ),
            .reset              (reset             ),
            .data_reset         (data_reset        ),
            .rtu_exu_ctrl_bus   (rtu_exu_ctrl_bus  ),
            .lsu_exu_ctrl_bus   (lsu_exu_ctrl_bus  ),
            .idu_exu_mdu_bus    (idu_exu_mdu_bus   ),
            .exu_idu_allowin    (exu_idu_allowin   ),
            .exu_lsu_ctrl_bus   (exu_lsu_ctrl_bus  ),
            .exu_rtu_result_bus (exu_rtu_result_bus)
        );
    end
endgenerate

endmodule
