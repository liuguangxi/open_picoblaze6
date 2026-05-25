//==============================================================================
// tb_opb6_vs_kcpsm6.sv
//
// Testbench of opb6 and kcpsm6.
// Differential test.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


`timescale 1ns / 1ps


`define CMP_GPR(IDX) \
    if (dut.sim_dbg.sim_gpr[4'h``IDX] !== 8'hxx && dut_1.sim_s``IDX !== dut.sim_dbg.sim_gpr[4'h``IDX]) \
    $display("[ERROR]  GPR s[%0d] mismatch", 4'h``IDX);

`define CMP_SPM(IDX) \
    if (dut.sim_dbg.sim_spm[8'h``IDX] !== 8'hxx && dut_1.sim_spm``IDX !== dut.sim_dbg.sim_spm[8'h``IDX]) \
    $display("[ERROR]  SPM spm[%0d] mismatch", 8'h``IDX);


module tb_opb6_vs_kcpsm6;

//------------------------------------------------------------------------------
// Parameters
parameter real ClkPeriod = 10.0;
parameter real Dly = 1.0;
parameter string TestDir = "../../test";


// Global variables
string mem_file;
int unsigned run_cycles;
int unsigned sleep_high_cycles;
int unsigned interrupt_interval_cycles;


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
logic interrupt_1;
logic interrupt_ack_1;
logic [11:0] address_1;
logic bram_enable_1;
logic [17:0] instruction_1;
logic [7:0] port_id_1;
logic write_strobe_1;
logic k_write_strobe_1;
logic read_strobe_1;
logic [7:0] out_port_1;
logic [7:0] in_port_1;
logic [11:0] address_1_r;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Instances
opb6 #(8'h41, 12'h7FF, 256) dut (
    .clk            (clk),
    .reset          (reset),
    .sleep          (sleep),
    .interrupt      (interrupt),
    .interrupt_ack  (interrupt_ack),
    .address        (address),
    .bram_enable    (bram_enable),
    .instruction    (instruction),
    .port_id        (port_id),
    .write_strobe   (write_strobe),
    .k_write_strobe (k_write_strobe),
    .read_strobe    (read_strobe),
    .out_port       (out_port),
    .in_port        (in_port)
);

sim_ram #(4096, 18, 0) prom (
    .clk    (clk),
    .cs     (bram_enable),
    .we     (1'b0),
    .addr   (address),
    .din    (18'h0),
    .dout   (instruction)
);

kcpsm6 #(8'h41, 12'h7FF, 256) dut_1 (
    .clk            (clk),
    .reset          (reset),
    .sleep          (sleep),
    .interrupt      (interrupt_1),
    .interrupt_ack  (interrupt_ack_1),
    .address        (address_1),
    .bram_enable    (bram_enable_1),
    .instruction    (instruction_1),
    .port_id        (port_id_1),
    .write_strobe   (write_strobe_1),
    .k_write_strobe (k_write_strobe_1),
    .read_strobe    (read_strobe_1),
    .out_port       (out_port_1),
    .in_port        (in_port_1)
);

sim_ram #(4096, 18, 1) prom_1 (
    .clk    (clk),
    .cs     (bram_enable_1),
    .we     (1'b0),
    .addr   (address_1),
    .din    (18'h0),
    .dout   (instruction_1)
);


// System signals
initial begin
    clk = 1'b0;
    forever #(ClkPeriod/2)    clk = ~clk;
end

initial begin
    reset = 1'b1;
    #(ClkPeriod*20);
    reset = 1'b0;
end
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Drive input port
always @(posedge clk) begin
    in_port <= #Dly port_id;
    in_port_1 <= port_id_1;
end


// Drive sleep
task automatic drv_sleep;
    if (sleep_high_cycles > 0) begin
        forever begin
            @(posedge clk);    #Dly;
            sleep = 1'b1;
            repeat (sleep_high_cycles - 1)
                @(posedge clk);
            @(posedge clk);    #Dly;
            sleep = 1'b0;
        end
    end else begin
        forever begin
        end
    end
endtask


// Drive interrupt
task automatic drv_interrupt;
    if (interrupt_interval_cycles > 0) begin
        forever begin
            repeat (interrupt_interval_cycles)
                @(posedge clk);
            @(posedge clk);    #Dly;
            interrupt = 1'b1;
            $display("[INT]  Generate interrupt");
            wait(interrupt_ack);
            @(posedge clk);    #Dly;
            interrupt = 1'b0;
            $display("[INT]  Acknowledge interrupt");
        end
    end else begin
        forever begin
        end
    end
endtask

task automatic drv_interrupt_1;
    if (interrupt_interval_cycles > 0) begin
        forever begin
            repeat (interrupt_interval_cycles)
                @(posedge clk);
            @(posedge clk);    #Dly;
            interrupt_1 = 1'b1;
            //$display("[INT]  Generate interrupt");
            wait(interrupt_ack_1);
            @(posedge clk);    #Dly;
            interrupt_1 = 1'b0;
            //$display("[INT]  Acknowledge interrupt");
        end
    end else begin
        forever begin
        end
    end
endtask


// Monitor input/output port
task automatic mon_out_port;
    forever begin
        @(negedge clk);
        if (write_strobe) begin
            $display("[IO]  (%t)  Output 0x%02h @0x%02h", $time, out_port, port_id);
            if (write_strobe_1 !== 1'b1 || out_port_1 !== out_port || port_id_1 !== port_id)
                $display("[ERROR]  Output port signals mismatch");
        end
        else if (k_write_strobe) begin
            $display("[IO]  (%t)  Output 0x%02h @0x%h", $time, out_port, port_id[3:0]);
            if (k_write_strobe_1 !== 1'b1 || out_port_1 !== out_port || port_id_1[3:0] !== port_id[3:0])
                $display("[ERROR]  Output port signals mismatch");
        end
        else if (read_strobe) begin
            $display("[IO]  (%t)  Input 0x%02h @0x%02h", $time, in_port, port_id);
            if (read_strobe_1 !== 1'b1 || in_port_1 !== in_port || port_id_1 !== port_id)
                $display("[ERROR]  Input port signals mismatch");
        end
    end
endtask


// Monitor instructions
`ifdef HAS_SIM_DBG
always @(posedge clk) begin
    if (bram_enable)
        address_r <= #Dly address;
    if (bram_enable_1)
        address_1_r <= #Dly address_1;
end

task automatic mon_instr;
    forever begin
        @(negedge clk);
        if (dut.sim_dbg.t_state[1]) begin
            $display("[INSTR]  @%03h -> %05h    %s (%s)",
                address_r, instruction,
                dut.sim_dbg.sim_opcode, dut.sim_dbg.sim_status
            );

            if (address_1_r !== address_r)
                $display("[ERROR]  PROM address mismatch");

            if (instruction_1 !== instruction)
                $display("[ERROR]  Instruction mismatch");

            if (dut_1.kcpsm6_status !== dut.sim_dbg.sim_status)
                $display("[ERROR]  Status mismatch");

            // Compare GPR
            `CMP_GPR(0)  `CMP_GPR(1)  `CMP_GPR(2)  `CMP_GPR(3)  `CMP_GPR(4)  `CMP_GPR(5)  `CMP_GPR(6)  `CMP_GPR(7)
            `CMP_GPR(8)  `CMP_GPR(9)  `CMP_GPR(A)  `CMP_GPR(B)  `CMP_GPR(C)  `CMP_GPR(D)  `CMP_GPR(E)  `CMP_GPR(F)

            // Compare SPM
            `CMP_SPM(00) `CMP_SPM(01) `CMP_SPM(02) `CMP_SPM(03) `CMP_SPM(04) `CMP_SPM(05) `CMP_SPM(06) `CMP_SPM(07)
            `CMP_SPM(08) `CMP_SPM(09) `CMP_SPM(0A) `CMP_SPM(0B) `CMP_SPM(0C) `CMP_SPM(0D) `CMP_SPM(0E) `CMP_SPM(0F)
            `CMP_SPM(10) `CMP_SPM(11) `CMP_SPM(12) `CMP_SPM(13) `CMP_SPM(14) `CMP_SPM(15) `CMP_SPM(16) `CMP_SPM(17)
            `CMP_SPM(18) `CMP_SPM(19) `CMP_SPM(1A) `CMP_SPM(1B) `CMP_SPM(1C) `CMP_SPM(1D) `CMP_SPM(1E) `CMP_SPM(1F)
            `CMP_SPM(20) `CMP_SPM(21) `CMP_SPM(22) `CMP_SPM(23) `CMP_SPM(24) `CMP_SPM(25) `CMP_SPM(26) `CMP_SPM(27)
            `CMP_SPM(28) `CMP_SPM(29) `CMP_SPM(2A) `CMP_SPM(2B) `CMP_SPM(2C) `CMP_SPM(2D) `CMP_SPM(2E) `CMP_SPM(2F)
            `CMP_SPM(30) `CMP_SPM(31) `CMP_SPM(32) `CMP_SPM(33) `CMP_SPM(34) `CMP_SPM(35) `CMP_SPM(36) `CMP_SPM(37)
            `CMP_SPM(38) `CMP_SPM(39) `CMP_SPM(3A) `CMP_SPM(3B) `CMP_SPM(3C) `CMP_SPM(3D) `CMP_SPM(3E) `CMP_SPM(3F)
            `CMP_SPM(40) `CMP_SPM(41) `CMP_SPM(42) `CMP_SPM(43) `CMP_SPM(44) `CMP_SPM(45) `CMP_SPM(46) `CMP_SPM(47)
            `CMP_SPM(48) `CMP_SPM(49) `CMP_SPM(4A) `CMP_SPM(4B) `CMP_SPM(4C) `CMP_SPM(4D) `CMP_SPM(4E) `CMP_SPM(4F)
            `CMP_SPM(50) `CMP_SPM(51) `CMP_SPM(52) `CMP_SPM(53) `CMP_SPM(54) `CMP_SPM(55) `CMP_SPM(56) `CMP_SPM(57)
            `CMP_SPM(58) `CMP_SPM(59) `CMP_SPM(5A) `CMP_SPM(5B) `CMP_SPM(5C) `CMP_SPM(5D) `CMP_SPM(5E) `CMP_SPM(5F)
            `CMP_SPM(60) `CMP_SPM(61) `CMP_SPM(62) `CMP_SPM(63) `CMP_SPM(64) `CMP_SPM(65) `CMP_SPM(66) `CMP_SPM(67)
            `CMP_SPM(68) `CMP_SPM(69) `CMP_SPM(6A) `CMP_SPM(6B) `CMP_SPM(6C) `CMP_SPM(6D) `CMP_SPM(6E) `CMP_SPM(6F)
            `CMP_SPM(70) `CMP_SPM(71) `CMP_SPM(72) `CMP_SPM(73) `CMP_SPM(74) `CMP_SPM(75) `CMP_SPM(76) `CMP_SPM(77)
            `CMP_SPM(78) `CMP_SPM(79) `CMP_SPM(7A) `CMP_SPM(7B) `CMP_SPM(7C) `CMP_SPM(7D) `CMP_SPM(7E) `CMP_SPM(7F)
            `CMP_SPM(80) `CMP_SPM(81) `CMP_SPM(82) `CMP_SPM(83) `CMP_SPM(84) `CMP_SPM(85) `CMP_SPM(86) `CMP_SPM(87)
            `CMP_SPM(88) `CMP_SPM(89) `CMP_SPM(8A) `CMP_SPM(8B) `CMP_SPM(8C) `CMP_SPM(8D) `CMP_SPM(8E) `CMP_SPM(8F)
            `CMP_SPM(90) `CMP_SPM(91) `CMP_SPM(92) `CMP_SPM(93) `CMP_SPM(94) `CMP_SPM(95) `CMP_SPM(96) `CMP_SPM(97)
            `CMP_SPM(98) `CMP_SPM(99) `CMP_SPM(9A) `CMP_SPM(9B) `CMP_SPM(9C) `CMP_SPM(9D) `CMP_SPM(9E) `CMP_SPM(9F)
            `CMP_SPM(A0) `CMP_SPM(A1) `CMP_SPM(A2) `CMP_SPM(A3) `CMP_SPM(A4) `CMP_SPM(A5) `CMP_SPM(A6) `CMP_SPM(A7)
            `CMP_SPM(A8) `CMP_SPM(A9) `CMP_SPM(AA) `CMP_SPM(AB) `CMP_SPM(AC) `CMP_SPM(AD) `CMP_SPM(AE) `CMP_SPM(AF)
            `CMP_SPM(B0) `CMP_SPM(B1) `CMP_SPM(B2) `CMP_SPM(B3) `CMP_SPM(B4) `CMP_SPM(B5) `CMP_SPM(B6) `CMP_SPM(B7)
            `CMP_SPM(B8) `CMP_SPM(B9) `CMP_SPM(BA) `CMP_SPM(BB) `CMP_SPM(BC) `CMP_SPM(BD) `CMP_SPM(BE) `CMP_SPM(BF)
            `CMP_SPM(C0) `CMP_SPM(C1) `CMP_SPM(C2) `CMP_SPM(C3) `CMP_SPM(C4) `CMP_SPM(C5) `CMP_SPM(C6) `CMP_SPM(C7)
            `CMP_SPM(C8) `CMP_SPM(C9) `CMP_SPM(CA) `CMP_SPM(CB) `CMP_SPM(CC) `CMP_SPM(CD) `CMP_SPM(CE) `CMP_SPM(CF)
            `CMP_SPM(D0) `CMP_SPM(D1) `CMP_SPM(D2) `CMP_SPM(D3) `CMP_SPM(D4) `CMP_SPM(D5) `CMP_SPM(D6) `CMP_SPM(D7)
            `CMP_SPM(D8) `CMP_SPM(D9) `CMP_SPM(DA) `CMP_SPM(DB) `CMP_SPM(DC) `CMP_SPM(DD) `CMP_SPM(DE) `CMP_SPM(DF)
            `CMP_SPM(E0) `CMP_SPM(E1) `CMP_SPM(E2) `CMP_SPM(E3) `CMP_SPM(E4) `CMP_SPM(E5) `CMP_SPM(E6) `CMP_SPM(E7)
            `CMP_SPM(E8) `CMP_SPM(E9) `CMP_SPM(EA) `CMP_SPM(EB) `CMP_SPM(EC) `CMP_SPM(ED) `CMP_SPM(EE) `CMP_SPM(EF)
            `CMP_SPM(F0) `CMP_SPM(F1) `CMP_SPM(F2) `CMP_SPM(F3) `CMP_SPM(F4) `CMP_SPM(F5) `CMP_SPM(F6) `CMP_SPM(F7)
            `CMP_SPM(F8) `CMP_SPM(F9) `CMP_SPM(FA) `CMP_SPM(FB) `CMP_SPM(FC) `CMP_SPM(FD) `CMP_SPM(FE) `CMP_SPM(FF)
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
    interrupt_1 = 1'b0;
    in_port = 8'h0;
    in_port_1 = 8'h0;

    $readmemh({TestDir, "/", mem_file}, prom.mem_r);
    $readmemh({TestDir, "/", mem_file}, prom_1.mem_r);

    wait(reset == 1'b0);
    fork
        drv_sleep;
        drv_interrupt;
        drv_interrupt_1;
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

    if ($value$plusargs("SLEEPCYC=%d", sleep_high_cycles)) begin
        $display("[INFO]  Parameter 'sleep_high_cycles' is %0d.", sleep_high_cycles);
    end
    else begin
        sleep_high_cycles = 0;
        $display("[INFO]  Singal 'sleep' inactive.");
    end

    if ($value$plusargs("INTCYC=%d", interrupt_interval_cycles)) begin
        $display("[INFO]  Parameter 'interrupt_interval_cycles' is %0d.", interrupt_interval_cycles);
    end
    else begin
        interrupt_interval_cycles = 0;
        $display("[INFO]  Singal 'interrupt' inactive.");
    end

    run_sim;

    $finish;
end
//------------------------------------------------------------------------------


endmodule
