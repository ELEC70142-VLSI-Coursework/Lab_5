`timescale 1ns/1ps

module FIFO #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 16
)(
    input  logic              clk,
    input  logic              rst_n,

    input  logic              clk_en,

    input  logic              in_valid,
    output logic              in_ready,
    input  logic [WIDTH-1:0]  in_data,

    output logic              out_valid,
    input  logic              out_ready,
    output logic [WIDTH-1:0]  out_data
);

    // Internal storage and pointers
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    logic [$clog2(DEPTH):0]   count; 

    // Status flags
    assign in_ready  = !(count == DEPTH) || out_ready;
    assign out_valid = !(count == 0);

    // Write operation
    always_ff @(posedge clk) begin
        if (!rst_n) begin
        wr_ptr <= '0;
        end else if (in_valid && in_ready) begin
            mem[wr_ptr] <= in_data;
            wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
        end
    end

    // Read operation
    always_ff @(posedge clk ) begin
        if (!rst_n) begin
        rd_ptr <= '0;
        end else if (out_valid && out_ready) begin
            rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
        end
    end

    // Count tracking
    always_ff @(posedge clk) begin
        if (!rst_n) begin
        count <= '0;
        end else begin
            case ({in_valid && in_ready, out_valid && out_ready})
                2'b10: count <= count + 1;   // write only
                2'b01: count <= count - 1;   // read only
                default: count <= count;     // simultaneous R/W
            endcase
        end
    end
        
    assign out_data = mem[rd_ptr];

endmodule
