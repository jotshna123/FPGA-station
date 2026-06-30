
module tm_argmax #(
    parameter MAX_CLASSES       = 7,
    parameter SCORE_WIDTH       = 32,
    parameter CLASS_INDEX_WIDTH = $clog2(MAX_CLASSES)
)(
    input  wire [CLASS_INDEX_WIDTH-1:0]              i_num_classes,
    input  wire [MAX_CLASSES*SCORE_WIDTH-1:0]        i_score_bus,
    output reg  [CLASS_INDEX_WIDTH-1:0]              o_predicted_class
);

    integer i;

    reg signed [SCORE_WIDTH-1:0] r_max_score;
    reg signed [SCORE_WIDTH-1:0] r_current_score;

    always @(*) begin
        r_max_score       = i_score_bus[0 +: SCORE_WIDTH];
        o_predicted_class = {CLASS_INDEX_WIDTH{1'b0}};

        for (i = 1; i < MAX_CLASSES; i = i + 1) begin
            if (i < i_num_classes) begin
                r_current_score = i_score_bus[(i*SCORE_WIDTH) +: SCORE_WIDTH];

                if (r_current_score > r_max_score) begin
                    r_max_score       = r_current_score;
                    o_predicted_class = i[CLASS_INDEX_WIDTH-1:0];
                end
            end
        end
    end

endmodule

