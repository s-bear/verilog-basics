`timescale 1ns/10ps
/*
synchronizer.v
2019-04-05 Samuel B Powell
samuel.powell@uq.edu.au

A shift register serial read/write only, meant for synchronizing registers
across clock domains.

synchronizer #(
    .Width(8), 
    .Stages(2),   //number of shift registers
    .Init(0),     //if nonzero, initialize each register to InitValue
    .InitValue(0) //initial & reset value
) sync_0 (
    .clk(),   //in: output clock
    .reset(), //in: active high reset
    .in(),    //in [Width]: data in
    .out()    //out [Width]: data out, delayed by Stages clk cycles
);
*/

module synchronizer #(
    parameter Width = 8,
    parameter Stages = 2,
    parameter Init = 0,
    parameter InitValue = 0
) (
    input wire clk,
    input wire reset,
    input wire [Width-1:0] in,
    output wire [Width-1:0] out
);
generate
if(Stages == 0) begin
    assign out = in;
end else begin
    reg [Width*Stages-1:0] shiftreg;
    assign out = shiftreg[Width-1:0];
    always @(posedge clk or posedge reset) begin
        if(reset == 1'b1) begin
            shiftreg <= {Stages{InitValue[Width-1:0]}};
        end else begin
            shiftreg <= {in, shiftreg[Width*Stages-1:Width]};
        end
    end
    if(Init != 0) initial begin
        shiftreg = {Stages{InitValue[Width-1:0]}};
    end
end
endgenerate
endmodule