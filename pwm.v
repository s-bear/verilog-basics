`timescale 1ns/10ps
/*
pwm.v
(C) 2019-04-15 Samuel B Powell
samuel.powell@uq.edu.au

Pulse width modulation with spread-spectrum mode.

When SpreadSpectrum is non-zero, the module reverses the bits of the internal
counter before comparing to the duty cycle. The ratio of on to off time remains
the same, but the periods of on time will be scattered evenly within the total 
counter period.
e.g: With a 3 bits and a duty cycle of 75% (duty_cycle=5)
count:  000  001  010  011  100  101  110  111
normal:  1    1    1    1    1    1    0    0
spread:  1    1    1    0    1    1    1    0


module pwm #(
    .Bits(8),
    .ActiveHigh(1),
    .SpreadSpectrum(1)
)(
    .clk(),        // in
    .reset(),      // in
    .enable(),     // in
    .set_duty(),   // in 
    .duty_cycle(), // in [Bits]: latched when set_duty is asserted
    .out()         //out: modulated when enable is asserted
);
*/

module pwm #(
    parameter Bits = 8,
    parameter ActiveHigh = 1,
    parameter SpreadSpectrum = 1
)(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire set_duty,
    input wire [Bits-1:0] duty_cycle,
    output reg out
);

reg [Bits-1:0] state, state_rev, duty;
reg comp;

integer i;
always @* begin
    if(SpreadSpectrum == 0) begin
        comp = (state <= duty);
    end else begin
        //reverse the bits of state
        for(i = 0; i < Bits; i = i + 1)
            state_rev[i] = state[Bits-1-i];
        comp = (state_rev <= duty);
    end
end

always @(posedge clk) begin
    if(reset) begin
        state <= 0;
        duty <= 0;
        out <= ~|ActiveHigh;
    end else begin
        if(set_duty) begin
            duty <= duty_cycle;
        end
        if(enable) begin
            state <= state + 1;
            out <= ~(comp ^ (|ActiveHigh));
        end
    end
    
end

endmodule