`timescale 1ns / 1ps

module tm_top #(
    parameter MAX_CLASSES       = 7,
    parameter NUM_CLASSES       = 7,
    parameter NUM_LITERALS      = 134,
    parameter TOTAL_CLAUSES     = 849,
    parameter NUM_TEST_SAMPLES  = 2500,
    parameter WEIGHT_WIDTH      = 8,
    parameter SCORE_WIDTH       = 32,
    parameter INDEX_WIDTH       = 32,
    parameter CLASS_INDEX_WIDTH = $clog2(NUM_CLASSES),

   
    parameter CLASS_COUNT_0 = 64,
    parameter CLASS_COUNT_1 = 96,
    parameter CLASS_COUNT_2 = 54,
    parameter CLASS_COUNT_3 = 68,
    parameter CLASS_COUNT_4 = 189,
    parameter CLASS_COUNT_5 = 200,
    parameter CLASS_COUNT_6 = 178
    
)(
    input  wire                         i_clk,
    input  wire                         i_rst_n,
    input  wire                         i_start,

    output wire                         o_busy,
    output wire                         o_done,
    output wire [31:0]                  o_correct_count,
    output wire [CLASS_INDEX_WIDTH-1:0] o_predicted_class,
    output wire [CLASS_INDEX_WIDTH-1:0] o_actual_label,
    output wire [INDEX_WIDTH-1:0]       o_sample_index,
    output wire [INDEX_WIDTH-1:0]       o_clause_index
);

    wire w_score_clear;
    wire w_eval_enable;
    wire w_prediction_enable;
    wire w_accuracy_enable;
    wire w_accuracy_clear;
    // BRAM interface wires

    wire [NUM_LITERALS-1:0] w_clause_data;
    wire [7:0]   w_weight_data;
    
    wire [NUM_LITERALS-1:0] w_test_x_data;
    wire [7:0]   w_test_y_data;
    
    wire [9:0]   w_clause_addr;
    wire [9:0]   w_weight_addr;
    
    wire [11:0]  w_test_x_addr;
    wire [11:0]  w_test_y_addr;
    tm_controlpath #(
        .TOTAL_CLAUSES   (TOTAL_CLAUSES),
        .NUM_TEST_SAMPLES(NUM_TEST_SAMPLES),
        .INDEX_WIDTH     (INDEX_WIDTH)
    ) u_tm_controlpath (
        .i_clk             (i_clk),
        .i_rst_n           (i_rst_n),
        .i_start           (i_start),
        .o_score_clear     (w_score_clear),
        .o_eval_enable     (w_eval_enable),
        .o_accuracy_enable (w_accuracy_enable),
        .o_accuracy_clear  (w_accuracy_clear),
        .o_busy            (o_busy),
        .o_done            (o_done),
        .o_clause_index    (o_clause_index),
        .o_sample_index    (o_sample_index),
        .o_prediction_enable(w_prediction_enable)
    );
    blk_mem_gen_pruned_clauses u_clause_bram (
        .clka  (i_clk),
        .ena   (1'b1),
        .addra (w_clause_addr),
        .douta (w_clause_data)
    );
    blk_mem_gen_pruned_weights u_weight_bram (
        .clka  (i_clk),
        .ena   (1'b1),
        .addra (w_weight_addr),
        .douta (w_weight_data)
    );
    blk_mem_gen_pruned_x_test_2500 u_test_x_bram (
        .clka  (i_clk),
        .ena   (1'b1),
        .addra (w_test_x_addr),
        .douta (w_test_x_data)
    );
    blk_mem_gen_pruned_y_test_2500 u_test_y_bram (
        .clka  (i_clk),
        .ena   (1'b1),
        .addra (w_test_y_addr),
        .douta (w_test_y_data)
    );
    
    tm_datapath #(
        .MAX_CLASSES      (MAX_CLASSES),
        .NUM_CLASSES      (NUM_CLASSES),
        .NUM_LITERALS     (NUM_LITERALS),
        .TOTAL_CLAUSES    (TOTAL_CLAUSES),
        .NUM_TEST_SAMPLES (NUM_TEST_SAMPLES),
        .WEIGHT_WIDTH     (WEIGHT_WIDTH),
        .SCORE_WIDTH      (SCORE_WIDTH),
        .INDEX_WIDTH      (INDEX_WIDTH),
        .CLASS_INDEX_WIDTH(CLASS_INDEX_WIDTH),

        .CLASS_COUNT_0    (CLASS_COUNT_0),
        .CLASS_COUNT_1    (CLASS_COUNT_1),
        .CLASS_COUNT_2    (CLASS_COUNT_2),
        .CLASS_COUNT_3    (CLASS_COUNT_3),
        .CLASS_COUNT_4    (CLASS_COUNT_4),
        .CLASS_COUNT_5    (CLASS_COUNT_5),
        .CLASS_COUNT_6    (CLASS_COUNT_6)
    ) u_tm_datapath (
        .i_clk             (i_clk),
        .i_rst_n           (i_rst_n),
        .i_clause_data (w_clause_data),
        .i_weight_data (w_weight_data),
        
        .i_test_x_data (w_test_x_data),
        .i_test_y_data (w_test_y_data),
        
        .o_clause_addr (w_clause_addr),
        .o_weight_addr (w_weight_addr),
        
        .o_test_x_addr (w_test_x_addr),
        .o_test_y_addr (w_test_y_addr),
        .i_score_clear     (w_score_clear),
        .i_eval_enable     (w_eval_enable),
        .i_accuracy_enable (w_accuracy_enable),
        .i_accuracy_clear  (w_accuracy_clear),
        .i_clause_index    (o_clause_index),
        .i_sample_index    (o_sample_index),
        .i_prediction_enable (w_prediction_enable),
        .o_predicted_class (o_predicted_class),
        .o_actual_label    (o_actual_label),
        .o_correct_count   (o_correct_count)
    );

endmodule