`timescale 1ns/1ps
module conv_tb;
    reg clk = 0;
    reg rst = 1;
    reg [71:0] i_pixbuf;
    reg i_valid_pixbuf;
    wire [7:0] o_pix_conv;
    wire o_valid_conv;

    // instantiate DUT
    conv dut (
        .i_clk(clk),
        .i_rst(rst),
        .i_pixbuf(i_pixbuf),
        .i_valid_pixbuf(i_valid_pixbuf),
        .o_pix_conv(o_pix_conv),
        .o_valid_conv(o_valid_conv)
    );

    // 10ns period clock
    always #5 clk = ~clk;

    integer i;
    initial begin
        // release reset after a few cycles
        i_pixbuf = 0;
        i_valid_pixbuf = 0;
        #20;
        rst = 0;
        // prepare a known 3x3 window: 1..9
        for (i=0; i<9; i=i+1) begin
            i_pixbuf[i*8 +: 8] = i+1;
        end
        // assert valid for one cycle
        @(posedge clk);
        i_valid_pixbuf = 1'b1;
        @(posedge clk);
        i_valid_pixbuf = 1'b0;

        // wait for output (pipeline latency about 4-5 cycles)
        repeat (12) begin
            @(posedge clk);
            if (o_valid_conv) begin
                $display("CONV_TB: time=%0t o=%0d expected=%0d", $time, o_pix_conv, (1+2+3+4+5+6+7+8+9)/9);
            end
        end
        $finish;
    end
endmodule
