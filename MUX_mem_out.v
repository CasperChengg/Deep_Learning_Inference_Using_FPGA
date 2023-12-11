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


module FC
#(

  //FC1 parameter
  parameter input_size1= 15'd1600,
  parameter out_size1= 4'd12,
  parameter weight_base1=15'd2664,
  parameter other_weight_base1=8'd108,
  
  //FC2 parameter
  parameter input_size2= 15'd12,
  parameter out_size2= 4'd8,
  parameter weight_base2=15'd21864,
  parameter other_weight_base2=8'd144,
  
  //FC3 parameter
  parameter input_size3= 15'd8,
  parameter out_size3= 4'd2,
  parameter weight_base3=15'd21960,
  parameter other_weight_base3=8'd168

  
) 
(
  input clk,
//  input rst_n,

//RAM write  
 input start_FC,
 output reg end_FC,
 output reg [15:0]ram_addr_w, 
 output reg [7:0]ram_data_w, 
 output reg ram_en,    //ram_enable
 output reg ram_wea,   //ram write enable
//ROM other weight
 output reg [8:0]rom_addr_row,
 input  [31:0]rom_data_row,
 output reg rom_en_row,
 
 //ROM read weight
 output reg [14:0]rom_addr_rw,
 input  [7:0]rom_data_rw,
 output reg rom_en_rw, 

//RAM read 
 output reg [15:0]ram_addr_r,
 input  [7:0]ram_data_r,
 output reg ram_en_r,
 
 output reg [7:0]NN_out_male,
 output reg [7:0]NN_out_female
 
 
);

//queue reg
integer i;
reg [3:0] t;

//FC2-FC3
/////////////////////////
reg signed[7:0] ans [21:0];
reg [4:0]num;
reg [7:0]num_reg;
reg [14:0]input_size;
reg [3:0]out_size;
/////////////////////////

reg [3:0]filter_num;
reg end_flag;
reg [14:0]cur_state;
reg [63:0]sum_reg;
//reg [14:0]next_state;
reg start_mp;

//fFC  reg
reg signed [63:0] q1q2_sum;
reg round;
reg signed [63:0]q3;

//other weight
reg signed [25:0]M0;
reg signed [20:0]Z1a2;
reg signed [5:0]bias;
//reg [15:0] count;
//reg [15:0]ram_addr_write;
//always @(posedge clk )begin //calculate
//    if(start_FC && start_mp==0)begin
//        start_mp<=1;
//        next_state<=11'd0;
//    end

//end
initial begin
cur_state=11'd0;
filter_num = 4'd0;
for(i=0;i<5'd22;i=i+1)
    ans[i]<=1;
num_reg=0;    
num=0;
start_mp=0;
end
always @(negedge clk)begin //calculate
        //read data
        //cur_state=next_state;
             
        case(cur_state)
            11'd0:begin
                
                if(start_FC || start_mp)begin
                    cur_state <= cur_state+1;
                    start_mp<=1;
                end
                else
                    cur_state<=cur_state;
                    
                if(num<5'd12 && num>=0)begin //FC1
                    ram_addr_r<=-2; //start from addr 0
                    rom_addr_rw <= weight_base1+filter_num * input_size1-1; //base addres  of filter weight
                    rom_addr_row <= other_weight_base1+filter_num * 9'd3; // base address of filter other weight
                    input_size<=input_size1;
                    out_size<=out_size1;
                end
                else if(num<5'd20&&num>=5'd12)begin //FC2
                    rom_addr_rw <= weight_base2+filter_num * input_size2-1; //base addres  of filter weight
                    rom_addr_row <= other_weight_base2+filter_num * 9'd3; // base address of filter other weight
                    input_size<=input_size2;
                    out_size<=out_size2;
                end
                else begin //FC3
                    rom_addr_rw <= weight_base3+filter_num * input_size3-1; //base addres  of filter weight
                    rom_addr_row <= other_weight_base3+filter_num * 9'd3; // base address of filter other weight
                    input_size<=input_size3;
                    out_size<=out_size3;
                end 
                t<=0;
                num_reg<=0;
                q3<=0;
                q1q2_sum<=0;
                rom_en_rw <= 1'd0;
                rom_en_row <= 1'd1;
                ram_en<=1'b0;
                ram_wea<=1'b0;
                ram_en_r<=1'b1;
                end_FC<=0;
                sum_reg<=0;
              
            end
            11'd1,11'd2,11'd3:begin //read data[0]
                 cur_state<= cur_state+1;
                 ram_addr_r<=ram_addr_r+1;
                 if(cur_state>=11'd2)begin
                    rom_addr_rw <= rom_addr_rw + 11'd1;
                    rom_en_rw <= 1'd1;
                 end
                 rom_addr_row <= rom_addr_row + 9'd1;
            end
            11'd1700:begin //end
                ram_addr_w<=t;
                ram_data_w<=ans[t+5'd20];
                NN_out_female<=ans[5'd20];
                NN_out_male<=ans[5'd21];
                ram_en<=1'b1;
                ram_wea<=1'b1;
                ram_en_r<=1'b0;
                if(t) // ifmap_w+2
                    cur_state<=11'd1702;
                else
                    cur_state<=11'd1700;
                t<=t+1;
            end
            11'd1702:begin //end_FC
                end_FC<=1;
                start_mp<=0;
                if(t==4'd4)
                    cur_state<=11'd0;
                else
                    cur_state<=11'd1702;   
                t<=t+1;
            end
            default:begin
                rom_addr_rw <= rom_addr_rw + 11'd1;
                cur_state<=cur_state+1;
                ram_addr_r<=ram_addr_r+1;
                
                if(cur_state == (input_size+4'd10))begin
                    if(num==5'd21)
                        cur_state<=12'd1700;
                    else
                        cur_state<=0;
                    
                    num<=num+1;
 
                    if(filter_num==(out_size-1))
                        filter_num<=0;    
                    else
                        filter_num<=filter_num+1;
                        
                end
                else if(cur_state == (input_size+9))begin
                    ans[num]<= q3[7:0];
                end
                else if(cur_state == (input_size+8))begin
                    if($signed(q3[31:0]) < -32'sd128) begin
                        q3[31:0] <= -32'd128;
                    end    
                end
                else if(cur_state == (input_size+7))begin
                    if(num<5'd20)
                        q3 <= (q3 >> 32) + round- 32'd128;
                    else
                        q3 <= (q3 >> 32) + round+ 32'd41; //conv3
                end
                else if(cur_state == (input_size+6))begin
                    round <= q3[31];
                end
                else if(cur_state == (input_size+5))begin
                    q3 <= M0 * sum_reg;
                end
                else if(cur_state == (input_size+4))begin
                    sum_reg<=(q1q2_sum - Z1a2 + bias);
                end
//                else if(cur_state == (input_size+4))begin

//                    q3 = M0 * (q1q2_sum - Z1a2 + bias);
                    
//                    round = q3[31];
//                    if(num<5'd20)
//                        q3 = (q3 >> 32) + round- 32'd128;
//                    else
//                        q3 = (q3 >> 32) + round+ 32'd41; //conv3
                    
//                    if($signed(q3[31:0]) < -32'sd128) begin
//                        q3[31:0] = -32'd128;
//                    end
//                    ans[num]= q3[7:0];
//                end
                else begin
                    if(num<5'd12&&num>=0)  
                        q1q2_sum<=q1q2_sum + $signed(rom_data_rw) * $signed(ram_data_r);
                    else if(num<5'd20&&num>=5'd12)begin
                        q1q2_sum<=q1q2_sum+$signed(rom_data_rw) * ans[num_reg];
                        num_reg<=num_reg+1;    
                    end
                    else begin
                        q1q2_sum<=q1q2_sum+$signed(rom_data_rw) * ans[5'd12+num_reg];
                        num_reg<=num_reg+1;    
                end    
             end
            end
            
            
        endcase        
end



always@(posedge clk ) begin
    case(cur_state)
        11'd3:begin
            M0 <= rom_data_row;
        end
        11'd4:begin
            Z1a2 <= rom_data_row;
        end
        11'd5:begin
            bias <= rom_data_row;
        end
        default:begin
            bias = bias;
        end
    endcase
end
endmodule
