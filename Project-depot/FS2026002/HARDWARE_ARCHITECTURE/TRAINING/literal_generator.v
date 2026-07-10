`timescale 1ns / 1ps
`include "tm_train_params.vh"
module literal_generator(
    input  wire [`NUM_FEATURES-1:0] i_x_in,
    output wire [`NUM_LITERALS-1:0] o_literals
);
    genvar i;
    generate
        // Positive literals
        for(i = 0; i < `NUM_FEATURES; i = i + 1)
        begin : POSITIVE_LITERALS
            assign o_literals[i] = i_x_in[i];
        end
        // Negative literals
        for(i = 0; i < `NUM_FEATURES; i = i + 1)
        begin : NEGATIVE_LITERALS
            assign o_literals[i + `NUM_FEATURES] = ~i_x_in[i];
        end
    endgenerate
endmodule