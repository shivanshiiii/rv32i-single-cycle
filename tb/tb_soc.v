`timescale 1ns/1ps
module tb_soc;
    reg clk=0;
    reg reset=1;
    wire [31:0] debug_pc;
    wire [31:0] debug_instr;
    wire debug_illegal;
    rv32i_soc dut (
        .clk(clk), .reset(reset),
        .debug_pc(debug_pc), .debug_instr(debug_instr),
        .debug_illegal(debug_illegal)
    );
    always #5 clk = ~clk;

    integer cycles=0;
    integer errors=0;
    `include "demo_expected.vh"

    task expect_reg;
        input integer regnum;
        input [31:0] expected;
        begin
            if (dut.cpu.regfile[regnum] !== expected) begin
                $display("FAIL x%0d: expected %08h, got %08h",
                         regnum, expected, dut.cpu.regfile[regnum]);
                errors=errors+1;
            end else
                $display("PASS x%0d = %08h", regnum, expected);
        end
    endtask

    // Sample the instruction being retired at each positive edge. Checking only
    // the post-edge PC could miss an illegal instruction on a skipped path.
    always @(posedge clk) begin
        if (!reset && debug_illegal !== 1'b0)
            $fatal(1, "Illegal instruction at PC %08h (word %08h)", debug_pc, debug_instr);
        if (!reset && debug_pc[1:0] !== 2'b00)
            $fatal(1, "Misaligned instruction PC %08h", debug_pc);
    end

    initial begin
        $dumpfile("build/rv32i.vcd");
        $dumpvars(0, tb_soc);
        repeat (3) @(negedge clk);
        reset=0;
        while (debug_pc !== HALT_PC && cycles < 200) begin
            @(negedge clk);
            cycles=cycles+1;
            if (debug_illegal) $fatal(1,"Illegal instruction at PC %08h", debug_pc);
        end
        if (cycles >= 200) $fatal(1,"TIMEOUT waiting for halt loop");
        // Results have committed because we sample at negative edge.
        expect_reg(0, 32'd0);
        expect_reg(1, 32'd7);
        expect_reg(2, 32'd5);
        expect_reg(3, 32'd12);
        expect_reg(4, 32'd2);
        expect_reg(5, 32'd5);
        expect_reg(6, 32'd7);
        expect_reg(7, 32'd2);
        expect_reg(8, 32'd640);
        expect_reg(9, 32'd5);
        expect_reg(10, 32'd1);
        expect_reg(11, 32'd20);
        expect_reg(12, 32'hfffffff8);
        expect_reg(13, 32'hfffffffe);
        expect_reg(14, 32'd3);
        expect_reg(15, 32'd7);
        expect_reg(16, 32'd4);
        expect_reg(17, 32'd1);
        expect_reg(18, 32'd20);
        expect_reg(19, 32'd10);
        expect_reg(20, 32'd12);
        expect_reg(21, 32'd0);
        expect_reg(22, 32'h12345000);
        expect_reg(23, AUIPC_RESULT);
        expect_reg(24, JAL_LINK);
        expect_reg(25, 32'd0);
        expect_reg(26, JALR_LINK);
        expect_reg(27, JALR_TARGET_PC);
        expect_reg(28, 32'd1);
        expect_reg(29, 32'd1);
        expect_reg(30, 32'hfffffffe);
        expect_reg(31, 32'hffffffff);
        if (dut.dmem[3] !== 32'd12) begin
            $display("FAIL dmem[3] expected 12, got %0d", dut.dmem[3]);
            errors=errors+1;
        end
        if (errors != 0) $fatal(1,"TEST FAILED: %0d errors", errors);
        $display("TEST PASSED: %0d cycles, RV32I demo program", cycles);
        $finish;
    end
endmodule
