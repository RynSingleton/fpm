# Single Precision Floating Point Multiplier

## Why: 

## Running the testbench

You will need icarus (or your own simulator) to run the verilog
Note, each simulator is very different and compiling and simulating is only tested for icarus 10.3 running g2012
It may not compile nicely with other simluators/versions

Icarus: https://steveicarus.github.io/iverilog/

1. Generate test vectors from golden reference:
```
   gcc -o gen gen.c -lm
   ./gen > vectors.txt
```

2. Compile and simulate: (you will need icarus to run the simulation!)
```
   iverilog -g2012 -o sim fpmult.sv tb_top.sv
   vvp sim
```

3. Expected output:
```
   PASS [3F800000 * 40000000]
   PASS [-1.0 * 2.0]
   ... (they should all pass)
   all tests done
```