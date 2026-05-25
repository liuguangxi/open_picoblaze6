//==============================================================================
// opb6_core.v
//
// Core module.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


module opb6_core #(
    parameter [7:0] hwbuild = 8'h00,                // 8-bit value in the range '00' to 'FF'
    parameter [11:0] interrupt_vector = 12'h3FF     // jump address when an interrupt occurs
)
(
    input clk,                          // system clock
`ifdef HAS_ASYNC_RST
    input rst_n,                        // system asynchronous reset, active low
`endif
    output [11:0] address,              // 12-bit program address to access programs
    output bram_enable,                 // read enable for the program memory
    input [17:0] instruction,           // 18-bit instructions
    output [7:0] port_id,               // port address for read/write data
    output reg write_strobe,            // indicate writing to 'out_port' for 'OUTPUT' instruction
    output reg k_write_strobe,          // indicate writing to 'out_port' for 'OUTPUTK' instruction
    output reg read_strobe,             // indicate reading from 'in_port' for 'INPUT' instruction
    output [7:0] out_port,              // output data for write
    input [7:0] in_port,                // input data for read
    input [2:1] t_state,                // state encoding
    input run,                          // run state
    input internal_reset,               // internal reset
    input active_interrupt,             // acive interrupt
    output special_bit,                 // special bit
    output stack_pointer_carry_msb,     // MSB of stack_pointer carry out
    output reg zero_flag,               // zero flag
    output reg carry_flag,              // carry flag
    output reg bank,                    // register bank
    output gpr_we,                      // GPR write enable
    output [4:0] gpr_addrx,             // GPR read/write address for sX
    output [4:0] gpr_addry,             // GPR read address for sY
    output [7:0] gpr_dinx,              // GPR data input for sX
    input [7:0] gpr_doutx,              // GPR data output for sX
    input [7:0] gpr_douty,              // GPR data output for sY
    output spm_we,                      // SPM write enable
    output [7:0] spm_addr,              // SPM read/write address
    output [7:0] spm_din,               // SPM data input
    input [7:0] spm_dout,               // SPM data output
    output stkm_we,                     // stack RAM write enable
    output [4:0] stkm_addr,             // stack RAM read/write address
    output [15:0] stkm_din,             // stack RAM data input
    input [15:0] stkm_dout              // stack RAM data output
);

// Local signals
wire [2:0] arith_logical_sel;
wire arith_carry_in;
wire arith_carry_value;
reg arith_carry;
wire carry_arith_logical_msb;
wire [7:0] arith_logical_result;
wire [7:0] shift_rotate_result;
wire [7:0] alu_result;
wire [1:0] alu_mux_sel_value;
reg [1:0] alu_mux_sel;
wire strobe_type;
wire write_strobe_value;
wire k_write_strobe_value;
wire read_strobe_value;
wire flag_enable_type;
wire flag_enable_value;
reg flag_enable;
wire parity;
wire shift_carry_value;
reg shift_carry;
wire carry_flag_value;
wire use_zero_flag_value;
reg use_zero_flag;
wire carry_middle_zero;
wire upper_zero_sel;
wire zero_flag_value;
wire spm_enable_value;
reg spm_enable;
wire [7:0] spm_data;
wire regbank_type;
wire bank_value;
wire loadstar_type;
wire sx_addr4_value;
reg sx_addr4;
wire register_enable_type;
wire register_enable_value;
reg register_enable;
wire [4:0] sx_addr;
wire [4:0] sy_addr;
wire [7:0] sx;
wire [7:0] sy;
wire [7:0] sy_or_kk;
wire pc_move_is_valid;
wire move_type;
wire returni_type;
wire [2:0] pc_mode;
wire [11:0] register_vector;
wire [11:0] half_pc;
wire [11:0] pc_value;
reg [11:0] pc;
wire [11:0] pc_vector;
wire push_stack;
wire pop_stack;
wire [11:0] return_vector;
wire shadow_carry_flag;
wire shadow_zero_value;
reg shadow_zero_flag;
wire shadow_bank;
wire [4:0] stack_pointer_add;
wire [4:0] stack_pointer_value;
reg [4:0] stack_pointer;


//------------------------------------------------------------------------------
// Decoders
//------------------------------------------------------------------------------
// Decoding for Program Counter and Stack
assign pc_move_is_valid = (~instruction[17]) ? 1'b0 :
                          (~instruction[16]) ? 1'b1 :
                          (~instruction[15]) ? (instruction[14] ^ zero_flag) :
                          (instruction[14] ^ carry_flag);

assign move_type = (instruction[16]) ? (~(&instruction[13:12])) :
                   ((instruction[15:12] == 4'b1001) | ((~instruction[15]) & (~(&instruction[13:12]))));

assign returni_type = (instruction[16:12] == 5'b01001);

assign pc_mode[0] = (~active_interrupt) & ((~pc_move_is_valid) | ((~returni_type) & ((~move_type) | instruction[12])));
assign pc_mode[1] = (~active_interrupt) & pc_move_is_valid & move_type;
assign pc_mode[2] = active_interrupt | ({instruction[17:14], instruction[12]} == 5'b10010);

assign push_stack = active_interrupt | (pc_move_is_valid & move_type & (~instruction[13]) & (~instruction[12]));
assign pop_stack = (~active_interrupt) & pc_move_is_valid & move_type & (~instruction[13]) & instruction[12];


// Decoding for ALU
assign alu_mux_sel_value[0] = (instruction[16:13] == 4'b0101 || instruction[16:13] == 4'b1010);
assign alu_mux_sel_value[1] = (instruction[16:14] == 3'b010);

assign arith_carry_in = (~instruction[16]) ? 1'b0 :
                        (~instruction[15]) ? ((~instruction[14]) & instruction[13] & carry_flag) :
                        ((~instruction[13]) | (~carry_flag));

assign arith_logical_sel[0] = (instruction[16:14] == 3'b100 || instruction[16:14] == 3'b011
                            || instruction[16:13] == 4'b0001 || instruction[16:13] == 4'b0011);
assign arith_logical_sel[1] = (instruction[16:14] == 3'b001);
assign arith_logical_sel[2] = instruction[16] & (instruction[15] | (~instruction[14]));

`ifdef HAS_ASYNC_RST
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        alu_mux_sel <= 1'b0;
    else
        alu_mux_sel <= alu_mux_sel_value;
end
`else
always @(posedge clk) begin
    alu_mux_sel <= alu_mux_sel_value;
end
`endif


// Decoding for strobes and enables
assign flag_enable_type = (instruction[17]) ? (instruction[16:13] == 4'b0100) :
                          (instruction[16]) ? (instruction[15] | (~instruction[14]) | (~instruction[13])) :
                          (instruction[15]) ? instruction[14] :
                          (instruction[14] | instruction[13]);
assign flag_enable_value = t_state[1] & flag_enable_type
                         & ((instruction[17] & instruction[12]) | (~instruction[17]));

assign register_enable_type = (instruction[17]) ? (~(|instruction[16:13])) :
                              ((~instruction[15]) | (~instruction[14]));
assign register_enable_value = t_state[1] & register_enable_type
                             & ((instruction[17] & instruction[12]) | (~instruction[17]));

assign strobe_type = (~instruction[16]) & instruction[15];
assign spm_enable_value = t_state[1] & strobe_type & instruction[17] & instruction[14] & instruction[13];
assign write_strobe_value = t_state[1] & strobe_type & instruction[17] & instruction[14] & (~instruction[13]);
assign k_write_strobe_value = t_state[1] & strobe_type & instruction[17] & (~instruction[14]) & instruction[13];
assign read_strobe_value = t_state[1] & strobe_type & (~instruction[17]) & (~instruction[14]) & (~instruction[13]);

`ifdef HAS_ASYNC_RST
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        flag_enable <= 1'b0;
        register_enable <= 1'b0;
        spm_enable <= 1'b0;
    end
    else if (active_interrupt) begin
        flag_enable <= 1'b0;
        register_enable <= 1'b0;
        spm_enable <= 1'b0;
    end
    else begin
        flag_enable <= flag_enable_value;
        register_enable <= register_enable_value;
        spm_enable <= spm_enable_value;
    end
end
`else
always @(posedge clk) begin
    if (active_interrupt) begin
        flag_enable <= 1'b0;
        register_enable <= 1'b0;
        spm_enable <= 1'b0;
    end
    else begin
        flag_enable <= flag_enable_value;
        register_enable <= register_enable_value;
        spm_enable <= spm_enable_value;
    end
end
`endif


//------------------------------------------------------------------------------
// Flags
//------------------------------------------------------------------------------
assign arith_carry_value = carry_arith_logical_msb;
assign parity = (instruction[13] & carry_flag) ^ (^arith_logical_result);

assign shift_carry_value = (instruction[16]) ? (
                             (instruction[7]) ? 1'b1 : (instruction[3]) ? sx[0] : sx[7]
                           ) :
                           shadow_carry_flag;

assign carry_flag_value = (instruction[16:14] == 3'b010 || instruction[16:14] == 3'b101) ? shift_carry :
                          (instruction[16:14] == 3'b011) ? parity :
                          (instruction[16:14] == 3'b100) ? arith_carry :
                          (instruction[16:15] == 2'b00) ? 1'b0 :
                          (~arith_carry);

assign use_zero_flag_value = (instruction[16:14] == 3'b011 || instruction[16:14] == 3'b100
                               || instruction[16:14] == 3'b110 || instruction[16:14] == 3'b111)
                           & instruction[13];

assign carry_middle_zero = (~(|alu_result)) & (zero_flag | (~use_zero_flag));
assign upper_zero_sel = instruction[16] | (~instruction[15]) | instruction[14];
assign zero_flag_value = (upper_zero_sel) ? carry_middle_zero : shadow_zero_flag;

`ifdef HAS_ASYNC_RST
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        arith_carry <= 1'b0;
        shift_carry <= 1'b0;
        use_zero_flag <= 1'b0;
        shadow_zero_flag <= 1'b0;
    end
    else begin
        arith_carry <= arith_carry_value;
        shift_carry <= shift_carry_value;
        use_zero_flag <= use_zero_flag_value;
        shadow_zero_flag <= shadow_zero_value;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        carry_flag <= 1'b0;
        zero_flag <= 1'b0;
    end
    else if (internal_reset) begin
        carry_flag <= 1'b0;
        zero_flag <= 1'b0;
    end
    else if (flag_enable) begin
        carry_flag <= carry_flag_value;
        zero_flag <= zero_flag_value;
    end
end
`else
always @(posedge clk) begin
    arith_carry <= arith_carry_value;
    shift_carry <= shift_carry_value;
    use_zero_flag <= use_zero_flag_value;
    shadow_zero_flag <= shadow_zero_value;
end

always @(posedge clk) begin
    if (internal_reset) begin
        carry_flag <= 1'b0;
        zero_flag <= 1'b0;
    end
    else if (flag_enable) begin
        carry_flag <= carry_flag_value;
        zero_flag <= zero_flag_value;
    end
end
`endif


//------------------------------------------------------------------------------
// Two Banks of 16 General Purpose Registers controller
//------------------------------------------------------------------------------
// sx_addr - Address for sX is formed by bank select and instruction[11:8]
// sy_addr - Address for sY is formed by bank select and instruction[7:4]
assign regbank_type = (instruction[17:12] == 6'b101001 || instruction[17:12] == 6'b110111);
assign bank_value = (t_state[1] & regbank_type) ? ((instruction[16]) ? instruction[0] : shadow_bank) :
                    bank;

assign loadstar_type = (instruction[17:13] == 5'b01011);

assign sx_addr4_value = (loadstar_type) ? (bank ~^ t_state[2]) : bank;
assign sx_addr = {sx_addr4, instruction[11:8]};
assign sy_addr = {bank, instruction[7:4]};

`ifdef HAS_ASYNC_RST
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        bank <= 1'b0;
    else if (internal_reset)
        bank <= 1'b0;
    else
        bank <= bank_value;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        sx_addr4 <= 1'b0;
    else
        sx_addr4 <= sx_addr4_value;
end
`else
always @(posedge clk) begin
    if (internal_reset)
        bank <= 1'b0;
    else
        bank <= bank_value;
end

always @(posedge clk) begin
    sx_addr4 <= sx_addr4_value;
end
`endif

assign gpr_we = register_enable;
assign gpr_addrx = sx_addr;
assign gpr_addry = sy_addr;
assign gpr_dinx = alu_result;
assign sx = gpr_doutx;
assign sy = gpr_douty;


//------------------------------------------------------------------------------
// 12-bit Program Address Generation
//------------------------------------------------------------------------------
// Prepare 12-bit vector from the sX and sY register outputs
assign register_vector = {sx[3:0], sy};


// Selection of vector to load program counter
//
// instruction[12]
//              0  Constant aaa from instruction(11:0)
//              1  Return vector from stack
//
// 'aaa' is used during 'JUMP aaa', 'JUMP c, aaa', 'CALL aaa' and 'CALL c, aaa'.
// Return vector is used during 'RETURN', 'RETURN c', 'RETURN&LOAD' and 'RETURNI'.
assign pc_vector = (instruction[12]) ? return_vector : instruction[11:0];


// Program Counter
//
// Reset by internal_reset has highest priority.
// Enabled by t_state[1] has second priority.
//
// The function performed is defined by pc_mode(2:0).
//
// pc_mode [2] [1] [0]
//          0   0   1  pc+1 for normal program flow.
//          1   0   0  Forces interrupt vector value (+0) during active interrupt.
//                     The vector is defined by a generic with default value FF0 hex.
//          1   1   0  register_vector (+0) for 'JUMP (sX, sY)' and 'CALL (sX, sY)'.
//          0   1   0  pc_vector (+0) for 'JUMP/CALL aaa' and 'RETURNI'.
//          0   1   1  pc_vector+1 for 'RETURN'.
//
// Note that pc_mode[0] is High during operations that require an increment to occur.
// pc_mode[0] also has to be connected to the start of the carry chain.
assign half_pc = (pc_mode[2]) ? (
                    (pc_mode[1:0] == 2'b10) ? register_vector :
                    (pc_mode[1:0] == 2'b00) ? interrupt_vector : 12'd1
                  ) :
                  (pc_mode[1]) ? pc_vector :
                  (pc_mode[0]) ? pc : 12'd0;

assign pc_value = half_pc + pc_mode[0];

`ifdef HAS_ASYNC_RST
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pc <= 12'h0;
    else if (internal_reset)
        pc <= 12'h0;
    else if (t_state[1])
        pc <= pc_value;
end
`else
always @(posedge clk) begin
    if (internal_reset)
        pc <= 12'h0;
    else if (t_state[1])
        pc <= pc_value;
end
`endif


//------------------------------------------------------------------------------
// Stack
//
// Preserves upto 31 nested values of the Program Counter during CALL and RETURN.
// Also preserves flags and bank selection during interrupt.
//------------------------------------------------------------------------------
assign stkm_we = t_state[1];
assign stkm_addr = stack_pointer;
assign stkm_din = {pc, run, bank, zero_flag, carry_flag};
assign {return_vector, special_bit, shadow_bank, shadow_zero_value, shadow_carry_flag} = stkm_dout;


// t_state can't be 2'b11, {push_stack, popstack} can't be 2'b11
assign stack_pointer_add = {{4{t_state[1] & (~push_stack)}},
                           (t_state[2] | (t_state[1] & (~push_stack) & (~pop_stack)))};

assign {stack_pointer_carry_msb, stack_pointer_value} = {1'b0, stack_pointer}
                                                      + {1'b0, stack_pointer_add};

`ifdef HAS_ASYNC_RST
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        stack_pointer <= 5'h0;
    else if (internal_reset)
        stack_pointer <= 5'h0;
    else
        stack_pointer <= stack_pointer_value;
end
`else
always @(posedge clk) begin
    if (internal_reset)
        stack_pointer <= 5'h0;
    else
        stack_pointer <= stack_pointer_value;
end
`endif


//------------------------------------------------------------------------------
// 8-bit Data Path
//------------------------------------------------------------------------------
// Selection of second operand to ALU and port_id
//
// instruction[12]
//           0  Register sY
//           1  Constant kk
assign sy_or_kk = (instruction[12]) ? instruction[7:0] : sy;


// Arithmetic and logical unit
opb6_alu #(
    .hwbuild                    (hwbuild)
) alu (
    .clk                        (clk),
    .instruction                (instruction),
    .arith_logical_sel          (arith_logical_sel),
    .sx                         (sx),
    .sy_or_kk                   (sy_or_kk),
    .arith_carry_in             (arith_carry_in),
    .carry_flag                 (carry_flag),
    .carry_arith_logical_msb    (carry_arith_logical_msb),
    .arith_logical_result       (arith_logical_result),
    .shift_rotate_result        (shift_rotate_result)
);


// Multiplex outputs from ALU functions, scratch pad memory and input port.
//
// alu_mux_sel [1] [0]
//              0   0  Arithmetic and Logical Instructions
//              0   1  Shift and Rotate Instructions
//              1   0  Input Port
//              1   1  Scratch Pad Memory
assign alu_result = (alu_mux_sel == 2'b00) ? arith_logical_result :
                    (alu_mux_sel == 2'b01) ? shift_rotate_result :
                    (alu_mux_sel == 2'b10) ? in_port :
                    spm_data;


//------------------------------------------------------------------------------
// Scratchpad Memory controller
//------------------------------------------------------------------------------
assign spm_we = spm_enable;
assign spm_addr = sy_or_kk;
assign spm_din = sx;
assign spm_data = spm_dout;


//------------------------------------------------------------------------------
// Connections to top module outputs
//------------------------------------------------------------------------------
assign address = pc;
assign bram_enable = t_state[2];

assign port_id = sy_or_kk;
assign out_port = (instruction[13]) ? instruction[11:4] : sx;

`ifdef HAS_ASYNC_RST
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_strobe <= 1'b0;
        k_write_strobe <= 1'b0;
        read_strobe <= 1'b0;
    end
    else if (active_interrupt) begin
        write_strobe <= 1'b0;
        k_write_strobe <= 1'b0;
        read_strobe <= 1'b0;
    end
    else begin
        write_strobe <= write_strobe_value;
        k_write_strobe <= k_write_strobe_value;
        read_strobe <= read_strobe_value;
    end
end
`else
always @(posedge clk) begin
    if (active_interrupt) begin
        write_strobe <= 1'b0;
        k_write_strobe <= 1'b0;
        read_strobe <= 1'b0;
    end
    else begin
        write_strobe <= write_strobe_value;
        k_write_strobe <= k_write_strobe_value;
        read_strobe <= read_strobe_value;
    end
end
`endif


endmodule
