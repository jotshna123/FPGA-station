`timescale 1ns / 1ps
`include "tm_train_params.vh"
module ta_action_generator(
    input  wire [`STATE_BITS-1:0] i_ta_state,
    output reg                    o_ta_action
);
    always @(*) begin
        if(i_ta_state > `INITIAL_TA_STATE)
            o_ta_action = 1'b1;      // INCLUDE
        else
            o_ta_action = 1'b0;      // EXCLUDE
    end
endmodule