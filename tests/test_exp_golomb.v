`timescale 1ns/10ps
/*
test_exp_golomb.v
(C) 2019-08-05 Samuel B Powell
samuel.powell@uq.edu.au
*/

module test_exp_golomb;

initial begin
    $dumpfile("test_exp_golomb.fst");
    $dumpvars(-1, test_exp_golomb);
end

parameter K0 = 3;
parameter K = 2;

parameter clk_t = 10;
reg clk, reset, enable, code;
wire data_valid;
wire [7:0] data;

always #(clk_t/2) clk = ~clk;

task automatic exp_golomb_encode (
    input integer x
);
    integer i, n, base, remainder;
    begin
        //find n first, as with max_n in exp_golomb.v
        i = 1 + x*(2**K-1)/(2**K0); 
        for(n = 0; i > 0; n = n + 1) i = i >> 1; //clog2
        n = (n-1)/K;
        //actually compute base & remainder
        base = (2**K0)*(2**(K*n)-1)/(2**K-1);
        remainder = x - base;
        //leading 0's:
        if(n > 0) begin
            code = 0;
            for(i = 0; i < n; i = i + 1) #clk_t;
        end
        //delimiter
        code = 1;
        #clk_t;
        //remainder
        n = K0 + K*n;
        if(n > 0) begin
            for(i = 1; i <= n; i = i + 1) begin
                code = remainder[n-i];
                #clk_t;
            end
        end
    end
endtask

exp_golomb #(
    .DataWidth(8), //output data width
    .K0(K0), //minimum number of code data bits (min code size is K0 + 1)
    .K(K) //code data bits per leading 0 (code size is (zeros)*K + K0 + 1)
) exp_golomb_0 (
    .clk(clk),    // in
    .reset(reset),  // in
    .enable(enable), // in: code bits are processed while enable is asserted
    .code(code),   // in: code bits
    .data_valid(data_valid), //out: asserted for 1 clk cycle when data is valid
    .data(data) //out [DataWidth]: decoded values
);

integer x;
initial begin
    clk = 1;
    reset = 0;
    enable = 0;
    code = 0;
    x = 0;
    @(negedge clk);
    reset = 1;
    #clk_t;
    reset = 0;
    #(3*clk_t);
    enable = 1;
    for(x = 0; x < 256; x = x + 1) begin
        exp_golomb_encode(x);
    end
    enable = 0;
    #(15*clk_t);
    $finish;
end

endmodule // test_exp_golomb