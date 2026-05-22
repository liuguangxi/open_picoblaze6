//==============================================================================
// sim_ram.v
//
// Simulation model of single port RAM.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


module sim_ram #(
    parameter DP = 1024,            // RAM data depth
    parameter DW = 18,              // RAM data width
    parameter FORCE_X2ZERO = 0      // force output X to 0
)
(
    input clk,                      // read/write clock
    input cs,                       // chip select
    input we,                       // write enable
    input [$clog2(DP)-1:0] addr,    // read/write address
    input [DW-1:0] din,             // data input
    output [DW-1:0] dout            // data output
);

// Local signals
reg [DW-1:0] mem_r [DP-1:0];
wire wen;
wire ren;
reg [$clog2(DP)-1:0] addr_r;
wire [DW-1:0] dout_pre;
genvar i;


// Read/Write logic
assign wen = cs & we;
assign ren = cs & (~we);

always @(posedge clk) begin
    if (wen)
        mem_r[addr] <= din;
end

always @(posedge clk) begin
    if (ren)
        addr_r <= addr;
end

assign dout_pre = mem_r[addr_r];

generate
    if (FORCE_X2ZERO == 1) begin : force_x_to_zero
        for (i = 0; i < DW; i = i+1) begin : force_x_gen
            assign dout[i] = (dout_pre[i] === 1'bx) ? 1'b0 : dout_pre[i];
        end
    end
    else begin : no_force_x_to_zero
        assign dout = dout_pre;
    end
endgenerate


endmodule
