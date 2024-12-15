`timescale 1ns / 1ps

module counter_1hz(
    input clk,
    input reset,
    output reg clk_out
    );
    reg [12:0] cnt;
    parameter period = 100000000;
    always @(posedge clk or negedge reset)
    begin 
         if(~reset)begin
            cnt <= 0;
            clk_out <= 0;
         end
         else begin 
            if(cnt == (period>>1) -1)
            begin 
              clk_out <= ~clk_out;
              cnt <= 0;
            end
            else
                cnt <= cnt + 1;
          end
    end
endmodule
