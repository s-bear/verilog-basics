`timescale 1ns/10ps

module test_lfsr;

//initialize simulation
initial begin
    $dumpfile("test_lfsr.fst");
    $dumpvars(-1, test_lfsr);
end

parameter Depth = 8;
parameter Coeffs = 8'b10111000;
parameter Galois = 0;

parameter clk_t = 10;
reg clk, reset, enable, set_state;
reg [Depth-1:0] state_in;
wire out;
always #(clk_t/2) clk = ~clk;

lfsr #(
    .Depth(Depth),
    .Coeffs(Coeffs),
    .Galois(Galois) // nonzero: use Galois architecture
) lfsr_0 (
    .clk(clk),    // in: system clock
    .reset(reset),  // in: active-high synchronous reset
    .enable(enable), // in: active-high enable
    .out(out),    //out: output bit stream
    .set_state(set_state), // in: set internal state to state_in when high
    .state_in(state_in)   // in [Depth]: new internal state
);

initial begin
    clk = 1;
    reset = 0;
    enable = 0;
    set_state = 0;
    state_in = 0;
    @(negedge clk);
    reset = 1;
    #clk_t;
    reset = 0;
    #(3*clk_t);
    enable = 1;
    #(300*clk_t);
    enable = 0;
    #(5*clk_t);
    $finish;
end

endmodule