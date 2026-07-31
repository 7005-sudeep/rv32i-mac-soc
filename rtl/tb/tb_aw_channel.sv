`timescale 1ns/1ps
module tb_aw_channel;

    logic clk = 0;
    logic rst_n;
    logic awvalid, awready;
    logic [3:0] awid, awlen;
    logic [2:0] awsize;
    logic [31:0] awaddr;
    logic [1:0] awburst;
    logic burst_done;
    logic [31:0] aw_addr_q;
    logic [3:0] aw_id_q, aw_len_q;
    logic [2:0] aw_size_q;
    logic [1:0] aw_burst_q;

    int errors = 0;

    aw_channel dut (.*);

    always #5 clk = ~clk;

    task automatic check(input bit cond, input string msg);
        if (!cond) begin $display("[FAIL] %s", msg); errors++; end
        else $display("[PASS] %s", msg);
    endtask

    initial begin
        rst_n = 0; awvalid = 0; awaddr = 0; awid = 0; awlen = 0;
        awsize = 0; awburst = 0; burst_done = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Step 1: before any request, slave should be offering "ready"
        check(awready == 1, "idle: awready is 1 (ready to accept an address)");

        // Step 2: master presents an address
        @(posedge clk);
        awaddr <= 32'h1000; awid <= 4'd3; awlen <= 4'd0; awsize <= 3'b010; awburst <= 2'b01;
        awvalid <= 1;
        @(posedge clk); // this is the edge where the DUT actually captures it
        awvalid <= 0;

        @(posedge clk); // let the latch settle
        check(aw_addr_q == 32'h1000, $sformatf("latched address correctly (got %h)", aw_addr_q));
        check(aw_id_q   == 4'd3,     "latched id correctly");
        check(awready   == 0,        "now busy: awready dropped to 0");

        // Step 3: while busy, a second address attempt should be ignored
        awaddr <= 32'h9999; awvalid <= 1;
        @(posedge clk);
        awvalid <= 0;
        check(aw_addr_q == 32'h1000, "still busy: second address was NOT latched over the first");

        // Step 4: signal the (stand-in) burst finished
        burst_done <= 1;
        @(posedge clk);
        burst_done <= 0;
        @(posedge clk);
        check(awready == 1, "after burst_done: back to idle, awready is 1 again");

        $display("========================================");
        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("%0d TEST(S) FAILED", errors);
        $display("========================================");
        $finish;
    end

endmodule
