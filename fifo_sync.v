`timescale 1ns / 10ps
/*
fifo_sync.v
2019-02-13 Samuel B Powell
samuel.powell@uq.edu.au

Synchronous FIFO queue.
Ignores reads when empty.
Ignores writes when full _unless_ simultaneously reading while not empty.

Parameters InitFile and InitCount may be used to give the FIFO an initial state.
This feature might not be supported by synthesis tools, but is useful for
simulation. Be aware that reset will *not* return the FIFO to this initial
state, but rather to the empty state.

fifo_sync #(
    .DataWidth(16),
    .DataDepth(1024),
    .AddrWidth(10),
    .InitFile(""), //read using $readmemh if InitCount > 0
    .InitCount(0) //number of words to read from InitFile, M= DataDepth
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

//memory
reg [DataWidth-1:0] mem [DataDepth-1:0];

//addressing
reg [AddrWidth-1:0] write_addr, write_addr_D;
reg [AddrWidth-1:0] read_addr, read_addr_D;
reg do_write, fifo_full_D, fifo_empty_D;

wire [AddrWidth-1:0] next_write_addr = (write_addr + 1) % DataDepth;
wire [AddrWidth-1:0] next_read_addr = (read_addr + 1) % DataDepth;

assign read_data = mem[read_addr];

//init from file. n.b. clobbered by reset!
generate
if(InitCount > 0) initial begin
    $readmemh(InitFile, mem, 0, InitCount-1);
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
    do_write = 1'b0;
    if(write_en == 1'b1 && read_en == 1'b1) begin
        //reading and writing at the same time
        do_write = 1'b1;
        write_addr_D = next_write_addr;
        if(fifo_empty == 1'b1) begin //we can only write
            fifo_full_D = (next_write_addr == read_addr);
            fifo_empty_D = 1'b0;
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
            fifo_empty_D = 1'b0;
        end
    end else if(read_en == 1'b1) begin
        if(fifo_empty == 1'b0) begin
            //read when not empty, and we're also not writing
            fifo_full_D = 1'b0;
            read_addr_D = next_read_addr;
            fifo_empty_D = (next_read_addr == write_addr);
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
    end else begin 
        write_addr <= write_addr_D;
        read_addr <= read_addr_D;
        fifo_full <= fifo_full_D;
        fifo_empty <= fifo_empty_D;
        if(do_write == 1'b1) begin
            mem[write_addr] <= write_data;
        end
    end
end

endmodule