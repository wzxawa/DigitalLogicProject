
/*
debounce module with inputs for buttons buttom_A, buttom_S, buttom_W, buttom_X, buttom_D, buttom_rst,clk
*/

module Edge_detection(
    input buttom_A,
    input buttom_S,
    input buttom_W,
    input buttom_X,
    input buttom_D,
    input buttom_rst,
    input clk,             // 输入时钟（假设为 100MHz）
    output sign_pos_A,
    output sign_pos_S,
    output sign_neg_S,
    output sign_pos_W,
    output sign_pos_X,
    output sign_pos_D
);
    // 分频器参数
    reg [16:0] counter;      // 17位计数器，最大值为 100,000（适应 100MHz 输入时钟）
    reg clk_out;             // 分频后的时钟，1kHz
    parameter DIVISOR = 100000;  // 分频系数：100MHz 到 1kHz

    always @(posedge clk or posedge buttom_rst) begin
        if (buttom_rst) begin
            counter <= 0;
            clk_out <= 0;
        end else begin
            if (counter == DIVISOR - 1) begin
                counter <= 0;
                clk_out <= ~clk_out;  // 每次计数到 DIVISOR 时反转输出时钟
            end else begin
                counter <= counter + 1;
            end
        end
    end

    // 按键消抖寄存器
    reg [2:0] trig_A, trig_S, trig_W, trig_X, trig_D;

    always @(posedge clk_out or negedge buttom_rst) begin
        if(!buttom_rst) begin
            trig_A <= 3'b000;
            trig_S <= 3'b000;
            trig_W <= 3'b000;
            trig_X <= 3'b000;
            trig_D <= 3'b000;
        end
        else begin
            trig_A <= {trig_A[1:0], buttom_A};
            trig_S <= {trig_S[1:0], buttom_S};
            trig_W <= {trig_W[1:0], buttom_W};
            trig_X <= {trig_X[1:0], buttom_X};
            trig_D <= {trig_D[1:0], buttom_D};
        end
    end

    // 输出按键状态 
    assign sign_pos_A = (~trig_A[2]) & trig_A[1];
    assign sign_pos_S = (~trig_S[2]) & trig_S[1];
    assign sign_neg_S = trig_S[2] & (~trig_S[1]);
    assign sign_pos_W = (~trig_W[2]) & trig_W[1];
    assign sign_pos_X = (~trig_X[2]) & trig_X[1];
    assign sign_pos_D = (~trig_D[2]) & trig_D[1];

endmodule