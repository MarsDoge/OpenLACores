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

module core_clk_ctrl (
    input  wire           clk,
    input  wire           test_mode,
    // sleeping
    input  wire           clk_slp_en,
    output wire           clk_g,
    // GPR-cg
    input  wire           clk_gpr_en,
    output wire           clk_gpr,

    input  wire           clk_cr_en,
    output wire           clk_cr

`ifdef OPEN132_HAS_LJTAG
    ,
    // ljtag-mode-cg
    input  wire           clk_ljt_en,
    output wire           clk_ljt,
    // debug-mode-cg, for dcr/ihb/dhb write
    input  wire           clk_dm_en,
    output wire           clk_dm
`endif

    ,
    // FPR-cg
    input  wire           clk_fpr_en,
    output wire           clk_fpr,
    // fpu-cg
    input  wire           clk_fpu_en,
    output wire           clk_fpu
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire          clock_in_cg_domain0;
wire          enable_cg_domain0;
wire          scan_en_cg_domain0;
wire          clock_out_cg_domain0;
wire          clock_in_cg_domain1;
wire          enable_cg_domain1;
wire          scan_en_cg_domain1;
wire          clock_out_cg_domain1;
wire          clock_in_cg_domain2;
wire          enable_cg_domain2;
wire          scan_en_cg_domain2;
wire          clock_out_cg_domain2;
wire          clock_in_cg_domain3;
wire          enable_cg_domain3;
wire          scan_en_cg_domain3;
wire          clock_out_cg_domain3;
wire          clock_in_cg_domain4;
wire          enable_cg_domain4;
wire          scan_en_cg_domain4;
wire          clock_out_cg_domain4;
wire          clock_in_cg_domain5;
wire          enable_cg_domain5;
wire          scan_en_cg_domain5;
wire          clock_out_cg_domain5;
wire          clock_in_cg_domain6;
wire          enable_cg_domain6;
wire          scan_en_cg_domain6;
wire          clock_out_cg_domain6;

wire          test_se;

//============================================================//
//                    Module Implementation
//============================================================//

assign test_se  =  test_mode;
// sleeping-cg
// Instance Boundary Alias Mapping
// x_open132_cg_cell_wrap_0

assign clock_in_cg_domain0  =  clk;
assign enable_cg_domain0    =  clk_slp_en;
assign scan_en_cg_domain0   =  test_se;
assign clk_g                =  clock_out_cg_domain0;
// x_open132_cg_cell_wrap_1
assign clock_in_cg_domain1  =  clk;
assign enable_cg_domain1    =  clk_gpr_en;
assign scan_en_cg_domain1   =  test_se;
assign clk_gpr              =  clock_out_cg_domain1;
// x_open132_cg_cell_wrap_2
assign clock_in_cg_domain2  =  clk;
assign enable_cg_domain2    =  clk_cr_en;
assign scan_en_cg_domain2   =  test_se;
assign clk_cr               =  clock_out_cg_domain2;
// x_open132_cg_cell_wrap_3
assign clock_in_cg_domain3  =  clk;
assign enable_cg_domain3    =  clk_ljt_en;
assign scan_en_cg_domain3   =  test_se;
assign clk_ljt              =  clock_out_cg_domain3;
// x_open132_cg_cell_wrap_4
assign clock_in_cg_domain4  =  clk;
assign enable_cg_domain4    =  clk_dm_en;
assign scan_en_cg_domain4   =  test_se;
assign clk_dm               =  clock_out_cg_domain4;
// x_open132_cg_cell_wrap_5
assign clock_in_cg_domain5  =  clk;
assign enable_cg_domain5    =  clk_fpr_en;
assign scan_en_cg_domain5   =  test_se;
assign clk_fpr              =  clock_out_cg_domain5;
// x_open132_cg_cell_wrap_6
assign clock_in_cg_domain6  =  clk;
assign enable_cg_domain6    =  clk_fpu_en;
assign scan_en_cg_domain6   =  test_se;
assign clk_fpu              =  clock_out_cg_domain6;

openla132_cg_cell_wrap x_open132_cg_cell_wrap_0 (
    .clock_in  (clock_in_cg_domain0 ),
    .enable    (enable_cg_domain0   ),
    .scan_en   (scan_en_cg_domain0  ),
    .clock_out (clock_out_cg_domain0)
);
openla132_cg_cell_wrap x_open132_cg_cell_wrap_1 (
    .clock_in  (clock_in_cg_domain1 ),
    .enable    (enable_cg_domain1   ),
    .scan_en   (scan_en_cg_domain1  ),
    .clock_out (clock_out_cg_domain1)
);
openla132_cg_cell_wrap x_open132_cg_cell_wrap_2 (
    .clock_in  (clock_in_cg_domain2 ),
    .enable    (enable_cg_domain2   ),
    .scan_en   (scan_en_cg_domain2  ),
    .clock_out (clock_out_cg_domain2)
);

`ifdef OPEN132_HAS_LJTAG
openla132_cg_cell_wrap x_open132_cg_cell_wrap_3 (
    .clock_in  (clock_in_cg_domain3 ),
    .enable    (enable_cg_domain3   ),
    .scan_en   (scan_en_cg_domain3  ),
    .clock_out (clock_out_cg_domain3)
);
openla132_cg_cell_wrap x_open132_cg_cell_wrap_4 (
    .clock_in  (clock_in_cg_domain4 ),
    .enable    (enable_cg_domain4   ),
    .scan_en   (scan_en_cg_domain4  ),
    .clock_out (clock_out_cg_domain4)
);
`endif

openla132_cg_cell_wrap x_open132_cg_cell_wrap_5 (
    .clock_in  (clock_in_cg_domain5 ),
    .enable    (enable_cg_domain5   ),
    .scan_en   (scan_en_cg_domain5  ),
    .clock_out (clock_out_cg_domain5)
);
openla132_cg_cell_wrap x_open132_cg_cell_wrap_6 (
    .clock_in  (clock_in_cg_domain6 ),
    .enable    (enable_cg_domain6   ),
    .scan_en   (scan_en_cg_domain6  ),
    .clock_out (clock_out_cg_domain6)
);

endmodule
