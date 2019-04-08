`timescale 1ns/10ps
/*
ram_dp_ice40.v

2019-04-08 Samuel B Powell
samuel.powell@uq.edu.au

Dual-port RAM using the Lattice iCE40 SB_RAM256x16 primitive
DataWidth *must* be a power of 2 and <= 16
TODO: add support for InitValue?

ram_dp_ice40 #(
    .DataWidth(8),
    .DataDepth(1024),
    .AddrWidth(10),
    .MaskEnable(0),
    .Debug(0) //use ram_dp_generic instead of SB_RAM256x16 for testing
) ram_dp_ice40_0 (
    .write_clk(), // in 
    .write_en(), // in 
    .write_addr(), // in [AddrWidth-1:0] 
    .write_data(), // in [DataWidth-1:0] 
    .write_mask(), // in [DataWidth-1:0] 

    .read_clk(), // in 
    .read_en(), // in 
    .read_addr(), // in [AddrWidth-1:0] 
    .read_data() // out [DataWidth-1:0] 
);

*/

module ram_dp_ice40 #(
    parameter DataWidth = 8,
    parameter DataDepth = 1024,
    parameter AddrWidth = 10,
    parameter MaskEnable = 0,
    parameter Debug = 0
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

//ceiling divide
function integer cdiv;
    input integer a, b;
    begin
        cdiv = a/b;
        if(cdiv*b < a) cdiv = cdiv + 1;
    end
endfunction

//ceil(log2(a))
function integer clog2;
    input integer a;
    begin
        a = a-1;
        for(clog2=0; a >0; clog2 = clog2+1) a = a >> 1;
    end
endfunction

//how many RAMs do we need?
localparam NumRAMs = cdiv(DataWidth*DataDepth, 4096);
//how many bits of the address are used within each 16-bit word?
localparam WordIdxWidth = clog2(16) - clog2(DataWidth);
//how many bits of the address are used to select each RAM?
localparam RamIdxWidth = clog2(NumRAMs);
localparam RamIdxBit = WordIdxWidth + 8;


genvar i;
generate

//wires connected to the array of RAMs
wire [15:0] rdata_mux [0:NumRAMs-1];
reg [15:0] rdata, wdata, mask;
reg [7:0] raddr, waddr;
reg [NumRAMs-1:0] we, re;

//pull the ram index out of the upper address bits
if(NumRAMs == 1) begin
    wire write_ram_idx = 1'b0;
    wire read_ram_idx = 1'b0;
end else begin
    wire [RamIdxWidth-1:0] write_ram_idx = write_addr[RamIdxBit +: RamIdxWidth];
    wire [RamIdxWidth-1:0] read_ram_idx = read_addr[RamIdxBit +: RamIdxWidth];
end
//pull the word index out of the lower address bits
if(WordIdxWidth == 0) begin
    wire write_word_idx = 1'b0;
    wire read_word_idx = 1'b0;
end else begin
    wire [WordIdxWidth-1:0] write_word_idx = write_addr[0 +: WordIdxWidth];
    wire [WordIdxWidth-1:0] read_word_idx = read_addr[0 +: WordIdxWidth];
end

always @* begin
    //select the RAM
    we = 0;
    re = 0;
    we[write_ram_idx] = write_en;
    re[read_ram_idx] = read_en;
    rdata = rdata_mux[read_ram_idx];
    
    //select the address bits
    raddr = read_addr[WordIdxWidth +: 8];
    waddr = write_addr[WordIdxWidth +: 8];

    //write mask
    if(MaskEnable == 0)
        mask = ~({WordIdxWidth{1'b1}} << write_word_idx);
    else
        mask = ~(({WordIdxWidth{1'b1}} & ~write_mask) << write_word_idx);
    
    //select words
    wdata = 0;
    wdata[write_word_idx*DataWidth +: DataWidth] = write_data;
    read_data = rdata[read_word_idx*DataWidth +: DataWidth];
end

//generate RAMs
for(i = 0; i < NumRAMs; i = i + 1) begin : rams
    if(Debug == 0) begin
        SB_RAM256x16 ram_i (
            .RDATA(rdata_mux[i]),
            .RADDR(raddr),
            .RCLK(read_clk),
            .RCLKE(re[i]),
            .RE(re[i]),
            .WADDR(waddr),
            .WCLK(write_clk),
            .WCLKE(we[i]),
            .WDATA(wdata),
            .WE(we[i]),
            .MASK(mask)
        );
    end else begin
        ram_dp_generic #(
            .DataWidth(16),    // word size, in bits
            .DataDepth(256), // RAM size, in words
            .AddrWidth(8),   // enough bits for DataDepth
            .MaskEnable(1),   // enable write_mask if non-zero
            .InitFile(""),    // initialize using $readmemh if InitCount > 0
            .InitValue(16'hACDC),    // initialize to value if InitFile == "" and InitCount > 0
            .InitCount(256)    // number of words to init using InitFile or InitValue
        ) ram_dp_generic_0 (
            .write_clk(write_clk),  // in: write domain clock
            .write_en(we[i]),   // in: write enable
            .write_addr(waddr), // in [AddrWidth]: write address
            .write_data(wdata), // in [DataWidth]: written on posedge write_clk when write_en == 1
            .write_mask(mask), // in [DataWidth]: only low bits are written
            .read_clk(read_clk),   // in: read domain clock
            .read_en(re[i]),    // in: read enable
            .read_addr(raddr),  // in [AddrWidth]: read address
            .read_data(rdata_mux[i])   // out [DataWidth]: registered on posedge read_clk when read_en == 1
        );
    end
end

endgenerate

endmodule