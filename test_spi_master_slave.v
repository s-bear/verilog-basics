`timescale 1ns / 10ps
/*
test_spi_master_slave.v
2019-04-02 Samuel B Powell
samuel.powell@uq.edu.au

Testbench for spi_master and spi_slave together

*/


module test_spi_master_slave;

parameter WordWidth = 8;
parameter IndexWidth = 3;

parameter SPOL = 0;
parameter CPOL = 0;
parameter MOSI_PHA = 0;
parameter MISO_PHA = 1;
parameter MSB_FIRST = 1;

//initialize simulation, clk and reset
parameter clk_t = 10;
reg clk, reset;
always #(clk_t/2) clk = ~clk;
initial begin
    $dumpfile("test_spi_master_slave.fst");
    $dumpvars(-1, test_spi_master_slave);
    clk = 1;
    reset = 1;
    #(1.1*clk_t) reset = 0;
end

reg transfer;
reg [IndexWidth-1:0] nbits_m1;

initial begin
    nbits_m1 = 0;
    transfer = 0;
    //wait for the reset to finish
    //add a partial clk delay so that our signals don't change exactly w/ clk
    #(3.25*clk_t); 
    //do a full transfer
    nbits_m1 = 7;
    transfer = 1;
    @(negedge mosi_accepted);
    transfer = 0;
    //wait for ssel to change, then a few extra cycles
    @(ssel);
    #(5*clk_t);
    //do two transfers
    transfer = 1;
    @(negedge mosi_accepted); //first word accepted
    @(negedge mosi_accepted); //second
    transfer = 0;
    @(ssel);
    #(5*clk_t);
    //do a partial transfer
    nbits_m1 = 5;
    transfer = 1;
    @(negedge mosi_accepted);
    transfer = 0;
    //wait for ssel to change, then a few extra cycles
    @(ssel);
    #(5*clk_t);
    //do two partial transfers
    nbits_m1 = 5;
    transfer = 1;
    @(negedge mosi_accepted);
    @(negedge mosi_accepted);
    transfer = 0;
    //wait for ssel to change, then a few extra cycles
    @(ssel);
    #(5*clk_t);
    $finish;
end

wire [WordWidth-1:0] mosi_word_in, miso_word_in;
wire [WordWidth-1:0] miso_word_out, mosi_word_out;

wire mosi_accepted, miso_valid, mosi_valid, miso_accepted;
wire ssel, sclk, mosi, miso;
wire fm_full, fm_empty, fs_full, fs_empty;

fifo_sync #(
    .DataWidth(WordWidth),
    .DataDepth(16),
    .AddrWidth(4),
    .InitFile("test_data.hex"), //read using $readmemh if InitCount > 0
    .InitCount(16) //number of words to read from InitFile
) fifo_master (
    .clk(clk),
    .reset(1'b0), //no reset because of InitFile
    .write_en(miso_valid),
    .write_data(miso_word_out), //[DataWidth-1:0]
    .fifo_full(fm_full),
    .read_en(mosi_accepted),
    .read_data(mosi_word_in), //[DataWidth-1:0]
    .fifo_empty(fm_empty)
);

spi_master #(
    .WordWidth(WordWidth),  // bits per word
    .IndexWidth(IndexWidth), // ceil(log2(WordWidth))
    .SPOL(SPOL),    // 0 or 1 -- if 0, SSEL is active low (typical)
    .CPOL(CPOL),     // 0 or 1 -- initial clock phase
    .MOSI_PHA(MOSI_PHA), // 0 or 1 -- if 0, MOSI shifts out on the leading sclk edge
    .MISO_PHA(MISO_PHA), // 0 or 1 -- if 0, MISO shifts in on the lagging sclk edge
    .MSB_FIRST(MSB_FIRST), // 0 or 1 -- if 0, shift the LSB in/out first
    .TimerWidth(4), // bits for the sclk timer -- enough to count to T_sclk
    .T_sclk(6),     // sclk period, in clk tick counts. must be at least 2
    .T_sclk_cpol(3) // sclk time in the CPOL phase. must be at least 1
) spi_master_0 (
    .clk(clk),   // system clock
    .reset(reset), // system reset
    
    .transfer(transfer),   //  in: begin a transfer. assert until accepted
    .nbits_m1(nbits_m1), //  in [IndexWidth]: number of bits to transfer, minus 1
    .mosi_word_in(mosi_word_in), //  in [WordWidth]: word to transfer. hold until accepted
    .mosi_accepted(mosi_accepted),   // out: one-shot pulse when a transfer begins
    .miso_word(miso_word_out), // out [WordWidth]: received word. unstable until miso_valid
    .miso_valid(miso_valid), // out: one-shot pulse when miso_word is valid to read

    .ssel(ssel), // out: slave select
    .sclk(sclk), // out: SPI clock
    .mosi(mosi), // out: master out, slave in
    .miso(miso)  //  in: master in, slave out
);
spi_slave #(
    .WordWidth(WordWidth), // bits per word
    .IndexWidth(IndexWidth), // ceil(log2(WordWidth))
    .SPOL(SPOL), // 0 or 1 -- if 0, SSEL is active low (typical)
    .CPOL(CPOL), // 0 or 1 -- sclk phase
    .MOSI_PHA(MOSI_PHA), // 0 or 1 -- if 0, MOSI shifts in on the lagging sclk edge
    .MISO_PHA(MISO_PHA), // 0 or 1 -- if 0, MISO shifts out on the leading sclk edge
    .MSB_FIRST(MSB_FIRST), // if nonzero, shift the MSb in/out first
    .OUTPUT_PARTIAL(1) // if nonzero, trigger mosi_valid on partial transfers
) spi_slave_0 (
    .clk(clk), // system clock
    .reset(reset), // system reset
    
    .mosi_valid(mosi_valid), // out: one-shot pulse when mosi_word is ready
    .mosi_word(mosi_word_out),  // out [WordWidth]: received word. read when mosi_valid == 1
    .miso_accepted(miso_accepted), // out: one-shot pulse when miso_word_in is registered
    .miso_word_in(miso_word_in), // in [WordWidth]: word to transfer. hold until accepted
    
    .ssel(ssel), //  in: slave select (sync externally to clk)
    .sclk(sclk), //  in: SPI clock (sync externally to clk)
    .mosi(mosi), //  in: master out, slave in (sync externally to clk)
    .miso(miso)  // out: master in, slave out (sync externally to clk)
);

fifo_sync #(
    .DataWidth(WordWidth),
    .DataDepth(16),
    .AddrWidth(4),
    .InitFile("test_data.hex"), //read using $readmemh if InitCount > 0
    .InitCount(16) //number of words to read from InitFile
) fifo_slave (
    .clk(clk),
    .reset(1'b0),
    .write_en(mosi_valid),
    .write_data(mosi_word_out), //[DataWidth-1:0]
    .fifo_full(fs_full),
    .read_en(miso_accepted),
    .read_data(miso_word_in), //[DataWidth-1:0]
    .fifo_empty(fs_empty)
);

endmodule