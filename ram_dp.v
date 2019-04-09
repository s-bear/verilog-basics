`timescale 1ns/10ps
/*
ram_dp.v
2019-04-05 Samuel B Powell
samuel.powell@uq.edu.au

Dual-port RAM with asynchronous clocks. Read and write ports are the same width.
Bit-level write-masking is optional, but is perhaps not synthesizable as coded here.

VendorImpl options:
"ICE40":
    Lattice iCE40 SB_RAM256x16 is used as the basis for the RAM.
    InitFile and InitCount are not supported. The RAM is always inititialized
    using InitValue.
"":
    A generic Verilog RAM implementation is used. Some synthesizers might not
    support write masking or initialization features.


ram_dp #(
    .DataWidth(8),    // word size, in bits
    .DataDepth(1024), // RAM size, in words
    .AddrWidth(10),   // enough bits for DataDepth
    .MaskEnable(0),   // enable write_mask if non-zero
    .InitFile(""),    // initialize using $readmemh if InitCount > 0
    .InitValue(0),    // initialize to value if InitFile == "" and InitCount > 0
    .InitCount(0),    // number of words to init using InitFile or InitValue
    .VendorImpl(""),  // Vendor-specific RAM primitives
    .VendorDebug(0)   // For testing the connections to vendor-specific primitives
) ram_dp_0 (
    .write_clk(),  // in: write domain clock
    .write_en(),   // in: write enable
    .write_addr(), // in [AddrWidth]: write address
    .write_data(), // in [DataWidth]: written on posedge write_clk when write_en == 1
    .write_mask(), // in [DataWidth]: only low bits are written
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
    parameter MaskEnable = 0,
    parameter InitFile = "",
    parameter InitValue = 0,
    parameter InitCount = 0,
    parameter VendorImpl = "",
    parameter VendorDebug = 0
) (
    //write
    input wire write_clk,
    input wire write_en,
    input wire [AddrWidth-1:0] write_addr,
    input wire [DataWidth-1:0] write_data,
    input wire [DataWidth-1:0] write_mask,

    input wire read_clk,
    input wire read_en,
    input wire [AddrWidth-1:0] read_addr,
    output wire [DataWidth-1:0] read_data
);

generate
case(VendorImpl)
"ICE40": //Lattice SB_RAM256x16

    ram_dp_ice40 #(
        .DataWidth(DataWidth),
        .DataDepth(DataDepth),
        .AddrWidth(AddrWidth),
        .MaskEnable(MaskEnable),
        .InitValue(InitValue),
        .Debug(VendorDebug)
    ) ram_dp_ice40_0 (
        .write_clk(write_clk), // in 
        .write_en(write_en), // in 
        .write_addr(write_addr), // in [AddrWidth-1:0] 
        .write_data(write_data), // in [DataWidth-1:0] 
        .write_mask(write_mask), // in [DataWidth-1:0] 

        .read_clk(read_clk), // in 
        .read_en(read_en), // in 
        .read_addr(read_addr), // in [AddrWidth-1:0] 
        .read_data(read_data) // out [DataWidth-1:0] 
    );

default: //generic verilog memory

    ram_dp_generic #(
        .DataWidth(DataWidth),    // word size, in bits
        .DataDepth(DataDepth), // RAM size, in words
        .AddrWidth(AddrWidth),   // enough bits for DataDepth
        .MaskEnable(MaskEnable),   // enable write_mask if non-zero
        .InitFile(InitFile),    // initialize using $readmemh if InitCount > 0
        .InitValue(InitValue),    // initialize to value if InitFile == "" and InitCount > 0
        .InitCount(InitCount)    // number of words to init using InitFile or InitValue
    ) ram_dp_generic_0 (
        .write_clk(write_clk),  // in: write domain clock
        .write_en(write_en),   // in: write enable
        .write_addr(write_addr), // in [AddrWidth]: write address
        .write_data(write_data), // in [DataWidth]: written on posedge write_clk when write_en == 1
        .write_mask(write_mask), // in [DataWidth]: only low bits are written
        .read_clk(read_clk),   // in: read domain clock
        .read_en(read_en),    // in: read enable
        .read_addr(read_addr),  // in [AddrWidth]: read address
        .read_data(read_data)   // out [DataWidth]: registered on posedge read_clk when read_en == 1
    );

endcase
endgenerate
endmodule