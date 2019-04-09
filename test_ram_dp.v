`timescale 1ns/10ps
/*
test_ram_dp.v
2019-04-09 Samuel B Powell
samuel.powell@uq.edu.au

*/

module test_ram_dp;

//initialize simulation
initial begin
    $dumpfile("test_ram_dp.fst");
    $dumpvars(-1, test_ram_dp);
end

parameter DataWidth = 8;
parameter DataDepth = 1024;
parameter AddrWidth = 10;
parameter MaskEnable = 1;
parameter VendorImpl = "ICE40";

//write port signals
reg write_clk, write_en;
reg [9:0] write_addr;
reg [7:0] write_data, write_mask;

parameter wclk_t = 10;
always #(wclk_t/2) write_clk = ~write_clk;

//read port signals
reg read_clk, read_en;
reg [9:0] read_addr;
wire [7:0] read_data;

parameter rclk_t = 12;
always #(rclk_t/2) read_clk = ~read_clk;

ram_dp #(
    .DataWidth(DataWidth),    // word size, in bits
    .DataDepth(DataDepth), // RAM size, in words
    .AddrWidth(AddrWidth),   // enough bits for DataDepth
    .MaskEnable(MaskEnable),   // enable write_mask if non-zero
    .InitFile(""),    // initialize using $readmemh if InitCount > 0
    .InitValue(0),    // initialize to value if InitFile == "" and InitCount > 0
    .InitCount(DataDepth),    // number of words to init using InitFile or InitValue
    .VendorImpl(VendorImpl),  // Vendor-specific RAM primitives
    .VendorDebug(1)   // For testing the connections to vendor-specific primitives
) ram_dp_0 (
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

integer write_count, read_count;
initial begin
    //reset all signals
    write_clk = 1;
    read_clk = 1;
    write_en = 0;
    write_addr = 0;
    write_data = 0;
    write_mask = 16'hF0F0;
    write_count = 0;
    read_en = 0;
    read_addr = 0;
    read_count = 0;
end

//write side
initial begin
    @(negedge write_clk);
    #(3.1*wclk_t);
    while(write_count < DataDepth) begin
        write_en = 1;
        #(13*wclk_t);
        write_en = 0;
        #(3*wclk_t);
    end
    wait(read_count == DataDepth);
    #(10*wclk_t);
    $finish;
end

always @(negedge write_clk) begin
    if(write_en && write_count < DataDepth) begin
        write_addr <= write_addr + 1;
        write_data <= write_data + 1;
        write_mask <= {write_mask[0], write_mask[DataWidth-1:1]};
        write_count <= write_count + 1;
    end
end

//read side
initial begin
    @(negedge read_clk);
    #(5.1*rclk_t);
    while(read_count < DataDepth) begin
        read_en = 1;
        #(11*rclk_t);
        read_en = 0;
        #(5*rclk_t);
    end
end

always @(negedge read_clk) begin
    if(read_en) begin
        read_addr <= read_addr + 1;
        read_count <= read_count + 1;
    end
end

endmodule