`timescale 1ns / 1ps
`include "tm_train_params.vh"
module negative_class_generator(
    input  wire [`CLASS_BITS-1:0] i_target_class,
    input  wire [`CLASS_BITS-1:0] i_random_class,
    output reg [`CLASS_BITS-1:0] o_negative_class
);
always @(*) begin
    if(i_random_class != i_target_class)
        o_negative_class = i_random_class;
    else begin
        if(i_target_class == (`NUM_CLASSES-1))
            o_negative_class = 0;
        else
            o_negative_class = i_target_class + 1'b1;
    end
end
endmodule