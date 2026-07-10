`timescale 1ns / 1ps
`include "tm_train_params.vh"
module clause_memory
(
    input  wire                     i_clk,
    input  wire                     i_read_en,
    input  wire [`CLAUSE_BITS-1:0]  i_clause_idx,
    output reg [`NUM_LITERALS-1:0]  o_clause_out
);
    //=========================================================
    // Clause Memory
    // One entry per clause
    //=========================================================
    reg [`NUM_LITERALS-1:0] r_clause_mem [0:`NUM_CLAUSES-1];
    //=========================================================
    // Load Learned Clauses
    //=========================================================
    initial
    begin
        $readmemb("clauses.mem", r_clause_mem);
    end
    //=========================================================
    // Read Clause
    //=========================================================
    always @(posedge i_clk)
    begin
        if(i_read_en)
            o_clause_out <= r_clause_mem[i_clause_idx];
    end
endmodule