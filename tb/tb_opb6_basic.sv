//==============================================================================
// tb_opb6_basic.sv
//
// Testbench of opb6.
// Basic test, no sleep, no interrupt.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


`timescale 1ns / 1ps


module tb_opb6_basic;

//------------------------------------------------------------------------------
// Parameters
parameter real ClkPeriod = 10.0;
parameter real Dly = 1.0;
parameter string TestDir = "../../test";


// Global variables
string mem_file;
int unsigned run_cycles;


// Signals
logic clk;
logic reset;
logic sleep;
logic interrupt;
logic interrupt_ack;
logic [11:0] address;
logic bram_enable;
logic [17:0] instruction;
logic [7:0] port_id;
logic write_strobe;
logic k_write_strobe;
logic read_strobe;
logic [7:0] out_port;
logic [7:0] in_port;
logic [11:0] address_r;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Instances
opb6 #(8'h41, 12'h3FF, 256) dut (.*);

sim_ram #(4096, 18, 0) prom (
    .clk    (clk),
    .cs     (bram_enable),
    .we     (1'b0),
    .addr   (address),
    .din    (18'h0),
    .dout   (instruction)
);


// System signals
initial begin
    clk = 1'b0;
    forever #(ClkPeriod/2)    clk = ~clk;
end

initial begin
    reset = 1'b1;
    #(ClkPeriod*10);
    reset = 1'b0;
end
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Drive input port
always @(posedge clk) begin
    in_port <= #Dly port_id;
end


// Monitor input/output port
task automatic mon_out_port;
    forever begin
        @(negedge clk);
        if (write_strobe)
            $display("[IO]  (%t)  Output 0x%02h @0x%02h", $time, out_port, port_id);
        else if (k_write_strobe)
            $display("[IO]  (%t)  Output 0x%02h @0x%h", $time, out_port, port_id[3:0]);
        else if (read_strobe)
            $display("[IO]  (%t)  Input 0x%02h @0x%02h", $time, in_port, port_id);
    end
endtask


// Monitor instructions
`ifdef HAS_SIM_DBG
always @(posedge clk) begin
    if (bram_enable)
        address_r <= #Dly address;
end

task automatic mon_instr;
    forever begin
        @(negedge clk);
        if (dut.sim_dbg.t_state[1]) begin
            $display("[INSTR]  @%03h -> %05h    %s (%s)",
                address_r, instruction,
                dut.sim_dbg.sim_opcode, dut.sim_dbg.sim_status
            );
        end
    end
endtask
`endif


// Run `run_cycles` clock cycles
task automatic timeout;
    #(ClkPeriod*run_cycles);
endtask


// Run simulation
task automatic run_sim;
    sleep = 1'b0;
    interrupt = 1'b0;
    in_port = 8'h0;

    $readmemh({TestDir, "/", mem_file}, prom.mem_r);

    wait(reset == 1'b0);
    fork
        mon_out_port;
        `ifdef HAS_SIM_DBG
        mon_instr;
        `endif
        timeout;
    join_any

    #(ClkPeriod*10);
    $display("[INFO]  Simulation complete.");
endtask
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Main process
initial begin
    $timeformat(-9, 0, " ns", 10);

    if ($value$plusargs("TESTFILE=%s", mem_file)) begin
        $display("[INFO]  Test file \"%s\" is loaded.", mem_file);
    end
    else begin
        $display("[ERROR]  Test file is not specified. Should use runtime option \"+TESTFILE=testfile\"");
        $finish;
    end

    if ($value$plusargs("RUNCYC=%d", run_cycles)) begin
        $display("[INFO]  Parameter 'run_cycles' is %0d.", run_cycles);
    end
    else begin
        run_cycles = 1000;
        $display("[INFO]  Parameter 'run_cycles' is %0d.", run_cycles);
    end

    run_sim;

    $finish;
end
//------------------------------------------------------------------------------


endmodule
