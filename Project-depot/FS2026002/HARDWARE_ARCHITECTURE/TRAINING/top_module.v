`timescale 1ns / 1ps
`include "tm_train_params.vh"

module top_module(

    input  wire                         i_clk,
    input  wire                         i_rst,
    input  wire                         i_start,

    input  wire [`NUM_LITERALS-1:0]     i_x_test_encoded,

    output reg  [`CLASS_BITS-1:0]       o_predicted_class,
    output reg                          o_done

);

//==========================================================
// FSM State Register
//==========================================================

reg [4:0] r_state;

//==========================================================
// Control Registers
//==========================================================

reg [`CLAUSE_BITS-1:0] r_clause_idx;
reg [`LITERAL_BITS-1:0] r_literal_idx;
reg [`CLASS_BITS-1:0]   r_class_idx;

reg                     r_clause_output;

reg                     r_clause_read_en;
reg                     r_weight_read_en;

//==========================================================
// Class Sum Registers
//==========================================================

reg signed [15:0] r_class_sum [0:`NUM_CLASSES-1];
reg signed [15:0] r_max_class_sum;
reg signed [15:0] r_temp_max;
reg [`CLASS_BITS-1:0] r_temp_pred;
integer i;

//==========================================================
// Internal Wires
//==========================================================

wire [`NUM_LITERALS-1:0] w_literals;
assign w_literals = i_x_test_encoded;

// One full clause word (NUM_LITERALS-wide action vector) comes back
// from clause_memory per clause_idx. clause_memory registers this
// output internally and only updates it when read_en is pulsed, so
// it stays stable while we index through literal_idx -- no separate
// latch/register needed on the top_module side.
wire [`NUM_LITERALS-1:0] w_clause_word;
reg r_clause_out_mem [0:`NUM_CLAUSES-1];

wire w_clause_action;
assign w_clause_action = w_clause_word[r_literal_idx];

wire w_literal_pass;

wire signed [15:0] w_clause_weight;
reg signed [15:0] r_clause_weight_reg;

//==========================================================
// Clause Memory
//==========================================================
// NOTE: This matches the ACTUAL clause_memory.v you provided:
//   - Sync read, 1-cycle latency: assert read_en with clause_idx,
//     clause_out is valid the following clock edge.
//   - clause_out is the FULL NUM_LITERALS-bit action vector for
//     that clause (not a single bit selected by literal_idx).
//   - There is NO write port on this memory at all.
// So we read once per clause (not once per literal); clause_out
// itself holds steady inside clause_memory until the next read_en
// pulse, so top_module just indexes the wire with literal_idx.
//==========================================================

clause_memory CM (

    .i_clk(i_clk),

    .i_read_en(r_clause_read_en),
    .i_clause_idx(r_clause_idx),
    .o_clause_out(w_clause_word)

);

//==========================================================
// Clause Evaluator
//==========================================================

clause_evaluator CE (

    .i_literal      (w_literals[r_literal_idx]),
    .i_ta_action    (w_clause_action),
    .o_literal_pass (w_literal_pass)

);

//==========================================================
// Weight Memory
//==========================================================

weight_memory WM (

    .i_clk(i_clk),
    .i_rst(i_rst),

    // Read Interface
    .i_read_en(r_weight_read_en),
    .i_class_idx(r_class_idx),
    .i_clause_idx(r_clause_idx),
    .o_weight_out(w_clause_weight),

    // Write Interface (Used during Training)
    .i_write_en(1'b0),
    .i_wr_class_idx({`CLASS_BITS{1'b0}}),
    .i_wr_clause_idx({`CLAUSE_BITS{1'b0}}),
    .i_weight_in(16'sd0)

);

//==========================================================
// FSM States
//==========================================================

localparam IDLE              = 5'd0;
localparam GEN_LITERALS      = 5'd1;
localparam INIT_CLASS_SUMS   = 5'd2;
localparam READ_CLAUSE       = 5'd3;
localparam CHECK_LITERAL     = 5'd4;
localparam NEXT_LITERAL      = 5'd5;
localparam READ_WEIGHT       = 5'd6;
localparam WAIT_WEIGHT       = 5'd7;
localparam UPDATE_CLASS_SUM  = 5'd8;
localparam NEXT_CLASS        = 5'd9;
localparam NEXT_CLAUSE       = 5'd10;
localparam FIND_MAX          = 5'd11;
localparam DONE_STATE        = 5'd12;
localparam LATCH_WEIGHT      = 5'd13;


//==========================================================
// FSM
//==========================================================

always @(posedge i_clk) begin

    if(i_rst) begin

        r_state <= IDLE;

        o_done <= 1'b0;

        o_predicted_class <= 0;

        r_clause_idx <= 0;
        r_literal_idx <= 0;
        r_class_idx <= 0;

        r_clause_output <= 1'b1;

        r_clause_read_en <= 1'b0;
        r_weight_read_en <= 1'b0;

        r_max_class_sum <= 16'sd0;

        for(i = 0; i < `NUM_CLASSES; i = i + 1)
            r_class_sum[i] <= 16'sd0;

    end
    else begin

        case(r_state)

            //--------------------------------------------------
            // IDLE
            //--------------------------------------------------
            IDLE: begin
                o_done <= 1'b0;

                r_clause_read_en <= 1'b0;
                r_weight_read_en <= 1'b0;

                if(i_start)
                begin
                    r_clause_idx    <= 0;
                    r_class_idx     <= 0;
                    r_literal_idx   <= 0;

                    r_clause_output <= 1'b1;

                    r_max_class_sum <= 0;
                    o_predicted_class <= 0;

                    r_state <= GEN_LITERALS;
                end
            end

            //--------------------------------------------------
            // Generate Literals
            //--------------------------------------------------
            GEN_LITERALS: begin

                r_clause_idx <= 0;
                r_literal_idx <= 0;
                r_class_idx <= 0;

                r_clause_output <= 1'b1;

                r_state <= INIT_CLASS_SUMS;

            end

            //--------------------------------------------------
            // Clear Class Sums
            //--------------------------------------------------
            INIT_CLASS_SUMS: begin

                for(i = 0; i < `NUM_CLASSES; i = i + 1)
                begin
                    r_class_sum[i] <= 16'sd0;
                end

                r_clause_idx    <= 0;
                r_class_idx     <= 0;
                r_literal_idx   <= 0;
                r_clause_output <= 1'b1;

                r_state <= READ_CLAUSE;

            end

            //--------------------------------------------------
            // READ CLAUSE WORD (once per clause)
            //--------------------------------------------------
            // Pulse read_en for one cycle to fetch clause_mem[clause_idx].
            // clause_memory registers the result internally and holds it
            // until the next read_en pulse, so by the time we reach
            // CHECK_LITERAL next cycle, clause_out (clause_word) is
            // already valid -- no separate wait state needed.
            //--------------------------------------------------
            READ_CLAUSE: begin

                r_clause_read_en <= 1'b1;
                r_literal_idx    <= 0;

                r_state <= CHECK_LITERAL;

            end

            //--------------------------------------------------
            // CHECK CURRENT LITERAL
            //--------------------------------------------------
            CHECK_LITERAL: begin

                r_clause_read_en <= 1'b0;

                if(!w_literal_pass) begin
                    r_clause_output <= 1'b0;
                end

                r_state <= NEXT_LITERAL;

            end

            //--------------------------------------------------
            // NEXT LITERAL
            //--------------------------------------------------
            NEXT_LITERAL: begin

                if(r_literal_idx == (`NUM_LITERALS-1))
                begin

                    r_literal_idx <= 0;

                    r_class_idx <= 0;

                    r_state <= READ_WEIGHT;

                end
                else
                begin

                    r_literal_idx <= r_literal_idx + 1;

                    r_state <= CHECK_LITERAL;

                end

            end

            //--------------------------------------------------
            // READ CLAUSE WEIGHT
            //--------------------------------------------------
            READ_WEIGHT: begin

                r_weight_read_en <= 1'b1;

                r_state <= WAIT_WEIGHT;

            end

            //--------------------------------------------------
            // WAIT FOR WEIGHT MEMORY
            //--------------------------------------------------
            WAIT_WEIGHT: begin

                r_weight_read_en <= 1'b0;

                
              

                r_state <= LATCH_WEIGHT;

            end
            
            
            LATCH_WEIGHT: begin

    r_clause_weight_reg <= w_clause_weight;

    r_state <= UPDATE_CLASS_SUM;

end
//--------------------------------------------------
// UPDATE CLASS SUM
//--------------------------------------------------
UPDATE_CLASS_SUM:
begin

    // Print weights only once per clause
    if(r_class_idx == 0)
    begin
        $display("Clause %0d : W0=%0d  W1=%0d  Out=%0d",
                 r_clause_idx,
                 WM.r_weight_mem[r_clause_idx],
                 WM.r_weight_mem[`NUM_CLAUSES + r_clause_idx],
                 r_clause_output);
                 
                
    end

    if(r_clause_output)
        r_class_sum[r_class_idx] <= r_class_sum[r_class_idx] + r_clause_weight_reg;

    r_state <= NEXT_CLASS;

end

            //--------------------------------------------------
            // NEXT CLASS
            //--------------------------------------------------
            NEXT_CLASS: begin

                if(r_class_idx == (`NUM_CLASSES-1))
                begin

                    r_class_idx <= 0;

                    r_state <= NEXT_CLAUSE;

                end
                else
                begin

                    r_class_idx <= r_class_idx + 1;

                    r_state <= READ_WEIGHT;

                end

            end

            //--------------------------------------------------
            // NEXT CLAUSE
            //--------------------------------------------------
            NEXT_CLAUSE: begin

                if(r_clause_idx == (`NUM_CLAUSES-1))
                begin

                    r_state <= FIND_MAX;

                end
                else
                begin

                    r_clause_idx <= r_clause_idx + 1;

                    r_literal_idx <= 0;

                    r_clause_output <= 1'b1;

                    r_state <= READ_CLAUSE;

                end

            end

            //--------------------------------------------------
            // FIND CLASS WITH MAXIMUM SUM
            //--------------------------------------------------
            FIND_MAX: begin

                r_temp_max = r_class_sum[0];
                r_temp_pred = 0;

                for(i=1;i<`NUM_CLASSES;i=i+1)
                begin
                    if(r_class_sum[i] > r_temp_max)
                    begin
                        r_temp_max = r_class_sum[i];
                        r_temp_pred = i;
                    end
                end

                r_max_class_sum <= r_temp_max;
                $display("----------------------------------------");
$display("Clause Outputs");
$display("----------------------------------------");

for(i = 0; i < `NUM_CLAUSES; i = i + 1)
    $write("%0d ", r_clause_out_mem[i]);

$display("");
$display("----------------------------------------");
$display("Class0 Sum = %0d", r_class_sum[0]);
$display("Class1 Sum = %0d", r_class_sum[1]);
$display("----------------------------------------");
                o_predicted_class <= r_temp_pred;
                $display("Predicted = %0d", r_temp_pred);
$display("----------------------------------------");

                r_state <= DONE_STATE;

            end

            //--------------------------------------------------
            // DONE
            //--------------------------------------------------
            DONE_STATE: begin

                o_done <= 1'b1;

                if(!i_start)
                    r_state <= IDLE;

            end

            //--------------------------------------------------
            // Default
            //--------------------------------------------------
            default:
                r_state <= IDLE;

        endcase

    end

end

endmodule