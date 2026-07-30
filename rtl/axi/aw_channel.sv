// aw_channel.sv
//
// Lesson 1: the write-address (AW) channel, on its own.
//
// Job: accept one write address at a time from a master, remember (latch)
// it, and stay "busy" until the rest of the write transaction (data +
// response, which we haven't built yet) finishes.
//
// `burst_done` is a temporary stand-in input for now — in a later lesson,
// once we build the write-data and write-response channels, this signal
// will come from inside the design instead of from a testbench.

module aw_channel (
    input  logic        clk,
    input  logic        rst_n,

    // AW channel (master -> this slave)
    input  logic        awvalid,
    output logic        awready,
    input  logic [3:0]  awid,
    input  logic [3:0]  awlen,
    input  logic [2:0]  awsize,
    input  logic [31:0] awaddr,
    input  logic [1:0]  awburst,

    // Temporary stand-in: "the write this address started for has finished"
    input  logic        burst_done,

    // Latched command, visible to whatever we build next
    output logic [31:0] aw_addr_q,
    output logic [3:0]  aw_id_q,
    output logic [3:0]  aw_len_q,
    output logic [2:0]  aw_size_q,
    output logic [1:0]  aw_burst_q
);

    typedef enum logic { AW_IDLE, AW_BUSY } aw_state_t;
    aw_state_t aw_state, aw_state_n;

    // ---- Process 1: pure decision-making, no memory ----
    always_comb begin
        aw_state_n = aw_state;              // default: stay put
        awready    = (aw_state == AW_IDLE);

        case (aw_state)
            AW_IDLE: if (awvalid)    aw_state_n = AW_BUSY;
            AW_BUSY: if (burst_done) aw_state_n = AW_IDLE;
        endcase
    end

    // ---- Process 2: the actual memory (state + latched fields) ----
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_state   <= AW_IDLE;
            aw_addr_q  <= '0;
            aw_id_q    <= '0;
            aw_len_q   <= '0;
            aw_size_q  <= '0;
            aw_burst_q <= '0;
        end
        else begin
            aw_state <= aw_state_n;
            if (aw_state == AW_IDLE && awvalid) begin
                aw_addr_q  <= awaddr;
                aw_id_q    <= awid;
                aw_len_q   <= awlen;
                aw_size_q  <= awsize;
                aw_burst_q <= awburst;
            end
        end
    end

endmodule
