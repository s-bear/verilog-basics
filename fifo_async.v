`timescale 1ns/10ps
/*
fifo_async.v
2019-04-04 Samuel B Powell
samuel.powell@uq.edu.au

Asynchronous FIFO queue, based on the design presented in "Simulation and 
 Synthesis Techniques for Asynchronous FIFO Design" by Clifford E Cummings,
 Sunburst Design, Inc. 

This FIFO uses First-Word Fall-Through (FWFT) semantics--meaning that the first
word of data pushed into the queue appears on read_data *before* read_en is
asserted. That is, when and only when fifo_empty == 1'b0, read_data is valid.

This FIFO design uses gray code to pass the read and write pointers across clock
boundaries, improving synchronizer performance. The fifo_full and fifo_empty
signals are asserted immediately but remove pessimisticly -- so there is no
chance for errors.

NOTE: write_reset and read_reset should be asserted simultaneously, but 
synchronized to their respective clocks for the FIFO to behave as expected.

Parameters InitFile and InitCount may be used to give the FIFO an initial state.
This feature might not be supported by synthesis tools, but is useful for 
simulation. Be aware that write_reset and read_reset will *not* return the FIFO
to this initial state, but rather to the empty state.

fifo_async #(
    .DataWidth(16),   // data word size, in bits
    .DataDepth(1024), // memory size, in words: must be a power of 2
    .AddrWidth(10),   // memory address size, in bits
    .SyncStages(2),   // number of synchronizer stages between clock domains
    .InitFile(""),    // read using $readmemh if InitCount > 0
    .InitCount(0),    // number of words to read from InitFile, <= DataDepth
    .VendorImpl("")   // vendor specific RAM primitive -- see ram_dp.v
) fifo_async_0 (
    .write_clk(),   // in: write domain clock
    .write_reset(), // in: write domain reset
    .write_en(),    // in: write enable -- pushes data when fifo is not full
    .write_data(),  // in [DataWidth]: write data
    .fifo_full(),   //out: asserted when writing is not possible

    .read_clk(),   // in: read domain clock
    .read_reset(), // in: read domain reset
    .read_en(),    // in: read enable -- pops data when fifo is not empty
    .read_data(),  //out [DataWidth]: read data -- valid when fifo is not empty
    .fifo_empty()  //out: asserted when read_data is invalid
);
*/

module fifo_async #(
    parameter DataWidth = 16,
    parameter DataDepth = 1024,
    parameter AddrWidth = 10,
    parameter SyncStages = 2,
    parameter InitFile = "",
    parameter InitCount = 0,
    parameter VendorImpl = ""
) (
    input wire write_clk,
    input wire write_reset,
    input wire write_en,
    input wire [DataWidth-1:0] write_data,
    output reg fifo_full,

    input wire read_clk,
    input wire read_reset,
    input wire read_en,
    output wire [DataWidth-1:0] read_data,
    output reg fifo_empty
);

function [AddrWidth:0] bin_to_gray;
    input [AddrWidth:0] bin;
    bin_to_gray = {bin[AddrWidth], bin[AddrWidth:1] ^ bin[AddrWidth-1:0]};
endfunction

/* WRITE SIDE VARIABLES */
//address registers have an extra bit to deal with wrap-around
//this simplifies full/empty logic
reg [AddrWidth:0] write_addr, write_addr_D;
reg [AddrWidth:0] write_addr_gray, write_addr_gray_D;
wire [AddrWidth:0] read_addr_gray_sync;
reg fifo_full_D;

wire write_en_not_full = (write_en == 1'b1 && fifo_full == 1'b0);

/* READ SIDE VARIABLES */
//address registers have an extra bit to deal with wrap-around
//this simplifies full/empty logic
reg [AddrWidth:0] read_addr, read_addr_D;
reg [AddrWidth:0] read_addr_gray, read_addr_gray_D;
wire [AddrWidth:0] write_addr_gray_sync;
reg fifo_empty_D;

wire read_en_not_empty = (read_en == 1'b1 && fifo_empty == 1'b0);

/* MEMORY */
// you can replace this with another dual-port memory as long as the read/write
// semantics stay the same (single clock cycle accesses)
ram_dp #(
    .DataWidth(DataWidth),    // word size, in bits
    .DataDepth(DataDepth), // RAM size, in words
    .AddrWidth(AddrWidth),   // enough bits for DataDepth
    .InitFile(InitFile),    // initialize using $readmemh if InitCount > 0
    .InitValue(0),    // initialize to value if InitFile == "" and InitCount > 0
    .InitCount(InitCount),    // number of words to init using InitFile or InitValue
    .VendorImpl(VendorImpl)
) mem (
    .write_clk(write_clk),  // in: write domain clock
    .write_en(write_en_not_full),   // in: write enable
    .write_addr(write_addr[AddrWidth-1:0]), // in [AddrWidth]: write address
    .write_data(write_data), // in [DataWidth]: written on posedge write_clk when write_en == 1
    .read_clk(read_clk),   // in: read domain clock
    .read_en(1'b1),    // in: read enable
    .read_addr(read_addr_D[AddrWidth-1:0]),  // in [AddrWidth]: read address
    .read_data(read_data)   // out [DataWidth]: registered on posedge read_clk when read_en == 1
);

//initialize memory from file. NOTE: clobbered by write_reset!
generate
if(InitCount > 0) initial begin
    write_addr = InitCount;
    write_addr_gray = bin_to_gray(InitCount);
    read_addr = 0;
    read_addr_gray = 0;
    fifo_full = (InitCount == DataDepth);
    fifo_empty = 0;
end
endgenerate

/* CROSS-CLOCK SYNCHRONIZERS */
synchronizer #(
    .Width(AddrWidth+1),
    .Stages(SyncStages),
    .Init(InitCount),
    .InitValue(0)
) write_clk_sync (
    .clk(write_clk),
    .reset(write_reset),
    .in(read_addr_gray),
    .out(read_addr_gray_sync)
);

synchronizer #(
    .Width(AddrWidth+1),
    .Stages(SyncStages),
    .Init(InitCount),
    .InitValue(bin_to_gray(InitCount))
) read_clk_sync (
    .clk(read_clk),
    .reset(read_reset),
    .in(write_addr_gray),
    .out(write_addr_gray_sync)
);

/* COMBINATIONAL LOGIC */
always @* begin
    //write logic
    write_addr_D = write_addr;
    if(write_en_not_full) begin
        write_addr_D = write_addr + 1;
    end

    write_addr_gray_D = bin_to_gray(write_addr_D);
    
    //full logic: the two MSb's are different, the rest are equal
    fifo_full_D = 
        (write_addr_gray_D == {~read_addr_gray_sync[AddrWidth:AddrWidth-1],
                                read_addr_gray_sync[AddrWidth-2:0]});

    //read logic
    read_addr_D = read_addr;
    if(read_en_not_empty) begin
        read_addr_D = read_addr + 1;
    end

    read_addr_gray_D = bin_to_gray(read_addr_D);
    
    //empty logic: the addresses are all equal
    fifo_empty_D = (read_addr_gray_D == write_addr_gray_sync);
end

/* WRITE SIDE SYNCRHONOUS LOGIC */
always @(posedge write_clk or posedge write_reset) begin
    if(write_reset) begin
        write_addr <= 0;
        write_addr_gray <= 0;
        fifo_full <= 1'b0;
    end else begin
        write_addr <= write_addr_D;
        write_addr_gray <= write_addr_gray_D;
        fifo_full <= fifo_full_D;
    end
end

/* READ SIDE SYNCHRONOUS LOGIC */
always @(posedge read_clk or posedge read_reset) begin
    if(read_reset) begin
        read_addr <= 0;
        read_addr_gray <= 0;
        fifo_empty <= 1'b1;
    end else begin
        read_addr <= read_addr_D;
        read_addr_gray <= read_addr_gray_D;
        fifo_empty <= fifo_empty_D;
    end
end

endmodule