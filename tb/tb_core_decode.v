`timescale 1ns/1ps
// Isolated core tests for unsupported encodings and misaligned word accesses.
// Current design signals illegal_instr but does NOT implement traps/exceptions.
module tb_core_decode;
    reg clk = 0;
    reg reset = 1;
    reg [31:0] instr_data = 32'h00000013;
    wire [31:0] instr_addr;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire dmem_we;
    wire illegal_instr;
    reg [31:0] dmem_rdata = 32'hcafebabe;
    integer steps = 0;

    rv32i_core dut (
        .clk(clk), .reset(reset), .instr_addr(instr_addr),
        .instr_data(instr_data), .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata), .dmem_we(dmem_we),
        .dmem_rdata(dmem_rdata), .illegal_instr(illegal_instr)
    );
    always #5 clk = ~clk;

    task apply_instruction;
        input [31:0] word;
        input expected_illegal;
        input expected_we;
        input expected_reg_write;
        begin
            instr_data = word;
            #1;
            if (illegal_instr !== expected_illegal)
                $fatal(1, "decode: illegal flag mismatch at PC=%08h word=%08h", instr_addr, word);
            if (dmem_we !== expected_we)
                $fatal(1, "decode: store enable mismatch at PC=%08h word=%08h", instr_addr, word);
            if (dut.reg_write !== expected_reg_write)
                $fatal(1, "decode: register write enable mismatch at PC=%08h word=%08h", instr_addr, word);
            if (expected_illegal && (dmem_we || dut.reg_write))
                $fatal(1, "decode: illegal instruction caused architectural write");
            @(posedge clk);
            #1;
            steps = steps + 1;
            if (instr_addr !== (steps * 4))
                $fatal(1, "decode: PC did not advance as documented; PC=%08h steps=%0d", instr_addr, steps);
        end
    endtask

    initial begin
        $dumpfile("build/rv32i_decode.vcd");
        $dumpvars(0, tb_core_decode);
        repeat (2) @(negedge clk);
        reset = 0;
        apply_instruction(32'h00000000, 1, 0, 0); // Invalid opcode.
        apply_instruction(32'h00100093, 0, 0, 1); // ADDI x1,x0,1.
        if (dut.regfile[1] !== 1) $fatal(1, "decode: setup ADDI failed");
        apply_instruction(32'h40101113, 1, 0, 0); // Illegal SLLI encoding (funct7=0100000).
        apply_instruction(32'h00102103, 1, 0, 0); // Misaligned LW x2,1(x0).
        apply_instruction(32'h00102123, 1, 0, 0); // Misaligned SW x1,2(x0).
        apply_instruction(32'h00001103, 1, 0, 0); // Unsupported LH x2,0(x0).
        apply_instruction(32'h000011e7, 1, 0, 0); // Unsupported JALR funct3=001.
        apply_instruction(32'h00002103, 0, 0, 1); // Aligned LW x2,0(x0).
        if (dut.regfile[2] !== 32'hcafebabe)
            $fatal(1, "decode: aligned LW failed");
        apply_instruction(32'h00102023, 0, 1, 0); // Aligned SW x1,0(x0).
        if (dmem_addr !== 0 || dmem_wdata !== 1)
            $fatal(1, "decode: aligned SW bus signals incorrect");
        apply_instruction(32'h07b00013, 0, 0, 1); // ADDI x0,x0,123; x0 must stay zero.
        if (dut.regfile[0] !== 0) $fatal(1, "decode: x0 changed");
        apply_instruction(32'hffffffff, 1, 0, 0); // Unsupported opcode.
        if (dut.regfile[1] !== 1 || dut.regfile[2] !== 32'hcafebabe)
            $fatal(1, "decode: illegal instruction modified register state");
        @(negedge clk);
        reset = 1;
        @(posedge clk);
        #1;
        if (instr_addr !== 0 || dut.regfile[1] !== 0 || dut.regfile[2] !== 0)
            $fatal(1, "decode: reset failed");
        $display("DECODE TEST PASSED: %0d steps; illegal encodings, alignment, x0, reset", steps);
        $finish;
    end
endmodule
