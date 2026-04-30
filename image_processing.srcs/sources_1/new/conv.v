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
    input           i_rst,
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

// Pipeline stage registers for adder tree
reg [15:0] sum1_0, sum1_1, sum1_2, sum1_3, sum1_4;
reg [15:0] sum2_0, sum2_1, sum2_2;
reg [15:0] sum3_0, sum3_1;
reg valid_s1, valid_s2, valid_s3;
integer dbg_conv_f;
initial dbg_conv_f = 0;
    initial begin
    dbg_conv_f = $fopen("conv_dbg.txt","w");
end


initial
begin
    for(i=0;i<9;i=i+1)
    begin
        kernel[i] = 1;
    end
end

    // debug: show when pixbuf is captured for mult
    always @(posedge i_clk) begin
        if (!i_rst && i_valid_pixbuf) begin
            $fwrite(dbg_conv_f, "CONV_DBG: time=%0t i_pixbuf=%h\n", $time, i_pixbuf);
        end
    end

always @(posedge i_clk)
begin
    if (i_rst) begin
        for (i=0;i<9;i=i+1) begin
            mult_data[i] <= 0;
        end
        mult_data_valid <= 1'b0;
    end else begin
        for(i=0;i<9;i=i+1)
        begin
            mult_data[i] <= kernel[i]*i_pixbuf[i*8+:8];
        end
        mult_data_valid <= i_valid_pixbuf;
    end
end

// debug: show when final conv output becomes valid
always @(posedge i_clk) begin
    if (!i_rst && sum_data_valid) begin
        $fwrite(dbg_conv_f, "CONV_DBG: time=%0t sum_data=%0d o_pix_conv=%0d\n", $time, sum_data, sum_data/9);
    end
end

// Stage 1: pairwise adds (uses mult_data registers)
always @(posedge i_clk)
begin
    if (i_rst) begin
        sum1_0 <= 0; sum1_1 <= 0; sum1_2 <= 0; sum1_3 <= 0; sum1_4 <= 0;
        valid_s1 <= 1'b0;
    end else begin
        sum1_0 <= mult_data[0] + mult_data[1];
        sum1_1 <= mult_data[2] + mult_data[3];
        sum1_2 <= mult_data[4] + mult_data[5];
        sum1_3 <= mult_data[6] + mult_data[7];
        sum1_4 <= mult_data[8];
        valid_s1 <= mult_data_valid;
    end
end

// Stage 2: combine pairwise sums
always @(posedge i_clk)
begin
    if (i_rst) begin
        sum2_0 <= 0; sum2_1 <= 0; sum2_2 <= 0;
        valid_s2 <= 1'b0;
    end else begin
        sum2_0 <= sum1_0 + sum1_1;
        sum2_1 <= sum1_2 + sum1_3;
        sum2_2 <= sum1_4;
        valid_s2 <= valid_s1;
    end
end

// Stage 3: final accumulation
always @(posedge i_clk)
begin
    if (i_rst) begin
        sum3_0 <= 0; sum3_1 <= 0;
        valid_s3 <= 1'b0;
    end else begin
        sum3_0 <= sum2_0 + sum2_1;
        sum3_1 <= sum2_2;
        valid_s3 <= valid_s2;
    end
end

// Register final sum and propagate valid
always @(posedge i_clk)
begin
    if (i_rst) begin
        sum_data <= 0;
        sum_data_valid <= 1'b0;
    end else begin
        sum_data <= sum3_0 + sum3_1;
        sum_data_valid <= valid_s3;
    end
end

// Output stage
always @(posedge i_clk)
begin
    if (i_rst) begin
        o_pix_conv <= 0;
        o_valid_conv <= 1'b0;
    end else begin
        o_pix_conv <= sum_data/9;
        o_valid_conv <= sum_data_valid;
    end
end

endmodule
