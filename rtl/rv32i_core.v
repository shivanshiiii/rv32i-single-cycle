`timescale 1ns/1ps
// RV32I single-cycle educational core. Word-aligned LW/SW only.
// External instruction and data memories are asynchronous-read for this design.
module rv32i_core (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] instr_addr,
    input  wire [31:0] instr_data,
    output reg  [31:0] dmem_addr,
    output reg  [31:0] dmem_wdata,
    output reg         dmem_we,
    input  wire [31:0] dmem_rdata,
    output reg         illegal_instr
);
    reg [31:0] pc;
    wire [31:0] regfile [0:31];
    wire [1023:0] regfile_flat;
    reg [31:0] next_pc;
    reg [31:0] write_data;
    reg        reg_write;

    wire [6:0] opcode = instr_data[6:0];
    wire [4:0] rd     = instr_data[11:7];
    wire [2:0] funct3 = instr_data[14:12];
    wire [4:0] rs1    = instr_data[19:15];
    wire [4:0] rs2    = instr_data[24:20];
    wire [6:0] funct7 = instr_data[31:25];
    wire [31:0] a = regfile_flat[rs1 * 32 +: 32];
    wire [31:0] b = regfile_flat[rs2 * 32 +: 32];
    wire [31:0] imm_i = {{20{instr_data[31]}}, instr_data[31:20]};
    wire [31:0] imm_s = {{20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]};
    wire [31:0] imm_b = {{19{instr_data[31]}}, instr_data[31], instr_data[7],
                         instr_data[30:25], instr_data[11:8], 1'b0};
    wire [31:0] imm_u = {instr_data[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr_data[31]}}, instr_data[31], instr_data[19:12],
                         instr_data[20], instr_data[30:21], 1'b0};
    // Register and immediate ALU instructions share the same execution units.
    wire [31:0] alu_b = (opcode == 7'b0010011) ? imm_i : b;
    wire [31:0] alu_add = a + alu_b;
    wire [31:0] alu_and = a & alu_b;
    wire [31:0] alu_or = a | alu_b;
    wire [31:0] alu_xor = a ^ alu_b;
    wire [31:0] alu_slt = {31'b0, ($signed(a) < $signed(alu_b))};
    wire [31:0] alu_sltu = {31'b0, (a < alu_b)};
    wire [31:0] alu_sll = a << alu_b[4:0];
    // A 33-bit signed input shares logical/arithmetic right-shift hardware.
    // Bit 30 chooses zero-fill or sign-fill; the decoder still validates funct7.
    wire signed [32:0] right_input = {instr_data[30] & a[31], a};
    wire [32:0] right_shifted = right_input >>> alu_b[4:0];
    wire [31:0] alu_right = right_shifted[31:0];
    assign instr_addr = pc;

    always @* begin
        next_pc       = pc + 32'd4;
        write_data    = 32'b0;
        reg_write     = 1'b0;
        dmem_addr     = 32'b0;
        dmem_wdata    = 32'b0;
        dmem_we       = 1'b0;
        illegal_instr = 1'b0;
        case (opcode)
            7'b0110011: begin // Register arithmetic
                reg_write = 1'b1;
                case ({funct7,funct3})
                    {7'b0000000,3'b000}: write_data = alu_add;                     // ADD
                    {7'b0100000,3'b000}: write_data = a - b;                     // SUB
                    {7'b0000000,3'b111}: write_data = alu_and;                     // AND
                    {7'b0000000,3'b110}: write_data = alu_or;                     // OR
                    {7'b0000000,3'b100}: write_data = alu_xor;                     // XOR
                    {7'b0000000,3'b010}: write_data = alu_slt; // SLT
                    {7'b0000000,3'b011}: write_data = alu_sltu;                   // SLTU
                    {7'b0000000,3'b001}: write_data = alu_sll;              // SLL
                    {7'b0000000,3'b101}: write_data = alu_right;              // SRL
                    {7'b0100000,3'b101}: write_data = alu_right;    // SRA
                    default: begin reg_write=1'b0; illegal_instr=1'b1; end
                endcase
            end
            7'b0010011: begin // Immediate arithmetic
                reg_write = 1'b1;
                case (funct3)
                    3'b000: write_data = alu_add;                       // ADDI
                    3'b111: write_data = alu_and;                       // ANDI
                    3'b110: write_data = alu_or;                       // ORI
                    3'b100: write_data = alu_xor;                       // XORI
                    3'b010: write_data = alu_slt;   // SLTI
                    3'b011: write_data = alu_sltu;                     // SLTIU
                    3'b001: begin
                        if (funct7 == 7'b0000000) write_data = alu_sll;
                        else begin reg_write=1'b0; illegal_instr=1'b1; end
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) write_data = alu_right;
                        else if (funct7 == 7'b0100000)
                            write_data = alu_right;
                        else begin reg_write=1'b0; illegal_instr=1'b1; end
                    end
                    default: begin reg_write=1'b0; illegal_instr=1'b1; end
                endcase
            end
            7'b0000011: begin // LW (word-aligned only)
                if (funct3 == 3'b010) begin
                    dmem_addr = a + imm_i;
                    write_data = dmem_rdata;
                    reg_write = 1'b1;
                end else illegal_instr=1'b1;
            end
            7'b0100011: begin // SW (word-aligned only)
                if (funct3 == 3'b010) begin
                    dmem_addr = a + imm_s;
                    dmem_wdata = b;
                    dmem_we = 1'b1;
                end else illegal_instr=1'b1;
            end
            7'b1100011: begin // Conditional branches
                case (funct3)
                    3'b000: if (a == b) next_pc = pc + imm_b;               // BEQ
                    3'b001: if (a != b) next_pc = pc + imm_b;               // BNE
                    3'b100: if ($signed(a) < $signed(b)) next_pc = pc + imm_b;  // BLT
                    3'b101: if ($signed(a) >= $signed(b)) next_pc = pc + imm_b; // BGE
                    default: illegal_instr=1'b1;
                endcase
            end
            7'b0110111: begin reg_write=1'b1; write_data=imm_u; end         // LUI
            7'b0010111: begin reg_write=1'b1; write_data=pc+imm_u; end      // AUIPC
            7'b1101111: begin                                              // JAL
                reg_write=1'b1; write_data=pc+32'd4; next_pc=pc+imm_j;
            end
            7'b1100111: begin                                              // JALR
                if (funct3==3'b000) begin
                    reg_write=1'b1; write_data=pc+32'd4;
                    next_pc=(a+imm_i) & 32'hfffffffe;
                end else illegal_instr=1'b1;
            end
            default: illegal_instr=1'b1;
        endcase
        // This initial implementation deliberately supports only word-aligned accesses.
        if ((opcode == 7'b0000011 || opcode == 7'b0100011) &&
            dmem_addr[1:0] != 2'b00) begin
            illegal_instr=1'b1;
            dmem_we=1'b0;
            reg_write=1'b0;
        end
    end

    // x0 has no storage. Packed read selection produces balanced mux trees.
    // The regfile view keeps waveform/testbench names stable.
    assign regfile[0] = 32'b0;
    assign regfile_flat[31:0] = 32'b0;
    genvar r;
    generate
        for (r=1; r<32; r=r+1) begin : g_regfile
            reg [31:0] value;
            assign regfile[r] = value;
            assign regfile_flat[r * 32 +: 32] = value;
            always @(posedge clk) begin
                if (reset) value <= 32'b0;
                else if (reg_write && rd == r) value <= write_data;
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (reset) pc <= 32'b0;
        else pc <= next_pc;
    end
endmodule
