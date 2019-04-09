`timescale 1ns/10ps

module test_fifo_sync;

localparam clk_t = 20;

reg clk, reset, write_en, read_en;
reg [7:0] write_data;

always begin
    #(clk_t/2) clk = ~clk;
end

always @(negedge clk) begin
    if(write_en) begin
        write_data = write_data + 1;
    end
end

initial begin
    $dumpfile("test_fifo_sync.fst");
    $dumpvars(-1, test_fifo_sync);
    clk = 0;
    reset = 0;
    write_en = 0;
    read_en = 0;
    write_data = 0;
    #(2*clk_t);
    reset = 1;
    #(2*clk_t)
    reset = 0;
    #clk_t;
    //write only
    write_en = 1;
    #(8*clk_t); 
    //read and write while partially full
    read_en = 1;
    #(4*clk_t);
    //write until full, then while full
    read_en = 0;
    #(10*clk_t);
    //do nothing while full
    write_en = 0;
    #(4*clk_t);
    //read and write while full
    write_en = 1;
    read_en = 1;
    #(4*clk_t);
    //read until empty, then while empty
    write_en = 0;
    #(18*clk_t);
    //read and write while empty
    write_en = 1;
    #(25*clk_t);
    $finish;
end

fifo_sync #(
    .DataWidth(8),
    .DataDepth(16),
    .AddrWidth(4),
    .InitFile("test_data.hex"),
    .InitCount(16)
) fifo_0 (
    .clk(clk),
    .reset(reset),
    .write_en(write_en),
    .write_data(write_data), //[DataWidth-1:0]
    .fifo_full(),
    .read_en(read_en),
    .read_data(), //[DataWidth-1:0]
    .fifo_empty()
);

endmodule