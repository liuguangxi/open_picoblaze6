//==============================================================================
// fpga_sp_ram.v
//
// FPGA synthesis model of single port RAM.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


module fpga_sp_ram #(
    parameter DP = 256,             // RAM data depth
    parameter DW = 8                // RAM data width
)
(
    input clk,                      // read/write clock
    input cs,                       // chip select
    input we,                       // write enable
    input [$clog2(DP)-1:0] addr,    // read/write address
    input [DW-1:0] din,             // data input
    output reg [DW-1:0] dout        // data output
);

// Local signals
reg [DW-1:0] mem [DP-1:0];
integer i;


// Read/Write logic
initial begin
    for (i = 0; i < DP; i = i + 1)
        mem[i] = {DW{1'b0}};
end

always @(posedge clk) begin
    if (cs) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr];
    end
end


endmodule
