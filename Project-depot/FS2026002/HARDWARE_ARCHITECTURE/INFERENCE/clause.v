
`include "tm_params.vh"

module clause_output_predict(

    input  [`CLAUSE_WIDTH-1:0] i_clause,
    input  [`CLAUSE_WIDTH-1:0] i_encoded_x_test,

    output o_clause_output

);

wire [`CLAUSE_WIDTH-1:0] w_clause_match;

assign w_clause_match =

       (~i_clause)
       |
       i_encoded_x_test;

assign o_clause_output =

       &w_clause_match;

endmodule
