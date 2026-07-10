`timescale 1ns / 1ps
module lfsr_random #(
    parameter WIDTH = 32
)(
    input  wire i_clk,
    input  wire i_rst,
    input  wire i_enable,
    output wire [WIDTH-1:0] o_random_value
);
reg [WIDTH-1:0] r_lfsr;
wire w_feedback;
// Primitive polynomial:
// x^32 + x^22 + x^2 + x + 1
assign w_feedback = r_lfsr[31] ^ r_lfsr[21] ^ r_lfsr[1] ^ r_lfsr[0];
always @(posedge i_clk) begin
    if (i_rst)
        r_lfsr <= 32'hACE1ACE1;     // Non-zero seed
    else if (i_enable)
        r_lfsr <= {r_lfsr[30:0], w_feedback};
end
assign o_random_value = r_lfsr;
endmodule