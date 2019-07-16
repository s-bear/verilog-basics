`timescale 1ns/10ps
/*

*/

module test_uart;
initial begin
    $dumpfile("test_uart.fst");
    $dumpvars(-1, test_uart);
end

parameter clk_t = 200; //20 ns = 50 MHz
reg clk, reset;
always #(clk_t/2) clk = ~clk;

parameter ClkFreq = 1000000000/clk_t;
//parameter TXBaudRate = 19400; //~1% too fast
parameter TXBaudRate = 19000; //~1% too slow
parameter RXBaudRate = 19200;
parameter DataBits = 8;
parameter StopBits = 1;
parameter ParityBits = 1;
parameter ErrorBits = 1;
parameter Samples = 8;
parameter Cooldown = 1;


wire tx_done, tx_active, tx_fifo_empty;
wire rx_fifo_full, rx_error, rx_done, rx_active;
wire [7:0] tx_word, rx_word;

reg rx_fifo_read_en;
//uart signals as seen from tx_uart's side
wire tx_rtr_n, tx_cts_n, tx_txd, tx_rxd;

fifo_sync #(
    .DataWidth(8),
    .DataDepth(16),
    .AddrWidth(4),
    .InitFile("test_data.hex"),
    .InitCount(16)
) tx_fifo (
    .clk(clk),
    .reset(1'b0), //no reset bcs we read from hex file!
    .write_en(0),
    .write_data(0), //[DataWidth-1:0]
    .fifo_full(),
    .read_en(tx_done),
    .read_data(tx_word), //[DataWidth-1:0]
    .fifo_empty(tx_fifo_empty)
);

uart #(
    .ClkFreq(ClkFreq), //in Hz
    .BaudRate(TXBaudRate),
    .DataBits(DataBits),   //typically 7 or 8
    .StopBits(StopBits),   //typically 1 or 2
    .ParityBits(ParityBits), //0 or 1
    .Samples(Samples),    //number of samples per baud
    .Cooldown(Cooldown)    //baud periods after stop bit before rx_active deasserts
) tx_uart (
    .clk(clk),
    .reset(reset),
    //RX FIFO interface
    .rx_enable(0),  // in: assert when ready to receive data
    .rx_word(),    //out [DataBits]: valid when rx_done is asserted
    .rx_error(),   //out: asserted when an error is detected during parity or stop bits
    .rx_done(), //out: asserted for a single cycle when rx finishes
    .rx_active(),
    //TX FIFO interface
    .tx_start(~tx_fifo_empty), // in: a transfer begins if (tx_start & ~cts_n)
    .tx_word(tx_word),       // in [DataBits]
    .tx_done(tx_done),    //out: asserted for a single cycle when tx finishes
    .tx_active(tx_active),
    // UART interface
    .rtr_n(tx_rtr_n),   //out: ready to receive, active low
    .cts_n(tx_cts_n),   // in: clear to send, active low
    .rxd(tx_rxd),     // in: received data
    .txd(tx_txd)      //out: transmitted data
);

uart #(
    .ClkFreq(ClkFreq), //in Hz
    .BaudRate(RXBaudRate),
    .DataBits(DataBits),   //typically 7 or 8
    .StopBits(StopBits),   //typically 1 or 2
    .ParityBits(ParityBits), //0 or 1
    .Samples(Samples),    //number of samples per baud
    .Cooldown(Cooldown)    //baud periods after stop bit before rx_active deasserts
) rx_uart (
    .clk(clk),
    .reset(reset),
    //RX FIFO interface
    .rx_enable(~rx_fifo_full),  // in: assert when ready to receive data
    .rx_word(rx_word),    //out [DataBits]: valid when rx_done is asserted and rx_error is 0
    .rx_error(rx_error),   //out: asserted when an error is detected during parity or stop bits. remains asserted until rx_done
    .rx_done(rx_done),    //out: asserted for a single cycle when rx finishes
    .rx_active(rx_active),  //out: asserted while the RX state machine is active
    //TX FIFO interface
    .tx_start(0),   // in: a transfer begins if (tx_start & ~cts_n)
    .tx_word(0),    // in [DataBits]
    .tx_done(),    //out: asserted for a single cycle when tx finishes
    .tx_active(),  //out: asserted while the TX state machine is active
    // UART interface
    .rtr_n(tx_cts_n),   //out: ready to receive, active low
    .cts_n(tx_rtr_n),   // in: clear to send, active low
    .rxd(tx_txd),     // in: received data
    .txd(tx_rxd)      //out: transmitted data
);

fifo_sync #(
    .DataWidth(8),
    .DataDepth(8),
    .AddrWidth(3),
    .InitFile(),
    .InitCount(0)
) rx_fifo (
    .clk(clk),
    .reset(reset),
    .write_en(rx_done),
    .write_data(rx_word), //[DataWidth-1:0]
    .fifo_full(rx_fifo_full),
    .read_en(rx_fifo_read_en),
    .read_data(), //[DataWidth-1:0]
    .fifo_empty()
);

initial begin
    clk = 1;
    reset = 0;
    rx_fifo_read_en = 0;
    @(negedge clk);
    #(3*clk_t);
    reset = 1;
    #clk_t;
    reset = 0;
    //wait until the rx_fifo fills up
    @(posedge rx_fifo_full)
    //then wait until flow control stops the transmitter
    @(negedge tx_active)
    //and a bit longer so we can see the receiver go into RX_HOLD state
    #(15*clk_t)
    //empty the rx fifo
    rx_fifo_read_en = 1;
    //wait until the transmitter and receiver stop again
    @(negedge tx_active);
    @(negedge rx_active);
    #(15*clk_t);
    $finish;
end
endmodule