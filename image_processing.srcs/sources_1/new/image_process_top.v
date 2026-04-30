`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/18/2026 01:58:49 AM
// Design Name: 
// Module Name: image_process_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module image_process_top(
        input           axi_clk,
        input           axi_rst_n,
        // slave interface
        input           i_data_valid,
        input[7:0]      i_data,
        output          o_data_ready,
        // master interface
        output          o_data_valid,
        output[7:0]     o_data,
        input           i_data_ready,
        // interrupt
        output          o_intr
    );
    wire [71:0]         pix_data;
    wire                pix_data_valid;
    wire                axis_prog_full;
    wire [7:0]          convolved_data;
    wire                convolved_data_valid;
    assign o_data_ready = !axis_prog_full;
    
    image_control ic(
        .i_clk(axi_clk),
        .i_rst(!axi_rst_n), // active low on axi interface
        .i_pixbuf(i_data),
        .i_pixbuf_valid(i_data_valid),
        .o_pixbuf(pix_data),
        .o_pixbuf_valid(pix_data_valid),
        .o_intr(o_intr)
    );
    conv conv(
        .i_clk(axi_clk),
        .i_rst(!axi_rst_n),
        .i_pixbuf(pix_data),
        .i_valid_pixbuf(pix_data_valid),
        .o_pix_conv(convolved_data),
        .o_valid_conv(convolved_data_valid)
    );
    
        // fifo queue to buffer output data to DMA
`ifdef SIM_BYPASS
        assign o_data = convolved_data;
        assign o_data_valid = convolved_data_valid;
        assign axis_prog_full = 1'b0;
`else
        output_buffer your_instance_name (
            .wr_rst_busy(),        // output wire wr_rst_busy
            .rd_rst_busy(),        // output wire rd_rst_busy
            .s_aclk(axi_clk),                  // input wire s_aclk
            .s_aresetn(axi_rst_n),            // input wire s_aresetn
            .s_axis_tvalid(convolved_data_valid),    // input wire s_axis_tvalid
            .s_axis_tready(),    // output wire s_axis_tready
            .s_axis_tdata(convolved_data),      // input wire [7 : 0] s_axis_tdata
            .m_axis_tvalid(o_data_valid),    // output wire m_axis_tvalid
            .m_axis_tready(i_data_ready),    // input wire m_axis_tready
            .m_axis_tdata(o_data),      // output wire [7 : 0] m_axis_tdata
            .axis_prog_full(axis_prog_full)  // output wire axis_prog_full
        );
`endif
endmodule
