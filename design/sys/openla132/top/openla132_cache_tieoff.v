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

module la132_cache_tieoff (
    output wire           dcc_ram_tagv_resp_bus,
    output wire           dcc_ram_data_resp_bus,
    output wire           dcc_ram_lrud_resp_bus,
    output wire           icc_ram_tagv_resp_bus,
    output wire           icc_ram_data_resp_bus,
    output wire           icc_ram_lrud_resp_bus
);

//============================================================//
//                    Module Implementation
//============================================================//

assign dcc_ram_tagv_resp_bus  =  1'b0;
assign dcc_ram_data_resp_bus  =  1'b0;
assign dcc_ram_lrud_resp_bus  =  1'b0;
assign icc_ram_tagv_resp_bus  =  1'b0;
assign icc_ram_data_resp_bus  =  1'b0;
assign icc_ram_lrud_resp_bus  =  1'b0;

endmodule  // la132_cache_tieoff
