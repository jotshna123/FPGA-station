`timescale 1ns / 1ps

module tm_wrapper(
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_start,

    output wire        o_done,
    output wire [31:0] o_correct_count
);

tm_top #(

    .MAX_CLASSES      (7),
    .NUM_CLASSES      (7),
    .NUM_LITERALS     (134),
    .TOTAL_CLAUSES    (849),
    .NUM_TEST_SAMPLES (2500),

    .WEIGHT_WIDTH     (8),
    .SCORE_WIDTH      (32),
    .INDEX_WIDTH      (32),

    .CLASS_COUNT_0    (64),
    .CLASS_COUNT_1    (96),
    .CLASS_COUNT_2    (54),
    .CLASS_COUNT_3    (68),
    .CLASS_COUNT_4    (189),
    .CLASS_COUNT_5    (200),
    .CLASS_COUNT_6    (178)

) u_tm_top (

    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_start(i_start),

    .o_busy(),

    .o_done(o_done),

    .o_correct_count(o_correct_count),

    .o_predicted_class(),

    .o_actual_label(),

    .o_sample_index(),

    .o_clause_index()

);

endmodule