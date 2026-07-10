`timescale 1ns / 1ps
`include "tm_train_params.vh"

module tb_training_top;

    //----------------------------------------------------------
    // Clock & Reset
    //----------------------------------------------------------
    reg r_clk;
    reg r_rst;
    reg r_start;

    //----------------------------------------------------------
    // Training Inputs
    //----------------------------------------------------------
    reg [`NUM_FEATURES-1:0] r_x_train;
    reg [`CLASS_BITS-1:0]   r_y_train;

    //----------------------------------------------------------
    // DUT Outputs
    //----------------------------------------------------------
    wire [`CLASS_BITS-1:0] w_predicted_class;
    wire w_done;

    //----------------------------------------------------------
    // Training Dataset
    //----------------------------------------------------------
    reg [`NUM_FEATURES-1:0] r_train_x [0:`TRAIN_SAMPLES-1];
    reg [`CLASS_BITS-1:0]   r_train_y [0:`TRAIN_SAMPLES-1];

    //----------------------------------------------------------
    // Variables
    //----------------------------------------------------------
    integer epoch;
    integer sample;
    integer clause;
    integer literal;
    integer class_id;
    integer fp;
    integer c, l;
    //----------------------------------------------------------
    // DUT
    //----------------------------------------------------------
    training_top DUT
    (
        .i_clk(r_clk),
        .i_rst(r_rst),
        .i_start(r_start),
        .i_x_train(r_x_train),
        .i_y_train(r_y_train),
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
    // Read Dataset Files
    //----------------------------------------------------------
    initial
    begin

        $display("======================================");
        $display("Loading Training Dataset...");
        $display("======================================");

        $readmemb("x_train.txt", r_train_x);
        $readmemb("y_train.txt", r_train_y);

        $display("Training Dataset Loaded.");

        $display("");

    end

    //----------------------------------------------------------
    // Waveform
    //----------------------------------------------------------
    initial
    begin
        $dumpfile("training_top.vcd");
        $dumpvars(0, tb_training_top);
    end
        //----------------------------------------------------------
    // TRAINING TASK
    //----------------------------------------------------------
    task train_sample;

        input [`NUM_FEATURES-1:0] sample_x;
        input [`CLASS_BITS-1:0]   sample_y;

        begin

            //--------------------------------------------------
            // Apply Sample
            //--------------------------------------------------
            @(posedge r_clk);

            r_x_train <= sample_x;
            r_y_train <= sample_y;

            r_start <= 1'b1;

            @(posedge r_clk);

            r_start <= 1'b0;

            //--------------------------------------------------
            // Wait Until Training Completes
            //--------------------------------------------------
            wait(w_done);

            @(posedge r_clk);

            $display("----------------------------------------");
            $display("Training Sample Completed");
            $display("----------------------------------------");
            $display("Input            : %b", sample_x);
            $display("Target Class     : %0d", sample_y);
            $display("Predicted Class  : %0d", w_predicted_class);
            $display("----------------------------------------");
            $display("");

        end

    endtask


    //----------------------------------------------------------
    // PRINT LEARNED CLAUSES
    //----------------------------------------------------------
    task print_clauses;

        begin

            $display("");
            $display("========================================");
            $display("LEARNED CLAUSES");
            $display("========================================");

            for(clause = 0; clause < `NUM_CLAUSES; clause = clause + 1)
            begin

                $write("Clause %0d : ", clause);

               
                for(literal = 0; literal < `NUM_LITERALS; literal = literal + 1)
                begin
                    if(DUT.TA_MEM.r_ta_mem[clause*`NUM_LITERALS + literal] >
                      (`NUMBER_OF_STATES/2))
                      $write("1");
                   else
                      $write("0");
                  end

                $write("\n");

            end

            $display("");

        end

    endtask

    //----------------------------------------------------------
    // PRINT CLAUSE WEIGHTS
    //----------------------------------------------------------
    task print_weights;

        integer class_id;
        integer clause_id;

        begin

            $display("");
            $display("========================================");
            $display("CLAUSE WEIGHTS");
            $display("========================================");

            for(class_id = 0;
                class_id < `NUM_CLASSES;
                class_id = class_id + 1)
            begin

                $display("");

                $write("Class %0d : ", class_id);

                for(clause_id = 0;
                    clause_id < `NUM_CLAUSES;
                    clause_id = clause_id + 1)
                begin

                    $write("%4d ",
                    DUT.WM.r_weight_mem
                    [class_id*`NUM_CLAUSES + clause_id]);

                end

                $write("\n");

            end

            $display("");

        end

    endtask
        //----------------------------------------------------------
    // MAIN TEST
    //----------------------------------------------------------
    initial
    begin

        //------------------------------------------------------
        // Initialize Signals
        //------------------------------------------------------
        r_rst  = 1'b1;
        r_start = 1'b0;
        r_x_train = 0;
        r_y_train = 0;

        //------------------------------------------------------
        // Reset
        //------------------------------------------------------
        repeat(5) @(posedge r_clk);

        r_rst = 1'b0;

        repeat(2) @(posedge r_clk);

        $display("");
        $display("========================================");
        $display("COALESCED TSETLIN MACHINE TRAINING");
        $display("========================================");

        //------------------------------------------------------
        // Training
        //------------------------------------------------------
        for(epoch = 0; epoch < `EPOCHS; epoch = epoch + 1)
        begin

            $display("");
            $display("----------------------------------------");
            $display("Epoch %0d", epoch+1);
            $display("----------------------------------------");

            for(sample = 0;
                sample < `TRAIN_SAMPLES;
                sample = sample + 1)
            begin

                train_sample
                (
                    r_train_x[sample],
                    r_train_y[sample]
                );

            end

        end

        //------------------------------------------------------
        // Print Learned Clauses
        //------------------------------------------------------
        $display("");
        $display("========================================");
        $display("TRAINING FINISHED");
        $display("========================================");

        print_clauses;

        //------------------------------------------------------
        // Print Clause Weights
        //------------------------------------------------------
        print_weights;

        //------------------------------------------------------
        // Save Learned Model
        //------------------------------------------------------
        //------------------------------------------------------
// Generate clauses.mem
//------------------------------------------------------


fp = $fopen("clauses.mem","w");

for(c = 0; c < `NUM_CLAUSES; c = c + 1)
begin
    for(l = 0; l < `NUM_LITERALS; l = l + 1)
    begin
        if(DUT.TA_MEM.r_ta_mem[c*`NUM_LITERALS + l] > (`NUMBER_OF_STATES/2) )
            $fwrite(fp,"1");
        else
            $fwrite(fp,"0");
    end

    $fwrite(fp,"\n");
end

$fclose(fp);
        $writememb("weights.mem", DUT.WM.r_weight_mem);

        $display("");
        $display("========================================");
        $display("TRAINED MODEL SAVED");
        $display("========================================");
        $display("clauses.mem");
        $display("weights.mem");

        #100;

        $finish;

    end

endmodule