`timescale 1ns/1ps
// Educational test system. Asynchronous reads make single-cycle LW possible.
module rv32i_soc #(parameter IMEM_HEX = "programs/demo.hex") (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instr,
    output wire        debug_illegal
);
    reg [31:0] imem [0:255];
    reg [31:0] dmem [0:255];
    wire [31:0] instr_addr;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire        dmem_we;
    wire [31:0] dmem_rdata;
    wire [31:0] instr_data;

    assign instr_data = imem[instr_addr[9:2]];
    assign dmem_rdata = dmem[dmem_addr[9:2]];
    assign debug_pc = instr_addr;
    assign debug_instr = instr_data;

    rv32i_core cpu (
        .clk(clk), .reset(reset), .instr_addr(instr_addr),
        .instr_data(instr_data), .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata), .dmem_we(dmem_we),
        .dmem_rdata(dmem_rdata), .illegal_instr(debug_illegal)
    );

    integer i;
    initial begin
        for (i=0; i<256; i=i+1) begin
            imem[i] = 32'h00000013; // NOP = ADDI x0,x0,0
            dmem[i] = 32'b0;
        end
        $readmemh(IMEM_HEX, imem);
    end

    always @(posedge clk) begin
        if (!reset && dmem_we) dmem[dmem_addr[9:2]] <= dmem_wdata;
    end
endmodule
