# Single Precision Floating Point Multiplier

## Why: 


## Running the testbench

1. Generate test vectors from golden reference:
   gcc -o gen gen.c -lm
   ./gen > vectors.txt

2. Compile and simulate:
   iverilog -g2012 -o sim fpmult.sv tb_top.sv
   vvp sim

3. Expected output:
   PASS [3F800000 * 40000000]
   PASS [-1.0 * 2.0]
   ... (they should all pass)
   all tests done