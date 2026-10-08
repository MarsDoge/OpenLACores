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

module openla132_cg_cell_wrap (
    input  wire           clock_in,
    input  wire           enable,
    input  wire           scan_en,
    output wire           clock_out
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire          CKIN_std_cg;
wire          EN_std_cg;
wire          SE_std_cg;
wire          CKOUT_std_cg;

//============================================================//
//                    Module Implementation
//============================================================//

// Instance Boundary Alias Mapping
// x_open132_std_cell_cg

assign CKIN_std_cg  =  clock_in;
assign EN_std_cg    =  enable;
assign SE_std_cg    =  scan_en;
assign clock_out    =  CKOUT_std_cg;

openla132_std_cell_cg x_open132_std_cell_cg (
    .CKIN  (CKIN_std_cg ),
    .EN    (EN_std_cg   ),
    .SE    (SE_std_cg   ),
    .CKOUT (CKOUT_std_cg)
);

endmodule  // openla132_cg_cell_wrap
