//==============================================================================
// opb6_main_ctrl.v
//
// Main controller.
//------------------------------------------------------------------------------
// Copyright (c) 2026 Guangxi Liu
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.
//==============================================================================


module opb6_main_ctrl (
    input clk,                      // system clock
`ifdef HAS_ASYNC_RST
    input rst_n,                    // system asynchronous reset, active low
`endif
    input reset,                    // system synchronous reset
    input sleep,                    // sleep control
    input interrupt,                // interrupt control
    input [17:0] instruction,       // 18-bit instructions
    input special_bit,              // special bit
    input stack_pointer_carry_msb,  // MSB of stack_pointer carry out
    output reg [2:1] t_state,       // state encoding
    output reg run,                 // run state
    output reg internal_reset,      // internal reset
    output reg sync_sleep,          // synchronized sleep
    output reg interrupt_enable,    // interrupt enable
    output reg active_interrupt,    // acive interrupt
    output reg interrupt_ack        // indicate starting to service an interrupt
);

// Local signals
wire [2:1] t_state_value;
wire run_value;
wire internal_reset_value;
wire int_enable_type;
wire interrupt_enable_value;
reg sync_interrupt;
wire active_interrupt_value;


// State Machine and Control
assign run_value = (reset) ? 1'b0 :
                   (((~t_state[2]) | (~stack_pointer_carry_msb)) & (internal_reset | run));

assign internal_reset_value = (reset) ? 1'b1 :
                              ((t_state[2] & stack_pointer_carry_msb) | (~run));

assign t_state_value[1] = (internal_reset) ? 1'b0 :
                          (t_state[2] & (~((special_bit ^ sync_sleep) & t_state[1])));

assign t_state_value[2] = (internal_reset) ? 1'b0 :
                          (special_bit) ? ((~sync_sleep) & (~t_state[2])) :
                          ((~sync_sleep) & ((~t_state[2]) | t_state[1]));

assign int_enable_type = (instruction[17:13] == 5'b10100);
assign interrupt_enable_value = (internal_reset | active_interrupt) ? 1'b0 :
                                (t_state[1] & int_enable_type & instruction[0]) ? 1'b1 :
                                (((~t_state[1]) | (~int_enable_type) | instruction[0]) & interrupt_enable);

assign active_interrupt_value = t_state[2] & interrupt_enable & sync_interrupt;

`ifdef HAS_ASYNC_RST
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        run <= 1'b0;
        internal_reset <= 1'b1;
        sync_sleep <= 1'b0;
        t_state <= 2'b00;
        interrupt_enable <= 1'b0;
        sync_interrupt <= 1'b0;
        active_interrupt <= 1'b0;
        interrupt_ack <= 1'b0;
    end
    else begin
        run <= run_value;
        internal_reset <= internal_reset_value;
        sync_sleep <= sleep;
        t_state <= t_state_value;
        interrupt_enable <= interrupt_enable_value;
        sync_interrupt <= interrupt;
        active_interrupt <= active_interrupt_value;
        interrupt_ack <= active_interrupt;
    end
end
`else
always @(posedge clk) begin
    run <= run_value;
    internal_reset <= internal_reset_value;
    sync_sleep <= sleep;
    t_state <= t_state_value;
    interrupt_enable <= interrupt_enable_value;
    sync_interrupt <= interrupt;
    active_interrupt <= active_interrupt_value;
    interrupt_ack <= active_interrupt;
end
`endif


endmodule
