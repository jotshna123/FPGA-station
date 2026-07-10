`timescale 1ns / 1ps
`include "tm_train_params.vh"

module tb_inference_top;

    //----------------------------------------------------------
    // Clock & Reset
    //----------------------------------------------------------
    reg r_clk;
    reg r_rst;
    reg r_start;

    //----------------------------------------------------------
    // Test Input
    //----------------------------------------------------------
    reg [`NUM_LITERALS-1:0] r_x_test_encoded;

    //----------------------------------------------------------
    // DUT Outputs
    //----------------------------------------------------------
    wire [`CLASS_BITS-1:0] w_predicted_class;
    wire w_done;

    //----------------------------------------------------------
    // Test Dataset
    //----------------------------------------------------------
    reg [`NUM_LITERALS-1:0] r_test_x [0:`TEST_SAMPLES-1];
    reg [`CLASS_BITS-1:0]   r_test_y [0:`TEST_SAMPLES-1];

    //----------------------------------------------------------
    // Variables
    //----------------------------------------------------------
    integer sample;
    integer correct_predictions;
    integer total_predictions;
    real accuracy;

    //----------------------------------------------------------
    // DUT
    //----------------------------------------------------------
    top_module DUT
    (
        .i_clk(r_clk),
        .i_rst(r_rst),
        .i_start(r_start),
        .i_x_test_encoded(r_x_test_encoded),
        .o_predicted_class(w_predicted_class),
        .o_done(w_done)
    );

    //----------------------------------------------------------
    // Clock Generation
    //----------------------------------------------------------
    initial
    begin
        r_clk = 0;
        forever #5 r_clk = ~r_clk;
    end

    //----------------------------------------------------------
    // Load Trained Model and Test Dataset
    //----------------------------------------------------------
    initial
    begin

        $display("======================================");
        $display("Loading Trained Model...");
        $display("======================================");

        $display("Trained Model Loaded.");
        $display("");

        $display("======================================");
        $display("Loading Test Dataset...");
        $display("======================================");

        $readmemb("x_test_encoded.mem", r_test_x);
        $readmemb("y_test.txt", r_test_y);

        $display("Test Dataset Loaded.");

    end

    //----------------------------------------------------------
    // Waveform
    //----------------------------------------------------------
    initial
    begin
        $dumpfile("top_module.vcd");
        $dumpvars(0, tb_inference_top);
    end

    //----------------------------------------------------------
    // Inference Task
    //----------------------------------------------------------
    task inference_sample;

        input [`NUM_LITERALS-1:0] sample_x;
        input [`CLASS_BITS-1:0]   sample_y;

        begin
        
            r_x_test_encoded <= sample_x;
            
            @(posedge r_clk);
          
            r_start <= 1'b1;

            @(posedge r_clk);

            r_start <= 1'b0;

            wait(w_done);

            @(posedge r_clk);

            total_predictions = total_predictions + 1;

            if(w_predicted_class == sample_y)
            begin

                correct_predictions = correct_predictions + 1;

                $display("Sample %0d  Pred=%0d  Actual=%0d  CORRECT",
                         total_predictions-1,
                         w_predicted_class,
                         sample_y);

            end
            else
            begin

                $display("Sample %0d  Pred=%0d  Actual=%0d  WRONG",
                         total_predictions-1,
                         w_predicted_class,
                         sample_y);

            end

        end

    endtask
        //----------------------------------------------------------
    // Main Test
    //----------------------------------------------------------
    initial
    begin

        //------------------------------------------------------
        // Initialize
        //------------------------------------------------------
        r_rst = 1'b1;
        r_start = 1'b0;
        r_x_test_encoded = 0;

        correct_predictions = 0;
        total_predictions   = 0;

        //------------------------------------------------------
        // Reset
        //------------------------------------------------------
        repeat(5) @(posedge r_clk);

        r_rst = 1'b0;
        $readmemb("clauses.mem", DUT.CM.r_clause_mem);
        $readmemb("weights.mem", DUT.WM.r_weight_mem);
        $display("Weight0  = %0d", DUT.WM.r_weight_mem[0]);
$display("Weight1  = %0d", DUT.WM.r_weight_mem[1]);
$display("Weight20 = %0d", DUT.WM.r_weight_mem[20]);
$display("Weight21 = %0d", DUT.WM.r_weight_mem[21]);

        repeat(2) @(posedge r_clk);

        //------------------------------------------------------
        // Inference
        //------------------------------------------------------
        $display("");
        $display("========================================");
        $display("COALESCED TSETLIN MACHINE INFERENCE");
        $display("========================================");

        for(sample = 0;
            sample < `TEST_SAMPLES;
            sample = sample + 1)
        begin

            inference_sample
            (
                r_test_x[sample],
                r_test_y[sample]
            );

        end

        //------------------------------------------------------
        // Accuracy
        //------------------------------------------------------
        if(total_predictions != 0)
            accuracy =
            (100.0 * correct_predictions) /
            total_predictions;
        else
            accuracy = 0.0;

        //------------------------------------------------------
        // Final Report
        //------------------------------------------------------
        $display("");
        $display("========================================");
        $display("FINAL RESULTS");
        $display("========================================");
        $display("Correct Predictions : %0d",
                 correct_predictions);
        $display("Total Predictions   : %0d",
                 total_predictions);
        $display("Accuracy            : %0.2f %%", accuracy);

        $display("");
        $display("========================================");
        $display("SIMULATION FINISHED");
        $display("========================================");

        #100;

        $finish;

    end

endmodule