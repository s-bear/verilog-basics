`timescale 1ns/10ps
/*
pwm.v
(C) 2021-07-08 Samuel B Powell
samuel.powell@uq.edu.au

Pulse width modulation with spread-spectrum mode.

When SpreadSpectrum is zero, the output is asserted when the internal counter
is less than the duty cycle value. The flicker period in this case is the full
counter period: flicker_period = clock_period * pow(2, Bits)

When SpreadSpectrum is n > 0, the high n bits of the counter are reversed and rotated
to be the least significant bits before comparing to the duty cycle value. This 
decreases the minimum flicker period of the output to:
  flicker_period = clock_period * pow(2, Bits - SpreadSpectrum)

E.g. Bits = 3, duty_cycle = 5 (62.5%)
SpreadSpectrum = 0
count: 000   001   010   011   100   101   110   111
  out:   1    1     1     1     1     0     0     0

SpreadSpectrum = 1  (splits the total period into 2)
count: 000   010   100   110 | 001   011   101   111
  out:   1     1     1     0 |   1     1     0     0

SpreadSpectrum = 2  (splits the total period into 4)
count: 000   100 | 010   110 | 001   101 | 011   111
  out:   1     1 |   1     0 |   1     0 |   1     0

//Instantiation template
module pwm #(
    .Bits(8),
    .ActiveHigh(1),
    .SpreadSpectrum(7) // 0 <= SpreadSpectrum < Bits
)(
    .clk(),        // in
    .reset(),      // in: synchronous, on posedge clk
    .enable(),     // in
    .set_duty(),   // in 
    .duty_cycle(), // in [Bits]: latched on posedge clk when set_duty is asserted
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
    input wire [Bits:0] duty_cycle,
    output reg out
);

reg [Bits-1:0] state, state_spread;
reg [Bits:0] duty;
reg comp;

integer i;
always @* begin
    //the LSBs of state_spread are the reversed MSBs of state
    for(i = 0; i < SpreadSpectrum; i = i + 1)
        state_spread[i] = state[Bits - 1 - i];
    //the MSBs of state_spread are the LSBs of state
    for(i = SpreadSpectrum; i < Bits; i = i + 1)
        state_spread[i] = state[i - SpreadSpectrum];
    //compare
    comp = (state_spread < duty);
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