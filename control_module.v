`timescale 1ns / 1ps

/*

special state: clean_state= 1010010 ; exit from storm= 1011101
control module

*/
module control_module(
    input [6:0] state,
    input sign_pos_A,
    input sign_pos_S,
    input sign_neg_S,
    input sign_pos_W,
    input sign_pos_X,
    input sign_pos_D,
    input rst,
    input clk,
    output reg [31:0] sign,
    output reg [6:0] nxt_state
    );
    //parameter about all states
    parameter shutdown=7'b0_00_0000,standby=7'b1_00_0000,menu=7'b1_01_0000,
              mode_one=7'b1_01_0100,mode_two=7'b1_01_1000,mode_three=7'b1_01_1100,exit_storm=7'b1_01_1101,clean=7'b1_01_0010,
              search=7'b1_01_0000,search_worktime=7'b1_10_0100,search_switch_time=7'b1_10_1000,search_remindtime=7'b1_10_1100,
              set_swi_hour=7'b1_11_1001,set_swi_min=7'b1_11_1010,set_swi_sec=7'b1_11_1011,
              set_remind_hour=7'b1_11_1101,set_remind_min=7'b1_11_1110,set_remind_sec=7'b1_11_1111;

    //parameter about all time
    parameter Nowtime=8'b00000000,Worktime=8'b00000001,Switchtime=8'b00000010,Remindtime=8'b00000011;//menu_clean

    //parameter used to exchange the clock frequency
    parameter period=100000000;//8 zero

    reg [23:0] nowtime,worktime,remindtime,switchtime;

    reg [2:0] buttom_effect; //S,A,D
    reg [47:0] cnt_S,cnt_A,cnt_D;
    parameter re_cnt=12'h000000000000,cnt_3s=12'h000011e1a300;
    wire [47:0] cnt_5s;

    reg clkout; //表示1s 的clk
    reg [31:0]cnt_clk;
    reg storm_once; //only one time for storm
    reg [7:0]countdown_storm;
    reg [11:0]countdown_clean;
    parameter countdown60=8'b01100000,countdown180=12'b000110000000;

    reg suspend; // work or not -> worktime++

    assign cnt_5s=(switchtime[23:20]*10+switchtime[19:16])*3600+(switchtime[15:12]*10+switchtime[11:8])*60+(switchtime[7:4]*10+switchtime[3:0])*100000000;

    always @(posedge clk,negedge rst) begin    // 只修改了suspend 和 sign（最后显示的值）
        if(!rst)begin
            nxt_state<=shutdown;
            nowtime<=0;
            worktime<=0;
            switchtime<=24'b000000000000000000000101;//to complete
            remindtime<=24'b000100000000000000000000;   
            buttom_effect<=3'b000;
            cnt_A=re_cnt;
            cnt_S=re_cnt;
            cnt_D=re_cnt;
            clkout<=0;
            cnt_clk<=0;
            storm_once<=1'b0;
            suspend<=1'b0;
            sign<={nowtime,Nowtime};
        end
        else begin
            // buttom_S -> off/on
            if(buttom_effect[2]==1'b1)begin 
                cnt_S<=cnt_S+1;
                if(cnt_S>=cnt_3s)begin
                    if(state[6]==1'b1)begin
                        //flag<=
                        nxt_state<=shutdown;
                    end
                    else begin
                        nxt_state<=standby;
                    end
                    buttom_effect[2]<=1'b0;
                    cnt_S<=re_cnt;
                end
            end
            else begin
                if(cnt_S!=re_cnt) cnt_S<=re_cnt;
            end
            //cnt_A,cnt_D
            if(buttom_effect[1]==1'b1)begin
                cnt_A<=cnt_A+1;
                if(cnt_A>=cnt_5s)begin
                    cnt_A<=re_cnt;
                    buttom_effect[1]<=1'b0;
                end
            end
            if(buttom_effect[0]==1'b1)begin
                cnt_D<=cnt_D+1;
                if(cnt_D>=cnt_5s)begin 
                    cnt_D<=re_cnt;
                    buttom_effect[0]<=1'b0;
                end
            end
                
            //clkout, 1ns -> 1s
            if(cnt_clk==(period>>1)-1)begin
                clkout<=~clkout;
                cnt_clk<=0;
            end
            else begin
                cnt_clk<=cnt_clk+1;
            end
            
        end
    end

    //to
    always @(nxt_state)begin
        buttom_effect[1:0]<=3'b00;
        cnt_A=re_cnt;
        cnt_D=re_cnt;
    end

    always @(posedge clkout)begin
        //控制 nowtime
        if(clkout==1'b1)begin
            if(nowtime[3:0]==4'b1001)begin //second ones
                if(nowtime[7:4]==4'b0101)begin //second tens
                    if(nowtime[11:8]==4'b1001)begin //minute ones
                        if(nowtime[15:12]==4'b0101)begin  //minute tens
                            if(nowtime[19:16]==4'b1001)begin //hour ones ,9+1=10
                                nowtime[23:20]<=nowtime[23:20]+4'b0001;
                                nowtime[19:0]<=20'b00000000000000000000;
                            end
                            else begin
                                if(nowtime[23:20]==4'b0010 && nowtime[19:16]==4'b0011) //23+1=0
                                    nowtime=24'b000000000000000000000000;
                                else begin
                                    nowtime[19:16]<=nowtime[19:16]+4'b0001;
                                    nowtime[15:0]<=16'b0000000000000000;
                                end
                            end
                        end
                        else begin
                            nowtime[15:12]<=nowtime[15:12]+4'b0001;
                            nowtime[11:0]<=12'b000000000000;
                        end
                    end
                    else begin
                        nowtime[11:8]<=nowtime[11:8]+4'b0001;
                        nowtime[7:0]<=8'b00000000;
                    end
                end
                else begin
                    nowtime[3:0]<=4'b0000;
                    nowtime[7:4]<=nowtime[7:4]+4'b0001;
                end
            end
            else nowtime[3:0]<=nowtime[3:0]+4'b0001;
        end
        //suspend,countdown_storm,countdown_clean 不为零时，显示--
        if(suspend==1'b1)begin
            worktime[7:0]<=worktime[7:0]+8'b00000001;
            if(worktime[7:0]==8'b01100000)begin
                worktime[7:0]<=8'b00000000;
                worktime[15:8]<=worktime[15:8]+1;
                if(worktime[15:8]==8'b01100000)begin
                    worktime[15:8]<=8'b00000000;
                    worktime[23:16]<=worktime[23:16]+1;
                end
            end
            if(worktime==remindtime)begin
                //to complete
                //nxt_state<= ;
            end
        end

        //
        if(countdown_storm!=0)begin
            if(countdown_storm[3:0]==4'b0000)begin
                countdown_storm[3:0]=4'b1001;
                countdown_storm[7:4]=countdown_storm[7:4]-4'b0001;
            end
            else countdown_storm[3:0]=countdown_storm[3:0]-4'b0001;
        end
        if(countdown_clean!=0)begin
            if(countdown_clean[3:0]==4'b0000)begin
                countdown_clean[3:0]=4'b1001;
                if(countdown_clean[7:4]==4'b0000)begin
                    countdown_clean[7:4]=4'b1001;
                    countdown_clean[11:8]=countdown_clean[11:8]-4'b0001;
                end
                else countdown_clean[7:4]=countdown_clean[7:4]-4'b0001;
            end
            else countdown_clean[3:0]=countdown_clean[3:0]-4'b0001;
        end
    end

    always @(negedge sign_pos_S)begin
        buttom_effect[2]<=1'b0;
    end

    //将所有修改state的模块综合起来
    //state machine
    always @(posedge clk) begin
        case(state)
                shutdown:begin
                    nowtime<=0;
                    worktime<=0;
                    switchtime<=24'b000000000000000000000101;//to complete
                    remindtime<=24'b000100000000000000000000;
                    storm_once<=1'b0;//是否飓风模式过
                    suspend<=1'b0;//是否在工作
                    sign<={nowtime,Nowtime};//显示当前时间和状态
                    if(sign_pos_A)begin
                        buttom_effect[1]<=1'b1;//按键关联
                        cnt_A<=re_cnt;
                    end
                    else if(buttom_effect[1]==1'b1 && sign_pos_D)begin
                        buttom_effect[1]<=1'b0;
                        nxt_state <= standby;
                    end
                end
                standby:begin
                    if(buttom_effect[0]==1'b1 && sign_pos_A)begin
                        buttom_effect[0]<=1'b0;
                        nxt_state <= shutdown;
                    end else if(sign_pos_D) begin
                            buttom_effect[0]<=1'b1;
                            cnt_D<=re_cnt;
                    end else if(sign_pos_W) begin
                        nxt_state <= menu;
                    end else if(sign_pos_X) begin
                        nxt_state <= search;
                    end
                end
                menu:begin
                    suspend<=1'b0;
                    if(sign_pos_A)begin
                        nxt_state <= mode_one;
                    end else if(sign_pos_S)begin
                        nxt_state <= mode_two;
                    end else if(sign_pos_D && storm_once==1'b0)begin
                            storm_once<=1'b1;
                            nxt_state <= mode_three;
                            countdown_storm<=countdown60;
                    end else if(sign_pos_X)begin
                        nxt_state <= clean;
                        countdown_clean<=countdown180;
                    end
                    //nxt_state<=;
                end
                mode_one:begin
                    suspend<=1'b1;
                    if(sign_pos_S)begin
                        nxt_state <= mode_two;
                    end else if(sign_pos_W)begin
                        nxt_state <= standby;
                    end
                end
                mode_two:begin
                    suspend<=1'b1;
                    if(sign_pos_A)begin
                        nxt_state <= mode_two;
                    end else if(sign_pos_W)begin
                        nxt_state <= standby;
                    end
                end
                mode_three:begin
                    suspend<=1'b1;
                    sign<={nowtime,countdown60};
                end
                clean:begin
                    suspend<=1'b0;
                    sign<={20'b0,countdown_clean};
                end
                search:begin
                    if(sign_pos_A)begin
                        nxt_state <= search_worktime;
                    end else if(sign_pos_S)
                        nxt_state <= search_switch_time;
                    else if(sign_pos_D)
                        nxt_state <= search_remindtime;
                    else if(sign_pos_W)
                        nxt_state <= standby;
                end
                search_worktime:begin
                    suspend<=1'b0;
                    sign<={worktime,Worktime};
                    if(sign_pos_W)
                        nxt_state <= search;
                end
                search_switch_time:begin
                    suspend<=1'b0;
                    sign<={switchtime,Switchtime};
                    if(sign_pos_W)
                        nxt_state <= search;
                    else if(sign_pos_X)begin
                        nxt_state <= set_swi_hour;
                    end
                end
                search_remindtime:begin
                    suspend<=1'b0;
                    sign<={remindtime,Remindtime};
                    if(sign_pos_W)
                        nxt_state <= search;
                    else if(sign_pos_X)
                        nxt_state <= set_remind_hour;
                end
                set_swi_hour:begin
                    suspend<=1'b0;
                    sign<={switchtime,Switchtime};
                    if(sign_pos_A)begin
                        if(switchtime[23:16]==8'b00100011) begin
                            switchtime[23:16] <= 8'b00000000;
                        end
                        else if(switchtime[19:16]==4'b1001) begin
                            switchtime[19:16] <= 4'b0000;
                            switchtime[23:16] <= switchtime[23:16]+1;
                        end
                        else switchtime[19:16] <= switchtime[19:16]+1;
                    end
                    else if (sign_pos_S)
                        nxt_state <= set_swi_min;
                end
                set_swi_min:begin
                    suspend<=1'b0;
                    sign<={switchtime,Switchtime};
                    if(sign_pos_A)begin
                        if(switchtime[15:8]==8'b01011001) begin
                             switchtime[15:8] <= 8'b00000000;
                         end
                        else if(switchtime[11:8]==4'b1001) begin
                            switchtime[11:8] <= 4'b0000;
                            switchtime[15:8] <= switchtime[15:8]+1;
                        end
                        else switchtime[11:8] <= switchtime[11:8]+1;
                    end
                    else if (sign_pos_S)
                        nxt_state <= set_swi_sec;
                end
                set_swi_sec:begin
                    suspend<=1'b0;
                    sign<={switchtime,Switchtime};
                    if(sign_pos_A)begin
                        if(switchtime[7:0]==8'b01011001) begin
                            switchtime[7:0] <= 8'b00000000;
                        end
                        else if(switchtime[3:0]==4'b1001) begin
                            switchtime[3:0] <= 4'b0000;
                            switchtime[7:0] <= switchtime[7:0]+1;
                        end
                        else switchtime[3:0] <= switchtime[3:0]+1;
                    end
                    else if (sign_pos_S)
                        nxt_state <= search_switch_time;
                end
                set_remind_hour:begin
                    suspend<=1'b0;
                    sign<={remindtime,Remindtime};
                    if(sign_pos_A)begin
                        if(remindtime[23:16] == 8'b00100011) begin  //23+1=0
                            remindtime[23:16] <= 8'b00000000;
                        end
                        else if(remindtime[19:16]==4'b1001) begin
                             remindtime[19:16] <= 4'b0000;
                             remindtime[23:16] <= remindtime[23:16]+1;
                        end
                        else remindtime[19:16] <= remindtime[19:16]+1;
                    end
                    else if (sign_pos_S)
                        nxt_state <= set_remind_min;
                end
                set_remind_min:begin
                    suspend<=1'b0;
                    sign<={remindtime,Remindtime};
                    if(sign_pos_A)begin
                        if(remindtime[15:8] == 8'b01011001) begin   //59+1=0
                            remindtime[15:8] <= 8'b00000000;
                        end
                        else if(remindtime[11:8]==4'b1001) begin
                            remindtime[11:8] <= 4'b0000;
                            remindtime[15:8] <= remindtime[15:8]+1;
                        end
                        else remindtime[11:8] <= remindtime[11:8]+1;
                    end
                    else if (sign_pos_S)
                        nxt_state <= set_remind_sec;
                end
                set_remind_sec:begin
                    suspend<=1'b0;
                    sign<={remindtime,Remindtime};
                    if(sign_pos_A)begin
                        if(remindtime[7:0] == 8'b01011001) begin
                            remindtime[7:0] <= 8'b00000000;
                        end
                        else if(remindtime[3:0]==4'b1001) begin
                            remindtime[3:0] <= 4'b0000;
                            remindtime[7:0] <= remindtime[7:0]+1;
                        end
                        else remindtime[3:0] <= remindtime[3:0]+1;
                    end
                    else if (sign_pos_S)
                        nxt_state <= search_remindtime;
                end
                default:begin
                    suspend<=1'b0;
                end
            endcase
        
endmodule