# verilog-basics

This is a collection of (mostly) synthesizable Verilog modules for use on FPGAs.
Documentation for each module, including an instantiation template, is included
in a comment at the top of each file. Test benches and Gtkwave layouts are
included for each module (`test_*.v` and `test_*.gtkw`). The `Makefile` is set
up to run all of the tests using `iverilog` and `vvp`.

## Memory and Queues

- `ram_dp.v` Dual-port RAM, with several implementations:
  - `ram_dp_generic.v` Generic verilog, some features might not synthesize.
  - `ram_dp_ice40.v` Using Lattice iCE40 primitives.
- `fifo_sync.v` Sychronous FIFO queue
- `fifo_async.v` Asynchronous FIFO queue

## Communication

- `spi_master.v` SPI Master
- `spi_slave.v` SPI Slave

## Utility

- `synchronizer.v` Shift register for synchronizing across clock domains
- `lfsr.v` Linear-feedback shift register for pseudorandom bit streams

As well as test for each and a Makefile for running said tests using `iverilog` and `vvp`.
