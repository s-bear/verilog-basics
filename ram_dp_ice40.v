`timescale 1ns/10ps
/*
ram_dp_ice40.v

2019-04-08 Samuel B Powell
samuel.powell@uq.edu.au

Dual-port RAM using the Lattice iCE40 SB_RAM256x16 primitive
DataWidth *must* be a power of 2 and <= 16
TODO: add support for InitValue?

ram_dp_ice40 #(
    .DataWidth(8), //MUST BE ONE OF 1, 2, 4, 8, 16
    .DataDepth(1024),
    .AddrWidth(10),
    .MaskEnable(0),
    .InitValue(8'h00),
    .Debug(0) //nonzero: use ram_dp_generic instead of SB_RAM256x16
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
    parameter InitValue = 8'h00,
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

`include "functions.vh"

//how many RAMs do we need?
localparam NumRAMs = cdiv(DataWidth*DataDepth, 4096);
//how many bits of the address are used within each 16-bit word?
localparam WordIdxWidth = (DataWidth >= 16) ? 1 : clog2(16) - clog2(DataWidth);
//how many bits of the address are used to select each RAM?
localparam RamIdxWidth = (NumRAMs == 1) ? 1 : clog2(NumRAMs);
localparam RamIdxBit = WordIdxWidth + 8;
localparam RamAddrWidth = AddrWidth - (clog2(16) - clog2(DataWidth)) - clog2(NumRAMs);

localparam InitString = {(256/DataWidth){InitValue[DataWidth-1:0]}};

//wires connected to the array of RAMs
wire [15:0] rdata_mux [0:NumRAMs-1];
wire [15:0] rdata;
reg [15:0] wdata, mask;
reg [7:0] raddr, waddr;
reg [NumRAMs-1:0] we, re;

wire [RamIdxWidth-1:0] write_ram_idx;
wire [WordIdxWidth-1:0] write_word_idx;
reg [RamIdxWidth-1:0] read_ram_idx, read_ram_idx_D;
reg [WordIdxWidth-1:0] read_word_idx, read_word_idx_D;

generate
//pull the ram index out of the upper address bits
if(NumRAMs == 1) begin
    assign write_ram_idx = 1'b0;
end else begin
    assign write_ram_idx = write_addr[RamIdxBit +: RamIdxWidth];
end
//pull the word index out of the lower address bits
if(DataWidth == 16) begin
    assign write_word_idx = 1'b0;
end else begin
    assign write_word_idx = write_addr[0 +: WordIdxWidth];
end
endgenerate

assign rdata = rdata_mux[read_ram_idx];

always @* begin
    //read indices
    if(NumRAMs == 1) read_ram_idx_D = 1'b0;
    else read_ram_idx_D = read_addr[RamIdxBit +: RamIdxWidth];
    if(DataWidth == 16) read_word_idx_D = 1'b0;
    else read_word_idx_D = read_addr[0 +: WordIdxWidth];

    //select the RAM
    we = 0;
    re = 0;
    we[write_ram_idx] = write_en;
    re[read_ram_idx_D] = read_en;
    
    //select the address bits
    if(DataWidth == 16) begin
        raddr = {{8-RamAddrWidth{1'b0}},read_addr[0 +: RamAddrWidth]};
        waddr = {{8-RamAddrWidth{1'b0}},write_addr[0 +: RamAddrWidth]};
    end else begin
        raddr = {{8-RamAddrWidth{1'b0}},read_addr[WordIdxWidth +: RamAddrWidth]};
        waddr = {{8-RamAddrWidth{1'b0}},write_addr[WordIdxWidth +: RamAddrWidth]};
    end
    //write mask
    if(MaskEnable == 0)
        mask = ~({DataWidth{1'b1}} << DataWidth*write_word_idx);
    else
        mask = ~(({DataWidth{1'b1}} & ~write_mask) << DataWidth*write_word_idx);
    
    //select words
    wdata = 0;
    wdata[write_word_idx*DataWidth +: DataWidth] = write_data;
    read_data = rdata[read_word_idx*DataWidth +: DataWidth];

end

always @(posedge read_clk) begin
    read_ram_idx <= read_ram_idx_D;
    read_word_idx <= read_word_idx_D;
end

//generate RAMs
genvar i;
generate
for(i = 0; i < NumRAMs; i = i + 1) begin : rams
    if(Debug == 0) begin
        SB_RAM256x16 #(
            .INIT_0(InitString),
            .INIT_1(InitString),
            .INIT_2(InitString),
            .INIT_3(InitString),
            .INIT_4(InitString),
            .INIT_5(InitString),
            .INIT_6(InitString),
            .INIT_7(InitString),
            .INIT_8(InitString),
            .INIT_9(InitString),
            .INIT_A(InitString),
            .INIT_B(InitString),
            .INIT_C(InitString),
            .INIT_D(InitString),
            .INIT_E(InitString),
            .INIT_F(InitString)
        ) ram_i (
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
            .InitValue(InitString[15:0]),    // initialize to value if InitFile == "" and InitCount > 0
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