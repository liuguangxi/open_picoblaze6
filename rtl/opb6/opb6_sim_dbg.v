//==============================================================================
// opb6_sim_dbg.v
//
// Debug module for simulation.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


module opb6_sim_dbg (
    input clk,                      // system clock
    input [17:0] instruction,       // 18-bit instructions
    input [2:1] t_state,            // state encoding
    input internal_reset,           // internal reset
    input sync_sleep,               // synchronized sleep
    input interrupt_enable,         // interrupt enable
    input gpr_we,                   // GPR write enable
    input [4:0] gpr_addrx,          // GPR read/write address for sX
    input [7:0] gpr_dinx,           // GPR data input for sX
    input spm_we,                   // SPM write enable
    input [7:0] spm_addr,           // SPM read/write address
    input [7:0] spm_din,            // SPM data input
    input zero_flag,                // zero flag
    input carry_flag,                // carry flag
    input bank                      // register bank
);

// Local signals
wire [1:16] sx_decode;
wire [1:16] sy_decode;
wire [1:16] kk_decode;
wire [1:24] aaa_decode;
reg [7:0] bank_a_s [15:0];
reg [7:0] bank_b_s [15:0];
genvar i;

// Observation signals
reg [1:152] sim_opcode;
wire [1:128] sim_status;
wire [7:0] sim_gpr [15:0];
reg [7:0] sim_spm [255:0];


// Function to convert 4-bit binary nibble to hexadecimal character
function [1:8] hexchar(input [3:0] nibble);
    case (nibble)
        4'b0000: hexchar = "0";
        4'b0001: hexchar = "1";
        4'b0010: hexchar = "2";
        4'b0011: hexchar = "3";
        4'b0100: hexchar = "4";
        4'b0101: hexchar = "5";
        4'b0110: hexchar = "6";
        4'b0111: hexchar = "7";
        4'b1000: hexchar = "8";
        4'b1001: hexchar = "9";
        4'b1010: hexchar = "A";
        4'b1011: hexchar = "B";
        4'b1100: hexchar = "C";
        4'b1101: hexchar = "D";
        4'b1110: hexchar = "E";
        4'b1111: hexchar = "F";
    endcase
endfunction


// Decode first register sX
assign sx_decode[1:8] = "s";
assign sx_decode[9:16] = hexchar(instruction[11:8]);

// Decode second register sY
assign sy_decode[1:8] = "s";
assign sy_decode[9:16] = hexchar(instruction[7:4]);

// Decode constant value
assign kk_decode[1:8] = hexchar(instruction[7:4]);
assign kk_decode[9:16] = hexchar(instruction[3:0]);

// Decode address value
assign aaa_decode[1:8] = hexchar(instruction[11:8]);
assign aaa_decode[9:16] = hexchar(instruction[7:4]);
assign aaa_decode[17:24] = hexchar(instruction[3:0]);

// Decode instruction
always @(*) begin : opcode
    case (instruction[17:12])
        6'b000000: sim_opcode = {"LOAD ", sx_decode, ", ", sy_decode, "        "} ;
        6'b000001: sim_opcode = {"LOAD ", sx_decode, ", ", kk_decode, "        "} ;
        6'b010110: sim_opcode = {"STAR ", sx_decode, ", ", sy_decode, "        "} ;
        6'b010111: sim_opcode = {"STAR ", sx_decode, ", ", kk_decode, "        "} ;
        6'b000010: sim_opcode = {"AND ", sx_decode, ", ", sy_decode, "         "} ;
        6'b000011: sim_opcode = {"AND ", sx_decode, ", ", kk_decode, "         "} ;
        6'b000100: sim_opcode = {"OR ", sx_decode, ", ", sy_decode, "          "} ;
        6'b000101: sim_opcode = {"OR ", sx_decode, ", ", kk_decode, "          "} ;
        6'b000110: sim_opcode = {"XOR ", sx_decode, ", ", sy_decode, "         "} ;
        6'b000111: sim_opcode = {"XOR ", sx_decode, ", ", kk_decode, "         "} ;
        6'b001100: sim_opcode = {"TEST ", sx_decode, ", ", sy_decode, "        "} ;
        6'b001101: sim_opcode = {"TEST ", sx_decode, ", ", kk_decode, "        "} ;
        6'b001110: sim_opcode = {"TESTCY ", sx_decode, ", ", sy_decode, "      "} ;
        6'b001111: sim_opcode = {"TESTCY ", sx_decode, ", ", kk_decode, "      "} ;
        6'b010000: sim_opcode = {"ADD ", sx_decode, ", ", sy_decode, "         "} ;
        6'b010001: sim_opcode = {"ADD ", sx_decode, ", ", kk_decode, "         "} ;
        6'b010010: sim_opcode = {"ADDCY ", sx_decode, ", ", sy_decode, "       "} ;
        6'b010011: sim_opcode = {"ADDCY ", sx_decode, ", ", kk_decode, "       "} ;
        6'b011000: sim_opcode = {"SUB ", sx_decode, ", ", sy_decode, "         "} ;
        6'b011001: sim_opcode = {"SUB ", sx_decode, ", ", kk_decode, "         "} ;
        6'b011010: sim_opcode = {"SUBCY ", sx_decode, ", ", sy_decode, "       "} ;
        6'b011011: sim_opcode = {"SUBCY ", sx_decode, ", ", kk_decode, "       "} ;
        6'b011100: sim_opcode = {"COMPARE ", sx_decode, ", ", sy_decode, "     "} ;
        6'b011101: sim_opcode = {"COMPARE ", sx_decode, ", ", kk_decode, "     "} ;
        6'b011110: sim_opcode = {"COMPARECY ", sx_decode, ", ", sy_decode, "   "} ;
        6'b011111: sim_opcode = {"COMPARECY ", sx_decode, ", ", kk_decode, "   "} ;
        6'b010100: begin
            if (instruction[7])
                sim_opcode = {"HWBUILD ", sx_decode, "         "} ;
            else
                case (instruction[3:0])
                    4'b0110: sim_opcode = {"SL0 ", sx_decode, "             "} ;
                    4'b0111: sim_opcode = {"SL1 ", sx_decode, "             "} ;
                    4'b0100: sim_opcode = {"SLX ", sx_decode, "             "} ;
                    4'b0000: sim_opcode = {"SLA ", sx_decode, "             "} ;
                    4'b0010: sim_opcode = {"RL ", sx_decode, "              "} ;
                    4'b1110: sim_opcode = {"SR0 ", sx_decode, "             "} ;
                    4'b1111: sim_opcode = {"SR1 ", sx_decode, "             "} ;
                    4'b1010: sim_opcode = {"SRX ", sx_decode, "             "} ;
                    4'b1000: sim_opcode = {"SRA ", sx_decode, "             "} ;
                    4'b1100: sim_opcode = {"RR ", sx_decode, "              "} ;
                    default: sim_opcode = "Invalid Instruction";
                endcase
        end
        6'b101100: sim_opcode = {"OUTPUT ", sx_decode, ", (", sy_decode, ")    "} ;
        6'b101101: sim_opcode = {"OUTPUT ", sx_decode, ", ", kk_decode, "      "} ;
        6'b101011: sim_opcode = {"OUTPUTK ", aaa_decode[1:16], ", ", aaa_decode[17:24], "      " };
        6'b001000: sim_opcode = {"INPUT ", sx_decode, ", (", sy_decode, ")     "} ;
        6'b001001: sim_opcode = {"INPUT ", sx_decode, ", ", kk_decode, "       "} ;
        6'b101110: sim_opcode = {"STORE ", sx_decode, ", (", sy_decode, ")     "} ;
        6'b101111: sim_opcode = {"STORE ", sx_decode, ", ", kk_decode, "       "} ;
        6'b001010: sim_opcode = {"FETCH ", sx_decode, ", (", sy_decode, ")     "} ;
        6'b001011: sim_opcode = {"FETCH ", sx_decode, ", ", kk_decode, "       "} ;
        6'b100010: sim_opcode = {"JUMP ", aaa_decode, "           "} ;
        6'b110010: sim_opcode = {"JUMP Z, ", aaa_decode, "        "} ;
        6'b110110: sim_opcode = {"JUMP NZ, ", aaa_decode, "       "} ;
        6'b111010: sim_opcode = {"JUMP C, ", aaa_decode, "        "} ;
        6'b111110: sim_opcode = {"JUMP NC, ", aaa_decode, "       "} ;
        6'b100110: sim_opcode = {"JUMP@ (", sx_decode, ", ", sy_decode, ")     "} ;
        6'b100000: sim_opcode = {"CALL ", aaa_decode, "           "} ;
        6'b110000: sim_opcode = {"CALL Z, ", aaa_decode, "        "} ;
        6'b110100: sim_opcode = {"CALL NZ, ", aaa_decode, "       "} ;
        6'b111000: sim_opcode = {"CALL C, ", aaa_decode, "        "} ;
        6'b111100: sim_opcode = {"CALL NC, ", aaa_decode, "       "} ;
        6'b100100: sim_opcode = {"CALL@ (", sx_decode, ", ", sy_decode, ")     "} ;
        6'b100101: sim_opcode = {"RETURN             "} ;
        6'b110001: sim_opcode = {"RETURN Z           "} ;
        6'b110101: sim_opcode = {"RETURN NZ          "} ;
        6'b111001: sim_opcode = {"RETURN C           "} ;
        6'b111101: sim_opcode = {"RETURN NC          "} ;
        6'b100001: sim_opcode = {"LOAD&RETURN ", sx_decode, ", ", kk_decode, " "} ;
        6'b101001: sim_opcode = (instruction[0]) ? "RETURNI ENABLE     " : "RETURNI DISABLE    ";
        6'b101000: sim_opcode = (instruction[0]) ? "ENABLE INTERRUPT   " : "DISABLE INTERRUPT  ";
        6'b110111: sim_opcode = (instruction[0]) ? "REGBANK B          " : "REGBANK A          ";
        default : sim_opcode = "Invalid Instruction";
    endcase
end


// Flag status information
assign sim_status[1:16] = (bank == 1'b0) ? "A," : "B,";
assign sim_status[17:40] = (zero_flag == 1'b0) ? "NZ," : " Z,";
assign sim_status[41:64] = (carry_flag == 1'b0) ? "NC," : " C,";
assign sim_status[65:80] = (interrupt_enable == 1'b0) ? "ID" : "IE";
assign sim_status[81:128] = (internal_reset) ? ",Reset" : (sync_sleep == 1'b1 && t_state == 2'b00) ? ",Sleep" : "      ";


// Register contents
always @(posedge clk) begin
    if (gpr_we) begin
        if (gpr_addrx[4] == 1'b0)
            bank_a_s[gpr_addrx[3:0]] <= gpr_dinx;
        else
            bank_b_s[gpr_addrx[3:0]] <= gpr_dinx;
    end
end

generate
    for (i = 0; i <= 15; i = i+1) begin : sel_bank
        assign sim_gpr[i] = (bank == 1'b0) ? bank_a_s[i] : bank_b_s[i];
    end
endgenerate


// Scratch pad memory contents
always @(posedge clk) begin
    if (spm_we)
        sim_spm[spm_addr] <= spm_din;
end


endmodule
