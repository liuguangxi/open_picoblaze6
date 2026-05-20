//==============================================================================
// opb6.v
//
// Open PicoBlaze6 top module.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


module opb6 #(
    parameter [7:0] hwbuild = 8'h00,                // 8-bit value in the range '00' to 'FF'
    parameter [11:0] interrupt_vector = 12'h3FF,    // jump address when an interrupt occurs
    parameter integer scratch_pad_memory_size = 64  // size of the scratch pad memory, could be 64/128/256
)
(
    input clk,                      // system clock
`ifdef HAS_ASYNC_RST
    input rst_n,                    // system asynchronous reset, active low
`endif
    input reset,                    // system synchronous reset
    input sleep,                    // sleep control
    input interrupt,                // interrupt control
    output interrupt_ack,           // indicate starting to service an interrupt
    output [11:0] address,          // 12-bit program address to access programs
    output bram_enable,             // read enable for the program memory
    input [17:0] instruction,       // 18-bit instructions
    output [7:0] port_id,           // port address for read/write data
    output write_strobe,            // indicate writing to 'out_port' for 'OUTPUT' instruction
    output k_write_strobe,          // indicate writing to 'out_port' for 'OUTPUTK' instruction
    output read_strobe,             // indicate reading from 'in_port' for 'INPUT' instruction
    output [7:0] out_port,          // output data for write
    input [7:0] in_port             // input data for read
);

// Local signals
wire [2:1] t_state;
wire run;
wire internal_reset;
wire sync_sleep;
wire interrupt_enable;
wire active_interrupt;
wire special_bit;
wire stack_pointer_carry_msb;
wire zero_flag;
wire carry_flag;
wire bank;
wire gpr_we;
wire [4:0] gpr_addrx;
wire [4:0] gpr_addry;
wire [7:0] gpr_dinx;
wire [7:0] gpr_doutx;
wire [7:0] gpr_douty;
wire spm_we;
wire [7:0] spm_addr;
wire [7:0] spm_din;
wire [7:0] spm_dout;
wire stkm_we;
wire [4:0] stkm_addr;
wire [15:0] stkm_din;
wire [15:0] stkm_dout;


// State Machine and Control
opb6_main_ctrl main_ctrl (
    .clk                        (clk),
`ifdef HAS_ASYNC_RST
    .rst_n                      (rst_n),
`endif
    .reset                      (reset),
    .sleep                      (sleep),
    .interrupt                  (interrupt),
    .instruction                (instruction),
    .special_bit                (special_bit),
    .stack_pointer_carry_msb    (stack_pointer_carry_msb),
    .t_state                    (t_state),
    .run                        (run),
    .internal_reset             (internal_reset),
    .sync_sleep                 (sync_sleep),
    .interrupt_enable           (interrupt_enable),
    .active_interrupt           (active_interrupt),
    .interrupt_ack              (interrupt_ack)
);


// Processor core
opb6_core #(
    .hwbuild                    (hwbuild),
    .interrupt_vector           (interrupt_vector)
) core (
    .clk                        (clk),
`ifdef HAS_ASYNC_RST
    .rst_n                      (rst_n),
`endif
    .address                    (address),
    .bram_enable                (bram_enable),
    .instruction                (instruction),
    .port_id                    (port_id),
    .write_strobe               (write_strobe),
    .k_write_strobe             (k_write_strobe),
    .read_strobe                (read_strobe),
    .out_port                   (out_port),
    .in_port                    (in_port),
    .t_state                    (t_state),
    .run                        (run),
    .internal_reset             (internal_reset),
    .active_interrupt           (active_interrupt),
    .special_bit                (special_bit),
    .stack_pointer_carry_msb    (stack_pointer_carry_msb),
    .zero_flag                  (zero_flag),
    .carry_flag                 (carry_flag),
    .bank                       (bank),
    .gpr_we                     (gpr_we),
    .gpr_addrx                  (gpr_addrx),
    .gpr_addry                  (gpr_addry),
    .gpr_dinx                   (gpr_dinx),
    .gpr_doutx                  (gpr_doutx),
    .gpr_douty                  (gpr_douty),
    .spm_we                     (spm_we),
    .spm_addr                   (spm_addr),
    .spm_din                    (spm_din),
    .spm_dout                   (spm_dout),
    .stkm_we                    (stkm_we),
    .stkm_addr                  (stkm_addr),
    .stkm_din                   (stkm_din),
    .stkm_dout                  (stkm_dout)
);


// Two Banks of 16 General Purpose Registers
opb6_gpr #(
    .DP         (32),
    .DW         (8)
) gpr (
    .clk        (clk),
    .we         (gpr_we),
    .addrx      (gpr_addrx),
    .addry      (gpr_addry),
    .dinx       (gpr_dinx),
    .doutx      (gpr_doutx),
    .douty      (gpr_douty)
);


`ifdef SIM
// Perform check of parameter to report error as soon as possible
initial begin
    if (scratch_pad_memory_size != 64 && scratch_pad_memory_size != 128 && scratch_pad_memory_size != 256) begin
        $display("\n\nInvalid 'scratch_pad_memory_size'. Please set to 64, 128 or 256.\n\n");
        $finish;
    end
end
`endif


// Scratchpad Memory with output register
generate
    if (scratch_pad_memory_size == 64) begin : small_spm
        opb6_sp_ram #(
            .DP         (64),
            .DW         (8)
        ) spm (
            .clk        (clk),
            .we         (spm_we),
            .addr       (spm_addr[5:0]),
            .din        (spm_din),
            .dout       (spm_dout)
        );
    end
    if (scratch_pad_memory_size == 128) begin : medium_spm
        opb6_sp_ram #(
            .DP         (128),
            .DW         (8)
        ) spm (
            .clk        (clk),
            .we         (spm_we),
            .addr       (spm_addr[6:0]),
            .din        (spm_din),
            .dout       (spm_dout)
        );
    end
    if (scratch_pad_memory_size == 256) begin : large_spm
        opb6_sp_ram #(
            .DP         (256),
            .DW         (8)
        ) spm (
            .clk        (clk),
            .we         (spm_we),
            .addr       (spm_addr),
            .din        (spm_din),
            .dout       (spm_dout)
        );
    end
endgenerate


// Stack RAM
opb6_sp_ram #(
    .DP         (32),
    .DW         (16)
) stkm (
    .clk        (clk),
    .we         (stkm_we),
    .addr       (stkm_addr),
    .din        (stkm_din),
    .dout       (stkm_dout)
);


`ifdef HAS_SIM_DBG
// Debug module for simulation
opb6_sim_dbg sim_dbg (
    .clk                        (clk),
    .instruction                (instruction),
    .t_state                    (t_state),
    .internal_reset             (internal_reset),
    .sync_sleep                 (sync_sleep),
    .interrupt_enable           (interrupt_enable),
    .gpr_we                     (gpr_we),
    .gpr_addrx                  (gpr_addrx),
    .gpr_dinx                   (gpr_dinx),
    .spm_we                     (spm_we),
    .spm_addr                   (spm_addr),
    .spm_din                    (spm_din),
    .zero_flag                  (zero_flag),
    .carry_flag                 (carry_flag),
    .bank                       (bank)
);
`endif


endmodule
