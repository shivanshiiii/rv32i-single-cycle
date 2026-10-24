`timescale 1ns/1ps
// Cycle-by-cycle PC-path checking catches wrong taken/not-taken branch decisions.
module tb_soc_edge;
    reg clk = 0;
    reg reset = 1;
    wire [31:0] debug_pc;
    wire [31:0] debug_instr;
    wire debug_illegal;

    rv32i_soc #(.IMEM_HEX("programs/edge.hex")) dut (
        .clk(clk), .reset(reset),
        .debug_pc(debug_pc), .debug_instr(debug_instr),
        .debug_illegal(debug_illegal)
    );
    always #5 clk = ~clk;

    `include "edge_expected.vh"
    `include "edge_trace_expected.vh"
    reg [31:0] expected_pc [0:EDGE_TRACE_STEPS-1];
    integer cycles;
    integer errors = 0;

    task expect_reg;
        input integer regnum;
        input [31:0] expected;
        begin
            if (dut.cpu.regfile[regnum] !== expected) begin
                $display("FAIL edge x%0d: expected %08h, got %08h",
                         regnum, expected, dut.cpu.regfile[regnum]);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("build/rv32i_edge.vcd");
        $dumpvars(0, tb_soc_edge);
        $readmemh("programs/edge_trace.hex", expected_pc);
        repeat (3) @(negedge clk);
        reset = 0;
        for (cycles = 0; cycles < EDGE_TRACE_STEPS; cycles = cycles + 1) begin
            #1;
            if (debug_pc !== expected_pc[cycles])
                $fatal(1, "EDGE PC mismatch at step %0d: expected %08h got %08h",
                       cycles, expected_pc[cycles], debug_pc);
            if (debug_illegal !== 1'b0)
                $fatal(1, "EDGE illegal instruction at PC %08h (word %08h)",
                       debug_pc, debug_instr);
            @(negedge clk);
        end
        if (debug_pc !== EDGE_HALT_PC)
            $fatal(1, "EDGE halt PC mismatch: expected %08h got %08h",
                   EDGE_HALT_PC, debug_pc);
        expect_reg(0, 0);
        expect_reg(1, 32'hffffffff);
        expect_reg(2, 1);
        expect_reg(3, 1);
        expect_reg(4, 0);
        expect_reg(5, 1);
        expect_reg(6, 0);
        expect_reg(7, 1);
        expect_reg(8, 32'hffffffff);
        expect_reg(9, 1);
        expect_reg(10, 32'h80000000);
        expect_reg(11, 32'hc0000000);
        expect_reg(12, 32'h40000000);
        expect_reg(13, 0);
        expect_reg(14, 32'hffffffff);
        expect_reg(15, 32'hfffff800);
        expect_reg(16, 2047);
        expect_reg(17, 32'hfffff800);
        expect_reg(18, 32'hffffffff);
        expect_reg(19, 0);
        expect_reg(20, 32'h80000000);
        expect_reg(21, 1);
        expect_reg(22, 32'hffffffff);
        expect_reg(23, 15);
        expect_reg(24, 0);
        expect_reg(25, 0);
        expect_reg(26, 1);
        expect_reg(27, 33);
        expect_reg(28, 32'h80000000);
        expect_reg(29, EDGE_JAL_LINK);
        expect_reg(30, EDGE_AUIPC_PC);
        expect_reg(31, EDGE_JALR_LINK);
        if (dut.dmem[7] !== 32'h80000000) begin
            $display("FAIL edge RAM[7]: expected 80000000, got %08h", dut.dmem[7]);
            errors = errors + 1;
        end
        if (errors != 0) $fatal(1, "EDGE TEST FAILED: %0d errors", errors);
        $display("EDGE TEST PASSED: %0d instruction steps; signed, unsigned, branch, loop, jump and RAM checks", cycles);
        $finish;
    end
endmodule
