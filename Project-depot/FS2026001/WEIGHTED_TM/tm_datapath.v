`timescale 1ns / 1ps

module tm_datapath #(

    parameter MAX_CLASSES       = 7,
    parameter NUM_CLASSES       = 7,
    parameter NUM_LITERALS      = 134,
    parameter TOTAL_CLAUSES     = 849,
    parameter NUM_TEST_SAMPLES  = 2500,
    parameter WEIGHT_WIDTH      = 8,
    parameter SCORE_WIDTH       = 32,
    parameter INDEX_WIDTH       = 32,
    parameter CLASS_INDEX_WIDTH = $clog2(NUM_CLASSES),
    parameter CLASS_COUNT_0     = 0,
    parameter CLASS_COUNT_1     = 0,
    parameter CLASS_COUNT_2     = 0,
    parameter CLASS_COUNT_3     = 0,
    parameter CLASS_COUNT_4     = 0,
    parameter CLASS_COUNT_5     = 0,
    parameter CLASS_COUNT_6     = 0
    
)(
    input  wire                         i_clk,
    input  wire                         i_rst_n,

    input  wire [NUM_LITERALS-1:0] i_clause_data,
    input  wire [7:0]   i_weight_data,
    input  wire [NUM_LITERALS-1:0] i_test_x_data,
    input  wire [7:0]   i_test_y_data,
    output wire [9:0]   o_clause_addr,
    output wire [9:0]   o_weight_addr,
    
    output wire [11:0]  o_test_x_addr,
    output wire [11:0]  o_test_y_addr,

    input  wire                         i_score_clear,
    input  wire                         i_eval_enable,
    input  wire                         i_prediction_enable,
    input  wire                         i_accuracy_enable,
    input  wire                         i_accuracy_clear,

    input  wire [INDEX_WIDTH-1:0]       i_clause_index,
    input  wire [INDEX_WIDTH-1:0]       i_sample_index,

    output wire [CLASS_INDEX_WIDTH-1:0] o_predicted_class,
    output wire [CLASS_INDEX_WIDTH-1:0] o_actual_label,
    output wire [31:0]                  o_correct_count
);

    // ------------------------------------------------------------
    // Memories
    // ------------------------------------------------------------

    // ------------------------------------------------------------
    // Score storage
    // ------------------------------------------------------------

    reg signed [SCORE_WIDTH-1:0] r_score_mem [0:MAX_CLASSES-1];

    wire [MAX_CLASSES*SCORE_WIDTH-1:0] w_score_bus;

    // ------------------------------------------------------------
    // Internal signals
    // ------------------------------------------------------------

    localparam [CLASS_INDEX_WIDTH-1:0] LP_NUM_CLASSES = NUM_CLASSES[CLASS_INDEX_WIDTH-1:0];

    wire [NUM_LITERALS-1:0]       w_clause_mask;
    wire [NUM_LITERALS-1:0]       w_test_literals;
    wire                          w_clause_vote;
    wire [CLASS_INDEX_WIDTH-1:0] w_argmax_class;
    reg  [CLASS_INDEX_WIDTH-1:0] r_predicted_class;

    wire [CLASS_INDEX_WIDTH-1:0]  w_clause_class;
    wire signed [WEIGHT_WIDTH-1:0] w_weight_raw;
    wire signed [SCORE_WIDTH-1:0]  w_weight_signed;

    integer i;
    // ------------------------------------------------------------
    // Current data
    // ------------------------------------------------------------
    assign o_clause_addr = i_clause_index[9:0];
    assign o_weight_addr = i_clause_index[9:0];
    
    assign o_test_x_addr = i_sample_index[11:0];
    assign o_test_y_addr = i_sample_index[11:0];
    
    assign w_clause_mask   = i_clause_data;
    assign w_test_literals = i_test_x_data;
    assign o_actual_label = i_test_y_data[CLASS_INDEX_WIDTH-1:0];
    assign w_weight_raw    = i_weight_data;
    assign w_weight_signed = {
        {(SCORE_WIDTH-WEIGHT_WIDTH){w_weight_raw[WEIGHT_WIDTH-1]}},
        w_weight_raw
    };

    // ------------------------------------------------------------
    // Class-count lookup
    // ------------------------------------------------------------

    function [INDEX_WIDTH-1:0] f_get_class_count;
        input [CLASS_INDEX_WIDTH-1:0] i_class_id;
        begin
            case (i_class_id)
                3'd0: f_get_class_count = CLASS_COUNT_0;
                3'd1: f_get_class_count = CLASS_COUNT_1;
                3'd2: f_get_class_count = CLASS_COUNT_2;
                3'd3: f_get_class_count = CLASS_COUNT_3;
                3'd4: f_get_class_count = CLASS_COUNT_4;
                3'd5: f_get_class_count = CLASS_COUNT_5;
                3'd6: f_get_class_count = CLASS_COUNT_6;
                default: f_get_class_count = 0;
            endcase
        end
    endfunction

    // ------------------------------------------------------------
    // Clause class decoder.
    // Clause rows are stored class-by-class.
    // ------------------------------------------------------------

    function [CLASS_INDEX_WIDTH-1:0] f_get_clause_class;
        input [INDEX_WIDTH-1:0] i_clause_id;

        integer j;
        reg [INDEX_WIDTH-1:0] r_cumulative_count;
        reg r_found;

        begin
            r_cumulative_count = {INDEX_WIDTH{1'b0}};
            r_found            = 1'b0;
            f_get_clause_class = {CLASS_INDEX_WIDTH{1'b0}};

            for (j = 0; j < MAX_CLASSES; j = j + 1) begin
                if ((j < NUM_CLASSES) && (!r_found)) begin
                    r_cumulative_count = r_cumulative_count + f_get_class_count(j[CLASS_INDEX_WIDTH-1:0]);

                    if (i_clause_id < r_cumulative_count) begin
                        f_get_clause_class = j[CLASS_INDEX_WIDTH-1:0];
                        r_found = 1'b1;
                    end
                end
            end
        end
    endfunction

    assign w_clause_class = f_get_clause_class(i_clause_index);

    // ------------------------------------------------------------
    // Clause evaluation
    // ------------------------------------------------------------

    tm_clause_evaluator #(
        .NUM_LITERALS(NUM_LITERALS)
    ) u_tm_clause_evaluator (
        .i_clause_mask  (w_clause_mask),
        .i_test_literals(w_test_literals),
        .o_clause_vote  (w_clause_vote)
    );

    // ------------------------------------------------------------
    // Score registers
    // ------------------------------------------------------------

    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            for (i = 0; i < MAX_CLASSES; i = i + 1) begin
                r_score_mem[i] <= {SCORE_WIDTH{1'b0}};
            end
        end else if (i_score_clear) begin
            for (i = 0; i < MAX_CLASSES; i = i + 1) begin
                r_score_mem[i] <= {SCORE_WIDTH{1'b0}};
            end
        end else if (i_eval_enable && w_clause_vote) begin
            r_score_mem[w_clause_class] <= r_score_mem[w_clause_class] + w_weight_signed;
        end
    end

    // ------------------------------------------------------------
    // Pack score memory into score bus
    // ------------------------------------------------------------

    genvar g_score;

    generate
        for (g_score = 0; g_score < MAX_CLASSES; g_score = g_score + 1) begin : gen_score_bus
            assign w_score_bus[(g_score*SCORE_WIDTH) +: SCORE_WIDTH] = r_score_mem[g_score];
        end
    endgenerate

    // ------------------------------------------------------------
    // Argmax
    // ------------------------------------------------------------

    tm_argmax #(
        .MAX_CLASSES      (MAX_CLASSES),
        .SCORE_WIDTH      (SCORE_WIDTH),
        .CLASS_INDEX_WIDTH(CLASS_INDEX_WIDTH)
    ) u_tm_argmax (
        .i_num_classes    (LP_NUM_CLASSES),
        .i_score_bus      (w_score_bus),
        .o_predicted_class(w_argmax_class)
    );
    
    always @(posedge i_clk) begin
    if (!i_rst_n) begin
        r_predicted_class <= {CLASS_INDEX_WIDTH{1'b0}};
    end else if (i_prediction_enable) begin
        r_predicted_class <= w_argmax_class;
    end
    end

assign o_predicted_class = r_predicted_class;
    // ------------------------------------------------------------
    // Accuracy counter
    // ------------------------------------------------------------

    tm_accuracy_counter #(
        .COUNT_WIDTH      (32),
        .CLASS_INDEX_WIDTH(CLASS_INDEX_WIDTH)
    ) u_tm_accuracy_counter (
        .i_clk            (i_clk),
        .i_rst_n          (i_rst_n),
        .i_clear          (i_accuracy_clear),
        .i_enable         (i_accuracy_enable),
        .i_predicted_class(o_predicted_class),
        .i_actual_label   (o_actual_label),
        .o_correct_count  (o_correct_count)
    );

endmodule
