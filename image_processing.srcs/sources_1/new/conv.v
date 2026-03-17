`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2026 12:11:17 PM
// Design Name: 
// Module Name: conv
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

// hardcoded for 3x3 kernel atm, therefore 3*3*8=72 -> 71:0
// box blur operation here
module conv(
    input           i_clk,
    input[71:0]     i_pixbuf,
    input           i_valid_pixbuf,
    output reg[7:0] o_pix_conv,
    output reg      o_valid_conv
);

integer i;
reg[7:0]    kernel[8:0];
reg[15:0]   mult_data[8:0]; // 8 bit x 8 bit mult therefore 16 bit output
reg[15:0]   sum_data;
reg[15:0]   sum_data_int;
reg         mult_data_valid;
reg         conv_data_valid;
reg         sum_data_valid;


initial
begin
    for(i=0;i<9;i=i+1)
    begin
        kernel[i] = 1;
    end
end

always @(posedge i_clk)
begin
    for(i=0;i<9;i=i+1)
    begin
        mult_data[i] <= kernel[i]*i_pixbuf[i*8+:8];
    end
    mult_data_valid <= i_valid_pixbuf;
end

always @(*)
begin
    sum_data_int <= 0;
    for(i=0;i<9;i=i+1)
    begin
        sum_data_int <= sum_data_int + mult_data[i];
    end
end

always @(posedge i_clk)
begin
    sum_data <= sum_data_int;
    sum_data_valid <= mult_data_valid;
end

always @(posedge i_clk)
begin
    o_pix_conv <= sum_data/9;
    o_valid_conv <= sum_data_valid;
end

endmodule
