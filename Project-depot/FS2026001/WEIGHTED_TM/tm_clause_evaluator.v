`timescale 1ns / 1ps
module tm_clause_evaluator #(
    parameter NUM_LITERALS = 134
)(
    input  wire [NUM_LITERALS-1:0] i_clause_mask,
    input  wire [NUM_LITERALS-1:0] i_test_literals,
    output wire                    o_clause_vote
);

    wire w_clause_match;
    wire w_clause_non_empty;

    assign w_clause_match     = &((~i_clause_mask) | i_test_literals);
    assign w_clause_non_empty = |i_clause_mask;

    // Match Python verifier setting: empty_clause_fires = False
    assign o_clause_vote = w_clause_non_empty & w_clause_match;
endmodule
