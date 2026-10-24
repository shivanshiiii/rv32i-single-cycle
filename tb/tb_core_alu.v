`timescale 1ns/1ps
// Port-only scoreboard: reusable for RTL and the generic synthesized netlist.
module tb_core_alu;
    reg clk = 0;
    reg reset = 1;
    reg [31:0] instr_data = 32'h00000013;
    wire [31:0] instr_addr, dmem_addr, dmem_wdata;
    wire dmem_we, illegal_instr;
    reg [64:0] vectors [0:`ALU_VECTOR_COUNT-1];
    integer n, checks = 0;

    rv32i_core dut (
        .clk(clk), .reset(reset), .instr_addr(instr_addr),
        .instr_data(instr_data), .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata), .dmem_we(dmem_we),
        .dmem_rdata(32'b0), .illegal_instr(illegal_instr)
    );
    always #5 clk = ~clk;

    initial begin
        $readmemh("build/alu_vectors.hex", vectors);
        repeat (2) @(negedge clk);
        reset = 0;
        for (n = 0; n < `ALU_VECTOR_COUNT; n = n + 1) begin
            instr_data = vectors[n][64:33];
            #1;
            if (instr_addr !== n * 4 || illegal_instr !== 1'b0)
                $fatal(1, "ALU PC/illegal mismatch at vector %0d", n);
            if (dmem_we !== vectors[n][32])
                $fatal(1, "ALU store enable mismatch at vector %0d", n);
            if (vectors[n][32]) begin
                if (dmem_addr !== 0 || dmem_wdata !== vectors[n][31:0])
                    $fatal(1, "ALU vector %0d: expected %08h, got %08h",
                           n, vectors[n][31:0], dmem_wdata);
                checks = checks + 1;
            end
            @(negedge clk);
        end
        if (instr_addr !== `ALU_VECTOR_COUNT * 4)
            $fatal(1, "ALU final PC mismatch");
        reset = 1;
        @(negedge clk);
        if (instr_addr !== 0) $fatal(1, "ALU reset PC mismatch");
        $display("ALU TEST PASSED: %0d instruction vectors; %0d result checks", n, checks);
        $finish;
    end

    initial begin
        #(`ALU_VECTOR_COUNT * 20 + 1000);
        $fatal(1, "ALU test timeout");
    end
endmodule
