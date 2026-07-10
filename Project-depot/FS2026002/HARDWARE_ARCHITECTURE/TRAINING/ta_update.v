`timescale 1ns / 1ps
`include "tm_train_params.vh"

module ta_update_engine
(
    //----------------------------------------------------------
    // Feedback Information
    //----------------------------------------------------------
    input  wire                    i_update_enable,
    input  wire                    i_type1_feedback,
    input  wire                    i_type2_feedback,

    //----------------------------------------------------------
    // Current Clause Information
    //----------------------------------------------------------
    input  wire                    i_clause_output,
    input  wire                    i_literal,

    //----------------------------------------------------------
    // Current TA Information
    //----------------------------------------------------------
    input  wire [`STATE_BITS-1:0]  i_ta_state,

    

    //----------------------------------------------------------
    // Random Number
    //----------------------------------------------------------
    input  wire [7:0]              i_random_value,

    //----------------------------------------------------------
    // Outputs
    //----------------------------------------------------------
    output reg [`STATE_BITS-1:0]   o_new_ta_state
   
);

    //----------------------------------------------------------
    // Internal Signals
    //----------------------------------------------------------

    wire w_ta_action;

    //----------------------------------------------------------
    // TA Action Generator
    //----------------------------------------------------------

    ta_action_generator TAG
    (
        .i_ta_state  (i_ta_state),
        .o_ta_action (w_ta_action)
    );

    //----------------------------------------------------------
    // Probability Thresholds
    //----------------------------------------------------------

    wire w_reward_pass;
    wire w_penalty_pass;

    assign w_reward_pass  = (i_random_value < `REWARD_THRESHOLD);
    assign w_penalty_pass = (i_random_value < `PENALTY_THRESHOLD);

    //----------------------------------------------------------
    // Update Type Encoding
    //----------------------------------------------------------

    localparam UPDATE_NONE    = 2'b00;
    localparam UPDATE_REWARD  = 2'b01;
    localparam UPDATE_PENALTY = 2'b10;

    reg [1:0] r_update_type;

    //----------------------------------------------------------
    // Decision Logic
    //----------------------------------------------------------

    always @(*)
    begin

        //------------------------------------------------------
        // Default
        //------------------------------------------------------

        r_update_type = UPDATE_NONE;

        //------------------------------------------------------
        // No Feedback
        //------------------------------------------------------

        if(!i_update_enable)
        begin

            r_update_type = UPDATE_NONE;

        end

        //------------------------------------------------------
        // TYPE-I
        //------------------------------------------------------

        else if(i_type1_feedback)
        begin

            //--------------------------------------------------
            // TYPE-Ia
            //--------------------------------------------------

            if(i_clause_output)
            begin

                //------------------------------
                // Include TA
                //------------------------------

                if(w_ta_action)
                begin

                    if(i_literal)
                    begin
                        if(w_reward_pass)
                            r_update_type = UPDATE_REWARD;
                    end
                    else
                    begin
                        if(w_penalty_pass)
                            r_update_type = UPDATE_PENALTY;
                    end

                end

                //------------------------------
                // Exclude TA
                //------------------------------

                else
                begin

                    if(i_literal)
                    begin
                        if(w_penalty_pass)
                            r_update_type = UPDATE_PENALTY;
                    end
                    else
                    begin
                        if(w_reward_pass)
                            r_update_type = UPDATE_REWARD;
                    end

                end

            end

            //--------------------------------------------------
            // TYPE-Ib
            //--------------------------------------------------

            else
            begin

                // Penalize only Include TAs

                if(w_ta_action)
                begin

                    if(w_penalty_pass)
                        r_update_type = UPDATE_PENALTY;

                end

            end

        end

        //------------------------------------------------------
        // TYPE-II
        //------------------------------------------------------

        else if(i_type2_feedback)
        begin

            // Clause must have fired

            if(i_clause_output)
            begin

                // Reward only Exclude TA with Literal=0

                if((!w_ta_action) && (!i_literal))
                begin

                    r_update_type = UPDATE_REWARD;

                end

            end

        end

    end
        //----------------------------------------------------------
    // TA State Update
    //----------------------------------------------------------

    always @(*)
    begin

        //------------------------------------------------------
        // Default
        //------------------------------------------------------

        o_new_ta_state = i_ta_state;

        //------------------------------------------------------
        // Reward (cb_inc)
        //------------------------------------------------------

        if(r_update_type == UPDATE_REWARD)
        begin

            if(i_ta_state < `STATE_MAX)
                o_new_ta_state = i_ta_state + 1'b1;
            else
                o_new_ta_state = i_ta_state;

        end

        //------------------------------------------------------
        // Penalty (cb_dec)
        //------------------------------------------------------

        else if(r_update_type == UPDATE_PENALTY)
        begin

            if(i_ta_state > `STATE_MIN)
                o_new_ta_state = i_ta_state - 1'b1;
            else
                o_new_ta_state = i_ta_state;

        end

        //------------------------------------------------------
        // Inaction
        //------------------------------------------------------

        else
        begin

            o_new_ta_state = i_ta_state;

        end

    end
        //----------------------------------------------------------
    // End of Module
    //----------------------------------------------------------

endmodule