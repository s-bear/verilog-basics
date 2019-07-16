`timescale 1ns/10ps
/*
debounce.v
2019-04-11 Samuel B Powell
samuel.powell@uq.edu.au

Button debouncer.
If StableTime == 0, the debouncer will be implemented as a shift register with
    Bits flip-flops. The necessary time for IN to be stable before OUT will
    switch is (Bits + 1) rising edges of CLK
If StableTime is non-zero, the debouncer will be implemented as a counter with
    Bits bits. The necessary time for IN to be stable before OUT will switch
    is StableTime rising edges of CLK.

StableState controls the debouncer's preffered output state:
    if "LOW" then OUT == 0 is stable:
        IN must remain 1 for the necessary time for OUT to switch to 1
        if IN is 0 at any rising edge of CLK, then OUT will switch to 0
    if "HIGH" then OUT == 1 is stable, with similar semantics to "LOW"
    if "BOTH" then OUT prefers not to change in either state:
        IN must remain ~OUT for the necessary time for OUT to switch to IN

*/

module debounce #(
    parameter Bits = 4,
    parameter StableTime = 0,
    parameter StableState = "BOTH" //"LOW", "HIGH", or "BOTH"
)(
    input wire clk,
    input wire reset,

    input wire in,
    output reg out
);

wire stable_bit;
reg [Bits-1:0] state, state_D;
reg out_D;

always @(posedge clk) begin
    if(reset) begin
        state <= 0;
        out <= 0;
    end else begin
        state <= state_D;
        out <= out_D;
    end
end

generate

case(StableState)
"LOW": assign stable_bit = 1'b0;
"HIGH": assign stable_bit = 1'b1;
default: assign stable_bit = out;
endcase

if(StableTime == 0) begin
//implement as a shift register
wire [Bits:0] state_in = {state, in};
always @* begin
    //shift
    state_D = state_in[Bits-1:0];
    //we only switch to the "unstable bit" if all of the bits equal it
    if(state_in == ~{Bits+1{stable_bit}})
        out_D = ~stable_bit;
    else //otherwise return to the stable_bit
        out_D = stable_bit;
end
//end shift register
end else begin
//implement as a counter

always @* begin
    out_D = out;
    state_D = state;
    //count down
    if(state > 0) state_D = state-1;
    
    if(in == stable_bit) begin
        //reset the timer whenever we're in the stable state
        state_D = StableTime - 1;
        out_D = stable_bit;
    end else if(state == 0) begin
        //if the timer ran out then we can switch
        out_D = ~stable_bit;
    end
end
//end counter
end
endgenerate

endmodule