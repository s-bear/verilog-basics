`timescale 1ns / 10ps
/*
spi_master.v
2019-03-27 Samuel B. Powell
samuel.powell@uq.edu.au

Basic SPI master with variable length transfers and a few protocol and timing 
options. Most notably, MISO and MOSI may have different phases.

spi_master #(
    .WordWidth(8),  // bits per word
    .IndexWidth(3), // ceil(log2(WordWidth))
    .SPOL(0),    // 0 or 1 -- if 0, SSEL is active low (typical)
    .CPOL(0),     // 0 or 1 -- sclk phase
    .MOSI_PHA(0), // 0 or 1 -- if 0, MOSI shifts out on the leading sclk edge
    .MISO_PHA(0), // 0 or 1 -- if 0, MISO shifts in on the lagging sclk edge
    .MSB_FIRST(1), // if nonzero, shift the MSb in/out first
    .TimerWidth(2), // bits for the sclk timer -- enough to count to T_sclk
    .T_sclk(2),     // sclk period, in clk tick counts. must be at least 2
    .T_sclk_cpol(1) // sclk time in the CPOL phase. must be at least 1
) spi_master_0 (
    .clk(),   // system clock
    .reset(), // system reset
    .transfer(),   //  in: begin a transfer. assert until accepted
    .nbits_m1(), //  in [IndexWidth]: number of bits to transfer, minus 1
    .mosi_word_in(), //  in [WordWidth]: word to transfer. hold until accepted
    .mosi_accepted(),   // out: one-shot pulse when a transfer begins
    .miso_valid(), // out: one-shot pulse when miso_word is valid to read
    .miso_word(), // out [WordWidth]: received word. unstable until miso_valid
    .ssel(), // out: slave select
    .sclk(), // out: SPI clock
    .mosi(), // out: master out, slave in
    .miso()  //  in: master in, slave out
);
*/

module spi_master #(
    parameter WordWidth = 8,
    parameter IndexWidth = 3,
    parameter SPOL = 0,
    parameter CPOL = 0,
    parameter MOSI_PHA = 0,
    parameter MISO_PHA = 0,
    parameter MSB_FIRST = 1,
    parameter TimerWidth = 2,
    parameter T_sclk = 2, //clk cycles (min 2, > T_sclk_cpol)
    parameter T_sclk_cpol = 1 //clk cycles (min 1)
)(
    input wire clk,
    input wire reset,

    input wire transfer,
    input wire [IndexWidth-1:0] nbits_m1,
    input wire [WordWidth-1:0] mosi_word_in,
    output reg mosi_accepted,   //pulse: transfer data was accepted
    output reg miso_valid, //pulse: miso_word can be read
    output reg [WordWidth-1:0] miso_word,
    
    output reg ssel,
    output reg sclk,
    output wire mosi,
    input wire miso
);

localparam T_sclk_p = T_sclk_cpol - 1;
localparam T_sclk_n = T_sclk - T_sclk_cpol - 1;

//states
localparam IDLE = 0;
localparam RUN = 1;
localparam NEW = 2;
localparam END = 3;

reg [1:0] state, state_D;
reg skip, skip_D;
reg [IndexWidth-1:0] cycle, cycle_D;
reg [TimerWidth-1:0] timer, timer_D;

reg ssel_D, sclk_D, mosi_D, mosi_accepted_D, miso_valid_D;
reg [WordWidth-1:0] mosi_word, mosi_word_D;
reg [WordWidth-1:0] miso_word_D;

generate
if(MSB_FIRST == 0)
    assign mosi = mosi_word[0];
else
    assign mosi = mosi_word[WordWidth-1];
endgenerate

//combinational logic
always @* begin
    //by default, don't change registers
    mosi_accepted_D = 0;   //one-shot pulse
    miso_valid_D = 0; //one-shot pulse
    mosi_word_D = mosi_word;
    miso_word_D = miso_word;
    ssel_D = ssel;
    sclk_D = sclk;
    mosi_D = mosi;
    state_D = state;
    skip_D = skip;
    cycle_D = cycle;
    timer_D = timer;
    //count-down timer
    if (timer > 0) timer_D = timer - 1;

    if(miso_valid) miso_word_D = 0; //reset miso_word

    //state machine
    case(state)
    IDLE: if(transfer == 1) begin
        state_D = RUN;
        cycle_D = nbits_m1;
        if(MOSI_PHA == 1) skip_D = 1; //skip the first output shift
        mosi_word_D = mosi_word_in;
        miso_word_D = 0;
        mosi_accepted_D = 1;
        ssel_D = SPOL; //assert ssel
        sclk_D = CPOL;
        timer_D = T_sclk_p;
    end
    RUN: if(timer == 0) begin
        if(sclk == CPOL) begin //sclk: CPOL to ~CPOL
            sclk_D = ~CPOL;
            timer_D = T_sclk_n;
            if(MOSI_PHA == 1) begin //shift next MOSI bit out
                if(skip == 1) skip_D = 0; //skip the first shift
                else begin
                    if(MSB_FIRST == 0)
                        mosi_word_D = {1'b0, mosi_word[WordWidth-1:1]};
                    else
                        mosi_word_D = {mosi_word[WordWidth-2:0], 1'b0};
                end
            end
            if(MISO_PHA == 0) begin //shift next MISO bit in
                if(MSB_FIRST == 0)
                    miso_word_D = {miso, miso_word[WordWidth-1:1]};
                else
                    miso_word_D = {miso_word[WordWidth-2:0], miso};
                if(cycle == 0) miso_valid_D = 1;
            end
        end else begin //sclk: ~CPOL to CPOL
            sclk_D = CPOL;
            timer_D = T_sclk_p;
            if(MOSI_PHA == 0) begin //shift next MOSI bit out
                if(MSB_FIRST == 0)
                    mosi_word_D = {1'b0, mosi_word[WordWidth-1:1]};
                else
                    mosi_word_D = {mosi_word[WordWidth-2:0], 1'b0};
            end
            if(MISO_PHA == 1) begin //shift next MISO bit in
                if(MSB_FIRST == 0)
                    miso_word_D = {miso, miso_word[WordWidth-1:1]};
                else
                    miso_word_D = {miso_word[WordWidth-2:0], miso};
                if(cycle == 0) miso_valid_D = 1;
            end
            if(cycle > 0) begin
                cycle_D = cycle - 1;
            end else begin
                if(transfer == 1) begin //start a new transfer
                    cycle_D = nbits_m1;
                    if(MOSI_PHA == 0) begin //we can begin now
                        mosi_accepted_D = 1;
                        mosi_word_D = mosi_word_in; //also changes mosi
                    end else begin // we need to start on the next half-cycle
                        state_D = NEW;
                    end
                end else begin
                    //we're done, do the last half-cycle of the clock
                    state_D = END;
                end
            end
        end
    end
    NEW:
    //we're starting a new transfer immediately after the previous
    //but this is a special case for when MOSI_PHA == 1
    if(timer == 0) begin //like a CPOL to ~CPOL transition
        state_D = RUN;
        sclk_D = ~CPOL;
        timer_D = T_sclk_n;
        mosi_word_D = mosi_word_in;
        mosi_accepted_D = 1;
        if(MISO_PHA == 0) begin //we have to shift MISO in
            if(MSB_FIRST == 0)
                miso_word_D = {miso, miso_word[WordWidth-1:1]};
            else
                miso_word_D = {miso_word[WordWidth-2:0],miso};
            if(cycle == 0) miso_valid_D = 1;
        end
    end
    END:
    if(timer == 0) begin
        state_D = IDLE;
        ssel_D = ~SPOL; //release ssel
    end
    endcase
end

//registers: D flip-flops, synchronous reset, always enabled
always @(posedge clk) begin
    if(reset) begin
        mosi_accepted <= 0;
        miso_valid <= 0;
        miso_word <= 0;
        mosi_word <= 0;
        ssel <= ~SPOL;
        sclk <= CPOL;
        state <= IDLE;
        cycle <= 0;
        skip <= 0;
        timer <= 0;
    end else begin
        mosi_accepted <= mosi_accepted_D;
        miso_valid <= miso_valid_D;
        miso_word <= miso_word_D;
        mosi_word <= mosi_word_D;
        ssel <= ssel_D;
        sclk <= sclk_D;
        state <= state_D;
        cycle <= cycle_D;
        skip <= skip_D;
        timer <= timer_D;
    end
end


endmodule