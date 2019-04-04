`timescale 1ns / 10ps

/*
spi_slave.v
2019-03-29 Samuel B Powell
samuel.powell@uq.edu.au

Basic SPI slave with a few protocol options. Most
notably, MISO and MOSI may have different phases.

While SSEL is asserted, every sclk cycle shifts another bit in/out.
As soon as WordWidth bits are shifted in, or SSEL is unasserted, mosi_valid is
 pulsed for a single clk cycle--indicating that it may be read.
When SSEL is asserted the slave registers miso_word_in to shift out. As soon as
WordWidth bits are shifted out, the next word is accepted.
if SSEL is deasserted before WordWidth bits are shifted and while sclk == CPOL,
 and OUTPUT_PARTIAL is nonzero, then mosi_valid will pulsed. Otherwise, partial
 transfers are discarded.

MISO is provided via a basic interface: when a transfer begins (ssel is asserted)
miso_word_in is latched and miso_accepted is asserted for a single cycle. Every time
WordWidth bits are shifted out, this repeats. This allows a first-word fall-through
FIFO to easily provide data to the slave.

NB: Assumes that select, sclk, and mosi are externally synchronized to clk.
This module also does not attempt clock recovery, so miso will lag sclk by a
 cycle of clk -- to avoid timing issues, clk must be sufficiently faster than
 sclk!

spi_slave #(
    .WordWidth(8), // bits per word
    .IndexWidth(3), // ceil(log2(WordWidth))
    .SPOL(0), // 0 or 1 -- if 0, SSEL is active low (typical)
    .CPOL(0), // 0 or 1 -- sclk phase
    .MOSI_PHA(0), // 0 or 1 -- if 0, MOSI shifts in on the lagging sclk edge
    .MISO_PHA(0), // 0 or 1 -- if 0, MISO shifts out on the leading sclk edge
    .MSB_FIRST(1), // if nonzero, shift the MSb in/out first
    .OUTPUT_PARTIAL(0) // if nonzero, trigger mosi_valid on partial transfers
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
    parameter SPOL = 0, // 0 or 1 -- if 0, SSEL is active low (typical)
    parameter CPOL = 0, // 0 or 1 -- sclk phase
    parameter MOSI_PHA = 0, // 0 or 1 -- if 0, MOSI shifts in the lagging sclk edge
    parameter MISO_PHA = 0,  // 0 or 1 -- if 0, MISO shifts out on the leading sclk edge
    parameter MSB_FIRST = 1, // if non-zero, shift the MSb in/out first
    parameter OUTPUT_PARTIAL = 0 // if non-zero, trigger mosi_valid on partial transfers
)(
    input wire clk,
    input wire reset,

    output reg mosi_valid, //pulse: mosi_word can be read
    output reg [WordWidth-1:0] mosi_word,
    input wire [WordWidth-1:0] miso_word_in,
    output reg miso_accepted,

    input wire ssel,
    input wire sclk,
    input wire mosi,
    output wire miso 
);

//states
localparam IDLE = 0;
localparam RUN = 1;
localparam END = 2;

reg [1:0] state, state_D;
reg [IndexWidth-1:0] cycle, cycle_D;
reg skip, skip_D;

reg mosi_valid_D, miso_accepted_D;
reg [WordWidth-1:0] miso_word, miso_word_D;
reg [WordWidth-1:0] mosi_word_D;
reg prev_sclk; //shift register to find edges in sclk

generate
if(MSB_FIRST == 0)
    assign miso = miso_word[0];
else
    assign miso = miso_word[WordWidth-1];
endgenerate

//combinational logic
always @* begin
    //defaults
    mosi_word_D = mosi_word;
    miso_word_D = miso_word;
    miso_accepted_D = 0; //one shot
    state_D = state;
    cycle_D = cycle;
    skip_D = skip;
    mosi_valid_D = 0; //one-shot
    if(mosi_valid == 1) mosi_word_D = 0; //reset mosi

    case(state)
    IDLE: begin
        //we need to be ready to send data at a moment's notice
        miso_word_D = miso_word_in;
        cycle_D = WordWidth-1;
        if(MISO_PHA == 1) skip_D = 1;
        if(ssel == SPOL[0]) begin
            //start a transfer
            state_D = RUN;
            miso_accepted_D = 1;
            mosi_word_D = 0;
        end
    end
    RUN:
    if(ssel == SPOL[0]) begin
        if((prev_sclk == CPOL[0]) && (sclk == ~CPOL[0])) begin
            //sclk: CPOL to ~CPOL (rising edge when CPOL == 0)
            if(MOSI_PHA == 0) begin
                //shift next MOSI bit in
                if(MSB_FIRST == 0)
                    mosi_word_D = {mosi, mosi_word[WordWidth-1:1]};
                else
                    mosi_word_D = {mosi_word[WordWidth-2:0], mosi};
                if(cycle == 0) mosi_valid_D = 1;
            end
            if(MISO_PHA == 1) begin
                //shift next MISO bit out
                if(skip == 1) skip_D = 0; //skip the first shift
                else begin
                    if(MSB_FIRST == 0)
                        miso_word_D = {1'b0, miso_word[WordWidth-1:1]};
                    else
                        miso_word_D = {miso_word[WordWidth-2:0], 1'b0};
                end
            end

        end else if((prev_sclk == ~CPOL[0]) && (sclk == CPOL[0])) begin
            //sclk: ~CPOL to CPOL (falling edge when CPOL == 0)
            if(MOSI_PHA == 1) begin
                //shift next MOSI bit in
                if(MSB_FIRST == 0)
                    mosi_word_D = {mosi, mosi_word[WordWidth-1:1]};
                else
                    mosi_word_D = {mosi_word[WordWidth-2:0], mosi};
                if(cycle == 0) mosi_valid_D = 1;
            end
            if(MISO_PHA == 0) begin
                //shift next MISO bit out
                if(skip == 1) skip_D = 0; //skip the first shift
                else begin
                    if(MSB_FIRST == 0)
                        miso_word_D = {1'b0, miso_word[WordWidth-1:1]};
                    else
                        miso_word_D = {miso_word[WordWidth-2:0], 1'b0};
                end
            end
            if(cycle > 0) begin
                cycle_D = cycle - 1;
            end else begin
                state_D = END;
                cycle_D = WordWidth - 1;
                //if sclk changes again a new cycle would begin
                //we must prepare
                if(MISO_PHA == 0) begin
                    miso_word_D = miso_word_in;
                end
            end
        end
    end else begin //ssel stopped early
        if(OUTPUT_PARTIAL != 0 && (sclk == CPOL[0])) begin
            //it stopped in a valid place
            //we'll output what we've received so far
            mosi_valid_D = 1;
        end
        state_D = IDLE;
    end
    END: begin
        if(ssel == SPOL[0]) begin
            if((prev_sclk == CPOL[0]) && (sclk == ~CPOL[0])) begin //(rising)
                //the clock transitioned again, so we carry on with another word
                miso_word_D = miso_word_in;
                miso_accepted_D = 1;
                state_D = RUN;
                if(MOSI_PHA == 0) begin
                    //shift next MOSI bit in
                    if(MSB_FIRST == 0)
                        mosi_word_D = {mosi, mosi_word[WordWidth-1:1]};
                    else
                        mosi_word_D = {mosi_word[WordWidth-2:0], mosi};
                    if(cycle == 0) mosi_valid_D = 1;
                end
            end
        end else begin //ssel stopped, as expected
            state_D = IDLE;
        end
    end
    endcase
end

//registers, synchronous reset, always enabled
always @(posedge clk) begin
    if(reset) begin
        prev_sclk <= 0;
        state <= IDLE;
        cycle <= 0;
        skip <= 0;
        mosi_valid <= 0;
        mosi_word <= 0;
        miso_accepted <= 0;
        miso_word <= 0;
    end else begin
        prev_sclk <= sclk;
        state <= state_D;
        cycle <= cycle_D;
        skip <= skip_D;
        mosi_valid <= mosi_valid_D;
        mosi_word <= mosi_word_D;
        miso_accepted <= miso_accepted_D;
        miso_word <= miso_word_D;
    end
end

endmodule