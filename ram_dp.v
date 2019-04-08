`timescale 1ns/10ps
/*
ram_dp.v
2019-04-05 Samuel B Powell
samuel.powell@uq.edu.au

Dual-port RAM with asynchronous clocks. No masking, read and write ports are
the same width.

ram_dp #(
    .DataWidth(8),    // word size, in bits
    .DataDepth(1024), // RAM size, in words
    .AddrWidth(10),   // enough bits for DataDepth
    .InitFile(""),    // initialize using $readmemh if InitCount > 0
    .InitValue(0),    // initialize to value if InitFile == "" and InitCount > 0
    .InitCount(0)    // number of words to init using InitFile or InitValue
) ram_dp_0 (
    .write_clk(),  // in: write domain clock
    .write_en(),   // in: write enable
    .write_addr(), // in [AddrWidth]: write address
    .write_data(), // in [DataWidth]: written on posedge write_clk when write_en == 1
    .read_clk(),   // in: read domain clock
    .read_en(),    // in: read enable
    .read_addr(),  // in [AddrWidth]: read address
    .read_data()   // out [DataWidth]: registered on posedge read_clk when read_en == 1
);
*/
module ram_dp #(
    parameter DataWidth = 8,
    parameter DataDepth = 1024,
    parameter AddrWidth = 10,
    parameter InitFile = "",
    parameter InitValue = 0,
    parameter InitCount = 0
) (
    //write
    input wire write_clk,
    input wire write_en,
    input wire [AddrWidth-1:0] write_addr,
    input wire [DataWidth-1:0] write_data,

    input wire read_clk,
    input wire read_en,
    input wire [AddrWidth-1:0] read_addr,
    output reg [DataWidth-1:0] read_data
);

//memory
reg [DataWidth-1:0] mem [0:DataDepth-1];

//initialize
generate

if(InitCount > 0) begin
    integer i;
    initial begin
        for(i = 0; i < InitCount && i < DataDepth; i = i + 1)
            mem[i] = InitValue[DataWidth-1:0];
        if(InitFile != "")
            $readmemh(InitFile, mem, 0, InitCount-1);
    end
end
endgenerate

//write port
always @(posedge write_clk) begin
    if(write_en == 1'b1) mem[write_addr] <= write_data;
end

//read port
always @(posedge read_clk) begin
    if(read_en == 1'b1) read_data <= mem[read_addr];
end

endmodule