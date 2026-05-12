`timescale 1ns / 1ps

module tb_top;
    //drivers
    logic clk, rst, start_in;
    logic [31:0] x_in, y_in;
    logic [1:0] round_in;
    logic expect_nan;

    //output
    logic valid, ready;
    logic [31:0] result;
    logic [3:0] oor_out;
    logic [31:0] p_out;
    
    //tb flags
    logic reset_done;

    //load
    integer fd;
    integer code;
    logic [31:0] vec_a, vec_b, vec_expected;

    //dut
    fpmult #(.P(8), .Q(24)) dut (
        .clk_in (clk),
        .rst_in_N (rst),
        .x_in (x_in),
        .y_in (y_in),
        .round_in (round_in),
        .start_in (start_in),
        .p_out (p_out),
        .oor_out (oor_out),
        .valid_out (valid),
        .ready_out (ready)
    );

    //clk
    initial clk = 0;
    always #5 clk = ~clk;

    //reset sequence to start
    initial begin 
        rst = 0;
        start_in = 0;
        x_in = 0;
        y_in = 0;
        round_in = 0;
        reset_done = 0;
        @(posedge clk);
        @(posedge clk);
        rst = 1;
        reset_done = 1;
    end

    //task module
    task run_test(
        input logic [31:0] a, b, expected
    );
        //0 cycle, wait for ready assertion
        @(posedge clk);
        wait(ready);

        //1 cycle, drive inputs
        x_in = a;
        y_in = b;
        round_in = 2'b00;
        start_in = 1'b1;
        @(posedge clk);

        //2 cycle, pulse, clear start
        start_in = 0;

        //3 cycle, wait for valid
        wait(valid);
        @(posedge clk);

        //check
        if(p_out !== expected)
            $display("FAIL : got %08h expected %08h", p_out, expected);
        else
            $display("PASS: %08h * %08h = %08h", a, b, p_out);
    endtask

    task run_nan_test(
        input logic [31:0] a, b
    );
        @(posedge clk);
        wait(ready);
        
        x_in = a;
        y_in = b;
        round_in = 2'b00;
        start_in = 1'b1;
        @(posedge clk);

        start_in = 0;

        wait(valid);
        @(posedge clk);

        //check
        if (p_out[30:23] !== 8'hFF || p_out[22:0] === 23'h0)
            $display("FAIL: expected NaN got %08h", p_out);
        else
            $display("PASS: %08h * %08h = NaN", a, b);
    endtask
    
    //reset sequence wait
    initial begin
        wait(reset_done);

        fd = $fopen("vectors.txt", "r");
        
        if (fd == 0) begin //bad fd
            $display("ERROR: could not open vectors.txt");
            $finish;
        end

        while(!$feof(fd)) begin //read tokens, run tests
            code = $fscanf(fd, "%h %h %h %b\n", vec_a, vec_b, vec_expected, expect_nan);
            if (code == 4) begin
                if (expect_nan) begin
                    run_nan_test(vec_a, vec_b);
                end else begin
                    run_test(vec_a, vec_b, vec_expected);
                end
            end
        end

        $fclose(fd);
        $display("done");
        $finish;
    end
    
endmodule