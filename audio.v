module speaker_player (
    input clk,                // 时钟信号
    input rst,                // 复位信号
    input [6:0] state,       // 状态参数（决定不同的音调）
    output reg speaker_pwm   // 小喇叭的 PWM 信号输出
);

    // PWM parameters
    reg [31:0] pwm_counter;   // 用于控制 PWM 信号的计数器
    reg [31:0] pwm_period;    // PWM 周期，用于调整频率
    reg [31:0] pwm_duty;      // PWM 占空比，用于调整音量

    // counter parameters
    reg [31:0] timer_counter;  // 用于倒计时 0.5 秒
    reg timer_en;              // 倒计时使能信号
    reg sound_on;              // 控制是否播放声音
    reg [6:0] prev_state;      // 上一个状态

    // clk frequency: 100 MHz
    localparam HALF_SECOND = 32'd50000000;

    always @(posedge clk, negedge rst) begin
        if (~rst) begin
            pwm_counter <= 0;           // 复位时清零计数器
            pwm_period <= 32'd100000;   // 默认频率周期
            pwm_duty <= 32'd50000;      // 默认占空比
            speaker_pwm <= 0;           // 复位时小喇叭输出为低电平
            timer_counter <= 0;         // 复位时清零倒计时
            timer_en <= 0;              // 复位时禁用倒计时
            sound_on <= 0;              // 复位时停止声音
            prev_state <= 7'b0;         // 复位时清空上一个状态
        end else begin
            // 如果状态发生变化
            if (state != prev_state) begin
                prev_state <= state;    // 更新上一个状态
                timer_counter <= 0;     // 重置倒计时
                timer_en <= 1;          // 启动倒计时
                sound_on <= 1;          // 启动声音播放
            end

            // 倒计时 0.5 秒
            if (timer_en) begin
                if (timer_counter < HALF_SECOND) begin
                    timer_counter <= timer_counter + 1;
                end else begin
                    timer_en <= 0;  // 倒计时结束，禁用倒计时
                    sound_on <= 0;  // 关闭声音播放
                end
            end

            // 如果声音开启
            if (sound_on) begin
                // 根据状态设置不同的 PWM 参数
                case (state)
                    7'b0000000, 7'b1000000: begin
                        pwm_period <= 32'd100000;  // 低频音调
                        pwm_duty <= 32'd50000;    // 占空比 50%
                    end

                    7'b1010000, 7'b1011101, 7'b1100000, 7'b1100100, 7'b1101000, 7'b1101100: begin
                        pwm_period <= 32'd50000;   // 中频音调
                        pwm_duty <= 32'd25000;     // 占空比 50%
                    end
                    7'b1010100, 7'b1011000, 7'b1011100: begin
                        pwm_period <= 32'd25000;   // 高频音调
                        pwm_duty <= 32'd12500;     // 占空比 50%
                    end
                    7'b1111001, 7'b1111010, 7'b1111011, 7'b1111101, 7'b1111110, 7'b1111111: begin
                        pwm_period <= 32'd12500;   // 更高频音调
                        pwm_duty <= 32'd6250;      // 占空比 50%
                    end
                    default: begin
                        pwm_period <= 32'd100000;
                        pwm_duty <= 32'd50000;
                    end
                endcase

                pwm_counter <= pwm_counter + 1;

                // 根据 PWM 占空比控制 speaker_pwm 输出
                if (pwm_counter < pwm_duty) begin
                    speaker_pwm <= 1;
                end else begin
                    speaker_pwm <= 0;
                end

                // 当 PWM 计数器达到周期时，清零
                if (pwm_counter == pwm_period) begin
                    pwm_counter <= 0;
                end
            end else begin
                // 如果倒计时结束，停止播放声音
                speaker_pwm <= 0;
            end
        end
    end

endmodule
