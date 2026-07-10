`timescale 1ns / 1ps
`include "tm_train_params.vh"

module training_top
(
    //----------------------------------------------------------
    // Clock & Control
    //----------------------------------------------------------
    input  wire                         i_clk,
    input  wire                         i_rst,
    input  wire                         i_start,
    

    //----------------------------------------------------------
    // Training Sample
    //----------------------------------------------------------
    input  wire [`NUM_FEATURES-1:0]     i_x_train,
    input  wire [`CLASS_BITS-1:0]       i_y_train,

    //----------------------------------------------------------
    // Outputs
    //----------------------------------------------------------
    output reg  [`CLASS_BITS-1:0]       o_predicted_class,
    output reg                          o_done
);

    //----------------------------------------------------------
    // FSM
    //----------------------------------------------------------
    reg [5:0] r_state;

    //----------------------------------------------------------
    // Update Phase
    //----------------------------------------------------------
    localparam TARGET_PHASE   = 1'b0;
    localparam NEGATIVE_PHASE = 1'b1;

    reg r_update_phase;

    //----------------------------------------------------------
    // Current Updating Class
    //----------------------------------------------------------
    reg [`CLASS_BITS-1:0] r_current_update_class;

    //----------------------------------------------------------
    // Controller Counters
    //----------------------------------------------------------
    reg [`CLAUSE_BITS-1:0]  r_clause_idx;
    reg [`LITERAL_BITS-1:0] r_literal_idx;
    reg [`CLASS_BITS-1:0]   r_class_idx;

    reg [`SAMPLE_COUNTER_BITS-1:0] r_sample_counter;
    reg [`EPOCH_COUNTER_BITS-1:0]  r_epoch_counter;

    //----------------------------------------------------------
    // Memory Control
    //----------------------------------------------------------
    reg r_ta_read_en;
    reg r_ta_write_en;

    reg r_weight_read_en;
    reg r_weight_write_en;
    reg signed [15:0] r_clause_weight_reg;

    //----------------------------------------------------------
    // Clause Evaluation
    //----------------------------------------------------------
    reg r_clause_output;

    //----------------------------------------------------------
    // Class Sums
    //----------------------------------------------------------
    reg signed [15:0] r_class_sum [0:`NUM_CLASSES-1];

    reg signed [15:0] r_max_class_sum;
    reg signed [15:0] r_updated_weight;

    //----------------------------------------------------------
    // Temporary Registers
    //----------------------------------------------------------
    reg signed [15:0] r_temp_max_sum;
    reg [`CLASS_BITS-1:0] r_temp_predicted_class;
    reg r_clause_out_mem [0:`NUM_CLAUSES-1];

    //----------------------------------------------------------
    // Random Class
    //----------------------------------------------------------
    wire [`CLASS_BITS-1:0] w_random_class;

    //----------------------------------------------------------
    // Literal Generator
    //----------------------------------------------------------
    wire [`NUM_LITERALS-1:0] w_literals;

    //----------------------------------------------------------
    // TA Memory
    //----------------------------------------------------------
    wire [`STATE_BITS-1:0] w_ta_state;

    //----------------------------------------------------------
    // TA Action
    //----------------------------------------------------------
    wire w_ta_action;

    //----------------------------------------------------------
    // Clause Evaluator
    //----------------------------------------------------------
    wire w_literal_pass;
    wire [`CLASS_BITS-1:0] w_weight_class_idx;

    //----------------------------------------------------------
    // Weight Memory
    //----------------------------------------------------------
    wire signed [15:0] w_clause_weight;

    //----------------------------------------------------------
    // LFSR
    //----------------------------------------------------------
    wire [31:0] w_random_value;

    //----------------------------------------------------------
    // Negative Class
    //----------------------------------------------------------
    wire [`CLASS_BITS-1:0] w_negative_class;

    //----------------------------------------------------------
    // Feedback
    //----------------------------------------------------------
    wire w_update_enable;
    wire w_type1_feedback;
    wire w_type2_feedback;

    //----------------------------------------------------------
    // TA Update
    //----------------------------------------------------------
    wire [`STATE_BITS-1:0] w_new_ta_state;

    //----------------------------------------------------------
    // Random Class Generator
    //----------------------------------------------------------
    assign w_random_class = w_random_value % `NUM_CLASSES;

    //----------------------------------------------------------
    // Loop Variable
    //----------------------------------------------------------
    integer i;

    //----------------------------------------------------------
    // FSM States
    //----------------------------------------------------------
  
    localparam IDLE                = 6'd0;
localparam GEN_LITERALS        = 6'd1;
localparam INIT_CLASS_SUMS     = 6'd2;
localparam READ_TA             = 6'd3;
localparam WAIT_TA             = 6'd4;
localparam CHECK_LITERAL       = 6'd5;
localparam NEXT_LITERAL        = 6'd6;
localparam READ_WEIGHT         = 6'd7;
localparam WAIT_WEIGHT         = 6'd8;
localparam UPDATE_CLASS_SUM    = 6'd9;
localparam NEXT_CLASS          = 6'd10;
localparam NEXT_CLAUSE         = 6'd11;
localparam FIND_MAX            = 6'd12;
localparam TARGET_INIT         = 6'd13;
localparam UPDATE_READ_TA      = 6'd14;
localparam UPDATE_WAIT_TA      = 6'd15;
localparam UPDATE_TA           = 6'd16;
localparam UPDATE_WRITE_TA     = 6'd17;
localparam UPDATE_WAIT_WRITE   = 6'd18;
localparam UPDATE_NEXT_LITERAL = 6'd19;
localparam UPDATE_READ_WEIGHT  = 6'd20;
localparam UPDATE_WAIT_WEIGHT  = 6'd21;
localparam UPDATE_WEIGHT       = 6'd22;
localparam UPDATE_NEXT_CLAUSE  = 6'd23;
localparam SWITCH_TO_NEGATIVE  = 6'd24;
localparam NEXT_SAMPLE         = 6'd25;
localparam NEXT_EPOCH          = 6'd26;
localparam DONE_STATE          = 6'd27;
localparam UPDATE_WRITE_WEIGHT = 6'd28;
    
   assign w_weight_class_idx = r_current_update_class;
        //----------------------------------------------------------
    // Literal Generator
    //----------------------------------------------------------
    literal_generator LG
    (
        .i_x_in       (i_x_train),
        .o_literals   (w_literals)
    );

    //----------------------------------------------------------
    // TA Memory
    //----------------------------------------------------------
    ta_memory TA_MEM
    (
        .i_clk             (i_clk),
        .i_rst             (i_rst),

        // Read Interface
        .i_read_en         (r_ta_read_en),
        .i_clause_idx      (r_clause_idx),
        .i_literal_idx     (r_literal_idx),
        .o_ta_state_out    (w_ta_state),

        // Write Interface
        .i_write_en        (r_ta_write_en),
        .i_wr_clause_idx   (r_clause_idx),
        .i_wr_literal_idx  (r_literal_idx),
        .i_ta_state_in     (w_new_ta_state)
    );

    //----------------------------------------------------------
    // TA Action Generator
    //----------------------------------------------------------
    ta_action_generator TAG
    (
        .i_ta_state    (w_ta_state),
        .o_ta_action   (w_ta_action)
    );

    //----------------------------------------------------------
    // Clause Evaluator
    //----------------------------------------------------------
    clause_evaluator CE
    (
        .i_literal       (w_literals[r_literal_idx]),
        .i_ta_action     (w_ta_action),
        .o_literal_pass  (w_literal_pass)
    );

    //----------------------------------------------------------
    // Weight Memory
    //----------------------------------------------------------
    weight_memory WM
    (
        .i_clk             (i_clk),
        .i_rst             (i_rst),

        // Read Interface
        .i_read_en         (r_weight_read_en),
        .i_class_idx       (w_weight_class_idx),
        .i_clause_idx      (r_clause_idx),
        .o_weight_out      (w_clause_weight),

        // Write Interface
        .i_write_en        (r_weight_write_en),
        .i_wr_class_idx    (r_current_update_class),
        .i_wr_clause_idx   (r_clause_idx),
        .i_weight_in       (r_updated_weight)
    );

    //----------------------------------------------------------
    // Random Number Generator
    //----------------------------------------------------------
    lfsr_random RNG
    (
        .i_clk            (i_clk),
        .i_rst            (i_rst),
        .i_enable         (1'b1),

        .o_random_value   (w_random_value)
    );

    //----------------------------------------------------------
    // Negative Class Generator
    //----------------------------------------------------------
    negative_class_generator NCG
    (
        .i_target_class    (i_y_train),
        .i_random_class    (w_random_class),
        .o_negative_class  (w_negative_class)
    );

    //----------------------------------------------------------
    // Feedback Generator
    //----------------------------------------------------------
    feedback_generator FG
    (
        .i_target_class     (i_y_train),
        .i_negative_class   (w_negative_class),
        .i_current_class    (r_current_update_class),

        .i_class_sum        (r_class_sum[r_current_update_class]),

        .i_clause_output    (r_clause_output),

        .i_random_value     (w_random_value),

        .o_type1_feedback   (w_type1_feedback),
        .o_type2_feedback   (w_type2_feedback),
        .o_update_enable    (w_update_enable)
    );

    //----------------------------------------------------------
    // TA Update Engine
    //----------------------------------------------------------
    ta_update_engine TUE
    (
        .i_update_enable      (w_update_enable),
        .i_type1_feedback     (w_type1_feedback),
        .i_type2_feedback     (w_type2_feedback),

        .i_clause_output      (r_clause_output),
        .i_literal            (w_literals[r_literal_idx]),

        .i_ta_state           (w_ta_state),

        .i_random_value       (w_random_value[7:0]),

        .o_new_ta_state       (w_new_ta_state)
    );
    //----------------------------------------------------------
// FSM
//----------------------------------------------------------
always @(posedge i_clk)
begin

    if(i_rst)
    begin

        r_state <= IDLE;

        o_done <= 1'b0;
        o_predicted_class <= 0;

        r_clause_idx  <= 0;
        r_literal_idx <= 0;
        r_class_idx   <= 0;

        r_sample_counter <= 0;
        r_epoch_counter  <= 0;

        r_update_phase <= TARGET_PHASE;
        r_current_update_class <= 0;

        r_ta_read_en      <= 1'b0;
        r_ta_write_en     <= 1'b0;

        r_weight_read_en  <= 1'b0;
        r_weight_write_en <= 1'b0;

        r_clause_output <= 1'b1;

        r_updated_weight <= 16'sd0;

        r_max_class_sum <= -16'sd32768;
        r_temp_max_sum  <= -16'sd32768;

        r_temp_predicted_class <= 0;

        for(i=0;i<`NUM_CLASSES;i=i+1)
            r_class_sum[i] <= 16'sd0;

    end
    else
    begin

        case(r_state)

        //--------------------------------------------------
        // IDLE
        //--------------------------------------------------
        IDLE:
        begin
           o_done<=1'b0;
          

            if(i_start)
                r_state <= GEN_LITERALS;      // Training FSM
     end

        //--------------------------------------------------
        // GENERATE LITERALS
        //--------------------------------------------------
        GEN_LITERALS:
        begin

            r_clause_idx  <= 0;
            r_literal_idx <= 0;
            r_class_idx   <= 0;

            r_clause_output <= 1'b1;

            r_state <= INIT_CLASS_SUMS;

        end

        //--------------------------------------------------
        // INITIALIZE CLASS SUMS
        //--------------------------------------------------
        INIT_CLASS_SUMS:
        begin

            for(i=0;i<`NUM_CLASSES;i=i+1)
                r_class_sum[i] <= 16'sd0;

            r_clause_idx    <= 0;
            r_literal_idx   <= 0;
            r_class_idx     <= 0;
            r_clause_output <= 1'b1;

            r_state <= READ_TA;

        end

        //--------------------------------------------------
        // READ TA
        //--------------------------------------------------
        READ_TA:
        begin

            r_ta_read_en <= 1'b1;

            r_state <= WAIT_TA;

        end

        //--------------------------------------------------
        // WAIT TA
        //--------------------------------------------------
        WAIT_TA:
        begin

            r_ta_read_en <= 1'b0;

            r_state <= CHECK_LITERAL;

        end

        //--------------------------------------------------
        // CHECK LITERAL
        //--------------------------------------------------
        CHECK_LITERAL:
        begin

            if(!w_literal_pass)
                r_clause_output <= 1'b0;

            r_state <= NEXT_LITERAL;

        end

        //--------------------------------------------------
        // NEXT LITERAL
        //--------------------------------------------------
        NEXT_LITERAL:
        begin

            if(r_literal_idx == (`NUM_LITERALS-1))
            begin
                
    r_clause_out_mem[r_clause_idx] <= r_clause_output;
                 
                r_literal_idx <= 0;

                r_state <= READ_WEIGHT;

            end
            else
            begin

                r_literal_idx <= r_literal_idx + 1'b1;

                r_state <= READ_TA;

            end

        end

        //--------------------------------------------------
        // READ WEIGHT
        //--------------------------------------------------
        READ_WEIGHT:
        begin

            r_weight_read_en <= 1'b1;

            r_state <= WAIT_WEIGHT;

        end

        //--------------------------------------------------
        // WAIT WEIGHT
        //--------------------------------------------------
        WAIT_WEIGHT:
        begin

            r_weight_read_en <= 1'b0;
            r_clause_weight_reg <= w_clause_weight;

            r_state <= UPDATE_CLASS_SUM;

        end

        //--------------------------------------------------
        // UPDATE CLASS SUM
        //--------------------------------------------------
        UPDATE_CLASS_SUM:
        begin

            if(r_clause_output) begin
                r_class_sum[r_class_idx] <= r_class_sum[r_class_idx] + r_clause_weight_reg;
             end
            r_state <= NEXT_CLASS;

        end

        //--------------------------------------------------
        // NEXT CLASS
        //--------------------------------------------------
        NEXT_CLASS:
        begin

            if(r_class_idx == (`NUM_CLASSES-1))
            begin

                r_class_idx <= 0;

                r_state <= NEXT_CLAUSE;

            end
            else
            begin

                r_class_idx <= r_class_idx + 1'b1;

                r_state <= READ_WEIGHT;

            end

        end

        //--------------------------------------------------
        // NEXT CLAUSE
        //--------------------------------------------------
        NEXT_CLAUSE:
        begin

            if(r_clause_idx == (`NUM_CLAUSES-1))
            begin

                // Reset max-tracking registers before FIND_MAX computes them
                r_temp_max_sum         <= -16'sd32768;
                r_temp_predicted_class <= 0;

                r_state <= FIND_MAX;

            end
            else
            begin

                r_clause_idx <= r_clause_idx + 1'b1;
                r_literal_idx <= 0;
                r_clause_output <= 1'b1;

                r_state <= READ_TA;

            end

        end
                //--------------------------------------------------
        // FIND MAX CLASS
        //--------------------------------------------------
        FIND_MAX:
        begin

            r_temp_max_sum = r_class_sum[0];
            r_temp_predicted_class = 0;

            for(i = 1; i < `NUM_CLASSES; i = i + 1)
            begin
                if(r_class_sum[i] > r_temp_max_sum)
                begin
                    r_temp_max_sum = r_class_sum[i];
                    r_temp_predicted_class = i[`CLASS_BITS-1:0];
                end
            end

            r_max_class_sum <= r_temp_max_sum;
            o_predicted_class <= r_temp_predicted_class;

    r_state <= TARGET_INIT;


        end

        //--------------------------------------------------
        // TARGET UPDATE INITIALIZATION
        //--------------------------------------------------
        TARGET_INIT:
        begin
            
            r_update_phase <= TARGET_PHASE;

            r_current_update_class <= i_y_train;


            r_clause_idx <= 0;
            r_literal_idx <= 0;

            r_clause_output <= r_clause_out_mem[0];

            r_state <= UPDATE_READ_TA;

        end

        //--------------------------------------------------
        // READ TA FOR UPDATE
        //--------------------------------------------------
        UPDATE_READ_TA:
        begin

            r_ta_read_en <= 1'b1;

            r_state <= UPDATE_WAIT_TA;

        end

        //--------------------------------------------------
        // WAIT TA MEMORY
        //--------------------------------------------------
        UPDATE_WAIT_TA:
        begin

            r_ta_read_en <= 1'b0;

            r_state <= UPDATE_TA;

        end

        //--------------------------------------------------
        // UPDATE TA
        //--------------------------------------------------
        UPDATE_TA:
        begin
             
            r_state <= UPDATE_WRITE_TA;

        end

        //--------------------------------------------------
        // WRITE UPDATED TA
        //--------------------------------------------------
        UPDATE_WRITE_TA:
        begin

            r_ta_write_en <= 1'b1;

            r_state <=UPDATE_WAIT_WRITE;

        end
        //--------------------------------------------------
// WAIT AFTER TA WRITE
//--------------------------------------------------
UPDATE_WAIT_WRITE:
begin

    r_ta_write_en <= 1'b0;

    r_state <= UPDATE_NEXT_LITERAL;

end
        //--------------------------------------------------
        // NEXT LITERAL
        //--------------------------------------------------
        UPDATE_NEXT_LITERAL:
        begin

            r_ta_write_en <= 1'b0;

            if(r_literal_idx == (`NUM_LITERALS-1))
            begin

                r_literal_idx <= 0;

                r_state <= UPDATE_READ_WEIGHT;

            end
            else
            begin

                r_literal_idx <= r_literal_idx + 1'b1;

                r_state <= UPDATE_READ_TA;

            end

        end
        //--------------------------------------------------
// READ CLAUSE WEIGHT
//--------------------------------------------------
UPDATE_READ_WEIGHT:
begin

    r_weight_read_en <= 1'b1;

    r_state <= UPDATE_WAIT_WEIGHT;

end


//--------------------------------------------------
// WAIT FOR WEIGHT MEMORY
//--------------------------------------------------
UPDATE_WAIT_WEIGHT:
begin

    r_weight_read_en <= 1'b0;

    r_state <= UPDATE_WEIGHT;

end
                //--------------------------------------------------
        // UPDATE CLAUSE WEIGHT
        //--------------------------------------------------
        UPDATE_WEIGHT:
        begin
          

            r_updated_weight = w_clause_weight;

            //--------------------------------------------------
            // TARGET CLASS
            //--------------------------------------------------
            if(r_update_phase == TARGET_PHASE)
            begin

                if(w_update_enable &&
                   w_type1_feedback &&
                   r_clause_output)
                begin
                    if(w_clause_weight < `WEIGHT_MAX)
    r_updated_weight = w_clause_weight + 16'sd1;
else
    r_updated_weight = w_clause_weight;
                end

            end

            //--------------------------------------------------
            // NEGATIVE CLASS
            //--------------------------------------------------
            else
            begin

                if(w_update_enable &&
                   w_type2_feedback &&
                   r_clause_output)
                begin
                    if(w_clause_weight > `WEIGHT_MIN)
    r_updated_weight = w_clause_weight - 16'sd1;
else
    r_updated_weight = w_clause_weight;
                end

            end

            r_state <= UPDATE_WRITE_WEIGHT;

        end
        //--------------------------------------------------
// WRITE UPDATED WEIGHT
//--------------------------------------------------
UPDATE_WRITE_WEIGHT:
begin

    r_weight_write_en <= 1'b1;

    r_state <= UPDATE_NEXT_CLAUSE;

end

        //--------------------------------------------------
        // NEXT CLAUSE
        //--------------------------------------------------
        UPDATE_NEXT_CLAUSE:
        begin

            r_weight_write_en <= 1'b0;

            if(r_clause_idx == (`NUM_CLAUSES-1))
            begin

                if(r_update_phase == TARGET_PHASE)
                begin

                    r_update_phase <= NEGATIVE_PHASE;

                    r_current_update_class <= w_negative_class;
                   

                    r_clause_idx <= 0;
                    r_literal_idx <= 0;
                    r_clause_output <= r_clause_out_mem[0];

                    r_state <= UPDATE_READ_TA;

                end
                else
                begin

                    r_state <= NEXT_SAMPLE;

                end

            end
            else
            begin

                r_clause_idx <= r_clause_idx + 1'b1;
                r_literal_idx <= 0;
                r_clause_output <= r_clause_out_mem[r_clause_idx + 1'b1];

                r_state <= UPDATE_READ_TA;

            end

        end
                //--------------------------------------------------
        // NEXT SAMPLE
        //--------------------------------------------------
        NEXT_SAMPLE:
        begin

            r_update_phase <= TARGET_PHASE;

            r_current_update_class <= 0;

            if(r_sample_counter == (`TRAIN_SAMPLES-1))
            begin

                r_sample_counter <= 0;

                r_state <= NEXT_EPOCH;

            end
            else
            begin

                r_sample_counter <= r_sample_counter + 1'b1;

                r_state <= GEN_LITERALS;

            end

        end

        //--------------------------------------------------
        // NEXT EPOCH
        //--------------------------------------------------
        NEXT_EPOCH:
        begin

            if(r_epoch_counter == (`EPOCHS-1))
            begin

                r_state <= DONE_STATE;

            end
            else
            begin

                r_epoch_counter  <= r_epoch_counter + 1'b1;
                r_sample_counter <= 0;

                r_clause_idx  <= 0;
                r_literal_idx <= 0;
                r_class_idx   <= 0;

                r_update_phase <= TARGET_PHASE;
                r_current_update_class <= 0;

                r_state <= GEN_LITERALS;

            end

        end

        //--------------------------------------------------
        // DONE
        //--------------------------------------------------
        DONE_STATE:
        begin

            o_done <= 1'b1;


            if(!i_start)
                r_state <= IDLE;

        end

        //--------------------------------------------------
        // DEFAULT
        //--------------------------------------------------
        default:
        begin

            r_state <= IDLE;

        end

        endcase

    end

end

endmodule