// SPDX-License-Identifier: MulanPSL-2.0
module cpucfg_cache_case #(parameter I=0, D=0)(output reg done=0);
reg [31:0] index=32'h10;
wire [31:0] value;
csr_cpucfg #(.HAS_ICC(I), .HAS_DCC(D), .ICC_SET_ASSOC(4),
 .DCC_SET_ASSOC(4), .ICC_WAYSIZE(4096), .DCC_WAYSIZE(4096),
 .PERF_CNT_NUM(0)) dut (.prid_revision(4'd0), .inst_cpucfg(1'b1),
 .cpucfg_addr(index), .cpucfg_result(value));
initial begin
 #1;
 if(value[0] !== (I!=0) || value[2] !== (D!=0))
   $fatal(1,"Incorrect cache presence I=%0d D=%0d: %h",I,D,value);
 index=32'h11;
 #1;
 if(value !== (I ? 32'h05070003 : 32'd0))
   $fatal(1,"Incorrect I-cache geometry I=%0d D=%0d: %h",I,D,value);
 index=32'h12;
 #1;
 if(value !== (D ? 32'h05070003 : 32'd0))
   $fatal(1,"Incorrect D-cache geometry I=%0d D=%0d: %h",I,D,value);
 done=1;
end
endmodule
module cpucfg_cache_tb;
wire [3:0] done;
cpucfg_cache_case #(0,0) c00(done[0]);
cpucfg_cache_case #(0,1) c01(done[1]);
cpucfg_cache_case #(1,0) c10(done[2]);
cpucfg_cache_case #(1,1) c11(done[3]);
initial begin
 wait(&done);
 $display("PASS: CPUCFG cache geometry for all four I/D presence combinations");
 $finish;
end
initial begin #100; $fatal(1,"timeout"); end
endmodule
