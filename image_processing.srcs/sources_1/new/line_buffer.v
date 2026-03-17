`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2026 11:45:30 AM
// Design Name: 
// Module Name: line_buffer
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

// writing single pixel at a time
// fixed size 512x512px image atm
module line_buffer(
    input           i_clk,
    input           i_rst,
    input[7:0]      i_data,
    input           i_data_valid,
    output[23:0]    o_data, // need to flatten output array
    input           i_rd_data
);

reg [7:0] line [511:0];  // line buffer
reg wr_ptr;
reg rd_ptr;

always @(posedge i_clk)
begin
    if (i_data_valid)
        line [wr_ptr] <= i_data;
end

always @(posedge i_clk)
begin
    if(i_rst)
        wr_ptr <= 'd0;
    else if(i_data_valid)
        wr_ptr <= wr_ptr + 'd1;
end

assign o_data = {line[rd_ptr], line[rd_ptr+1], line[rd_ptr+2]};

always @(posedge i_clk)
begin
    if(i_rst)
        rd_ptr <= 'd0;
    else if(i_rd_data)
        rd_ptr <= wr_ptr + 'd1;
end
endmodule
