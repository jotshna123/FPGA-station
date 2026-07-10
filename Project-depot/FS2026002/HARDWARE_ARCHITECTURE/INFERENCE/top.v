`timescale 1ns / 1ns
`include "tm_params.vh"


`ifndef SIMULATION
    `define SIMULATION
`endif


module top_module (
    input  i_clk_p,
    input  i_clk_n,
    input  i_btnC,
    output reg [3:0] o_led
);

    // ---------------------------------------------------------------
    // CLK_125 on the ZCU104 is LVDS-only - there is no single-ended
    // clock available on this board. This buffers the differential
    // pair down to a single internal w_clk wire; everything below
    // this point is unchanged and still just uses w_clk.
    // ---------------------------------------------------------------
    wire w_clk;
    IBUFDS #(
        .DIFF_TERM    ("TRUE"),
        .IBUF_LOW_PWR ("FALSE"),
        .IOSTANDARD   ("LVDS")
    ) IBUFDS_CLK (
        .I  (i_clk_p),
        .IB (i_clk_n),
        .O  (w_clk)
    );

    localparam NUM_CLASSES  = `NUM_CLASSES;
    localparam NUM_CLAUSES  = `NUM_CLAUSES;
    localparam HALF_CLAUSES = NUM_CLAUSES / 2;

    (* ram_style = "block", dont_touch = "true" *)
    reg [`CLAUSE_WIDTH-1:0] r_clause_bank_A [0:HALF_CLAUSES-1];
    (* ram_style = "block", dont_touch = "true" *)
    reg [`CLAUSE_WIDTH-1:0] r_clause_bank_B [0:HALF_CLAUSES-1];
    (* dont_touch = "true" *)
    reg signed [15:0] r_weight_banks [0:(NUM_CLASSES*NUM_CLAUSES)-1];

    // Added missing memory for actual classes
    reg [3:0] r_actual_class_mem [0:`NUM_TEST_VECTORS-1];

   
    reg [`CLAUSE_WIDTH-1:0] r_test_vectors [0:`NUM_TEST_VECTORS-1];

    reg [31:0] r_test_index;
    reg [31:0] r_correct_count;
    reg [7:0]  r_accuracy;
    reg [2:0]  r_state;
    reg [7:0]  r_clause_index;

    integer r_output_file, r_class_sums_file, r_vec_file, r_mapping_file, r_debug_file;
    reg        r_file_closed;
    reg        r_correct_flag;

    localparam LOAD        = 3'd0;
    localparam CLASSIFY    = 3'd1;
    localparam COMPARE     = 3'd2;
    localparam NEXTVEC     = 3'd3;
    localparam FINISH      = 3'd4;
    localparam CALC        = 3'd5;
    localparam LOAD_CLAUSE = 3'd6;

    reg [4:0] r_clk_div;
    `ifdef SIMULATION
        wire w_fsm_clk = w_clk;
    `else
        wire w_fsm_clk = r_clk_div[2];
    `endif

    wire [`CLAUSE_WIDTH-1:0] w_current_test_vec = r_test_vectors[r_test_index];

    reg  [`CLAUSE_WIDTH-1:0] r_current_clause;
    wire w_clause_output;

    clause_output_predict COP (
       .i_clause(r_current_clause),
       .i_encoded_x_test(w_current_test_vec),
       .o_clause_output(w_clause_output)
    );

    reg signed [15:0] r_class_sums [0:NUM_CLASSES-1];
    reg signed [15:0] r_max_class_sum;
    reg [3:0]         r_max_class_index_reg;

    integer c, d;

    initial begin
        r_state = LOAD;
        r_test_index = 0; r_correct_count = 0; r_accuracy = 0;
        r_clause_index = 0; r_clk_div = 0;
        r_max_class_index_reg = 0; r_file_closed = 0; r_correct_flag = 0;

        $readmemb("clauses_A.mem", r_clause_bank_A);
        $readmemb("clauses_B.mem", r_clause_bank_B);
        $readmemb("clause_weights.mem", r_weight_banks);
        $readmemb("x_test_encoded.mem", r_test_vectors);
        $readmemh("y_test.txt", r_actual_class_mem); // Ensure this file exists
        $display("===== MEMORY CHECK =====");
        $display("ClauseA[0] = %h", r_clause_bank_A[0]);
        $display("ClauseB[0] = %h", r_clause_bank_B[0]);
        $display("Weight[0]  = %d", r_weight_banks[0]);
        $display("Y[0]       = %d", r_actual_class_mem[0]);
        $display("========================");

        r_debug_file = $fopen("debug_y_test_load.txt", "w");
        if (r_debug_file) begin
            $fdisplay(r_debug_file, "--- Y_TEST LOAD DEBUG ---");
            for (d = 0; d < 10; d = d + 1) $fdisplay(r_debug_file, "Index %0d: %0d", d, r_actual_class_mem[d]);
            $fclose(r_debug_file);
        end

        r_output_file = $fopen("hardware_predictions.txt", "w");
        r_class_sums_file = $fopen("hardware_class_sums.txt", "w");
        r_mapping_file = $fopen("hardware_prediction_mapping.csv", "w");
    end

    always @(posedge w_clk) r_clk_div <= r_clk_div + 1;

    wire w_safe_reset = (i_btnC === 1'b1);

    always @(posedge w_fsm_clk) begin
        if (w_safe_reset) begin
            r_state <= LOAD; r_test_index <= 0; r_correct_count <= 0; r_clause_index <= 0;
        end else begin
            case (r_state)
                LOAD: begin
                    r_test_index <= 0;
                    r_correct_count <= 0;
                    r_clause_index <= 0;

                    `ifdef SIM_VERBOSE
                        $display("Input Vector = %h", w_current_test_vec);
                    `endif

                    r_state <= CLASSIFY;
                end

                CLASSIFY: begin
                    for (c = 0; c < NUM_CLASSES; c = c + 1) r_class_sums[c] <= 0;
                    r_clause_index <= 0;
                    r_state <= LOAD_CLAUSE;
                end
                LOAD_CLAUSE: begin
                    r_current_clause <= (r_clause_index < HALF_CLAUSES) ?
                                       r_clause_bank_A[r_clause_index] :
                                       r_clause_bank_B[r_clause_index - HALF_CLAUSES];
                    `ifdef SIM_VERBOSE
                        $display("Loading Clause %0d", r_clause_index);
                    `endif
                    r_state <= CALC;
                end
                CALC: begin
                    `ifdef SIM_VERBOSE
                        $display(
                            "Clause=%0d Output=%0b",
                            r_clause_index,
                            w_clause_output
                        );
                    `endif
                    if (w_clause_output) begin
                        for (c = 0; c < NUM_CLASSES; c = c + 1) begin
                            `ifdef SIM_VERBOSE
                                $display(
                                    "Class=%0d Weight=%0d",
                                     c,
                                     r_weight_banks[(c * NUM_CLAUSES) + r_clause_index]
                                );
                            `endif
                            r_class_sums[c] <= r_class_sums[c] + r_weight_banks[(c * NUM_CLAUSES) + r_clause_index];
                        end
                    end
                    if (r_clause_index == NUM_CLAUSES - 1) r_state <= COMPARE;
                    else begin r_clause_index <= r_clause_index + 1; r_state <= LOAD_CLAUSE; end
                end
                COMPARE: begin
                    `ifdef SIM_VERBOSE
                        $display("===== CLASS SUMS =====");
                        for(c=0;c<NUM_CLASSES;c=c+1)
                        begin
                            $display(
                                "Class %0d Sum = %0d",
                                 c,
                                 r_class_sums[c]
                            );
                        end
                        $display("======================");
                    `endif
                    r_max_class_sum = r_class_sums[0];
                    r_max_class_index_reg = 0;
                    for (c = 1; c < NUM_CLASSES; c = c + 1) begin
                        if (r_class_sums[c] > r_max_class_sum) begin
                            r_max_class_sum = r_class_sums[c];
                            r_max_class_index_reg = c[3:0];
                        end
                    end
                    r_correct_flag = (r_max_class_index_reg == r_actual_class_mem[r_test_index]);
                    `ifdef SIM_VERBOSE
                        $display(
                            "Prediction=%0d Actual=%0d",
                            r_max_class_index_reg,
                            r_actual_class_mem[r_test_index]
                        );
                    `endif
                    if (r_correct_flag) r_correct_count <= r_correct_count + 1;

                    r_state <= NEXTVEC;
                end
                NEXTVEC: begin
                    if (r_test_index == `NUM_TEST_VECTORS - 1) r_state <= FINISH;
                    else begin r_test_index <= r_test_index + 1; r_state <= CLASSIFY; end
                end
                FINISH: begin
                    r_accuracy <= (r_correct_count * 100) / `NUM_TEST_VECTORS;
                    $display("===============");
                    $display("Correct = %0d", r_correct_count);
                    $display("Total   = %0d", `NUM_TEST_VECTORS);
                    $display("Acc     = %0d", (r_correct_count * 100) / `NUM_TEST_VECTORS);
                    $display("===============");
                    o_led <= ((r_correct_count * 100) / `NUM_TEST_VECTORS);
                    r_state <= FINISH;
                end
                default: r_state <= LOAD;
            endcase
        end
    end


    
    //======================================================
// Integrated Logic Analyzer
//======================================================
ila_0 ILA_INST (
    .clk(w_fsm_clk),

    .probe0(r_state),
    .probe1(r_test_index),
    .probe2(r_correct_count),
    .probe3(r_accuracy),
    .probe4(r_clause_index),
    .probe5(r_max_class_index_reg),
    .probe6(r_max_class_sum),
    .probe7(r_correct_flag)
);

endmodule