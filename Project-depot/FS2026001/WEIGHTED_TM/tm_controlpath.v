`timescale 1ns / 1ps

module tm_controlpath #(
    parameter TOTAL_CLAUSES    = 849,
    parameter NUM_TEST_SAMPLES = 2500,
    parameter INDEX_WIDTH      = 32
)(
    input  wire                   i_clk,
    input  wire                   i_rst_n,
    input  wire                   i_start,

    output reg                    o_score_clear,
    output reg                    o_eval_enable,
    output reg                    o_prediction_enable,
    output reg                    o_accuracy_enable,
    output reg                    o_accuracy_clear,
    output reg                    o_busy,
    output reg                    o_done,

    output reg  [INDEX_WIDTH-1:0] o_clause_index,
    output reg  [INDEX_WIDTH-1:0] o_sample_index
);
    
    localparam IDLE            = 3'd0;
    localparam CLEAR_SCORE     = 3'd1;
    localparam BRAM_WAIT       = 3'd2;
    localparam EVAL_CLAUSES    = 3'd3;
    localparam ARGMAX_WAIT     = 3'd4;
    localparam UPDATE_ACCURACY = 3'd5;
    localparam NEXT_SAMPLE     = 3'd6;
    localparam DONE            = 3'd7;

    reg [3:0] r_state;
    reg [3:0] w_next_state;

    // ------------------------------------------------------------
    // State register
    // ------------------------------------------------------------
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_state <= IDLE;
        end else begin
            r_state <= w_next_state;
        end
    end

    // ------------------------------------------------------------
    // Next-state logic
    // ------------------------------------------------------------
    always @(*) begin
        w_next_state = r_state;

        case (r_state)

            IDLE: begin
                if (i_start) begin
                    w_next_state = CLEAR_SCORE;
                end
            end

            CLEAR_SCORE: begin
                w_next_state = BRAM_WAIT;
            end
            BRAM_WAIT:
                w_next_state = EVAL_CLAUSES;
                
            EVAL_CLAUSES: begin
                if (o_clause_index == TOTAL_CLAUSES - 1) begin
                    w_next_state = ARGMAX_WAIT;
                end
            end

            ARGMAX_WAIT: begin
                w_next_state = UPDATE_ACCURACY;
            end

            UPDATE_ACCURACY: begin
                w_next_state = NEXT_SAMPLE;
            end

            NEXT_SAMPLE: begin
                if (o_sample_index == NUM_TEST_SAMPLES - 1) begin
                    w_next_state = DONE;
                end else begin
                    w_next_state = CLEAR_SCORE;
                end
            end

            DONE: begin
                w_next_state = DONE;
            end

            default: begin
                w_next_state = IDLE;
            end

        endcase
    end

    // ------------------------------------------------------------
    // Counter logic
    // ------------------------------------------------------------
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_clause_index <= {INDEX_WIDTH{1'b0}};
            o_sample_index <= {INDEX_WIDTH{1'b0}};
        end else begin

            case (r_state)

                IDLE: begin
                    if (i_start) begin
                        o_clause_index <= {INDEX_WIDTH{1'b0}};
                        o_sample_index <= {INDEX_WIDTH{1'b0}};
                    end
                end

                CLEAR_SCORE: begin
                    o_clause_index <= {INDEX_WIDTH{1'b0}};
                end

                EVAL_CLAUSES: begin
                    if (o_clause_index < TOTAL_CLAUSES - 1) begin
                        o_clause_index <= o_clause_index + 1'b1;
                    end
                end

                NEXT_SAMPLE: begin
                    if (o_sample_index < NUM_TEST_SAMPLES - 1) begin
                        o_sample_index <= o_sample_index + 1'b1;
                    end
                    o_clause_index <= {INDEX_WIDTH{1'b0}};
                end

                default: begin
                    o_clause_index <= o_clause_index;
                    o_sample_index <= o_sample_index;
                end

            endcase
        end
    end

    // ------------------------------------------------------------
    // Output control signals
    // ------------------------------------------------------------
    always @(*) begin
        o_score_clear     = 1'b0;
        o_eval_enable     = 1'b0;
        o_accuracy_enable = 1'b0;
        o_accuracy_clear  = 1'b0;
        o_busy            = 1'b0;
        o_done            = 1'b0;
        o_prediction_enable = 1'b0;

        case (r_state)

            IDLE: begin
                o_accuracy_clear = i_start;
            end

            CLEAR_SCORE: begin
                o_score_clear = 1'b1;
                o_busy        = 1'b1;
            end
            
            BRAM_WAIT:
            begin
                o_busy = 1'b1;
            end 
            
            EVAL_CLAUSES: begin
                o_eval_enable = 1'b1;
                o_busy        = 1'b1;
            end

            ARGMAX_WAIT: begin
                o_prediction_enable = 1'b1;
                o_busy = 1'b1;
            end

            UPDATE_ACCURACY: begin
                o_accuracy_enable = 1'b1;
                o_busy            = 1'b1;
            end

            NEXT_SAMPLE: begin
                o_busy = 1'b1;
            end

            DONE: begin
                o_done = 1'b1;
            end

            default: begin
                o_busy = 1'b0;
            end

        endcase
    end

endmodule