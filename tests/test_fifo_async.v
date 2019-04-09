`timescale 1ns/10ps
/*
test_fifo_async.v
2019-04-04 Samuel B Powell
samuel.powell@uq.edu.au
*/

module test_fifo_async;

//initialize simulation
initial begin
    $dumpfile("test_fifo_async.fst");
    $dumpvars(-1, test_fifo_async);
end

//write domain signals
parameter wclk_t = 10;
reg write_clk, write_reset, write_en;
reg [7:0] write_data;
wire fifo_full;
always #(wclk_t/2) write_clk = ~write_clk;

//read domain signals
parameter rclk_t = 12;
reg read_clk, read_reset, read_en;
wire [7:0] read_data;
wire fifo_empty;
always #(rclk_t/2) read_clk = ~read_clk;

fifo_async #(
    .DataWidth(8),   // data word size, in bits
    .DataDepth(16), // memory size, in words: must be a power of 2
    .AddrWidth(4),   // memory address size, in bits
    .SyncStages(2),   // number of synchronizer stages between clock domains
    .InitFile("test_data.hex"),    // read using $readmemh if InitCount > 0
    .InitCount(16)     // number of words to read from InitFile, <= DataDepth
) fifo_async_0 (
    .write_clk(write_clk),   // in: write domain clock
    .write_reset(write_reset), // in: write domain reset
    .write_en(write_en),    // in: write enable -- pushes data when fifo is not full
    .write_data(write_data),  // in [DataWidth]: write data
    .fifo_full(fifo_full),   //out: asserted when writing is not possible

    .read_clk(read_clk),   // in: read domain clock
    .read_reset(read_reset), // in: read domain reset
    .read_en(read_en),    // in: read enable -- pops data when fifo is not empty
    .read_data(read_data),  //out [DataWidth]: read data -- valid when fifo is not empty
    .fifo_empty(fifo_empty)  //out: asserted when read_data is invalid
);

//write side
always @(negedge write_clk) begin
    if(write_en) write_data = write_data + 1;
end

initial begin
    write_clk = 1;
    write_reset = 0;
    write_en = 0;
    write_data = 0;
    #(1.5*wclk_t);
    write_reset = 1;
    #(1*wclk_t);
    write_reset = 0;
    write_en = 1;
    @(posedge fifo_full);
    #(4*wclk_t);
    write_en = 0;
    @(posedge fifo_empty);
    @(negedge write_clk);
    write_en = 1;
    #(10*wclk_t);
    $finish;
end

//read side
initial begin
    read_clk = 1;
    read_reset = 0;
    read_en = 0;
    #(1.5*rclk_t);
    read_reset = 1;
    #(1*rclk_t);
    read_reset = 0;
    @(negedge fifo_empty);
    @(negedge read_clk);
    #(4*rclk_t);
    read_en = 1;
    #(4*rclk_t);
    read_en = 0;
    @(posedge fifo_full); //this isn't synced to rclk!
    @(negedge read_clk); //now we're back synced to rclk
    #(4*rclk_t);
    read_en = 1;
    @(posedge fifo_empty);
    #(4*rclk_t);
    read_en = 0;
    #(2*rclk_t);
    read_en = 1;
end

endmodule