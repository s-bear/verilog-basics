`timescale 1ns/10ps
/*
uart.v
(C) 2019-04-12 Samuel B Powell
samuel.powell@uq.edu.au

UART module with hardware flow control and a FIFO interface.

The module will resynchronize its timers at the start of each word, even during
  the last half of the final stop bit.

The module will not start a transmission unless tx_start == 1 and cts_n == 0. To
  ensure that the module has started transmission, keep tx_start asserted at
  least until tx_active is asserted.

For half-duplex operation, you can use the rx_active and tx_active outputs to
  gate tx_start and rx_enable, respectively:
    .rx_enable(~tx_active && ( ... )),
    .tx_start(~rx_active && ( ... )),
  Additionally, use tx_active to control tristate output:
    assign transmission_line = tx_active ? txd : 1'bZ;
  When operating in half-duplex mode you need to be careful of contention on the
    transmission line. This can be done through hardware flow control, but that
    seems unlikely if you're minimizing wires enough that you need half-duplex
    comm's. Consider using a master/slave protocol with clearly delimited
    messages. E.g: master sends "command;" and then waits until it receives
    from the slave "command:response;" before sending another message. The slave
    would buffer received bytes until it receives a ";" then echo the command as
    an acknowledgement, process the command, send the response, and ";" to end.
    An alternative would be for the slave to immediately echo each received byte
    but such a protocol would be annoying to program on a PC.

The Cooldown parameter keeps rx_active asserted for a number of baud periods
  after the last stop bit was received just in case our timers are running
  fast and the (other) transmitter begins a new transmission soon after we
  assert rx_done.

uart #(
    .ClkFreq(50000000), //in Hz
    .BaudRate(9600),
    .DataBits(8),   //typically 7 or 8
    .StopBits(1),   //typically 1 or 2
    .ParityBits(0), //0 or 1
    .ParityOdd(1),  //0 for even parity, 1 for odd
    .Samples(8),    //number of samples per baud
    .Cooldown(1)    //baud periods after stop bit before rx_active deasserts
) uart_0 (
    .clk(),
    .reset(),
    //RX FIFO interface
    .rx_enable(),  // in: assert when ready to receive data
    .rx_word(),    //out [DataBits]: valid when rx_done is asserted and rx_error is 0
    .rx_error(),   //out: asserted when an error is detected during parity or stop bits. remains asserted until rx_done
    .rx_done(),    //out: asserted for a single cycle when rx finishes
    .rx_active(),  //out: asserted while the RX state machine is active
    //TX FIFO interface
    .tx_start(),   // in: a transfer begins if (tx_start & ~cts_n)
    .tx_word(),    // in [DataBits]
    .tx_done(),    //out: asserted for a single cycle when tx finishes
    .tx_active(),  //out: asserted while the TX state machine is active
    // UART interface
    .rtr_n(),   //out: ready to receive, active low
    .cts_n(),   // in: clear to send, active low
    .rxd(),     // in: received data
    .txd()      //out: transmitted data
);
*/

module uart #(
    parameter ClkFreq = 50000000,
    parameter BaudRate = 9600,
    parameter DataBits = 8,
    parameter StopBits = 1,
    parameter ParityBits = 0,
    parameter ParityOdd = 1,
    parameter Samples = 8,
    parameter Cooldown = 1
)(
    input wire clk,
    input wire reset,
    //RX FIFO interface
    input wire rx_enable,
    output reg [DataBits-1:0] rx_word,
    output reg rx_error,
    output reg rx_done,
    output wire rx_active,
    //TX FIFO interface
    input wire tx_start,
    input wire [DataBits-1:0] tx_word,
    output reg tx_done,
    output wire tx_active,
    //UART interface
    output wire rtr_n, //out: ready to receive, active low
    input wire cts_n, // in: clear to send, active low
    input wire rxd, // in: received data
    output reg txd  //out: transmitted data
);

//get clog2
`include "functions.vh"

//how many clocks is each Baud 
localparam BaudCount = ClkFreq / BaudRate;
localparam SampleCount = ClkFreq / (BaudRate*Samples);
localparam FirstSampleCount = BaudCount - SampleCount*(Samples-1); //account for the remainder
localparam SampleBits = clog2(Samples);
localparam BaudTBits = clog2(BaudCount);

/* RECEIVER STATES */
localparam [3:0]
    RX_IDLE     = 0,
    RX_START    = 1,
    RX_DATA     = 2,
    RX_PARITY   = 3,
    RX_STOP     = 4,
    RX_HOLD     = 5,
    RX_COOLDOWN = 6;

/* RECEIVER REGISTERS */
reg [3:0] rx_state, rx_state_D;
reg [2:0] rx_bit, rx_bit_D;
reg rx_error_D, rx_done_D;
reg [DataBits-1:0] rx_word_D;
reg rx_parity, rx_parity_D;
reg [SampleBits-1:0] rx_samples, rx_samples_D, rx_sample_count, rx_sample_count_D;
reg [BaudTBits-1:0] rx_timer, rx_timer_D;

/* RECEIVER LOGIC */
assign rtr_n = ~rx_enable | rx_error;
wire rx_sample_bit = (rx_samples >= Samples/2);
assign rx_active = !(rx_state == RX_IDLE || rx_state == RX_HOLD);
always @* begin
    rx_state_D = rx_state;
    rx_bit_D = rx_bit;
    rx_error_D = rx_error;
    rx_done_D = 0; //1-shot pulse
    rx_word_D = rx_word;
    rx_parity_D = rx_parity;
    rx_samples_D = rx_samples;
    rx_sample_count_D = rx_sample_count;
    rx_timer_D = rx_timer;
    
    //reset the error state when we finish an rx cycle
    if(rx_done) rx_error_D = 0;

    //timer and sampling logic
    if(rx_timer > 0) begin
        //decrement the timer
        rx_timer_D = rx_timer - 1;
    end else if(rx_sample_count > 0) begin
        //take another sample
        rx_samples_D = rx_samples + rxd;
        rx_sample_count_D = rx_sample_count - 1;
        rx_timer_D = SampleCount - 1;
    end

    //state machine
    case(rx_state)
    RX_IDLE: if(rx_enable == 1'b1 && rxd == 1'b0) begin
        //we've detected a start bit. begin sampling
        rx_samples_D = 0;
        rx_sample_count_D = Samples-1;
        rx_timer_D = FirstSampleCount-1;
        rx_state_D = RX_START;
    end
    RX_START: begin //reading the start bit
        if(rx_timer == 0 && rx_sample_count == 0) begin
            if(rx_sample_bit == 1'b0) begin
                //start!
                rx_state_D = RX_DATA;
                rx_samples_D = 0;
                rx_sample_count_D = Samples-1;
                rx_timer_D = FirstSampleCount-1;
                rx_bit_D = DataBits-1;
                rx_word_D = 0;
                rx_parity_D = ParityOdd[0];
            end else begin
                //don't start
                rx_state_D = RX_IDLE;
            end
        end
    end
    RX_DATA: begin //read the data bits
        if(rx_timer == 0 && rx_sample_count == 0) begin
            //shift the next bit in:
            rx_word_D = {rx_sample_bit, rx_word[DataBits-1:1]};
            rx_parity_D = rx_parity ^ rx_sample_bit;
            //prepare for the next set of samples
            rx_samples_D = 0;
            rx_sample_count_D = Samples-1;
            rx_timer_D = FirstSampleCount-1;
            //was that the last bit of the word?
            if(rx_bit == 0) begin
                //move on to either the parity bit or the stop bit(s)
                if(ParityBits == 0) begin
                    rx_state_D = RX_STOP;
                    rx_bit_D = StopBits-1;
                end else begin
                    rx_state_D = RX_PARITY;
                end
            end else begin
                //move on to the next data bit
                rx_bit_D = rx_bit - 1;
            end
        end
    end
    RX_PARITY: begin
        if(rx_timer == 0 && rx_sample_count == 0) begin
            if(rx_sample_bit != rx_parity) begin
                //uh oh! the parity bit didn't match D:
                rx_error_D = 1'b1;
            end
            //we'll read the STOP bits regardless
            rx_state_D = RX_STOP;
            rx_bit_D = StopBits-1;
            rx_samples_D = 0;
            rx_sample_count_D = Samples-1;
            rx_timer_D = FirstSampleCount-1;
        end
    end
    RX_STOP: begin
        if(rx_bit == 0) begin //the last stop bit
            if(rx_sample_bit == 1'b1 && rxd == 1'b0) begin
                //the start bit came early
                if(rx_enable == 1'b1) begin
                    //we can start a new cycle
                    rx_done_D = 1'b1;
                    rx_samples_D = 0;
                    rx_sample_count_D = Samples-1;
                    rx_timer_D = FirstSampleCount-1;
                    rx_state_D = RX_START;
                end else begin
                    //we have to wait to be enabled again
                    //is the transmitter respecting flow control??
                    rx_state_D = RX_HOLD;
                end
            end else if (rx_timer == 0 && rx_sample_count == 0) begin
                //the timer expired
                if(rx_sample_bit == 1'b0) begin
                    //uh oh! we got the wrong bit D:
                    rx_error_D = 1'b1; 
                end
                if(rx_enable == 1'b1) begin
                    //we can keep going
                    rx_done_D = 1'b1;
                    if(rxd == 1'b0) begin
                        //and start a new cycle
                        rx_samples_D = 0;
                        rx_sample_count_D = Samples-1;
                        rx_timer_D = FirstSampleCount-1;
                        rx_state_D = RX_START;
                    end else begin
                        //and wait for a new cycle
                        if(Cooldown > 0) begin
                            rx_samples_D = 0;
                            rx_sample_count_D = Samples-1;
                            rx_timer_D = FirstSampleCount-1;
                            rx_state_D = RX_COOLDOWN;
                        end else begin
                            rx_state_D = RX_IDLE;
                        end
                    end
                end else begin
                    //we have to wait to be enabled again
                    rx_state_D = RX_HOLD;
                end
            end
        end else if(rx_timer == 0 && rx_sample_count == 0) begin
            //timer expired, go to the next stop bit
            rx_bit_D = rx_bit - 1;
            rx_samples_D = 0;
            rx_sample_count_D = Samples-1;
            rx_timer_D = FirstSampleCount - 1;
        end
    end
    RX_HOLD: if(rx_enable == 1'b1) begin
        //if rx_enable went low while we were receiving data, we'll keep it
        //in our register until it goes high again
        rx_done_D = 1;
        rx_state_D = RX_IDLE;
    end
    RX_COOLDOWN: begin
        //like RX_IDLE but it keeps rx_active asserted until the timers expire
        if(rxd == 1'b0) begin //start bit
            rx_samples_D = 0;
            rx_sample_count_D = Samples-1;
            rx_timer_D = FirstSampleCount-1;
            rx_state_D = RX_START;
        end else if(rx_timer == 0 && rx_sample_count == 0) begin
            if(rx_bit == 0) begin
                rx_state_D = RX_IDLE;
            end else begin
                rx_bit_D = rx_bit - 1;
                rx_samples_D = 0;
                rx_sample_count_D = Samples-1;
                rx_timer_D = FirstSampleCount-1;
            end
        end
    end
    endcase
end

/* TRANSMITTER STATES */
localparam [2:0]
    TX_IDLE     = 0,
    TX_START    = 1,
    TX_DATA     = 2,
    TX_PARITY   = 3,
    TX_STOP     = 4,
    TX_DONE     = 5;

/* TRANSMITTER REGISTERS */
reg [2:0] tx_state, tx_state_D;
reg [2:0] tx_bit, tx_bit_D;
reg tx_done_D, txd_D;
reg [DataBits-1:0] tx_word_sr, tx_word_sr_D;
reg [BaudTBits-1:0] tx_timer, tx_timer_D;
reg tx_parity, tx_parity_D;

reg [2:0] cts_sync_reg; //synchronizer shift register for cts_n
wire cts_sync = cts_sync_reg[0];

/* TRANSMITTER LOGIC */
assign tx_active = (tx_state != TX_IDLE);
always @* begin
    tx_state_D = tx_state;
    tx_bit_D = tx_bit;
    tx_done_D = 0; //one-shot
    txd_D = txd;
    tx_word_sr_D = tx_word_sr;
    tx_timer_D = tx_timer;
    tx_parity_D = tx_parity;
    //countdown timer
    if(tx_timer > 0) tx_timer_D = tx_timer - 1;
    case(tx_state)
    TX_IDLE: begin
        if(cts_sync == 1'b1 && tx_start == 1'b1) begin
            tx_state_D = TX_START;
            tx_word_sr_D = tx_word;
            tx_timer_D = BaudCount-1;
            tx_parity_D = ParityOdd[0];
            txd_D = 1'b0; //start bit
        end
    end
    TX_START: begin
        if(tx_timer == 0) begin
            tx_timer_D = BaudCount-1;
            tx_state_D = TX_DATA;
            tx_bit_D = DataBits-1;
            tx_parity_D = tx_parity ^ tx_word_sr[0];
            txd_D = tx_word_sr[0];
            tx_word_sr_D = {1'b1, tx_word_sr[DataBits-1:1]};
        end
    end
    TX_DATA: begin
        if(tx_timer == 0) begin
            tx_timer_D = BaudCount-1;
            if(tx_bit == 0) begin
                if(ParityBits == 0) begin
                    tx_state_D = TX_STOP;
                    tx_bit_D = StopBits-1;
                    txd_D = 1'b1;
                end else begin
                    tx_state_D = TX_PARITY;
                    txd_D = tx_parity;
                end
            end else begin
                tx_bit_D = tx_bit - 1;
                txd_D = tx_word_sr[0];
                tx_parity_D = tx_parity ^ tx_word_sr[0];
                tx_word_sr_D = {1'b1, tx_word_sr[DataBits-1:1]};
            end
        end
    end
    TX_PARITY: begin
        if(tx_timer == 0) begin
            tx_timer_D = BaudCount-1;
            tx_state_D = TX_STOP;
            tx_bit_D = StopBits-1;
            txd_D = 1'b1;
        end
    end
    TX_STOP: begin
        if(tx_timer == 0) begin
            if(tx_bit == 0) begin
                tx_state_D = TX_DONE;
                tx_done_D = 1'b1;
            end else begin
                tx_timer_D = BaudCount-1;
                tx_bit_D = tx_bit - 1;
            end
        end
    end
    TX_DONE: begin
        tx_state_D = TX_IDLE;
    end
    endcase
end

//flip flops
always @(posedge clk) begin
    if(reset) begin
        //receiver
        rx_state <= RX_IDLE;
        rx_bit <= 0;
        rx_error <= 0;
        rx_done <= 0;
        rx_word <= 0;
        rx_parity <= 0;
        rx_samples <= 0;
        rx_sample_count <= 0;
        rx_timer <= 0;
        //transmitter
        tx_state <= TX_IDLE;
        tx_bit <= 0;
        tx_done <= 0;
        txd <= 1'b1; //idle high
        tx_word_sr <= 0;
        tx_timer <= 0;
        tx_parity <= 0;
        cts_sync_reg <= 0;
    end else begin
        //receiver
        rx_state <= rx_state_D;
        rx_bit <= rx_bit_D;
        rx_error <= rx_error_D;
        rx_done <= rx_done_D;
        rx_word <= rx_word_D;
        rx_parity <= rx_parity_D;
        rx_samples <= rx_samples_D;
        rx_sample_count <= rx_sample_count_D;
        rx_timer <= rx_timer_D;
        //transmitter
        tx_state <= tx_state_D;
        tx_bit <= tx_bit_D;
        tx_done <= tx_done_D;
        txd <= txd_D;
        tx_word_sr <= tx_word_sr_D;
        tx_timer <= tx_timer_D;
        tx_parity <= tx_parity_D;
        cts_sync_reg <= {~cts_n, cts_sync_reg[2:1]};
    end
end

endmodule