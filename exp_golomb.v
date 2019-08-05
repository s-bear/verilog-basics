`timescale 1ns/10ps
/*
exp_golomb.v
(C) 2019-08-05 Samuel B Powell
samuel.powell@uq.edu.au

Exponential-Golomb decoder

Exponential-Golomb codes are a universal variable-length code where the number
of leading 0's indicates the number of bits in the second part of the code. The
base code has one bit for each leading zero. In general, one may set k bits for
each leading 0 resulting in fewer bits used for larger numbers, but more
for smaller numbers.
k = 1         k = 2
   1    -> 0     1     -> 0
  010   -> 1    0100   -> 1
  011   -> 2    0101   -> 2
 00100  -> 3    0110   -> 3
 00101  -> 4    0111   -> 4
 00110  -> 5   0010000 -> 5
 00111  -> 6   0010001 -> 6
0001000 -> 7   0010010 -> 7
...

This implementation also includes a k0 term, setting the minimum number of bits
per code. E.g: k = 2, k0 = 3
 1000   -> 0 ...  1111   -> 7
0100000 -> 8 ... 0111111 -> 39
This might make sense to use if you have several equally likely values at the
low end and don't want to grow the code too quickly. (Here, 7 requires 4 bits
rather than 7 bits as in k=2, k0=0).

exp_golomb #(
    .DataWidth(16), //output data width
    .K0(2), //minimum number of code data bits (min code size is K0 + 1)
    .K(2) //code data bits per leading 0 (code size is (zeros)*K + K0 + 1)
) exp_golomb_0 (
    .clk(),    // in
    .reset(),  // in
    .enable(), // in: code bits are processed while enable is asserted
    .code(),   // in: code bits
    .data_valid(), //out: asserted for 1 clk cycle when data is valid
    .data() //out [DataWidth]: decoded values
);
*/


module exp_golomb #(
    parameter DataWidth = 16,
    parameter K0 = 2,
    parameter K = 2
)(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire code,
    output reg data_valid,
    output reg [DataWidth-1:0] data 
);

`include "functions.vh"

function integer max_n;
    input integer b; //number of output bits
    begin
        //floor(log2(x)) == ceil(log2(x+1))-1
        b = 1 + (2**b - 1)*(2**K - 1)/(2**K0);
        //do clog2
        for(max_n = 0; b > 0; max_n = max_n + 1) b = b >> 1;
        max_n = (max_n-1)/K;
    end
endfunction

localparam MaxN = max_n(DataWidth);
localparam NBits = clog2(MaxN+1);
localparam BBits = clog2(DataWidth)+1;

reg [DataWidth-1:0] base_table [0:MaxN];
integer i;
initial begin
    for(i = 0; i <= MaxN; i = i + 1) begin
        base_table[i] = (2**K0)*(2**(K*i)-1)/(2**K - 1);
    end
end

reg [NBits-1:0] n, n_D; //number of leading 0's, index into base_table
reg [BBits-1:0] b, b_D; //number of bits of offset to read
reg [DataWidth-1:0] data_D, base, base_D, offset, offset_D;
reg data_valid_D;
reg counting, counting_D; //are we counting leading 0's?

always @* begin
    n_D = n;
    b_D = b;
    data_D = data;
    base_D = base;
    offset_D = offset;
    data_valid_D = 0;
    counting_D = counting;

    if(enable) begin
        if(counting) begin
            if(code == 1'b1) begin //end of leading 0's
                if(b == 0) begin //no bits of offset to read
                    data_D = 0;
                    data_valid_D = 1'b1;
                end else begin //switch to reading offset
                    base_D = base_table[n];
                    offset_D = 0;
                    b_D = b - 1;
                    counting_D = 0;
                end
            end else begin //count leading 0
                n_D = n + 1;
                b_D = b + K;
            end
        end else begin //read offset bits
            offset_D = {offset[DataWidth-2:0],code}; //shift code in left
            if(b > 0) begin
                b_D = b - 1;    
            end else begin //no bits of offset left to read
                data_D = base + offset_D;
                data_valid_D = 1'b1;
                counting_D = 1'b1;
                n_D = 0;
                b_D = K0;
            end
        end
    end
end

always @(posedge clk) begin
    if(reset) begin
        n <= 0;
        b <= K0;
        data <= 0;
        base <= 0;
        offset <= 0;
        data_valid <= 0;
        counting <= 1;
    end else begin
        n <= n_D;
        b <= b_D;
        data <= data_D;
        offset <= offset_D;
        base <= base_D;
        data_valid <= data_valid_D;
        counting <= counting_D;
    end
end

endmodule // expgolomb 

