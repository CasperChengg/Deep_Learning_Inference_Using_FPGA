`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
//   
// Create Date: 2023/10/29 16:15:27
// Design Name: 
// Module Name: MP1
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


module MP1
#(
  parameter layer =      3'd2,
  //maxpooling 1 parameter
  parameter ifmap_h=    6'd48,
  parameter ifmap_w=     6'd48, 
  parameter ifmap_c=      6'd8,
parameter init       = 4'b0101,
parameter read_data1 = 4'b0000,
parameter read_data2 = 4'b0001,
parameter read_data3 = 4'b0111,
parameter read_data4 = 4'b1111,
parameter read_get   = 4'b0010,
parameter maxpooling = 4'b0011,
parameter finish     = 4'b0100,
parameter test       = 4'b0110
  
) 
(
  input clk,
//  input rst_n,

//RAM write  
 input start_MP1,
 output reg end_MP1,
 output reg [15:0]ram_addr_w, 
 output reg [7:0]ram_data_w, 
 output reg ram_en,    //ram_enable
 output reg ram_wea,   //ram write enable

//RAM read 
 output reg [15:0]ram_addr_r,
 input  [7:0]ram_data_r,
 output reg ram_en_r
);

//queue reg
reg [7:0] FIFO [ifmap_w+1:0];
reg [5:0] push_times;
integer i;


//comparator
//reg [4:0] base;
reg [7:0] comp1;
reg [7:0] comp2;
reg [7:0] polling_result;
reg [7:0] t=1;


reg end_flag;
reg next_row;
reg [3:0]cur_state;
reg [3:0]next_state;
reg [15:0] get_count;//change row

reg [2:0]waitmp;
//reg [15:0] count;
//reg [15:0]ram_addr_write;
//always @(posedge clk )begin //calculate
//    if(start_MP1 && start_mp==0)begin
//        start_mp<=1;
//        next_state<=4'b0101;
//    end

//end
initial begin
next_state<= init;
end

always @(negedge clk)begin //calculate
    
        //read data
        cur_state=next_state;
        if(cur_state!=init)begin
            ram_addr_r=ram_addr_r+1;
            ram_en_r=1'b1;
        end
        
             
        case(cur_state)
            init:begin
                if(start_MP1)
                    next_state= read_data1;
                else
                    next_state= next_state;
                
                ram_addr_w=-1;
                ram_addr_r=-3; //start from addr 0
                get_count=0;
                polling_result=0;
                comp1=0;
                comp2=0;
                push_times<=0;
                end_flag<=0;
                ram_en=1'b0;
                ram_wea=1'b0;
                ram_en_r=1'b0;
                end_MP1<=0;
                waitmp<=0;
                for(i=ifmap_w+1;i>=0;i=i-1)
                        FIFO[i]<=1;
              
            end
            read_data1:begin //read data[0]
                next_state<=read_data2;
            end
            read_data2:begin //read data[1]
                //ram_addr_r<=count;
                //ram_en_r=1'b1;
                next_state<=read_data3;
            end
            read_data3:begin //read data[1]
                //ram_addr_r<=count;
                //ram_en_r=1'b1;
                next_state<=read_data4;
            end
            read_data4:begin //read data[1]
                next_state<=read_get;
            end
            read_get:begin
                //ram_addr_r<=count;
                //ram_en=1'b1;     
                //ram_addr_w<=ram_addr_write;
                ram_en<=1'b0;
                ram_wea<=1'b0;
                for( i=ifmap_w+1;i>=0;i=i-1)begin
                    if(i==0)
                        FIFO[i]=ram_data_r;
                    else
                        FIFO[i]= FIFO[i-1];
                end
                
                //ram_wea=1'b1;
                //ram_en_r=1'b1;
                push_times=push_times+1;
                get_count=get_count+1;
                
                    
                if(get_count==ifmap_h*ifmap_w*ifmap_c)//last one maxpooling then end
                    end_flag<=1;
                else if(get_count%(2*ifmap_w)==0) //if we need to start from new row
                    next_row<=1;
                else begin
                    end_flag<=0;
                    next_row<=0;
                end
                
                if(push_times==(ifmap_w+2))
                    next_state<=maxpooling;
                else 
                    next_state<=read_get;
          
            end
//            test:begin
//                ram_addr_w=t;
//                ram_data_w=1;
//                ram_en=1'b1;
//                ram_wea=1'b1;
//                ram_en_r=1'b0;
//                if(t>=8'd50) // ifmap_w+2
//                    next_state<=finish;
//                else
//                    next_state<=test;
//                t=t+1;
//            end
            maxpooling:begin
                comp1=($signed(FIFO[0])>$signed(FIFO[1]))?FIFO[0]:FIFO[1];
                comp2=($signed(FIFO[ifmap_w])>$signed(FIFO[ifmap_w+1]))?FIFO[ifmap_w]:FIFO[ifmap_w+1];
                polling_result=($signed(comp1)>$signed(comp2))?comp1:comp2;
               
                ram_addr_w=ram_addr_w+1;
                ram_data_w=polling_result;
                ram_en=1'b1;
                ram_wea=1'b1;
               
                
                if(next_row==1)//need to push w+2 data to compute next pooling
                    push_times<=1;
                 else  //push one data  in FIFO
                    push_times<=push_times-1;
                
                 //push data in FIFO
                 get_count=get_count+1;
                 for( i=ifmap_w+1;i>=0;i=i-1)
                        if(i==0)
                            FIFO[i]<=ram_data_r;
                        else
                            FIFO[i]<= FIFO[i-1];
                    
                //end or keep doing maxpooling
                
                if(end_flag==1)
                   next_state<=finish;
                else
                    next_state<=read_get;
                
            end
            finish:begin
                end_MP1<=1;
                if(waitmp==3'd4)
                    next_state<=init;   
                else
                    next_state<=finish;
                waitmp=waitmp+1;
            end
            default:
                cur_state=cur_state;
        endcase
       
end

//always @(posedge clk && start_MP1)begin //change addr
//    if(cur_state!=init) 
//        count<=count+1;
//    if(cur_state==maxpooling)// || cur_state==test)    
//        ram_addr_write<=ram_addr_write+1;
//end

endmodule