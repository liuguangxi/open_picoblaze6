//==============================================================================
// opb6_sp_ram.v
//
// Generic single port RAM.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


module opb6_sp_ram #(
    parameter DP = 32,              // RAM data depth
    parameter DW = 8                // RAM data width
)
(
    input clk,                      // read/write clock
    input we,                       // write enable
    input [$clog2(DP)-1:0] addr,    // read/write address
    input [DW-1:0] din,             // data input
    output reg [DW-1:0] dout        // data output
);

// Local signals
reg [DW-1:0] mem [DP-1:0];


// Read/Write logic
always @(posedge clk) begin
    if (we)
        mem[addr] <= din;
end

always @(posedge clk) begin
    dout <= mem[addr];
end


endmodule
