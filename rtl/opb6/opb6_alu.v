//==============================================================================
// opb6_alu.v
//
// Arithmetic and logical unit.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


module opb6_alu #(
    parameter [7:0] hwbuild = 8'h00         // 8-bit value in the range '00' to 'FF'
)
(
    input clk,                              // system clock
    input [17:0] instruction,               // 18-bit instructions
    input [2:0] arith_logical_sel,          // arithmetic/logical operation selection
    input [7:0] sx,                         // value of sX
    input [7:0] sy_or_kk,                   // value of sY or constant kk
    input arith_carry_in,                   // carry input for arithmetic operation
    input carry_flag,                       // carry flag for shift/rotate operations
    output carry_arith_logical_msb,         // MSB of arithmetic operation carry out
    output reg [7:0] arith_logical_result,  // arithmetic/logical operation result
    output reg [7:0] shift_rotate_result    // shift/rotate operation result
);

// Local signals
wire [7:0] arith_logical_add1;
wire [7:0] arith_logical_add2;
wire [7:0] arith_logical_value;
wire shift_in_bit;
wire [7:0] shift_rotate_value;
wire [7:0] shift_rotate_value_mux;


// Arithmetic and Logical operations
//
// Definition of....
//    ADD and SUB also used for ADDCY, SUBCY, COMPARE and COMPARECY.
//    LOAD, AND, OR and XOR also used for LOAD*, RETURN&LOAD, TEST and TESTCY.
//
// arith_logical_sel [2] [1] [0]
//                    0   0   0  - LOAD
//                    0   0   1  - AND
//                    0   1   0  - OR
//                    0   1   1  - XOR
//                    1   X   0  - SUB
//                    1   X   1  - ADD
//
// Includes pipeline stage.
assign arith_logical_add1 = (arith_logical_sel[2]) ? sx :
                            (arith_logical_sel[1]) ? ((arith_logical_sel[0]) ? (sx ^ sy_or_kk) : (sx | sy_or_kk)) :
                            (arith_logical_sel[0]) ? (sx & sy_or_kk) : sy_or_kk;

assign arith_logical_add2 = (arith_logical_sel[2]) ? ({8{arith_logical_sel[0]}} ~^ sy_or_kk) : 8'd0;

assign {carry_arith_logical_msb, arith_logical_value} = {1'b0, arith_logical_add1}
                                                      + {1'b0, arith_logical_add2} + arith_carry_in;

always @(posedge clk) begin
    arith_logical_result <= arith_logical_value;
end


// Shift and Rotate operations
//
// Definition of SL0, SL1, SLX, SLA, RL, SR0, SR1, SRX, SRA, and RR
//
// instruction [3] [2] [1] [0]
//              0   1   1   0  - SL0
//              0   1   1   1  - SL1
//              0   1   0   0  - SLX
//              0   0   0   0  - SLA
//              0   0   1   0  - RL
//              1   1   1   0  - SR0
//              1   1   1   1  - SR1
//              1   0   1   0  - SRX
//              1   0   0   0  - SRA
//              1   1   0   0  - RR
//
// instruction[3]
//             0 - Left
//             1 - Right
//
// instruction [2] [1]  Bit shifted in
//              0   0   Carry_flag
//              0   1   sX[7]
//              1   0   sX[0]
//              1   1   instruction[0]
//
// Includes pipeline stage.
assign shift_in_bit = (instruction[2:1] == 2'b00) ? carry_flag :
                      (instruction[2:1] == 2'b01) ? sx[7] :
                      (instruction[2:1] == 2'b10) ? sx[0] :
                      instruction[0];

assign shift_rotate_value = (instruction[3]) ? {shift_in_bit, sx[7:1]} : {sx[6:0], shift_in_bit};

assign shift_rotate_value_mux = (instruction[7]) ? hwbuild : shift_rotate_value;

always @(posedge clk) begin
    shift_rotate_result <= shift_rotate_value_mux;
end


endmodule
