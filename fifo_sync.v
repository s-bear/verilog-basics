`timescale 1ns / 10ps
/*
fifo_sync.v
2019-02-13 Samuel B Powell
samuel.powell@uq.edu.au

Synchronous FIFO queue.
Ignores reads when empty.
Ignores writes when full _unless_ simultaneously reading while not empty.

This FIFO uses First-Word Fall-Through (FWFT) semantics--meaning that the first
word of data pushed into the queue appears on read_data *before* read_en is
asserted. That is, when and only when fifo_empty == 1'b0, read_data is valid.

Parameters InitFile and InitCount may be used to give the FIFO an initial state.
This feature might not be supported by synthesis tools, but is useful for
simulation. Be aware that reset will *not* return the FIFO to this initial
state, but rather to the empty state.

fifo_sync #(
    .DataWidth(16),
    .DataDepth(1024),
    .AddrWidth(10),
    .InitFile(""), //read using $readmemh if InitCount > 0
    .InitCount(0) //number of words to read from InitFile, <= DataDepth
) fifo_sync_0 (
    .clk(),   //system clock
    .reset(), //system reset
    .write_en(),   //  in: pushes write_data when fifo is not full
    .write_data(), //  in [DataWidth-1:0]
    .fifo_full(),  // out
    .read_en(),  //  in: pops read_data when fifo is not empty
    .read_data(),  // out[DataWidth-1:0]
    .fifo_empty()  // out
);
*/

module fifo_sync #(
    parameter DataWidth = 16,
    parameter DataDepth = 1024,
    parameter AddrWidth = 10,
    parameter InitFile = "",
    parameter InitCount = 0
)(
    input wire clk,
    input wire reset,
    //write interface
    input wire write_en,
    input wire [DataWidth-1:0] write_data,
    output reg fifo_full,
    //read interface
    input wire read_en,
    output wire [DataWidth-1:0] read_data,
    output reg fifo_empty
);

//addressing
reg [AddrWidth-1:0] write_addr, write_addr_D;
reg [AddrWidth-1:0] read_addr, read_addr_D;
reg first_write, first_write_D; //first write after being empty
reg do_write, fifo_full_D, fifo_empty_D;

wire [AddrWidth-1:0] next_write_addr = (write_addr + 1) % DataDepth;
wire [AddrWidth-1:0] next_read_addr = (read_addr + 1) % DataDepth;

//memory
//you can replace this with another ram as long as it's single-clock access
ram_dp #(
    .DataWidth(DataWidth),    // word size, in bits
    .DataDepth(DataDepth), // RAM size, in words
    .AddrWidth(AddrWidth),   // enough bits for DataDepth
    .InitFile(InitFile),    // initialize using $readmemh if InitCount > 0
    .InitValue(0),    // initialize to value if InitFile == "" and InitCount > 0
    .InitCount(InitCount)    // number of words to init using InitFile or InitValue
) mem (
    .write_clk(clk),  // in: write domain clock
    .write_en(do_write),   // in: write enable
    .write_addr(write_addr), // in [AddrWidth]: write address
    .write_data(write_data), // in [DataWidth]: written on posedge write_clk when write_en == 1
    .read_clk(clk),   // in: read domain clock
    .read_en(1'b1),    // in: read enable
    .read_addr(read_addr_D),  // in [AddrWidth]: read address
    .read_data(read_data)   // out [DataWidth]: registered on posedge read_clk when read_en == 1
);

//init from file. n.b. clobbered by reset!
generate
if(InitCount > 0) initial begin
    write_addr = InitCount % DataDepth;
    read_addr  = 0;
    fifo_full  = (InitCount == DataDepth);
    fifo_empty = 0;
end
endgenerate

//logic
always @* begin
    write_addr_D = write_addr;
    read_addr_D = read_addr;
    fifo_full_D = fifo_full;
    fifo_empty_D = fifo_empty;
    first_write_D = first_write;
    if(first_write == 1'b0) fifo_empty_D = 1'b0;
    do_write = 1'b0;
    if(write_en == 1'b1 && read_en == 1'b1) begin
        //reading and writing at the same time
        do_write = 1'b1;
        write_addr_D = next_write_addr;
        if(fifo_empty == 1'b1) begin //we can only write
            fifo_full_D = (next_write_addr == read_addr);
            first_write_D = 1'b0;
        end else begin //even if the fifo is full we can write
            read_addr_D = next_read_addr;
            //neither empty nor full status will change
        end
    end else if(write_en == 1'b1) begin
        if(fifo_full == 1'b0) begin
            //write while not full, and we're not reading
            do_write = 1'b1;
            write_addr_D = next_write_addr;
            fifo_full_D = (next_write_addr == read_addr);
            if(fifo_empty) first_write_D = 1'b0;
        end
    end else if(read_en == 1'b1) begin
        if(fifo_empty == 1'b0) begin
            //read when not empty, and we're also not writing
            fifo_full_D = 1'b0;
            read_addr_D = next_read_addr;
            fifo_empty_D = (next_read_addr == write_addr);
            first_write_D = fifo_empty_D;
        end
    end
end

//registers
always @(posedge clk) begin
    if(reset) begin
        write_addr <= 0;
        read_addr <= 0;
        fifo_full <= 1'b0;
        fifo_empty <= 1'b1;
        first_write <= 1'b1;
    end else begin 
        write_addr <= write_addr_D;
        read_addr <= read_addr_D;
        fifo_full <= fifo_full_D;
        fifo_empty <= fifo_empty_D;
        first_write <= first_write_D;
    end
end

endmodule
