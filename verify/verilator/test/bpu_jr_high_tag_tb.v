// SPDX-License-Identifier: MulanPSL-2.0
`include "openla132_global.h"

module bpu_jr_high_tag_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset = 1;
    reg [31:0] pc = 0;
    reg [`OPEN132_DE2PRED_BUS_WD-1:0] update_bus = 0;
    wire [`OPEN132_PRED2FT_BUS_WD-1:0] prediction;
    integer i;

    ifu_bpu dut (
        .clk_g(clk), .reset(reset), .data_reset(reset),
        .ifu_bpu_pc(pc), .idu_bpu_update_bus(update_bus),
        .csr_bpu_ctrl_bus(2'b01), .bpu_ifu_pred_bus(prediction)
    );

    // Supply a taken, previously unpredicted branch through the public
    // update interface. The initial count matches dsu_stage's PC hash.
    task insert_branch;
        input [31:0] branch_pc;
        input is_return;
        reg [2:0] count;
        begin
            count = 3'b010 + {1'b0,
                branch_pc[2]^branch_pc[3]^branch_pc[5],
                branch_pc[3]^branch_pc[4]};
            @(negedge clk);
            update_bus = {branch_pc, branch_pc + 32'd4,
                          is_return, 1'b0, 1'b0, 4'd0, count,
                          1'b0, 1'b1};
            @(negedge clk);
            update_bus = 0;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset = 0;
        // Control case: return allocation works when both tables have space.
        insert_branch(32'h20000080, 1);
        pc = 32'h20000080;
        #1;
        if (prediction[42] !== 1'b1 || prediction[39] !== 1'b1)
            $fatal(1, "Return allocation failed with empty BTB");
        @(negedge clk);
        reset = 1;
        repeat (2) @(negedge clk);
        reset = 0;
        // Fill all 16 direct-branch entries, leaving the return table empty.
        for (i = 0; i < 16; i = i + 1)
            insert_branch(32'h10000000 + i * 4, 0);
        pc = 32'h1000003c;
        #1;
        if (prediction[42] !== 1'b1 || prediction[39] !== 1'b0)
            $fatal(1, "Direct-branch allocation failed");
        // This return needs a different shared high tag.
        insert_branch(32'h20000080, 1);
        pc = 32'h20000080;
        #1;
        if (prediction[42] !== 1'b1 || prediction[39] !== 1'b1)
            $fatal(1, "New return is not predicted with full BTB: prediction=%h", prediction);
        $display("PASS: return allocation installs its high tag even with a full BTB");
        $finish;
    end
endmodule
