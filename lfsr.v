`timescale 1ns/10ps
/*
lfsr.v
2019-04-09 Samuel B Powell
samuel.powell@uq.edu.au

Linear feedback shift register with both Fibonacci (wide XOR) and Galois
(many 2-bit XOR) architectures.

lfsr #(
    .Depth(8),
    .Coeffs(8'b10111000),
    .Galois(1) // nonzero: use Galois architecture
) lfsr_0 (
    .clk(),    // in: system clock
    .reset(),  // in: active-high synchronous reset
    .enable(), // in: active-high enable
    .out(),    //out: output bit stream
    .set_state(), // in: set internal state to state_in when high
    .state_in()   // in [Depth]: new internal state
);

The maximum sequence length is (2**Depth - 1). 
See http://users.ece.cmu.edu/~koopman/lfsr/index.html for lists of polynomials.

Depth: a few possible coefficient bit-strings for max-length sequences
4:  4'h9, 4'hC
5:  5'h12, 5'h14, 5'h17, 5'h1B, 5'h1D, 5'h1E
6:  6'h21, 6'h2D, 6'h30, 6'h33, 6'h36, 6'h39
7:  7'h41, 7'h44, 7'h47, 7'h48, 7'h4E, 7'h53, 7'h55, 7'h5C, 7'h5F, 7'h60, 7'h65
8:  8'h8E, 8'h95, 8'h96, 8'hA6, 8'hAF, 8'hB1, 8'hB2, 8'hB4, 8'hB8, 8'hC3, 8'hC6
9:  9'h108, 9'h10D, 9'h110, 9'h116, 9'h119, 9'h12C, 9'h12F, 9'h134, 9'h137
10: 10'h204, 10'h20D, 10'h213, 10'h216, 10'h232, 10'h237, 10'h240, 10'h245
12: 12'h829, 12'h834, 12'h83D, 12'h83E, 12'h84C, 12'h868, 12'h875, 12'h883
14: 14'h2015, 14'h201C, 14'h2029, 14'h202F, 14'h203D, 14'h2054, 14'h2057
16: 16'h8016, 16'h801C, 16'h801F, 16'h8029, 16'h805E, 16'h806B, 16'h8097
20: 20'h80004, 20'h80029, 20'h80032, 20'h80034, 20'h8003D, 20'h80079, 20'h800B3
24: 24'h80000D, 24'h800043, 24'h800058, 24'h80006D, 24'h80007A, 24'h800092
28: 28'h8000004, 28'h8000029, 28'h800003B, 28'h8000070, 28'h80000B3, 28'h80000B9
32: 32'h80000057, 32'h80000062, 32'h8000007A, 32'h80000092, 32'h800000B9

*/

module lfsr #(
    parameter Depth = 8,
    parameter Coeffs = 8'hB8,
    parameter Galois = 1
)(
    input wire clk,
    input wire reset,
    input wire enable,
    output wire out,
    input wire set_state,
    input wire [Depth-1:0] state_in
);


reg [Depth-1:0] state, state_D;
assign out = state[0];

always @(posedge clk) begin
    if(reset == 1'b1) begin
        state <= 1;
    end else begin
        state <= state_D;
    end
end

integer bit;

generate
if(Galois == 0) begin 
//Fibonacci (parallel) architecture
always @* begin
    state_D = state;
    if(set_state == 1'b1) begin
        state_D = state_in;
    end else if(enable == 1'b1) begin
        //shift up
        state_D = {state[Depth-2:0],state[Depth-1]};
        //do the parallel xor
        for(bit = 0; bit < Depth-1; bit = bit + 1) begin
            if(Coeffs[bit] == 1'b1) state_D[0] = state_D[0] ^ state[bit];
        end
    end
end
//End Fibonacci
end else begin 
//Galois (serial) architecture
always @* begin
    state_D = state;
    if(set_state == 1'b1) begin
        state_D = state_in;
    end else if(enable == 1'b1) begin
        //shift down
        state_D = {state[0], state[Depth-1:1]};
        //insert the XORs, count bits
        for(bit = 0; bit < Depth-1; bit = bit + 1) begin
            if(Coeffs[bit] == 1'b1) state_D[bit] = state[0] ^ state[bit+1];
        end
    end
end
//End Galois
end
endgenerate

endmodule
