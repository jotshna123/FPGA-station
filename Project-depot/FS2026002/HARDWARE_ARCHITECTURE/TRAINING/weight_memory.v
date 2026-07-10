`timescale 1ns / 1ps
`include "tm_train_params.vh"
module weight_memory(
    input  wire                        i_clk,
    input  wire                        i_rst,
    // Read Interface
    input  wire                        i_read_en,
    input  wire [`CLASS_BITS-1:0]      i_class_idx,
    input  wire [`CLAUSE_BITS-1:0]     i_clause_idx,
    output reg  signed [15:0]          o_weight_out,
    // Write Interface
    input  wire                        i_write_en,
    input  wire [`CLASS_BITS-1:0]      i_wr_class_idx,
    input  wire [`CLAUSE_BITS-1:0]     i_wr_clause_idx,
    input  wire signed [15:0]          i_weight_in
);
    //=========================================================
    // Clause Weight Memory
    //=========================================================
    reg signed [15:0] r_weight_mem [0:`TOTAL_WEIGHTS-1];
    integer i;
    wire [15:0] w_rd_addr;
    wire [15:0] w_wr_addr;
    assign w_rd_addr = (i_class_idx * `NUM_CLAUSES) + i_clause_idx;
    assign w_wr_addr = (i_wr_class_idx * `NUM_CLAUSES) + i_wr_clause_idx;
    always @(posedge i_clk) begin
        if(i_rst) begin
            for(i = 0; i < `TOTAL_WEIGHTS; i = i + 1)
                r_weight_mem[i] <= `INITIAL_WEIGHT;
        end
        else begin
            if(i_write_en)
                begin
    r_weight_mem[w_wr_addr] <= i_weight_in;
   
end
            if(i_read_en)
                if(i_read_en)
begin
    o_weight_out <= r_weight_mem[w_rd_addr];
   
end
        end
    end
endmodule