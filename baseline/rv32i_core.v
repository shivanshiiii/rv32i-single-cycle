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
    reg [31:0] regfile [0:31];
    reg [31:0] next_pc;
    reg [31:0] write_data;
    reg        reg_write;

    wire [6:0] opcode = instr_data[6:0];
    wire [4:0] rd     = instr_data[11:7];
    wire [2:0] funct3 = instr_data[14:12];
    wire [4:0] rs1    = instr_data[19:15];
    wire [4:0] rs2    = instr_data[24:20];
    wire [6:0] funct7 = instr_data[31:25];
    wire [31:0] a = regfile[rs1];
    wire [31:0] b = regfile[rs2];
    wire [31:0] imm_i = {{20{instr_data[31]}}, instr_data[31:20]};
    wire [31:0] imm_s = {{20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]};
    wire [31:0] imm_b = {{19{instr_data[31]}}, instr_data[31], instr_data[7],
                         instr_data[30:25], instr_data[11:8], 1'b0};
    wire [31:0] imm_u = {instr_data[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr_data[31]}}, instr_data[31], instr_data[19:12],
                         instr_data[20], instr_data[30:21], 1'b0};
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
                    {7'b0000000,3'b000}: write_data = a + b;                     // ADD
                    {7'b0100000,3'b000}: write_data = a - b;                     // SUB
                    {7'b0000000,3'b111}: write_data = a & b;                     // AND
                    {7'b0000000,3'b110}: write_data = a | b;                     // OR
                    {7'b0000000,3'b100}: write_data = a ^ b;                     // XOR
                    {7'b0000000,3'b010}: write_data = ($signed(a) < $signed(b)); // SLT
                    {7'b0000000,3'b011}: write_data = (a < b);                   // SLTU
                    {7'b0000000,3'b001}: write_data = a << b[4:0];              // SLL
                    {7'b0000000,3'b101}: write_data = a >> b[4:0];              // SRL
                    {7'b0100000,3'b101}: write_data = $signed(a) >>> b[4:0];    // SRA
                    default: begin reg_write=1'b0; illegal_instr=1'b1; end
                endcase
            end
            7'b0010011: begin // Immediate arithmetic
                reg_write = 1'b1;
                case (funct3)
                    3'b000: write_data = a + imm_i;                       // ADDI
                    3'b111: write_data = a & imm_i;                       // ANDI
                    3'b110: write_data = a | imm_i;                       // ORI
                    3'b100: write_data = a ^ imm_i;                       // XORI
                    3'b010: write_data = ($signed(a) < $signed(imm_i));   // SLTI
                    3'b011: write_data = (a < imm_i);                     // SLTIU
                    3'b001: begin
                        if (funct7 == 7'b0000000) write_data = a << instr_data[24:20];
                        else begin reg_write=1'b0; illegal_instr=1'b1; end
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) write_data = a >> instr_data[24:20];
                        else if (funct7 == 7'b0100000)
                            write_data = $signed(a) >>> instr_data[24:20];
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

    integer r;
    always @(posedge clk) begin
        if (reset) begin
            pc <= 32'b0;
            for (r=0; r<32; r=r+1) regfile[r] <= 32'b0;
        end else begin
            pc <= next_pc;
            if (reg_write && rd!=5'd0) regfile[rd] <= write_data;
            regfile[0] <= 32'b0;
        end
    end
endmodule
