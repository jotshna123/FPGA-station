`timescale 1ns / 1ps
`include "tm_params.vh"

module top_module_tb;

    // ---------------------------------------------------------------
    // DUT I/O
    // ---------------------------------------------------------------
    reg                         r_clk_p;
    wire                        w_clk_n;
    reg                         r_btnC;
    wire [3:0]                  w_led;
   

    // ---------------------------------------------------------------
    // Test vectors are now loaded on-chip inside top_module itself
    // (same x_test_encoded.mem file, same shape), so the testbench no
    // longer needs its own local copy or the always @(*) alignment
    // block that used to drive i_test_vector - that port is gone.
    // ---------------------------------------------------------------

    reg [2:0] r_prev_state;
    reg       r_finished_printed;
    reg       r_finish_seen_prev; // delays final readout by one cycle so the
                                 // DUT's FINISH-state body has actually run
                                 // (and its non-blocking accuracy update has
                                 // settled) before we sample it

    integer r_total_seen;

    // ---------------------------------------------------------------
    // DUT instantiation
    // ---------------------------------------------------------------
    top_module dut (
        .i_clk_p      (r_clk_p),
        .i_clk_n      (w_clk_n),
        .i_btnC       (r_btnC),
        .o_led        (w_led)
    );

    // w_clk_n is just the inverse of r_clk_p - this models the same
    // differential pair the real CLK_125 LVDS oscillator drives.
    assign w_clk_n = ~r_clk_p;

    // ---------------------------------------------------------------
    // Clock generation (100 MHz)
    // ---------------------------------------------------------------
    initial r_clk_p = 1'b0;
    always #5 r_clk_p = ~r_clk_p;

    // ---------------------------------------------------------------
    // Stimulus: hold reset low, let the FSM run on its own
    // ---------------------------------------------------------------
    initial begin
        r_btnC             = 1'b0;
        r_prev_state       = 3'd0;
        r_finished_printed = 1'b0;
        r_finish_seen_prev = 1'b0;
        r_total_seen       = 0;
    end

    // ---------------------------------------------------------------
    // Result monitor. Sampled on negedge clk so that all of the DUT's
    // non-blocking updates from the prior posedge have already
    // settled (avoids the classic same-edge race when peeking at
    // internal DUT signals from the testbench).
    // ---------------------------------------------------------------
    always @(negedge r_clk_p) begin

        // A COMPARE -> NEXTVEC transition means one test vector just
        // finished being classified; r_test_index still points at the
        // vector that was just evaluated.
        if (r_prev_state == dut.COMPARE && dut.r_state != dut.COMPARE) begin
            r_total_seen = r_total_seen + 1;
            $display("[TB] Test %0d | Predicted=%0d Actual=%0d | %s",
                dut.r_test_index,
                dut.r_max_class_index_reg,
                dut.r_actual_class_mem[dut.r_test_index],
                (dut.r_max_class_index_reg == dut.r_actual_class_mem[dut.r_test_index]) ?
                    "CORRECT" : "WRONG");
        end

        // Print the final accuracy exactly once - but only on the cycle
        // AFTER the FSM first entered FINISH, since the FINISH state's
        // own body (which computes accuracy via a non-blocking
        // assignment) hasn't executed yet at the instant state first
        // becomes FINISH.
        if (r_finish_seen_prev && !r_finished_printed) begin
            r_finished_printed = 1'b1;
            $display("[TB] =================================");
            $display("[TB]  Vectors evaluated : %0d", r_total_seen);
            $display("[TB]  Correct           : %0d", dut.r_correct_count);
            $display("[TB]  Final Accuracy    : %0d %%", dut.r_accuracy);
            $display("[TB] =================================");
            #100;
            $finish;
        end

        r_finish_seen_prev = (dut.r_state == dut.FINISH);

        r_prev_state = dut.r_state;
    end

    // ---------------------------------------------------------------
    // Safety timeout in case the FSM never reaches FINISH.
    // 60ms comfortably covers up to ~14,800 vectors at the measured
    // rate (i.e. the full 10,000-image MNIST test set plus margin).
    // ---------------------------------------------------------------
    initial begin
        #60_000_000; // 60ms - sized for up to ~14,800 vectors at measured rate
        if (!r_finished_printed) begin
            $display("[TB] ERROR: simulation timed out before FINISH state was reached.");
            $finish;
        end
    end

endmodule