`timescale 1ns / 1ps

module tm_accuracy_counter #(
    parameter COUNT_WIDTH       = 32,
    parameter CLASS_INDEX_WIDTH = 8
)(
    input  wire                         i_clk,
    input  wire                         i_rst_n,
    input  wire                         i_clear,
    input  wire                         i_enable,
    input  wire [CLASS_INDEX_WIDTH-1:0] i_predicted_class,
    input  wire [CLASS_INDEX_WIDTH-1:0] i_actual_label,
    output reg  [COUNT_WIDTH-1:0]       o_correct_count
);

    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_correct_count <= {COUNT_WIDTH{1'b0}};
        end else if (i_clear) begin
            o_correct_count <= {COUNT_WIDTH{1'b0}};
        end else if (i_enable) begin
            if (i_predicted_class == i_actual_label[CLASS_INDEX_WIDTH-1:0]) begin
                o_correct_count <= o_correct_count + 1'b1;
            end
        end
    end
endmodule

