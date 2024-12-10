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
    parameter SHUTDOWN=7'b0000000,STANDBY=7'b1000000,MENU=7'b1010000,ONE=7'b1010100,TWO=7'b1011000,THREE=7'b1011100,EXIT_STROM=7'b1011101,CLEAN=7'b1010010,
        SEARCH=7'b1010000,SEARCH_WORKTIME=7'b1100100,SEARCH_SWITCH_TIME=7'b1101000,SEARCH_REMINDTIME=7'b1101100,
        SET_SWI_HOUR=7'b1111001,SET_SWI_MIN=7'b1111010,SET_SWI_SEC=7'b1111011,SET_REMIND_HOUR=7'b1111101,SET_REMIND_MIN=7'b1111110,SET_REMIND_SEC=7'b1111111;
    parameter NOWTIME=8'b00000000,WORKTIME=8'b00000001,SWITCHTIME=8'b00000010,REMINDTIME=8'b00000011;//menu_clean

    parameter period=100000000;

    reg [23:0]nowtime,worktime,remindtime,switchtime;

    reg [2:0]buttom_effect; //S,A,D
    reg [47:0]cnt_S,cnt_A,cnt_D;
    parameter re_cnt=12'h000000000000,cnt_3s=12'h000011e1a300;
    wire [47:0]cnt_5s;

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
            nxt_state<=SHUTDOWN;
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
            sign<={nowtime,NOWTIME};
        end
        else begin
            // buttom_S -> off/on
            if(buttom_effect[2]==1'b1)begin 
                cnt_S<=cnt_S+1;
                if(cnt_S>=cnt_3s)begin
                    if(state[6]==1'b1)begin
                        //flag<=
                        nxt_state<=SHUTDOWN;
                    end
                    else begin
                        nxt_state<=STANDBY;
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

            //state machine
            case(state)
                SHUTDOWN:begin
                    nowtime<=0;
                    worktime<=0;
                    switchtime<=24'b000000000000000000000101;//to complete
                    remindtime<=24'b000100000000000000000000;
                    storm_once<=1'b0;
                    suspend<=1'b0;
                    sign<={nowtime,NOWTIME};
                end
                MENU:begin
                    suspend<=1'b0;
                    //nxt_state<=;
                end
                ONE:begin
                    suspend<=1'b1;

                end
                TWO:begin
                    suspend<=1'b1;
                end
                THREE:begin
                    suspend<=1'b1;
                    sign<={nowtime,countdown60};
                end
                CLEAN:begin
                    suspend<=1'b0;
                    sign<={20'b0,countdown_clean};
                end
                SEARCH_WORKTIME:begin
                    suspend<=1'b0;
                    sign<={worktime,WORKTIME};
                end
                SEARCH_SWITCH_TIME:begin
                    suspend<=1'b0;
                    sign<={switchtime,SWITCHTIME};
                end
                SEARCH_REMINDTIME:begin
                    suspend<=1'b0;
                    sign<={remindtime,REMINDTIME};
                end
                SET_SWI_HOUR:begin
                    suspend<=1'b0;
                    sign<={switchtime,SWITCHTIME};
                end
                SET_SWI_MIN:begin
                    suspend<=1'b0;
                    sign<={switchtime,SWITCHTIME};
                end
                SET_SWI_SEC:begin
                    suspend<=1'b0;
                    sign<={switchtime,SWITCHTIME};
                end
                SET_REMIND_HOUR:begin
                    suspend<=1'b0;
                    sign<={remindtime,REMINDTIME};
                end
                SET_REMIND_MIN:begin
                    suspend<=1'b0;
                    sign<={remindtime,REMINDTIME};
                end
                SET_REMIND_SEC:begin
                    suspend<=1'b0;
                    sign<={remindtime,REMINDTIME};
                end
                default:begin
                    suspend<=1'b0;
                end
            endcase
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

    always @(posedge sign_pos_S) begin
        buttom_effect[2]<=1'b1;
        case(state)
            MENU:begin
                nxt_state <= TWO;
            end
            ONE:begin
                nxt_state <= TWO;
            end
            SEARCH:begin
                nxt_state <= SEARCH_SWITCH_TIME;
            end
            SET_REMIND_HOUR:begin
                nxt_state <= SET_REMIND_MIN;
            end
            SET_REMIND_MIN:begin
                nxt_state <= SET_REMIND_SEC;
            end
            SET_REMIND_SEC:begin
                nxt_state <= SEARCH_REMINDTIME;
            end
            SET_SWI_HOUR:begin
                nxt_state <= SET_SWI_MIN;
            end
            SET_SWI_MIN:begin
                nxt_state <= SET_SWI_SEC;
            end
            SET_SWI_SEC:begin
                nxt_state <= SEARCH_SWITCH_TIME;
            end
            default:; //do nothing
        endcase
    end
    always @(negedge sign_pos_S)begin
        buttom_effect[2]<=1'b0;
    end

    always @(posedge sign_pos_W) begin
        case(state)
            STANDBY:begin
                nxt_state <= MENU;
            end
            MENU:begin
                nxt_state <= STANDBY;
            end
            ONE:begin
                nxt_state <= STANDBY;
            end
            TWO:begin
                nxt_state <= STANDBY;
            end
            THREE:begin //exit
                nxt_state <= EXIT_STROM;
                //to complete
            end
            SEARCH:begin
                nxt_state <= STANDBY;
            end
            SEARCH_WORKTIME:begin
                nxt_state <= SEARCH;
            end
            SEARCH_SWITCH_TIME:begin
                nxt_state <= SEARCH;
            end
            SEARCH_REMINDTIME:begin
                nxt_state <= SEARCH;
            end
        endcase
    end

    always @(posedge sign_pos_A) begin
        case(state)
            SHUTDOWN:begin
                buttom_effect[1]<=1'b1;
                cnt_A<=re_cnt;
            end
            STANDBY:begin
                if(buttom_effect[0]==1'b1)begin
                    buttom_effect[0]<=1'b0;
                    nxt_state <= SHUTDOWN;
                end
            end
            MENU:begin
                nxt_state <= ONE;
            end
            TWO:begin
                nxt_state <= TWO;
            end
            SEARCH:begin
                nxt_state <= SEARCH_WORKTIME;
            end
            SET_REMIND_HOUR:begin
                if(remindtime[23:16] == 8'b00100011) begin  //23+1=0
                    remindtime[23:16] <= 8'b00000000;
                end
                else if(remindtime[19:16]==4'b1001) begin
                    remindtime[19:16] <= 4'b0000;
                    remindtime[23:16] <= remindtime[23:16]+1;
                end
                else remindtime[19:16] <= remindtime[19:16]+1;
            end
            SET_REMIND_MIN:begin
                if(remindtime[15:8] == 8'b01011001) begin   //59+1=0
                    remindtime[15:8] <= 8'b00000000;
                end
                else if(remindtime[11:8]==4'b1001) begin
                    remindtime[11:8] <= 4'b0000;
                    remindtime[15:8] <= remindtime[15:8]+1;
                end
                else remindtime[11:8] <= remindtime[11:8]+1;
            end
            SET_REMIND_SEC:begin
                if(remindtime[7:0] == 8'b01011001) begin
                    remindtime[7:0] <= 8'b00000000;
                end
                else if(remindtime[3:0]==4'b1001) begin
                    remindtime[3:0] <= 4'b0000;
                    remindtime[7:0] <= remindtime[7:0]+1;
                end
                else remindtime[3:0] <= remindtime[3:0]+1;
            end
            SET_SWI_HOUR:begin
                if(switchtime[23:16]==8'b00100011) begin
                    switchtime[23:16] <= 8'b00000000;
                end
                else if(switchtime[19:16]==4'b1001) begin
                    switchtime[19:16] <= 4'b0000;
                    switchtime[23:16] <= switchtime[23:16]+1;
                end
                else switchtime[19:16] <= switchtime[19:16]+1;
            end
            SET_SWI_MIN:begin
                if(switchtime[15:8]==8'b01011001) begin
                    switchtime[15:8] <= 8'b00000000;
                end
                else if(switchtime[11:8]==4'b1001) begin
                    switchtime[11:8] <= 4'b0000;
                    switchtime[15:8] <= switchtime[15:8]+1;
                end
                else switchtime[11:8] <= switchtime[11:8]+1;
            end
            SET_SWI_SEC:begin
                if(switchtime[7:0]==8'b01011001) begin
                    switchtime[7:0] <= 8'b00000000;
                end
                else if(switchtime[3:0]==4'b1001) begin
                    switchtime[3:0] <= 4'b0000;
                    switchtime[7:0] <= switchtime[7:0]+1;
                end
                else switchtime[3:0] <= switchtime[3:0]+1;
            end
            default:; //do nothing
        endcase
    end

    always @(posedge sign_pos_X) begin
        case(state)
            STANDBY:begin
                nxt_state <= SEARCH;
            end
            MENU:begin
                nxt_state <= CLEAN;
                countdown_clean<=countdown180;
            end
            SEARCH_SWITCH_TIME:begin
                nxt_state <= SET_SWI_HOUR;
            end
            SEARCH_REMINDTIME:begin
                nxt_state <= SET_REMIND_HOUR;
            end
            default:; //do nothing
        endcase
    end

    always @(posedge sign_pos_D) begin
        case(state)
            SHUTDOWN:begin
                if(buttom_effect[1]==1'b1)begin
                    buttom_effect[1]<=1'b0;
                    nxt_state <= STANDBY;
                end
            end
            STANDBY:begin
                buttom_effect[0]<=1'b1;
                cnt_D<=re_cnt;
            end
            MENU:begin
                if(storm_once==1'b0) begin
                    storm_once<=1'b1;
                    nxt_state <= THREE;
                    countdown_storm<=countdown60;
                end
            end
            SEARCH:begin
                nxt_state <= SEARCH_REMINDTIME;
            end
            default:; //do nothing
        endcase
    end
endmodule