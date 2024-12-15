`timescale 1ns / 1ps
`include "PARAMETER.v" 
module ps2_keyboard_control(
	clk, rst_n,
	ps2_clk, ps2_data,
    go_input
    );
	
	input clk;
	input rst_n;
	input ps2_clk;
	input ps2_data;
    output wire [9:0] go_input;
    
	reg ps2_clk_r0,ps2_clk_r1,ps2_clk_r2;
	wire neg_ps2_clk;
    
    //按键消抖
	always @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
		    {ps2_clk_r0,ps2_clk_r1,ps2_clk_r2} <=3'b000;
		end
		else begin
			ps2_clk_r0 <= ps2_clk;
			ps2_clk_r1 <= ps2_clk_r0;
			ps2_clk_r2 <= ps2_clk_r1;
		end
	end 
	assign neg_ps2_clk = ps2_clk_r2 & (~ps2_clk_r1);
	

	reg [7:0] ps2_byte_r;		
	reg [7:0] temp_data;
	reg [3:0] num;
	
	always @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			num <= 4'd0;
			temp_data <= 8'd0;
		end
		else if (neg_ps2_clk) begin//信号位数为11位
			case (num)
				4'd0: begin
					num <= num + 1'b1;
				end
				4'd1: begin
					num <= num + 1'b1;
					temp_data[0] <= ps2_data;
				end
				4'd2: begin
					num <= num + 1'b1;
					temp_data[1] <= ps2_data;
				end
				4'd3: begin
					num <= num + 1'b1;
					temp_data[2] <= ps2_data;
				end
				4'd4: begin
					num <= num + 1'b1;
					temp_data[3] <= ps2_data;
				end
				4'd5: begin
					num <= num + 1'b1;
					temp_data[4] <= ps2_data;
				end
				4'd6: begin
					num <= num + 1'b1;
					temp_data[5] <= ps2_data;
				end
				4'd7: begin
					num <= num + 1'b1;
					temp_data[6] <= ps2_data;
				end
				4'd8: begin
					num <= num + 1'b1;
					temp_data[7] <= ps2_data;
				end
				4'd9: begin
					num <= num + 1'b1;
				end
				4'd10: begin
					num <= 4'b0;
				end
				default: num <= 4'd0;
			endcase
		end
	end
	
	
	reg key_f0;
	reg ps2_state_r;
	
	always @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			key_f0 <= 1'b0;
			ps2_state_r <= 1'b0;
			ps2_byte_r <= 8'd0;
		end
		else if (num == 4'd10) begin
			    if (temp_data == 8'hf0)	begin
				    key_f0 <= 1'b1;//说明松开按键
			    end	
			    else begin
				    if (key_f0) begin//说明上一个clk为f0，这里是松开按键，若松开按键，state为0，key为0
					    ps2_state_r <= 1'b0;
					    ps2_byte_r <= temp_data;
					    key_f0 <= 1'b0;
				    end
				    else begin//说明上一个clk不是f0，这里是按下按键，若是按下按键，state为1，key为0
					    ps2_state_r <= 1'b1;
					    ps2_byte_r <= temp_data;
					    key_f0 <= 1'b0;
			    	end
			    end	
		    end
		//else	ps2_state_r <= 1'b0;
	end

    
	reg w,a,s,d,x,pos_h,neg_h,j,k,l;
	assign go_input={w,a,s,d,x,pos_h,neg_h,j,k,l};
	always @(posedge clk or negedge rst_n) begin
	   if(~rst_n)begin
	       w <= 1'b0; a <= 1'b0; s <= 1'b0; d  <= 1'b0; x <= 1'b0;
           pos_h <= 1'b0; neg_h <= 1'b0; j <= 1'b0; k <= 1'b0; l <= 1'b0;
          end
      else
        if(ps2_state_r)begin
         case (ps2_byte_r)
		        8'h1d: w <= 1'b1; // W
                8'h1c: a <= 1'b1; // A
                8'h1b: s <= 1'b1; // S
                8'h23: d <= 1'b1; // D
                8'h22: x <= 1'b1; // X
                8'h33: pos_h <= 1'b1; // pos_H
                8'h3b: j <= 1'b1; // J
                8'h42: k <= 1'b1; // K
                8'h4b: l <= 1'b1; // L
                default: begin
                       // 松开按键时清除对应状态
                    w <= 1'b0; a <= 1'b0; s <= 1'b0; d  <= 1'b0; x <= 1'b0;
                    pos_h <= 1'b0; neg_h <= 1'b0; j <= 1'b0; k <= 1'b0; l <= 1'b0;
                end
            endcase
        end
       else if(ps2_byte_r == 8'h33)begin
            neg_h=1'b1;
       end 
	end
endmodule
                    