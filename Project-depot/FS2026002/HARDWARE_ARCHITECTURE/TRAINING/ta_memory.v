`timescale 1ns / 1ps
`include "tm_train_params.vh"
module ta_memory(
    input  wire                         i_clk,
    input  wire                         i_rst,
    // Read Interface
    input  wire                         i_read_en,
    input  wire [`CLAUSE_BITS-1:0]      i_clause_idx,
    input  wire [`LITERAL_BITS-1:0]     i_literal_idx,
    output reg  [`STATE_BITS-1:0]       o_ta_state_out,
    // Write Interface
    input  wire                         i_write_en,
    input  wire [`CLAUSE_BITS-1:0]      i_wr_clause_idx,
    input  wire [`LITERAL_BITS-1:0]     i_wr_literal_idx,
    input  wire [`STATE_BITS-1:0]       i_ta_state_in
);
    //=========================================================
    // TA State Memory
    //=========================================================
    reg [`STATE_BITS-1:0] r_ta_mem [0:`TOTAL_TAS-1];
    integer i;
    wire [15:0] w_rd_addr;
    wire [15:0] w_wr_addr;
    assign w_rd_addr = (i_clause_idx * `NUM_LITERALS) + i_literal_idx;
    assign w_wr_addr = (i_wr_clause_idx * `NUM_LITERALS) + i_wr_literal_idx;
    //=========================================================
    // Initialize TA States
    //=========================================================
    always @(posedge i_clk) begin
        if (i_rst) begin
            for(i = 0; i < `TOTAL_TAS; i = i + 1)
                r_ta_mem[i] <= `INITIAL_TA_STATE;
        end
        else begin
            // Write Operation
            if(i_write_en)
                r_ta_mem[w_wr_addr] <= i_ta_state_in;
            // Read Operation
            if(i_read_en)
                o_ta_state_out <= r_ta_mem[w_rd_addr];
        end
    end
endmodule