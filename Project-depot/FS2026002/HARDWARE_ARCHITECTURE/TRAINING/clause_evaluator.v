`timescale 1ns / 1ps
module clause_evaluator(
    input  wire i_literal,
    input  wire i_ta_action,
    output wire o_literal_pass
);
assign o_literal_pass = (~i_ta_action) | i_literal;
endmodule