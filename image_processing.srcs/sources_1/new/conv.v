`timescale 1ns / 1ps

`define KERNEL_SIZE 3

// 1 = gaussian/binomial blur
// 2 = box blur
// 3 = laplacian edge detection
`define FILTER_TYPE 3

module conv(
    input           i_clk,
    input           i_rst,
    input  [71:0]   i_pixbuf,
    input           i_valid_pixbuf,
    output reg [7:0] o_pix_conv,
    output reg      o_valid_conv
);

integer i, j, idx;

reg signed [7:0]  kernel [0:8];
reg signed [19:0] mult_data [0:8];
reg signed [19:0] sum_data;
reg signed [19:0] kernel_sum;

reg mult_data_valid;
reg sum_data_valid;

// Pipeline stage registers for adder tree
reg signed [19:0] sum1_0, sum1_1, sum1_2, sum1_3, sum1_4;
reg signed [19:0] sum2_0, sum2_1, sum2_2;
reg signed [19:0] sum3_0, sum3_1;

reg valid_s1, valid_s2, valid_s3;

reg signed [19:0] abs_sum;

integer dbg_conv_f;

initial begin
    dbg_conv_f = $fopen("conv_dbg.txt", "w");
end

function integer binomial;
    input integer n;
    input integer k;
    integer r;
    integer t;
    begin
        r = 1;

        if (k > n - k)
            k = n - k;

        for (t = 0; t < k; t = t + 1) begin
            r = r * (n - t);
            r = r / (t + 1);
        end

        binomial = r;
    end
endfunction

function integer laplacian;
    input integer i;
    input integer j;
    begin
        if (i == 1 && j == 1)
            laplacian = 4;
        else if ((i == 0 && j == 1) ||
                 (i == 1 && j == 0) ||
                 (i == 1 && j == 2) ||
                 (i == 2 && j == 1))
            laplacian = -1;
        else
            laplacian = 0;
    end
endfunction

initial begin
    kernel_sum = 0;

    for (i = 0; i < `KERNEL_SIZE; i = i + 1) begin
        for (j = 0; j < `KERNEL_SIZE; j = j + 1) begin
            idx = i * `KERNEL_SIZE + j;

            if (`FILTER_TYPE == 1) begin
                // Gaussian/binomial kernel:
                // 1 2 1
                // 2 4 2
                // 1 2 1
                kernel[idx] =
                    binomial(`KERNEL_SIZE - 1, i) *
                    binomial(`KERNEL_SIZE - 1, j);

                kernel_sum = kernel_sum + kernel[idx];
            end

            else if (`FILTER_TYPE == 2) begin
                // Box blur kernel:
                // 1 1 1
                // 1 1 1
                // 1 1 1
                kernel[idx] = 1;
                kernel_sum = kernel_sum + kernel[idx];
            end

            else if (`FILTER_TYPE == 3) begin
                // Laplacian kernel:
                //  0 -1  0
                // -1  4 -1
                //  0 -1  0
                kernel[idx] = laplacian(i, j);

                // Do NOT use kernel_sum for Laplacian normalisation.
                // Laplacian kernel sum is zero.
            end

            else begin
                kernel[idx] = 0;
            end
        end
    end
end

// Debug: show when pixbuf is captured
always @(posedge i_clk) begin
    if (!i_rst && i_valid_pixbuf) begin
        $fwrite(dbg_conv_f,
                "CONV_DBG: time=%0t i_pixbuf=%h\n",
                $time, i_pixbuf);
    end
end

// Multiplication stage
always @(posedge i_clk) begin
    if (i_rst) begin
        for (i = 0; i < `KERNEL_SIZE; i = i + 1) begin
            for (j = 0; j < `KERNEL_SIZE; j = j + 1) begin
                idx = i * `KERNEL_SIZE + j;
                mult_data[idx] <= 0;
            end
        end

        mult_data_valid <= 1'b0;
    end else begin
        for (i = 0; i < `KERNEL_SIZE; i = i + 1) begin
            for (j = 0; j < `KERNEL_SIZE; j = j + 1) begin
                idx = i * `KERNEL_SIZE + j;

                mult_data[idx] <=
                    kernel[idx] * $signed({1'b0, i_pixbuf[idx*8 +: 8]});
            end
        end

        mult_data_valid <= i_valid_pixbuf;
    end
end

// Stage 1: pairwise adds
always @(posedge i_clk) begin
    if (i_rst) begin
        sum1_0 <= 0;
        sum1_1 <= 0;
        sum1_2 <= 0;
        sum1_3 <= 0;
        sum1_4 <= 0;
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

// Stage 2
always @(posedge i_clk) begin
    if (i_rst) begin
        sum2_0 <= 0;
        sum2_1 <= 0;
        sum2_2 <= 0;
        valid_s2 <= 1'b0;
    end else begin
        sum2_0 <= sum1_0 + sum1_1;
        sum2_1 <= sum1_2 + sum1_3;
        sum2_2 <= sum1_4;

        valid_s2 <= valid_s1;
    end
end

// Stage 3
always @(posedge i_clk) begin
    if (i_rst) begin
        sum3_0 <= 0;
        sum3_1 <= 0;
        valid_s3 <= 1'b0;
    end else begin
        sum3_0 <= sum2_0 + sum2_1;
        sum3_1 <= sum2_2;

        valid_s3 <= valid_s2;
    end
end

// Register final sum
always @(posedge i_clk) begin
    if (i_rst) begin
        sum_data <= 0;
        sum_data_valid <= 1'b0;
    end else begin
        sum_data <= sum3_0 + sum3_1;
        sum_data_valid <= valid_s3;
    end
end

// Absolute value for edge filters
always @(*) begin
    if (sum_data < 0)
        abs_sum = -sum_data;
    else
        abs_sum = sum_data;
end

// Debug output
always @(posedge i_clk) begin
    if (!i_rst && sum_data_valid) begin
        $fwrite(dbg_conv_f,
                "CONV_DBG: time=%0t sum_data=%0d abs_sum=%0d o_pix_conv=%0d kernel_sum=%0d\n",
                $time, sum_data, abs_sum, o_pix_conv, kernel_sum);
    end
end

// Output stage
always @(posedge i_clk) begin
    if (i_rst) begin
        o_pix_conv <= 8'd0;
        o_valid_conv <= 1'b0;
    end else begin

        if (`FILTER_TYPE == 3) begin
            // Laplacian: no division, use abs + clamp
            if (abs_sum > 255)
                o_pix_conv <= 8'd255;
            else
                o_pix_conv <= abs_sum[7:0];
        end

        else begin
            // Blur filters: divide by kernel sum
            if (kernel_sum != 0)
                o_pix_conv <= sum_data / kernel_sum;
            else
                o_pix_conv <= 8'd0;
        end

        o_valid_conv <= sum_data_valid;
    end
end

endmodule