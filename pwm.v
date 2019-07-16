`timescale 1ns/10ps
/*
pwm.v
(C) 2019-04-15 Samuel B Powell
samuel.powell@uq.edu.au
*/

module pwm #(
    parameter Bits = 8,
    parameter ActiveHigh = 1,
    parameter SpreadSpectrum = 1,
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
    //reverse the bits of state
    for(i = 0; i < Bits; i = i + 1)
        state_rev[i] = state[Bits-1-i];

    if(SpreadSpectrum == 0)
        comp = (state <= duty);
    else
        comp = (state_rev <= duty);
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