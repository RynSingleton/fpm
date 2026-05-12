`timescale 1ns / 1ps


module fpmult #(parameter int P = 8, parameter int Q = 24) (
    input  logic rst_in_N,           // synchronous active-low reset
    input  logic clk_in,             // clock
    input  logic [P+Q-1:0] x_in,     // input X; x_in[P+Q-1] is the sign bit
    input  logic [P+Q-1:0] y_in,     // input Y: y_in[P+Q-1] is the sign bit
    input  logic [1:0] round_in,     // Wrounding mode specifier
    input  logic start_in,           // signal to start multiplication
    output logic [P+Q-1:0] p_out,    // output P: p_out[P+Q-1] is the sign bit
    output logic [3:0] oor_out,      // out-of-range indicator vector
    output logic valid_out,          // the outputs are valid
    output logic ready_out           // the FPM is ready to receive new inputs
);

     // Constants
    localparam TOTAL_BITS = 32;
    localparam EXP_BITS = P;
    localparam FRAC_BITS = Q - 1;
    localparam BIAS = (1 << (EXP_BITS - 1)) - 1; //127 but tbh this is the correct way to get the bias

    // Signals for computed result
    logic [TOTAL_BITS-1:0] result_computed;
    logic [3:0] oor_computed;

    //inputs
    logic [TOTAL_BITS-1:0] x_latched, y_latched;

    //combinational registers
    logic sign_x, sign_y, sign_result;
    logic [EXP_BITS-1:0] exp_x, exp_y;
    logic [FRAC_BITS-1:0] frac_x, frac_y;
    logic signed [EXP_BITS:0] exp_sum, exp_normalized;
    logic [FRAC_BITS:0] sig_x, sig_y;
    logic [2*(FRAC_BITS+1)-1:0] sig_product;
    logic [FRAC_BITS:0] sig_normalized, sig_rounded;
    logic signed [EXP_BITS:0] shift_by;
    logic signed [EXP_BITS:0] exp_x_adjusted, exp_y_adjusted;
    logic g, r, s;
    logic round_up;
    logic overflow, underflow;

    //check for special cases
    logic x_is_nan, y_is_nan;
    logic x_is_inf, y_is_inf;
    logic x_is_zero, y_is_zero;

    //state
    logic [1:0] state, next_state;

    always_ff @(posedge clk_in) begin
    if (start_in && state == 2'b00) begin
        x_latched <= x_in;
        y_latched <= y_in;
        end
    end

   always_ff @(posedge clk_in) begin
       if (!rst_in_N)
           state <= 2'b00;
       else
           state <= next_state;
   end

   always_comb begin
       case (state)
           2'b00: next_state = start_in ? 2'b01 : 2'b00;
           2'b01: next_state = 2'b10;
           2'b10: next_state = 2'b00;
           default: next_state = 2'b00;
       endcase
   end

    always_comb begin
       ready_out = (state == 2'b00);
       valid_out = (state == 2'b10);
   end

    //comb logic for compute state
    always_comb begin
        //extract
        sign_x = x_latched[TOTAL_BITS-1];
        sign_y = y_latched[TOTAL_BITS-1];
        exp_x = x_latched[TOTAL_BITS-2 : FRAC_BITS];
        exp_y = y_latched[TOTAL_BITS-2 : FRAC_BITS];
        frac_x = x_latched[FRAC_BITS-1 : 0];
        frac_y = y_latched[FRAC_BITS-1 : 0];
        
        sign_result = sign_x ^ sign_y;

        x_is_nan  = (exp_x == '1) && (frac_x != '0);
        y_is_nan  = (exp_y == '1) && (frac_y != '0);
        x_is_inf  = (exp_x == '1) && (frac_x == '0);
        y_is_inf  = (exp_y == '1) && (frac_y == '0);
        x_is_zero = (exp_x == '0) && (frac_x == '0);
        y_is_zero = (exp_y == '0) && (frac_y == '0);

        //in special cases, we can skip arithmetic
        if(x_is_nan || y_is_nan) begin //nan ops silently propogate nan
            result_computed = {1'b0, {EXP_BITS{1'b1}}, 1'b1, {(FRAC_BITS-1){1'b0}}};
            oor_computed = 4'b0010;
        end else if ((x_is_inf && y_is_zero) || (y_is_inf && x_is_zero)) begin //ifn x 0 = nan and invalid flag
            result_computed = {1'b0, {EXP_BITS{1'b1}}, 1'b1, {(FRAC_BITS-1){1'b0}}};
            oor_computed = 4'b0100;
        end else if (x_is_inf || y_is_inf) begin //fallthrough infs, make inf with sign result
            result_computed = {sign_result, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}};
            oor_computed = 4'b0001;
        end else if (x_is_zero || y_is_zero) begin //fallthrough zeros, make zero with sign result
            result_computed = {sign_result, {(TOTAL_BITS-1){1'b0}}};
            oor_computed = 4'b0000;
        end else begin
            exp_x_adjusted = (exp_x == 0) ? 9'd1 : {1'b0, exp_x}; //fix if subnormal by settinf exp to 1, or -126
            exp_y_adjusted = (exp_y == 0) ? 9'd1 : {1'b0, exp_y};

            exp_sum = exp_x_adjusted + exp_y_adjusted - BIAS; 
            
            // multiply significands (add leading 1 or 0 for subs)
            sig_x = {(exp_x == 0 ? 1'b0 : 1'b1), frac_x};
            sig_y = {(exp_y == 0 ? 1'b0 : 1'b1), frac_y};

            //ty sysverilog for unsigned multiplication
            sig_product = sig_x * sig_y;
                
            // normalize based on leading bit
            if (sig_product[2*(FRAC_BITS+1)-1]) begin //is there a leading one
                //bit = 1, already normalized
                sig_normalized = sig_product[2*(FRAC_BITS+1)-1 : FRAC_BITS+1];
                exp_normalized = exp_sum + 1;
                g = sig_product[FRAC_BITS];
                r = sig_product[FRAC_BITS-1];
                s = |sig_product[FRAC_BITS-2:0];
            end else begin
                //bit = 0, normalize
                sig_normalized = sig_product[2*(FRAC_BITS+1)-2 : FRAC_BITS];
                exp_normalized = exp_sum;
                g = sig_product[FRAC_BITS-1]; 
                r = sig_product[FRAC_BITS-2];
                s = |sig_product[FRAC_BITS-3:0]; 
            end
                                    
            // round to nearest, ties to even 
            case(round_in)
                2'b00: //rtn
                    round_up = g & (r|s|sig_normalized[0]);
                2'b01: //rtz
                    round_up = 1'b0;
                2'b10: //rtpi
                    round_up = ~sign_result & (g|r|s);
                2'b11: //rtni (trunc)
                    round_up = sign_result & (g|r|s);
                default: //trunc
                    round_up = 1'b0;
            endcase
                    
            if (round_up) begin
                sig_rounded = sig_normalized + 1;
                //carry from rounding, shift and add 1 to exp
                if (sig_rounded[FRAC_BITS]) begin
                    sig_rounded = sig_rounded >> 1;
                    exp_normalized = exp_normalized + 1;
                end
            end else begin //trunc
                sig_rounded = sig_normalized;
            end
            
            //prelim in case subs
            overflow = (exp_normalized >= 255);
            underflow = 1'b0;

            //check for subs
            if(exp_normalized <= 0 && !overflow) begin
                shift_by = 1 - exp_normalized; //how much to shift by to fix sig

                if (shift_by > signed'(FRAC_BITS)) begin //we're shifting by more bits than we habe
                    sig_rounded = '0;
                    underflow = 1'b1;
                end else begin
                    sig_rounded = sig_rounded >> shift_by;
                end

                exp_normalized = 0;

            end

            // check overflow/underflow
            overflow = (exp_normalized >= 255);
            underflow = (exp_normalized < 0);

            // pack result or set OOR
            if(overflow) begin
                result_computed = {sign_result, {EXP_BITS{1'b1}}, {FRAC_BITS{1'b0}}}; //+/-inf
                oor_computed = 4'b0001;
            end else if (underflow) begin
                result_computed = {sign_result, {(TOTAL_BITS-1){1'b0}}};//+/-zer0
                oor_computed = 4'b0001;
            end else begin
                result_computed = {sign_result, exp_normalized[EXP_BITS-1:0], sig_rounded[FRAC_BITS-1:0]};
                oor_computed = 4'b0000;
            end

        end
    end 

    //latch outputs to p_out and oor_out
    always_ff @(posedge clk_in) begin
        if (!rst_in_N) begin
            p_out <= '0;
            oor_out <= '0;
        end else if (state == 2'b01) begin  // COMPUTE state
            p_out <= result_computed;
            oor_out <= oor_computed;
        end
    end

endmodule