# Single Precision Floating Point Multiplier

## Why: 
    I created a basic version of this project for my Advanced Computer Arch class, and wanted to make a version that actually matched the golden standard. A buddy c program to generate vectors for testing is provided, but you are encouraged to tweak if you would like an exhaustive testbench. I just didn't migrate my exhaustive one over to this repo, as it was written to be used over FPGA and wrote a new one to quckly match the new tb. 

## Docs:
    Floating Point Multiplication is a really interseting topic that most students gloss over after writing their first implementation. Addition, Subtraction, and Division not to even be mentioned. I hope to one day tackle a whole fpm arthemetic module, but for now, here's now this multiplier works.

    TODO lol

## Running the testbench:

You will need icarus (or your own simulator) to run the verilog

Note, each simulator is very different and compiling and simulating is only tested for icarus 10.3 running '-g2012'

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

