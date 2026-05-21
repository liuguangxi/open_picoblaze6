//==============================================================================
// kcpsm6_sys.v
//
// A simple system based on KCPSM6.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


`ifndef SPM_SIZE
`define SPM_SIZE 64
`endif


module kcpsm6_sys (
    input clk,                  // system clock
    input reset,                // system synchronous reset
    input sleep,                // sleep control
    input test_in               // test input
);

// Local signals
wire interrupt;
wire interrupt_ack;
wire [11:0] address;
wire bram_enable;
wire [17:0] instruction;
wire [7:0] port_id;
wire write_strobe;
wire k_write_strobe;
wire read_strobe;
wire [7:0] out_port;
wire [7:0] in_port;
wire ram_we;


// Glue logic
assign interrupt = interrupt_ack;
assign ram_we = (~read_strobe) & (write_strobe | k_write_strobe);


// Instances
kcpsm6 #(
    .interrupt_vector           (12'h3FF),
    .scratch_pad_memory_size    (`SPM_SIZE),    // 64, 128, 256
    .hwbuild                    (8'h41)         // 41 hex is ASCII character 'A'
) processor (
    .clk                        (clk),
    .reset                      (reset),
    .sleep                      (sleep),
    .interrupt                  (interrupt),
    .interrupt_ack              (interrupt_ack),
    .address                    (address),
    .bram_enable                (bram_enable),
    .instruction                (instruction),
    .port_id                    (port_id),
    .write_strobe               (write_strobe),
    .k_write_strobe             (k_write_strobe),
    .read_strobe                (read_strobe),
    .out_port                   (out_port),
    .in_port                    (in_port)
);

fpga_sp_ram #(
    .DP                         (4096),
    .DW                         (18)
) program_rom (
    .clk                        (clk),
    .cs                         (bram_enable),
    .we                         (test_in),
    .addr                       (address),
    .din                        ({18{test_in}}),
    .dout                       (instruction)
);

fpga_sp_ram #(
    .DP                         (256),
    .DW                         (8)
) port_ram (
    .clk                        (clk),
    .cs                         (1'b1),
    .we                         (ram_we),
    .addr                       (port_id),
    .din                        (out_port),
    .dout                       (in_port)
);


endmodule
