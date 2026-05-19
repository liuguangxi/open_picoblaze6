//==============================================================================
// opb6_gpr.v
//
// Generic general purpose registers (GPR).
// One synchronous write port, two asynchronous read ports.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


module opb6_gpr #(
    parameter DP = 32,             // RAM data depth
    parameter DW = 8               // RAM data width
)
(
    input clk,                      // write clock
    input we,                       // write enable
    input [$clog2(DP)-1:0] addrx,   // read/write address for sX
    input [$clog2(DP)-1:0] addry,   // read address for sY
    input [DW-1:0] dinx,            // data input for sX
    output [DW-1:0] doutx,          // data output for sX
    output [DW-1:0] douty           // data output for sY
);

// Local signals
reg [DW-1:0] mem [DP-1:0];


// Read/Write logic
always @(posedge clk) begin
    if (we)
        mem[addrx] <= dinx;
end

assign doutx = mem[addrx];
assign douty = mem[addry];


endmodule
