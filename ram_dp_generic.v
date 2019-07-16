`timescale 1ns/10ps
/*
ram_dp_generic.v

2019-04-08 Samuel B Powell
samuel.powell@uq.edu.au

Dual-port RAM with asynchronous clocks. Read and write ports are the same width.
Bit-level write-masking is optional, but is perhaps not synthesizable as coded here.


ram_dp_generic #(
    .DataWidth(8),    // word size, in bits
    .DataDepth(1024), // RAM size, in words
    .AddrWidth(10),   // enough bits for DataDepth
    .MaskEnable(0),   // enable write_mask if non-zero
    .InitFile(""),    // initialize using $readmemh if InitCount > 0
    .InitValue(0),    // initialize to value if InitFile == "" and InitCount > 0
    .InitCount(0)    // number of words to init using InitFile or InitValue
) ram_dp_generic_0 (
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
module ram_dp_generic #(
    parameter DataWidth = 8,
    parameter DataDepth = 1024,
    parameter AddrWidth = 10,
    parameter MaskEnable = 0,
    parameter InitFile = "",
    parameter InitValue = 0,
    parameter InitCount = 0
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
    output reg [DataWidth-1:0] read_data
);

//memory
reg [DataWidth-1:0] mem [0:DataDepth-1];

//initialize
generate
if(InitCount > 0) begin
    integer i;
    initial begin
        if(InitFile != "") begin
            $readmemh(InitFile, mem, 0, InitCount-1);
        end else begin
            for(i = 0; i < InitCount && i < DataDepth; i = i + 1)
                mem[i] = InitValue[DataWidth-1:0];
        end
        read_data <= mem[0];
    end
end
endgenerate

//write port
generate
if(MaskEnable == 0) begin
    always @(posedge write_clk) begin
        if(write_en == 1'b1) mem[write_addr] <= write_data;
    end
end else begin //MaskEnable
    always @(posedge write_clk) begin
        if(write_en == 1'b1) begin
            //this probably won't synthesize correctly to an inferred BRAM because
            //it reads before writing, but without using the read-port (which is
            //in a different clock domain here!)
            //it *might* synthesize correctly if write_clk == read_clk
            mem[write_addr] <= (mem[write_addr] & write_mask) | (write_data & ~write_mask);
        end
    end
end
endgenerate

//read port
always @(posedge read_clk) begin
    if(read_en == 1'b1) read_data <= mem[read_addr];
end

endmodule