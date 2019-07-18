`timescale 1ns/10ps
/*
test_uart_half_duplex.v
(C) 2019-07-18 Samuel B Powell
samuel.powell@uq.edu.au

This test is organized as a loopback:
fifo_0 -> uart_0 -> uart_1 -> fifo_1 -> uart_1 -> uart_0

fifo_1's capacity is lower than fifo_0, so that the flow control signals will
be involved and we should see interleaved communication

*/

module test_uart_half_duplex;

initial begin
    $dumpfile("test_uart_half_duplex.fst");
    $dumpvars(-1,test_uart_half_duplex);
end

parameter clk_t = 20; // 50 MHz

reg clk, reset;
always #(clk_t/2) clk = ~clk;

parameter ClkFreq = 1000000000/clk_t;
parameter BaudRate = 19200;
parameter DataBits = 8;
parameter StopBits = 1;
parameter ParityBits = 1;
parameter ParityOdd = 1;
parameter Samples = 8;
parameter Cooldown = 1;

wire f0_empty;
wire u0_rx_done, u0_rx_error, u0_rx_active;
wire u0_tx_done, u0_tx_active;
wire u0_rtr_n, u0_cts_n, u0_txd, u0_rxd;
wire [7:0] u0_tx_word, u0_rx_word;

fifo_sync #(
    .DataWidth(8),
    .DataDepth(16),
    .AddrWidth(4),
    .InitFile("test_data.hex"),
    .InitCount(16)
) fifo_0 (
    .clk(clk),
    .reset(1'b0), //no reset bcs we read from hex file!
    .write_en(0),
    .write_data(0), //[DataWidth-1:0]
    .fifo_full(),
    .read_en(u0_tx_done),
    .read_data(u0_tx_word), //[DataWidth-1:0]
    .fifo_empty(f0_empty)
);

uart #(
    .ClkFreq(ClkFreq), //in Hz
    .BaudRate(BaudRate),
    .DataBits(DataBits),   //typically 7 or 8
    .StopBits(StopBits),   //typically 1 or 2
    .ParityBits(ParityBits), //0 or 1
    .ParityOdd(ParityOdd),
    .Samples(Samples),    //number of samples per baud
    .Cooldown(Cooldown)    //baud periods after stop bit before rx_active deasserts
) uart_0 (
    .clk(clk),
    .reset(reset),
    //RX FIFO interface
    .rx_enable(~u0_tx_active),  // in: assert when ready to receive data
    .rx_word(u0_rx_word),    //out [DataBits]: valid when rx_done is asserted
    .rx_error(u0_rx_error),   //out: asserted when an error is detected during parity or stop bits
    .rx_done(u0_rx_done), //out: asserted for a single cycle when rx finishes
    .rx_active(u0_rx_active),
    //TX FIFO interface
    .tx_start(~u0_rx_active && ~f0_empty), // in: a transfer begins if (tx_start & ~cts_n)
    .tx_word(u0_tx_word),       // in [DataBits]
    .tx_done(u0_tx_done),    //out: asserted for a single cycle when tx finishes
    .tx_active(u0_tx_active),
    // UART interface
    .rtr_n(u0_rtr_n),   //out: ready to receive, active low
    .cts_n(u0_cts_n),   // in: clear to send, active low
    .rxd(u0_rxd),     // in: received data
    .txd(u0_txd)      //out: transmitted data
);

wire f1_full, f1_empty;
wire u1_rx_done, u1_rx_error, u1_rx_active;
wire u1_tx_done, u1_tx_active;
wire u1_rtr_n, u1_cts_n, u1_txd, u1_rxd;
wire [7:0] u1_tx_word, u1_rx_word;

//the shared transmission line:
wire transmission_line;
assign transmission_line = u0_tx_active ? u0_txd : 1'bZ;
assign u0_rxd = transmission_line;

assign transmission_line = u1_tx_active ? u1_txd : 1'bZ;
assign u1_rxd = transmission_line;

assign u1_cts_n = u0_rtr_n; //u1 is clear to send when u0 is ready to receive
assign u0_cts_n = u1_rtr_n; //and vice versas

uart #(
    .ClkFreq(ClkFreq), //in Hz
    .BaudRate(BaudRate),
    .DataBits(DataBits),   //typically 7 or 8
    .StopBits(StopBits),   //typically 1 or 2
    .ParityBits(ParityBits), //0 or 1
    .ParityOdd(ParityOdd),
    .Samples(Samples),    //number of samples per baud
    .Cooldown(Cooldown)    //baud periods after stop bit before rx_active deasserts
) uart_1 (
    .clk(clk),
    .reset(reset),
    //RX FIFO interface
    .rx_enable(~u1_tx_active && ~f1_full),  // in: assert when ready to receive data
    .rx_word(u1_rx_word),    //out [DataBits]: valid when rx_done is asserted
    .rx_error(u1_rx_error),   //out: asserted when an error is detected during parity or stop bits
    .rx_done(u1_rx_done), //out: asserted for a single cycle when rx finishes
    .rx_active(u1_rx_active),
    //TX FIFO interface
    .tx_start(~u1_rx_active && ~f1_empty), // in: a transfer begins if (tx_start & ~cts_n)
    .tx_word(u1_tx_word),       // in [DataBits]
    .tx_done(u1_tx_done),    //out: asserted for a single cycle when tx finishes
    .tx_active(u1_tx_active),
    // UART interface
    .rtr_n(u1_rtr_n),   //out: ready to receive, active low
    .cts_n(u1_cts_n),   // in: clear to send, active low
    .rxd(u1_rxd),     // in: received data
    .txd(u1_txd)      //out: transmitted data
);

fifo_sync #(
    .DataWidth(8),
    .DataDepth(4),
    .AddrWidth(2),
    .InitFile(""),
    .InitCount(0)
) fifo_1 (
    .clk(clk),
    .reset(reset), //no reset bcs we read from hex file!
    .write_en(u1_rx_done),
    .write_data(u1_rx_word), //[DataWidth-1:0]
    .fifo_full(f1_full),
    .read_en(u1_tx_done),
    .read_data(u1_tx_word), //[DataWidth-1:0]
    .fifo_empty(f1_empty)
);

initial begin
    clk = 1;
    reset = 0;
    @(negedge clk);
    #(3*clk_t);
    reset = 1;
    #clk_t;
    reset = 0;
    //wait until fifo_0 is empty
    @(posedge f0_empty);
    //then wait until fifo_1 is empty
    @(posedge f1_empty);
    //then a bit more
    #(15*clk_t);
    $finish;
end

endmodule