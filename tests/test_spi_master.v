`timescale 1ns / 10ps
/*
test_spi_master.v

Testbench for spi_master.v
2019-03-28 Samuel B Powell
samuel.powell@uq.edu.au

*/

module test_spi_master;

parameter WordWidth = 8;
parameter IndexWidth = 3;
parameter clk_t = 10;

//inputs:
reg clk, reset, transfer;
reg [IndexWidth-1:0] nbits_m1;
reg [WordWidth-1:0] mosi_word_in;
wire miso;
//outputs:
wire mosi_accepted, miso_valid, ssel, sclk, mosi;
wire [WordWidth-1:0] miso_word;

assign #(clk_t) miso = mosi;

spi_master #(
    .WordWidth(WordWidth),  // bits per word
    .IndexWidth(IndexWidth), // ceil(log2(WordWidth))
    .SPOL(0),    // 0 or 1 -- if 0, SSEL is active low (typical)
    .CPOL(0),     // 0 or 1 -- initial SCLK value
    .MOSI_PHA(0), // 0 or 1 -- if 0, MOSI shifts out on the leading sclk edge
    .MISO_PHA(1), // 0 or 1 -- if 0, MISO is latched on the lagging sclk edge
    .MSB_FIRST(1), // 0 or 1 -- if 0, LSB is shifted in/out first
    .TimerWidth(2), // bits for the sclk timer -- enough to count to T_sclk
    .T_sclk(2),     // sclk period, in clk tick counts. must be at least 2
    .T_sclk_cpol(1) // sclk time in the CPOL phase. must be at least 1
) spi_master_0 (
    .clk(clk),   // system clock
    .reset(reset), // system reset
    .transfer(transfer),   // in: begin a transfer. assert until mosi_accepted
    .nbits_m1(nbits_m1), // in [IndexWidth]: highest bit of mosi_word_in to xfer.
    .mosi_word_in(mosi_word_in), // in [WordWidth]: word to transfer. hold until accepted
    .mosi_accepted(mosi_accepted),   // out: one-shot pulse when a transfer begins
    .miso_valid(miso_valid), // out: one-shot pulse when miso_word is valid to read
    .miso_word(miso_word), // out [WordWidth]: received word. unstable until miso_valid
    .ssel(ssel), // out: slave select
    .sclk(sclk), // out: SPI clock
    .mosi(mosi), // out: master out, slave in
    .miso(miso)  // in:  master in, slave out
);

//clock
always #(clk_t/2) clk = ~clk;

//simulation
initial begin
    $dumpfile("test_spi_master.fst");
    $dumpvars(-1,test_spi_master);
    //initial values
    clk = 1;
    reset = 0;
    transfer = 0;
    nbits_m1 = 0;
    mosi_word_in = 0;
    //wait so that signal changes don't happen exactly on clock transitions
    #(clk_t/4);
    reset = 1;
    #(clk_t);
    reset = 0;
    nbits_m1 = 3;
    mosi_word_in = 8'hAD;
    #(clk_t);
    transfer = 1;
    #clk_t;
    mosi_word_in = 8'hEA;
    nbits_m1 = 5;
    #(8*clk_t);
    transfer = 0;
    #(20*clk_t);
    $finish;
end

endmodule