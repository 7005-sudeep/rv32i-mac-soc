// w_channel.sv
//
// Lesson 2: the write-data (W) channel, on its own.
//
// Job: once a burst has been "commanded" (a stand-in for what the AW
// channel will hand us once we wire them together in a later lesson),
// accept one data beat per clock cycle, write only the bytes wstrb marks,
// advance the write address each beat, and pulse burst_done on the last
// beat (wlast). This is the REAL burst_done — no more stand-in.
//
// Only FIXED and INCR burst types for now. WRAP comes in a later lesson.

module w_channel #(
    parameter int MEM_DEPTH_BYTES = 128
)(
    input  logic        clk,
    input  logic        rst_n,

    // Stand-in "command" — what a real AW channel will eventually hand us:
    // "a burst was just accepted, here's where it starts and how big it is"
    input  logic        cmd_valid,
    input  logic [31:0] cmd_addr,
    input  logic [3:0]  cmd_len,    // AXI awlen: (cmd_len + 1) beats total
    input  logic [2:0]  cmd_size,   // AXI awsize: bytes per beat = 2^cmd_size
    input  logic [1:0]  cmd_burst,  // 0 = FIXED, 1 = INCR

    // W channel proper
    input  logic        wvalid,
    output logic        wready,
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic        wlast,

    // Real burst_done now — pulses for one cycle when the last beat lands
    output logic        burst_done
);

    localparam logic [1:0] BURST_FIXED = 2'b00;
    localparam logic [1:0] BURST_INCR  = 2'b01;

    logic [7:0] mem [0:MEM_DEPTH_BYTES-1];

    typedef enum logic { W_IDLE, W_ACTIVE } w_state_t;
    w_state_t w_state, w_state_n;

    logic [31:0] cur_addr_q;
    logic [2:0]  size_q;
    logic [1:0]  burst_q;

    function automatic int unsigned bytes_per_beat(input logic [2:0] size);
        bytes_per_beat = (32'd1 << size);
    endfunction

    // ---- Process 1: pure decision-making, no memory ----
    always_comb begin
        w_state_n  = w_state;
        wready     = (w_state == W_ACTIVE);
        burst_done = (w_state == W_ACTIVE) && wvalid && wlast;

        case (w_state)
            W_IDLE:   if (cmd_valid) w_state_n = W_ACTIVE;
            W_ACTIVE: if (wvalid && wlast) w_state_n = W_IDLE;
        endcase
    end

    // ---- Process 2: the actual memory (state, address counter, mem writes) ----
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state    <= W_IDLE;
            cur_addr_q <= '0;
            size_q     <= '0;
            burst_q    <= '0;
        end
        else begin
            w_state <= w_state_n;

            case (w_state)
                W_IDLE: begin
                    if (cmd_valid) begin
                        cur_addr_q <= cmd_addr;
                        size_q     <= cmd_size;
                        burst_q    <= cmd_burst;
                    end
                end

                W_ACTIVE: begin
                    if (wvalid) begin
                        // Only the bytes wstrb marks actually get written —
                        // everything else in mem[] is left untouched.
                        for (int lane = 0; lane < 4; lane++) begin
                            if (wstrb[lane])
                                mem[cur_addr_q + lane] <= wdata[8*lane +: 8];
                        end

                        // Advance the address for the NEXT beat.
                        if (burst_q == BURST_INCR)
                            cur_addr_q <= cur_addr_q + bytes_per_beat(size_q);
                        // FIXED: cur_addr_q simply doesn't change.
                    end
                end
            endcase
        end
    end

endmodule
