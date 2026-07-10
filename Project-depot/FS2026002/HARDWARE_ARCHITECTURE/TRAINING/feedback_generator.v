`timescale 1ns / 1ps
`include "tm_train_params.vh"
module feedback_generator(
    input  wire [`CLASS_BITS-1:0] i_target_class,
    input  wire [`CLASS_BITS-1:0] i_negative_class,
    input  wire [`CLASS_BITS-1:0] i_current_class,
    input  wire signed [15:0] i_class_sum,
    input  wire i_clause_output,
    input  wire [31:0] i_random_value,
    output reg o_type1_feedback,
    output reg o_type2_feedback,
    output reg o_update_enable
);
    reg signed [15:0] r_clamped_sum;
    reg [15:0] r_threshold;
    reg [15:0] r_random_threshold;
    always @(*) begin
        //------------------------------------------------------
        // Defaults
        //------------------------------------------------------
        o_type1_feedback = 1'b0;
        o_type2_feedback = 1'b0;
        o_update_enable  = 1'b0;
        //------------------------------------------------------
        // Clamp class_sum to [-T, T]
        //------------------------------------------------------
        if(i_class_sum > `THRESHOLD_T)
            r_clamped_sum = `THRESHOLD_T;
        else if(i_class_sum < -`THRESHOLD_T)
            r_clamped_sum = -`THRESHOLD_T;
        else
            r_clamped_sum = i_class_sum;
        //------------------------------------------------------
        // Random number in range [0, 2T-1]
        //------------------------------------------------------
        r_random_threshold = i_random_value % (2*`THRESHOLD_T);
        //------------------------------------------------------
        // Target Class -> Type I Feedback
        //------------------------------------------------------
        if(i_current_class == i_target_class)
        begin
            r_threshold = `THRESHOLD_T - r_clamped_sum;
            if(r_random_threshold < r_threshold)
            begin
                o_type1_feedback = 1'b1;
                o_update_enable  = 1'b1;
            end
        end
        //------------------------------------------------------
        // Negative Class -> Type II Feedback
        //------------------------------------------------------
        else if(i_current_class == i_negative_class)
        begin
            r_threshold = `THRESHOLD_T + r_clamped_sum;
            if(r_random_threshold < r_threshold)
            begin
                o_type2_feedback = 1'b1;
                o_update_enable  = 1'b1;
            end
        end
    end
endmodule