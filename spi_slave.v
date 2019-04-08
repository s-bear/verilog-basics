`timescale 1ns / 10ps

/*
spi_slave.v
2019-03-29 Samuel B Powell
samuel.powell@uq.edu.au

Basic SPI slave with a few protocol options. Most notably, MISO and MOSI may have different phases.

This module includes synchonizers for ssel and sclk to clk controlled by the
SyncStages parameter. If you don't want synchronization, set SyncStages to 0.
If SyncStages is nonzero, be sure that clk is sufficiently faster than sclk that
the protocol timing is not overly disturbed. With SyncStages == 2, clk should be
at least N times faster than sclk.

While SSEL is asserted, every sclk cycle shifts another bit in/out.
As soon as WordWidth bits are shifted in, mosi_valid is pulsed for a single clk
 cycle--indicating that it may be read. If SSEL is deasserted before all of the
 bits are read, the SPI slave rejects the read and resets.
When SSEL is asserted the slave registers miso_word_in to shift out. As soon as
WordWidth bits are shifted out, the next word is accepted.

MISO is provided via a basic interface: when a transfer begins (ssel is asserted)
miso_word_in is latched and miso_accepted is asserted for a single cycle. Every time
WordWidth bits are shifted out, this repeats. This allows a first-word fall-through
FIFO to easily provide data to the slave.

spi_slave #(
    .WordWidth(8), // bits per word
    .IndexWidth(3), // ceil(log2(WordWidth))
    .SyncStages(2), // synchronizer stages for ssel and sclk
    .SPOL(0), // 0 or 1 -- if 0, SSEL is active low (typical)
    .CPOL(0), // 0 or 1 -- sclk phase
    .MOSI_PHA(0), // 0 or 1 -- if 0, MOSI shifts in on the lagging sclk edge
    .MISO_PHA(0), // 0 or 1 -- if 0, MISO shifts out on the leading sclk edge
    .MSB_FIRST(1) // if nonzero, shift the MSb in/out first
) spi_slave_0 (
    .clk(), // system clock
    .reset(), // system reset
    .mosi_valid(), // out: one-shot pulse when mosi_word is ready
    .mosi_word(),  // out [WordWidth]: received word. read when mosi_valid == 1
    .miso_word_in(), // in [WordWidth]: word to transfer. hold until accepted
    .miso_accepted(), // out: one-shot pulse when miso_word_in is registered
    .ssel(), //  in: slave select (sync externally to clk)
    .sclk(), //  in: SPI clock (sync externally to clk)
    .mosi(), //  in: master out, slave in (sync externally to clk)
    .miso()  // out: master in, slave out (sync externally to clk)
);
*/

module spi_slave #(
    parameter WordWidth = 8,
    parameter IndexWidth = 3,
    parameter SyncStages = 2,
    parameter SPOL = 0, // 0 or 1 -- if 0, SSEL is active low (typical)
    parameter CPOL = 0, // 0 or 1 -- sclk phase
    parameter MOSI_PHA = 0, // 0 or 1 -- if 0, MOSI shifts in the lagging sclk edge
    parameter MISO_PHA = 0,  // 0 or 1 -- if 0, MISO shifts out on the leading sclk edge
    parameter MSB_FIRST = 1 // if non-zero, shift the MSb in/out first
)(
    input wire clk,
    input wire reset,

    output wire mosi_valid, //pulse: mosi_word can be read
    output reg [WordWidth-1:0] mosi_word,
    input wire [WordWidth-1:0] miso_word_in,
    output wire miso_accepted,

    input wire ssel,
    input wire sclk,
    input wire mosi,
    output wire miso 
);

//normalize ssel to active high:
//normalize and gate sclk:
wire ssel_norm = (ssel == SPOL[0]);
wire sclk_norm = ~(ssel_norm && (sclk == CPOL));
//synchronize ssel and sclk in their normalized forms
wire ssel_sync, sclk_sync; 
synchronizer #(
    .Width(2), 
    .Stages(SyncStages),   //number of shift registers
    .Init(0),     //if nonzero, initialize each register to InitValue
    .InitValue(2'b01) //initial & reset value
) ssel_sclk_sync (
    .clk(clk),   //in: output clock
    .reset(reset), //in: active high reset
    .in({ssel_norm, sclk_norm}), //in [Width]: data in
    .out({ssel_sync, sclk_sync}) //out [Width]: data out, delayed by Stages clk cycles
);

//state
reg idle, idle_D;
reg last, last_D;
reg [IndexWidth-1:0] cycle, cycle_D;
reg skip, skip_D;

//we have to do this double register thing to get a proper one-shot pulse in
// the clk domain
reg miso_ack, miso_ack_D;
reg miso_ack_gate, miso_ack_gate_D;
assign miso_accepted = miso_ack & miso_ack_gate;

reg mosi_val, mosi_val_D;
reg mosi_val_gate, mosi_val_gate_D;
assign mosi_valid = mosi_val & mosi_val_gate;

reg [WordWidth-1:0] miso_word, miso_word_D;
reg [WordWidth-1:0] mosi_word_D;

function [WordWidth-1:0] shift;
    input [WordWidth-1:0] word;
    input bit;
    if(MSB_FIRST == 0) shift = {bit, word[WordWidth-1:1]};
    else shift = {word[WordWidth-2:0], bit};
endfunction

generate
if(MSB_FIRST == 0) begin
    assign miso = miso_word[0];
end else begin
    assign miso = miso_word[WordWidth-1];
end
endgenerate

//combinational logic
always @* begin
    //defaults
    mosi_word_D = mosi_word;
    miso_word_D = miso_word;
    
    miso_ack_D = 0;
    mosi_val_D = 0;
    miso_ack_gate_D = miso_ack_gate;
    mosi_val_gate_D = mosi_val_gate;

    idle_D = idle;
    if(cycle == 0) cycle_D = WordWidth - 1;
    else cycle_D = cycle - 1;
    
    skip_D = skip;
    if(mosi_val == 1) mosi_word_D = 0; //reset mosi

    //one-shot pulses for miso_accepted and mosi_valid
    if(miso_ack == 1'b1) begin
        miso_ack_gate_D = 1'b0;
        mosi_val_gate_D = 1'b1;
    end
    if(mosi_val == 1'b1) mosi_val_gate_D = 1'b0;

    if(idle == 1'b1) begin
        //we need to be ready to send data at a moment's notice
        miso_ack_gate_D = 1'b1;
        miso_word_D = miso_word_in;
        mosi_word_D = 0;
        cycle_D = WordWidth-1;
        last_D = 0;
        if(MISO_PHA == 1) skip_D = 1;
        if(ssel_sync == 1'b1) begin
            //start a transfer
            idle_D = 1'b0;
            miso_ack_D = 1;
        end
    end else begin
        if(last == 1'b0) begin
            if(ssel_sync == 1'b1) begin
                mosi_word_D = shift(mosi_word, mosi);
                
                if(skip == 1)  begin
                    skip_D = 0; //skip the first shift
                    miso_ack_D = 1;
                end
                else miso_word_D = shift(miso_word, 1'b0);

                if(cycle == 0) begin 
                    mosi_val_D = 1;
                    last_D = 1'b1;
                    cycle_D = WordWidth-1;
                    miso_ack_gate_D = 1'b1;
                    if(MISO_PHA == 0) begin
                        miso_word_D = miso_word_in;
                    end
                end
            end else begin
                //ssel went low early
                //quit
                idle_D = 1'b1;
            end
        end else begin //last == 1'b1
            //it's the last sclk low pulse
            miso_word_D = miso_word_in;
            if(ssel_sync == 1'b1) begin
                miso_ack_D = 1'b1;
                last_D = 1'b0;
                if(MOSI_PHA == 0) begin
                    mosi_word_D = shift(mosi_word, mosi);
                    if(cycle == 0) mosi_val_D = 1;
                end
            end else begin
                idle_D = 1'b1;
            end
        end
    end
end

//registers on the system clock
always @(posedge clk) begin
    if(reset) begin
        idle <= 1'b1;
        mosi_val_gate <= 1'b0;
        miso_ack_gate <= 1'b0;
    end else begin
        idle <= idle_D;
        mosi_val_gate <= mosi_val_gate_D;
        miso_ack_gate <= miso_ack_gate_D;
    end
end

//registers on sclk
always @(posedge sclk_sync) begin
    if(MOSI_PHA == 0) begin
        mosi_word <= mosi_word_D;
        mosi_val <= mosi_val_D;
    end
    if(MISO_PHA == 1) begin
        miso_word <= miso_word_D;
        miso_ack <= miso_ack_D;
    end
end

always @(negedge sclk_sync) begin
    skip <= skip_D;
    cycle <= cycle_D;
    last <= last_D;
    if(MOSI_PHA == 1) begin
        mosi_word <= mosi_word_D;
        mosi_val <= mosi_val_D;
    end
    if(MISO_PHA == 0) begin
        miso_word <= miso_word_D;
        miso_ack <= miso_ack_D;
    end
end

endmodule