`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/01/2026 01:26:24 AM
// Design Name: 
// Module Name: tb
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

`define headerSize 1080
`define imageSize 512*512

module tb(

    );
    
 
 reg clk;
 reg reset;
 reg [7:0] imgData;
 integer file,file1,i;
integer dbgfile;
integer dbg_pix_f;
integer dbg_conv_f;
integer dbg_in;
 reg imgDataValid;
 integer sentSize;
 wire intr;
 wire [7:0] outData;
 wire outDataValid;
 integer receivedData=0;

 initial
 begin
    clk = 1'b0;
    forever
    begin
        #5 clk = ~clk;
    end
 end
 
 initial
 begin
    reset = 0;
    sentSize = 0;
    imgDataValid = 0;
    #100;
    reset = 1;
    #100;
    // VCD dump for post-mortem inspection
    $dumpfile("trace.vcd");
    $dumpvars(0, tb);
    file = $fopen("lena_gray.bmp","rb");
    file1 = $fopen("blurred_lena.bmp","wb");
    dbgfile = $fopen("tb_out.txt","w");
    dbg_pix_f = $fopen("tb_pix.txt","w");
    dbg_conv_f = $fopen("tb_conv.txt","w");
    dbg_in = $fopen("tb_in.txt","w");
    for(i=0;i<`headerSize;i=i+1)
    begin
        $fscanf(file,"%c",imgData);
        $fwrite(file1,"%c",imgData);
    end
    
    for(i=0;i<4*512;i=i+1)
    begin
        @(posedge clk);
            $fscanf(file,"%c",imgData);
            if (i < 32) $fwrite(dbg_in, "%0d\n", imgData);
        imgDataValid <= 1'b1;
    end
    sentSize = 4*512;
    @(posedge clk);
    imgDataValid <= 1'b0;
    while(sentSize < `imageSize)
    begin
        @(posedge intr);
        for(i=0;i<512;i=i+1)
        begin
            @(posedge clk);
            $fscanf(file,"%c",imgData);
            // log pix window from top module when we assert valid
            if (i < 4) begin
                $fwrite(dbg_pix_f, "pix_in_cycle %0d: %0h\n", i, dut.pix_data);
            end
            imgDataValid <= 1'b1;    
        end
        @(posedge clk);
        imgDataValid <= 1'b0;
        sentSize = sentSize+512;
    end
    @(posedge clk);
    imgDataValid <= 1'b0;
    @(posedge intr);
    for(i=0;i<512;i=i+1)
    begin
        @(posedge clk);
        imgData <= 0;
        imgDataValid <= 1'b1;    
    end
    @(posedge clk);
    imgDataValid <= 1'b0;
    @(posedge intr);
    for(i=0;i<512;i=i+1)
    begin
        @(posedge clk);
        imgData <= 0;
        imgDataValid <= 1'b1;    
    end
    @(posedge clk);
    imgDataValid <= 1'b0;
    $fclose(file);
 end
 
 always @(posedge clk)
 begin
     if(outDataValid)
     begin
            $fwrite(file1,"%c",outData);
            if (receivedData < 16) $display("TB: outData[%0d]=%0d", receivedData, outData);
            if (receivedData < 256) $fwrite(dbgfile,"%0d\n", outData);
        // also log conv output from top-level net
        if (receivedData < 256) $fwrite(dbg_conv_f, "conv_out %0d: %0h valid=%0d out=%0d\n", receivedData, dut.convolved_data, dut.convolved_data_valid, outData);
            receivedData = receivedData+1;
     end 
     if(receivedData == `imageSize)
     begin
        $fclose(file1);
        if (dbg_in) $fclose(dbg_in);
       if (dbgfile) $fclose(dbgfile);
       if (dbg_pix_f) $fclose(dbg_pix_f);
       if (dbg_conv_f) $fclose(dbg_conv_f);
        $stop;
     end
 end

// Monitor pix_data and conv outputs to simulator console/log
always @(posedge clk) begin
    if (dut.pix_data_valid) begin
        $display("TB-MON: time=%0t pix_data=%h", $time, dut.pix_data);
    end
    if (dut.convolved_data_valid) begin
        $display("TB-MON: time=%0t conv=%0d valid=%0d", $time, dut.convolved_data, dut.convolved_data_valid);
    end
end

 image_process_top dut(
    .axi_clk(clk),
    .axi_rst_n(reset),
    //slave interface
    .i_data_valid(imgDataValid),
    .i_data(imgData),
    .o_data_ready(),
    //master interface
    .o_data_valid(outDataValid),
    .o_data(outData),
    .i_data_ready(1'b1),
    //interrupt
    .o_intr(intr)
);   
    
endmodule