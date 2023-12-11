`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/29 16:12:41
// Design Name: 
// Module Name: ConV2
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


module ConV1
(
    input clk,
    
	input start_ConV1,
    output reg end_ConV1,
	input start_ConV2,
    output reg end_ConV3,
//    input start_ConV3,
//    output reg end_ConV3,
		   
    //RAM read
    output reg [15:0]ram_addr_ri,
    input [7:0]ram_data_ri,
    output reg ram_en_ri,
    
    //RAM write
    output reg [15:0]ram_addr_w,
    output reg[7:0]ram_data_w,
    output reg ram_en_w,
    output reg ram_wea,
    
    //ROM read input image
    output reg [11:0]rom_addr_ri,
    input [7:0]rom_data_ri,
    output reg rom_en_ri,
    
    //ROM read weight
    output reg [14:0]rom_addr_rw,
    input  [7:0]rom_data_rw,
    output reg rom_en_rw, 
 
    //ROM read other_weight
    output reg [8:0]rom_addr_row,
    input  [31:0]rom_data_row,
    output reg rom_en_row  
);

reg [12:0]read_stage;
reg [3:0]filter_num;

// store ifmap by channels
reg [3:0]ifmap_channel_counter;
reg signed [7:0]ifmap_c0 [102:0];
reg signed [7:0]ifmap_c1 [50:0];
reg signed [7:0]ifmap_c2 [50:0];
reg signed [7:0]ifmap_c3 [50:0];
reg signed [7:0]ifmap_c4 [50:0];
reg signed [7:0]ifmap_c5 [50:0];
reg signed [7:0]ifmap_c6 [50:0];
reg signed [7:0]ifmap_c7 [50:0];
reg signed [7:0]ifmap_c8 [46:0];
reg signed [7:0]ifmap_c9 [46:0];
reg signed [7:0]ifmap_c10 [46:0];
reg signed [7:0]ifmap_c11 [46:0];

// store weights
reg signed [7:0]weights [107:0];

// store other weights
reg signed [25:0]M0;
reg signed [20:0]Z1a2;
reg signed [5:0]bias;

// for calculating result
reg round;
reg signed [23:0]sum;
reg signed [23:0]sum_z1a2_bias;
reg signed [63:0]q3;
reg signed [31:0]result;
reg signed [7:0]result_relu;

// store the address  of ifmap channel 0 
reg [15:0]ram_addr_ri_c0;

reg [7:0]channel_vector_counter;

// partial sum
reg signed[15:0]partial_0;
reg signed[15:0]partial_1;
reg signed[15:0]partial_2;
reg signed[15:0]partial_3;
reg signed[15:0]partial_4;
reg signed[15:0]partial_5;
reg signed[15:0]partial_6;
reg signed[15:0]partial_7;
reg signed[15:0]partial_8;

// state
parameter idle  = 2'd0;
parameter ConV1 = 2'd1;
parameter ConV2 = 2'd2;
parameter ConV3 = 2'd3;
reg [1:0]cur_state;

// parameter for differnt state
reg [6:0]weighs_size;
parameter weights_size_ConV1 = 7'd9;
parameter weights_size_ConV2 = 7'd72;
parameter weights_size_ConV3 = 7'd108;

reg [9:0]start_right_moving;
parameter start_right_moving_ConV1 = 10'd104;
parameter start_right_moving_ConV2 = 10'd402;
parameter start_right_moving_ConV3 = 10'd554;

reg [3:0]ifmap_c;
parameter ifmap_c_ConV1 = 4'd1;
parameter ifmap_c_ConV2 = 4'd8;
parameter ifmap_c_ConV3 = 4'd12;

reg [6:0]enough_size;
parameter enough_size_ConV1 = 7'd102;
parameter enough_size_ConV2 = 7'd50;
parameter enough_size_ConV3 = 7'd46;

reg [9:0]base_addr_rw;
parameter base_addr_rw_ConV1 = 10'd0;
parameter base_addr_rw_ConV2 = 10'd72;
parameter base_addr_rw_ConV3 = 10'd936;

reg [5:0]base_addr_row;
parameter base_addr_row_ConV1 = 6'd0;
parameter base_addr_row_ConV2 = 6'd24;
parameter base_addr_row_ConV3 = 6'd60;

reg [3:0]filter_offset;
parameter filter_offset_ConV1 = 4'd7;
parameter filter_offset_ConV2 = 4'd11;
parameter filter_offset_ConV3 = 4'd15;

reg [12:0]end_stage;
parameter end_stage_ConV1 = 13'd2509;
parameter end_stage_ConV2 = 13'd4608;
parameter end_stage_ConV3 = 13'd5808;

reg change_to_ConV1;
reg change_to_ConV2;
reg change_to_ConV3;
reg start_ConV3;
reg [1:0]delay;
reg pause;
integer i;

initial begin
    pause = 1'b1;
    delay = 2'd0;
    read_stage=13'd0;
    cur_state = idle;
    start_ConV3 = 1'b0;
end

// state controller
always@(posedge clk) begin
    case(cur_state) 
        idle : begin
            if(start_ConV1) change_to_ConV1 <= 1'b1;
            else change_to_ConV1 <= 1'b0;
        end
        ConV1 : begin
            if(start_ConV2) change_to_ConV2 <= 1'b1;
            else change_to_ConV2 <= 1'b0;
        end
        ConV2 : begin
            if(start_ConV3) change_to_ConV3 <= 1'b1;
            else change_to_ConV3 <= 1'b0;
        end
        default : begin
            change_to_ConV1 <= 1'b0;
            change_to_ConV2 <= 1'b0;
            change_to_ConV3 <= 1'b0;
        end
    endcase
end

// setting the address for getting data during posedge and calculating result
always@(negedge clk) begin
    if(read_stage == 13'd0) begin // initialize
        if(!pause) begin		
            case(cur_state)
                ConV1:begin
                    rom_addr_ri <= 12'd0;
                end
                ConV2 : begin
                    ram_addr_ri <= 16'd0; // base address of input feature map
                    ram_addr_ri_c0 <= 16'd0;
                end
                ConV3 : begin
                    ram_addr_ri <= 16'd4608; // base address of input feature map
                    ram_addr_ri_c0 <= 16'd4608;
                end
                default : begin
                    rom_addr_ri <= rom_addr_ri;
                    ram_addr_ri <= ram_addr_ri;
                    ram_addr_ri_c0 <= ram_addr_ri_c0;
                end
            endcase
            
            rom_addr_rw <= base_addr_rw + filter_num * 15'd9; //base addres  of filter weight
            rom_addr_row <= base_addr_row + filter_num * 9'd3; // base address of filter other weight
            
            case(cur_state) // base address for writing result
                ConV1 : begin
                    ram_addr_w <= filter_num * 16'd2304; 
                end
                ConV2 : begin
                    ram_addr_w <= 16'd4608 + filter_num * 16'd484; 
                end
                ConV3 : begin
                    ram_addr_w <= 16'd10416 + filter_num * 16'd400;
                end
                default : begin
                    ram_addr_w <= ram_addr_w;
                end
            endcase
            ram_en_w <= 1'b0;
            ram_wea <= 1'b0;
            ram_en_ri <= 1'b1;
            rom_en_ri <= 1'b1;
            rom_en_rw <= 1'b1;
            rom_en_row <= 1'd1;
            read_stage <= 13'd1;
        end
        else begin // pause
            case(cur_state)
                idle : begin
                    if(change_to_ConV1) begin
                        weighs_size <= weights_size_ConV1;
                        start_right_moving <= start_right_moving_ConV1;
                        enough_size <= enough_size_ConV1;
                        ifmap_c <= ifmap_c_ConV1;
                        base_addr_rw <= base_addr_rw_ConV1;
                        base_addr_row <= base_addr_row_ConV1;		
                        filter_offset <= filter_offset_ConV1;
                        end_stage <= end_stage_ConV1;
                        cur_state <= ConV1;
                        end_ConV1 <= 1'd0;
                        end_ConV3 <= 1'b0;
                        pause <= 1'b0;
                     end
                     else begin
                        cur_state <= cur_state;
                     end
                end
                ConV1 : begin
                    if(change_to_ConV2) begin
                        weighs_size <= weights_size_ConV2;
                        start_right_moving <= start_right_moving_ConV2;
                        enough_size <= enough_size_ConV2;
                        ifmap_c <= ifmap_c_ConV2;
                        base_addr_rw <= base_addr_rw_ConV2;
                        base_addr_row <= base_addr_row_ConV2;		
                        filter_offset <= filter_offset_ConV2;
                        end_stage <= end_stage_ConV2;
                        start_ConV3 <= 1'b0;
                        end_ConV1 <= 1'd0;
                        end_ConV3 <= 1'b0;
                        cur_state <= ConV2;
                        pause <= 1'b0;	
                    end	
                    else begin
                        cur_state <= cur_state;
                    end
                    if(delay < 2'd2) begin
                        delay = delay + 2'd1;
                    end
                    else begin
                        end_ConV1 = 1'b0;
                    end
                end
                ConV2 : begin
                  if(change_to_ConV3) begin
                        weighs_size <= weights_size_ConV3;
                        start_right_moving <= start_right_moving_ConV3;
                        enough_size <= enough_size_ConV3;
                        ifmap_c <= ifmap_c_ConV3;
                        base_addr_rw <= base_addr_rw_ConV3;
                        base_addr_row <= base_addr_row_ConV3;		
                        filter_offset <= filter_offset_ConV3;
                        end_stage <= end_stage_ConV3;
                        start_ConV3 <= 1'b0;
                        end_ConV1 <= 1'd0;
                        end_ConV3 <= 1'b0;
                        cur_state <= ConV3;	
                        pause <= 1'b0;		
                    end
                    else begin
                        cur_state <= cur_state;
                    end
                end
                ConV3 : begin
                    if(delay < 2'd2) begin
                        delay = delay + 2'd1;
                    end
                    else begin
                        end_ConV3 = 1'b0;
                        cur_state <= idle;
                    end
                end
                default : begin
                    cur_state <= cur_state;
                end
            endcase		
            read_stage <= 13'd0;
            filter_num <= 4'd0;
        end
    end
    else if(read_stage == 13'd1 || read_stage == 13'd2) begin
        read_stage = read_stage + 13'd1;
        case(cur_state) // read input feature mpa
            ConV1 : begin
                rom_addr_ri <= rom_addr_ri + 16'd1;
            end
            ConV2 : begin
                ram_addr_ri <= ram_addr_ri + 16'd576;
            end
            ConV3 : begin
                ram_addr_ri <= ram_addr_ri + 16'd484;
            end
            default: begin
                rom_addr_ri <= rom_addr_ri;
                ram_addr_ri <= ram_addr_ri;
            end
        endcase
        rom_addr_rw <= rom_addr_rw + 15'd1; // read weight
        rom_addr_row <= rom_addr_row + 9'd1; // read other weight
    end
    else if(read_stage >= 13'd3 && read_stage < weighs_size) begin
        read_stage <= read_stage + 13'd1;
        case(cur_state)
            ConV1 : begin
                rom_addr_ri <= rom_addr_ri + 16'd1;
            end
            ConV2, ConV3 : begin
                if(read_stage % ifmap_c == 16'd0) begin
                    ram_addr_ri_c0 <= ram_addr_ri_c0 + 16'd1;
                    ram_addr_ri <= ram_addr_ri_c0 + 16'd1;
                end 
                else begin
                    case(cur_state) // read input feature mpa
                        ConV2 : begin
                            ram_addr_ri <= ram_addr_ri + 16'd576;
                        end
                        ConV3 : begin
                            ram_addr_ri <= ram_addr_ri + 16'd484;
                        end
                    endcase
                end
            end
            default : begin
                rom_addr_ri <= rom_addr_ri;
                ram_addr_ri <= ram_addr_ri;
            end
        endcase
        if(rom_addr_rw < 15'd8) begin
            rom_addr_rw <= rom_addr_rw + 15'd1;
        end
        else begin
            if((rom_addr_rw - 15'd8) % 15'd9 == 15'd0) begin
                rom_addr_rw <= rom_addr_rw + 9 * filter_offset + 15'd1;
            end
            else begin
                rom_addr_rw <= rom_addr_rw + 15'd1;
            end
        end
    end
    else if(read_stage >= weighs_size && read_stage <= start_right_moving) begin
        read_stage <= read_stage + 13'd1;
        case(cur_state)
            ConV1 : begin
                rom_addr_ri <= rom_addr_ri + 16'd1;
            end
            ConV2, ConV3 : begin
                if(read_stage % ifmap_c == 16'd0) begin
                    ram_addr_ri_c0 <= ram_addr_ri_c0 + 16'd1;
                    ram_addr_ri <= ram_addr_ri_c0 + 16'd1;
                end 
                else begin
                    case(cur_state) // read input feature mpa
                        ConV2 : begin
                            ram_addr_ri <= ram_addr_ri + 16'd576;
                        end
                        ConV3 : begin
                            ram_addr_ri <= ram_addr_ri + 16'd484;
                        end
                    endcase
                end	   
            end
            default : begin
                rom_addr_ri <= rom_addr_ri;
                ram_addr_ri <= ram_addr_ri;
            end
        endcase
    end
    else begin
        case(ifmap_channel_counter)
            4'd0: begin
                if(read_stage < end_stage) begin
                    case(cur_state)
                        ConV1 : begin
                            read_stage <= read_stage + 13'd1;
                            rom_addr_ri <= rom_addr_ri + 16'd1;
                        end
                        ConV2 : begin
                            read_stage <= read_stage + 13'd1;
                            ram_addr_ri <= ram_addr_ri + 16'd576;
                        end
                        ConV3 : begin
                            read_stage <= read_stage + 13'd1;
                            ram_addr_ri <= ram_addr_ri + 16'd484;
                        end
                        default : begin
                             rom_addr_ri <= rom_addr_ri;
                             ram_addr_ri <= ram_addr_ri;
                        end
                    endcase
                end
                else begin
                    case(cur_state)
                        ConV1 : begin
                            if(filter_num == 3'd7) begin
                                end_ConV1 <= 1'b1;
                                delay = 2'd0;
                                pause <= 1'b1;
                            end
                            filter_num <= filter_num + 4'd1;
                            read_stage <= 13'd0;
                            ram_en_w <= 1'b0;
                            ram_wea <= 1'b0;
                            rom_en_ri <= 1'b0;
                            rom_en_rw <= 1'd0;
                            rom_en_row <= 1'd0;
                        end
                        default : begin
                            read_stage <= read_stage + 13'd1;
                            ram_addr_ri <= ram_addr_ri;
                        end
                    endcase
                end
                case(cur_state)
                    ConV1:begin
                        if(read_stage < 13'd162) begin
                            if(read_stage <= 13'd111 || read_stage == 13'd160 || read_stage == 13'd161) begin
                                ram_addr_w <= ram_addr_w;
                            end
                            else begin
                                ram_addr_w <= ram_addr_w + 16'd1;
                            end
                        end
                        else begin
                            if((read_stage - 13'd160) % 13'd50 == 13'd0 || (read_stage - 13'd161) % 13'd50 == 13'd0) begin
                                ram_addr_w <= ram_addr_w;
                            end
                            else begin
                                ram_addr_w <= ram_addr_w + 16'd1;
                            end
                        end
                        sum <= partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                        sum_z1a2_bias <= sum - Z1a2 + bias;
                        q3 <= M0 * sum_z1a2_bias;
                        result <= q3[63:32] + q3[31] - 32'd128;
                        if(result < -32'sd128) begin
                            result_relu <= -8'd128;
                        end
                        else begin
                            result_relu <= result;
                        end
                        ram_data_w <= result_relu;
                        ram_en_w <= 1'b1;
                        ram_wea <= 1'b1;
                    end
                    ConV2, ConV3 : begin
                       sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    default : begin
                        sum <= sum;
                        q3 <= q3;
                    end
                endcase                                       
            end
            4'd1: begin
                read_stage <= read_stage + 13'd1;
                case(cur_state)
                    ConV2 : begin
                        ram_addr_ri <= ram_addr_ri + 16'd576; 
                        sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8; 
                    end
                    ConV3 : begin
                        ram_addr_ri <= ram_addr_ri + 16'd484; 
                        sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    default:begin
                        ram_addr_ri <= ram_addr_ri;
                        sum <= sum;
                    end
                endcase
            end
            4'd2: begin
                sum_z1a2_bias <= sum - Z1a2 + bias;
                read_stage <= read_stage + 13'd1;
                case(cur_state)
                    ConV2 : begin
                        ram_addr_ri <= ram_addr_ri + 16'd576; 
                        sum <= partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    ConV3 : begin
                        ram_addr_ri = ram_addr_ri + 16'd484; 
                        sum <= partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    default:begin
                        ram_addr_ri <= ram_addr_ri;
                       sum <= sum;
                    end
                endcase
            end
            4'd3: begin
                read_stage <= read_stage + 13'd1;
                q3 <= M0 * sum_z1a2_bias;
                case(cur_state)
                    ConV2 : begin
                        ram_addr_ri <= ram_addr_ri + 16'd576; 
                        sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    ConV3 : begin
                        ram_addr_ri <= ram_addr_ri + 16'd484; 
                        sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    default:begin
                        ram_addr_ri <= ram_addr_ri;
                        sum <= sum;
                    end
                endcase
             end
            4'd4: begin
                result <= q3[63:32] + q3[31] - 32'd128;
                read_stage <= read_stage + 13'd1;
                case(cur_state)
                    ConV2 : begin
                        ram_addr_ri <= ram_addr_ri + 16'd576; 
                        sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    ConV3 : begin
                        ram_addr_ri <= ram_addr_ri + 16'd484; 
                        sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    default:begin
                        ram_addr_ri <= ram_addr_ri;
                        sum <= sum;
                    end
                endcase               
            end
            4'd5: begin
                if(result < -32'sd128) begin
                    result_relu <= -8'd128;
                end
                else begin
                    result_relu <= result;
                end
                read_stage <= read_stage + 13'd1;
                case(cur_state)
                    ConV2 : begin
                        ram_addr_ri <= ram_addr_ri + 16'd576; 
                        sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    ConV3 : begin
                        ram_addr_ri <= ram_addr_ri + 16'd484; 
                        sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    default:begin
                        ram_addr_ri <= ram_addr_ri;
                        sum <= sum;
                    end
                endcase
            end
            4'd6: begin
                read_stage <= read_stage + 13'd1;
                ram_data_w <= result_relu;
                case(cur_state)
                    ConV2 : begin
                        if(read_stage < 16'd4607) begin
                            ram_addr_ri_c0 <= ram_addr_ri_c0 + 16'd1;
                            ram_addr_ri <= ram_addr_ri_c0 + 16'd1;
                        end
                        if(read_stage < 13'd609) begin
                            if(read_stage <= 13'd416 || read_stage == 13'd608 || read_stage == 13'd600) begin
                                ram_addr_w <= ram_addr_w;
                            end
                            else begin
                                ram_addr_w <= ram_addr_w + 16'd1;
                            end
                        end
                        else begin
                            if((read_stage - 13'd608) % 13'd192 == 13'd0 || (read_stage - 13'd600) % 13'd192 == 13'd0) begin
                                ram_addr_w <= ram_addr_w;
                            end
                            else begin
                                ram_addr_w <= ram_addr_w + 16'd1;
                            end
                        end
                        sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    ConV3 : begin
                        ram_addr_ri <= ram_addr_ri + 16'd484;
                        sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                    end
                    default:begin
                        ram_addr_ri <= ram_addr_ri;
                        sum <= sum;
                    end
                endcase
                ram_en_w <= 1'b1;
                ram_wea <= 1'b1;
            end
            4'd7: begin
                read_stage <= read_stage + 13'd1;
                if(read_stage == (end_stage + 13'd9)) begin
                    if(filter_num == filter_offset) begin
                        case(cur_state)
                            ConV2 : begin
                                start_ConV3 <= 1'b1;
                                //end_ConV3 <= 1'b1;
                                delay = 2'd2;
                            end
                            ConV3 : begin
                                end_ConV3 <= 1'b1;
                                delay = 2'd0;
                            end
                            default : begin
                                start_ConV3 <= start_ConV3;
                                end_ConV3 <= end_ConV3;
                            end
                        endcase
                        pause <= 1'b1;
                    end
                    else begin
                        start_ConV3 <= start_ConV3;
                        end_ConV3 <= end_ConV3;
                    end
                    filter_num <= filter_num + 4'd1;
                    read_stage <= 13'd0;
                    ram_en_w <= 1'b0;
                    ram_wea <= 1'b0;
                    rom_en_rw <= 1'd0;
                    rom_en_row <= 1'd0;
                end
                else begin
                    case(cur_state)
                        ConV2 : begin
                            if(read_stage < end_stage) begin
                                ram_addr_ri <= ram_addr_ri + 16'd576;
                            end
                            sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                        end
                        ConV3 : begin
                            ram_addr_ri <= ram_addr_ri + 16'd484;
                            sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                        end
                        default:begin
                            ram_addr_ri <= ram_addr_ri;
                            sum <= sum;
                        end
                    endcase     
                end             
            end
            4'd8, 4'd9: begin
                read_stage <= read_stage + 13'd1;
                ram_addr_ri <= ram_addr_ri + 16'd484;
                sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
            end
            4'd10: begin
                read_stage <= read_stage + 13'd1;
               if(read_stage < end_stage) begin
                    ram_addr_ri_c0 <= ram_addr_ri_c0 + 16'd1;
                    ram_addr_ri <= ram_addr_ri_c0 + 16'd1;
                end
                else begin
                    ram_addr_ri <= ram_addr_ri;
                end
                if(read_stage < 13'd829) begin
                    if(read_stage <= 13'd575 || read_stage == 13'd816 || read_stage == 13'd828) begin
                        ram_addr_w <= ram_addr_w;
                    end
                    else begin
                        ram_addr_w <= ram_addr_w + 16'd1;
                    end
                end
                else begin
                    if((read_stage - 13'd816) % 13'd264 == 13'd0 || (read_stage - 13'd828) % 13'd264 == 13'd0) begin
                        ram_addr_w <= ram_addr_w;
                    end
                    else begin
                        ram_addr_w <= ram_addr_w + 16'd1;
                    end
                end
                sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
                ram_en_w <= 1'b1;
                ram_wea <= 1'b1;
            end
            4'd11: begin
                read_stage <= read_stage + 13'd1;
                if(read_stage < end_stage) begin
                    ram_addr_ri <= ram_addr_ri + 16'd484;
                end
                else begin
                    ram_addr_ri <= ram_addr_ri;
                end
                sum <= sum + partial_0 + partial_1 + partial_2 + partial_3 + partial_4 + partial_5 + partial_6 + partial_7 + partial_8;
            end
            default : begin
                ram_addr_ri <= ram_addr_ri;
                sum <= sum;
            end
        endcase
    end
end

// multipliter 0
always@(negedge clk) begin
    if(read_stage > start_right_moving) begin
        case(ifmap_channel_counter)
            4'd0: begin
                case(cur_state)
                    ConV1:begin
                        partial_0 <= ifmap_c0[0] * weights[0];
                    end
                    ConV2 : begin
                        partial_0 <= ifmap_c7[0] * weights[63];
                    end
                    ConV3 : begin
                        partial_0 <= ifmap_c11[0] * weights[99];
                    end
                    default : begin
                        partial_0 <= partial_0;
                    end
                endcase                                       
            end
            4'd1: begin
                case(cur_state)
                    ConV2 : begin
                        partial_0 <= ifmap_c0[0] * weights[0]; 
                    end
                    ConV3 : begin
                        partial_0 <=  ifmap_c0[0] * weights[0];
                    end
                    default:begin
                        partial_0 <= partial_0;
                    end
                endcase
            end
            4'd2: begin
                case(cur_state)
                    ConV2 : begin
                        partial_0 <= ifmap_c1[0] * weights[9];
                    end
                    ConV3 : begin
                        partial_0 <= ifmap_c1[0] * weights[9];
                    end
                    default:begin
                        partial_0 <= partial_0;
                    end
                endcase
            end
            4'd3: begin
                case(cur_state)
                    ConV2 : begin
                        partial_0 <= ifmap_c2[0] * weights[18];
                    end
                    ConV3 : begin
                        partial_0 <=  ifmap_c2[0] * weights[18];
                    end
                    default:begin
                        partial_0 <= partial_0;
                    end
                endcase
             end
            4'd4: begin
                case(cur_state)
                    ConV2 : begin
                        partial_0 <= ifmap_c3[0] * weights[27];
                    end
                    ConV3 : begin
                        partial_0 <= ifmap_c3[0] * weights[27];
                    end
                    default:begin
                        partial_0 <= partial_0;
                    end
                endcase           
            end
            4'd5: begin
                case(cur_state)
                    ConV2 : begin
                        partial_0 <=  ifmap_c4[0] * weights[36];
                    end
                    ConV3 : begin
                        partial_0 <=  ifmap_c4[0] * weights[36] ;
                    end
                    default:begin
                        partial_0 <= partial_0;
                    end
                endcase  
            end
            4'd6: begin
                case(cur_state)
                    ConV2 : begin
                        partial_0 <=  ifmap_c5[0] * weights[45];
                    end
                    ConV3 : begin
                        partial_0 <=  ifmap_c5[0] * weights[45];
                    end
                    default:begin
                        partial_0 <= partial_0;
                    end
                endcase
            end
            4'd7: begin
                case(cur_state)
                    ConV2 : begin
                        partial_0 <=  ifmap_c6[0] * weights[54];
                    end
                    ConV3 : begin
                        partial_0 <=  ifmap_c6[0] * weights[54];
                    end
                    default:begin
                        partial_0 <= partial_0;
                    end
                endcase                  
            end
            4'd8: begin
                partial_0 <=  ifmap_c7[0] * weights[63];
            end
            4'd9: begin
                partial_0 <=  ifmap_c8[0] * weights[72];
            end
            4'd10: begin
                partial_0 <=  ifmap_c9[0] * weights[81];
            end
            4'd11: begin
                partial_0 <=  ifmap_c10[0] * weights[90];
            end
            default : begin
                partial_0 <= partial_0;
            end
        endcase
    end
    else begin
        partial_0 = partial_0;
    end
end

// multiplier 1
always@(negedge clk) begin
    if(read_stage > start_right_moving) begin
        case(ifmap_channel_counter)
            4'd0: begin
                case(cur_state)
                    ConV1:begin
                        partial_1 <= ifmap_c0[1] * weights[1];
                    end
                    ConV2 : begin
                        partial_1 <= ifmap_c7[1] * weights[64];
                    end
                    ConV3 : begin
                        partial_1 <= ifmap_c11[1] * weights[100];
                    end
                    default : begin
                        partial_1 <= partial_1;
                    end
                endcase                                       
            end
            4'd1: begin
                case(cur_state)
                    ConV2 : begin
                        partial_1 <= ifmap_c0[1] * weights[1]; 
                    end
                    ConV3 : begin
                        partial_1 <=  ifmap_c0[1] * weights[1];
                    end
                    default:begin
                        partial_1 <= partial_1;
                    end
                endcase
            end
            4'd2: begin
                case(cur_state)
                    ConV2 : begin
                        partial_1 <= ifmap_c1[1] * weights[10];
                    end
                    ConV3 : begin
                        partial_1 <= ifmap_c1[1] * weights[10];
                    end
                    default:begin
                        partial_1 <= partial_1;
                    end
                endcase
            end
            4'd3: begin
                case(cur_state)
                    ConV2 : begin
                        partial_1 <= ifmap_c2[1] * weights[19];
                    end
                    ConV3 : begin
                        partial_1 <=  ifmap_c2[1] * weights[19];
                    end
                    default:begin
                        partial_1 <= partial_1;
                    end
                endcase
             end
            4'd4: begin
                case(cur_state)
                    ConV2 : begin
                        partial_1 <= ifmap_c3[1] * weights[28];
                    end
                    ConV3 : begin
                        partial_1 <= ifmap_c3[1] * weights[28];
                    end
                    default:begin
                        partial_1 <= partial_1;
                    end
                endcase           
            end
            4'd5: begin
                case(cur_state)
                    ConV2 : begin
                        partial_1 <=  ifmap_c4[1] * weights[37];
                    end
                    ConV3 : begin
                        partial_1 <=  ifmap_c4[1] * weights[37] ;
                    end
                    default:begin
                        partial_1 <= partial_1;
                    end
                endcase  
            end
            4'd6: begin
                case(cur_state)
                    ConV2 : begin
                        partial_1 <=  ifmap_c5[1] * weights[46];
                    end
                    ConV3 : begin
                        partial_1 <=  ifmap_c5[1] * weights[46];
                    end
                    default:begin
                        partial_1 <= partial_1;
                    end
                endcase
            end
            4'd7: begin
                case(cur_state)
                    ConV2 : begin
                        partial_1 <=  ifmap_c6[1] * weights[55];
                    end
                    ConV3 : begin
                        partial_1 <=  ifmap_c6[1] * weights[55];
                    end
                    default:begin
                        partial_1 <= partial_1;
                    end
                endcase                  
            end
            4'd8: begin
                partial_1 <=  ifmap_c7[1] * weights[64];
            end
            4'd9: begin
                partial_1 <=  ifmap_c8[1] * weights[73];
            end
            4'd10: begin
                partial_1 <=  ifmap_c9[1] * weights[82];
            end
            4'd11: begin
                partial_1 <=  ifmap_c10[1] * weights[91];
            end
            default : begin
                partial_1 <= partial_1;
            end
        endcase
    end
    else begin
        partial_1 = partial_1;
    end
end

// multiplier 2
always@(negedge clk) begin
    if(read_stage > start_right_moving) begin
        case(ifmap_channel_counter)
            4'd0: begin
                case(cur_state)
                    ConV1:begin
                        partial_2 <= ifmap_c0[2] * weights[2];
                    end
                    ConV2 : begin
                        partial_2 <= ifmap_c7[2] * weights[65];
                    end
                    ConV3 : begin
                        partial_2 <= ifmap_c11[2] * weights[101];
                    end
                    default : begin
                        partial_2 <= partial_2;
                    end
                endcase                                       
            end
            4'd1: begin
                case(cur_state)
                    ConV2 : begin
                        partial_2 <= ifmap_c0[2] * weights[2]; 
                    end
                    ConV3 : begin
                        partial_2 <=  ifmap_c0[2] * weights[2];
                    end
                    default:begin
                        partial_2 <= partial_2;
                    end
                endcase
            end
            4'd2: begin
                case(cur_state)
                    ConV2 : begin
                        partial_2 <= ifmap_c1[2] * weights[11];
                    end
                    ConV3 : begin
                        partial_2 <= ifmap_c1[2] * weights[11];
                    end
                    default:begin
                        partial_2 <= partial_2;
                    end
                endcase
            end
            4'd3: begin
                case(cur_state)
                    ConV2 : begin
                        partial_2 <= ifmap_c2[2] * weights[20];
                    end
                    ConV3 : begin
                        partial_2 <=  ifmap_c2[2] * weights[20];
                    end
                    default:begin
                        partial_2<= partial_2;
                    end
                endcase
             end
            4'd4: begin
                case(cur_state)
                    ConV2 : begin
                        partial_2 <= ifmap_c3[2] * weights[29];
                    end
                    ConV3 : begin
                        partial_2 <= ifmap_c3[2] * weights[29];
                    end
                    default:begin
                        partial_2 <= partial_2;
                    end
                endcase           
            end
            4'd5: begin
                case(cur_state)
                    ConV2 : begin
                        partial_2 <=  ifmap_c4[2] * weights[38];
                    end
                    ConV3 : begin
                        partial_2 <=  ifmap_c4[2] * weights[38] ;
                    end
                    default:begin
                        partial_2 <= partial_2;
                    end
                endcase  
            end
            4'd6: begin
                case(cur_state)
                    ConV2 : begin
                        partial_2 <=  ifmap_c5[2] * weights[47];
                    end
                    ConV3 : begin
                        partial_2 <=  ifmap_c5[2] * weights[47];
                    end
                    default:begin
                        partial_2 <= partial_2;
                    end
                endcase
            end
            4'd7: begin
                case(cur_state)
                    ConV2 : begin
                        partial_2 <=  ifmap_c6[2] * weights[56];
                    end
                    ConV3 : begin
                        partial_2 <=  ifmap_c6[2] * weights[56];
                    end
                    default:begin
                        partial_2 <= partial_2;
                    end
                endcase                  
            end
            4'd8: begin
                partial_2 <=  ifmap_c7[2] * weights[65];
            end
            4'd9: begin
                partial_2 <=  ifmap_c8[2] * weights[74];
            end
            4'd10: begin
                partial_2 <=  ifmap_c9[2] * weights[83];
            end
            4'd11: begin
                partial_2 <=  ifmap_c10[2] * weights[92];
            end
            default : begin
                partial_2 <= partial_2;
            end
        endcase
    end
    else begin
        partial_2 = partial_2;
    end
end

// multiplier 3
always@(negedge clk) begin
    if(read_stage > start_right_moving) begin
        case(ifmap_channel_counter)
            4'd0: begin
                case(cur_state)
                    ConV1:begin
                        partial_3 <= ifmap_c0[50] * weights[3];
                    end
                    ConV2 : begin
                        partial_3 <= ifmap_c7[24] * weights[66];
                    end
                    ConV3 : begin
                        partial_3 <= ifmap_c11[22] * weights[102];
                    end
                    default : begin
                        partial_3 <= partial_3;
                    end
                endcase                                       
            end
            4'd1: begin
                case(cur_state)
                    ConV2 : begin
                        partial_3 <= ifmap_c0[24] * weights[3]; 
                    end
                    ConV3 : begin
                        partial_3 <=  ifmap_c0[22] * weights[3];
                    end
                    default:begin
                        partial_3 <= partial_3;
                    end
                endcase
            end
            4'd2: begin
                case(cur_state)
                    ConV2 : begin
                        partial_3 <= ifmap_c1[24] * weights[12];
                    end
                    ConV3 : begin
                        partial_3 <= ifmap_c1[22] * weights[12];
                    end
                    default:begin
                        partial_3 <= partial_3;
                    end
                endcase
            end
            4'd3: begin
                case(cur_state)
                    ConV2 : begin
                        partial_3 <= ifmap_c2[24] * weights[21];
                    end
                    ConV3 : begin
                        partial_3 <=  ifmap_c2[22] * weights[21];
                    end
                    default:begin
                        partial_3 <= partial_3;
                    end
                endcase
             end
            4'd4: begin
                case(cur_state)
                    ConV2 : begin
                        partial_3 <= ifmap_c3[24] * weights[30];
                    end
                    ConV3 : begin
                        partial_3 <= ifmap_c3[22] * weights[30];
                    end
                    default:begin
                        partial_3 <= partial_3;
                    end
                endcase           
            end
            4'd5: begin
                case(cur_state)
                    ConV2 : begin
                        partial_3 <=  ifmap_c4[24] * weights[39];
                    end
                    ConV3 : begin
                        partial_3 <=  ifmap_c4[22] * weights[39] ;
                    end
                    default:begin
                        partial_3 <= partial_3;
                    end
                endcase  
            end
            4'd6: begin
                case(cur_state)
                    ConV2 : begin
                        partial_3 <=  ifmap_c5[24] * weights[48];
                    end
                    ConV3 : begin
                        partial_3 <=  ifmap_c5[22] * weights[48];
                    end
                    default:begin
                        partial_3 <= partial_3;
                    end
                endcase
            end
            4'd7: begin
                case(cur_state)
                    ConV2 : begin
                        partial_3 <=  ifmap_c6[24] * weights[57];
                    end
                    ConV3 : begin
                        partial_3 <=  ifmap_c6[22] * weights[57];
                    end
                    default:begin
                        partial_3 <= partial_3;
                    end
                endcase                  
            end
            4'd8: begin
                partial_3 <=  ifmap_c7[22] * weights[66];
            end
            4'd9: begin
                partial_3 <=  ifmap_c8[22] * weights[75];
            end
            4'd10: begin
                partial_3 <=  ifmap_c9[22] * weights[84];
            end
            4'd11: begin
                partial_3 <=  ifmap_c10[22] * weights[93];
            end
            default : begin
                partial_3 <= partial_3;
            end
        endcase
    end
    else begin
        partial_3 = partial_3;
    end
end

// multiplier 4
always@(negedge clk) begin
    if(read_stage > start_right_moving) begin
        case(ifmap_channel_counter)
            4'd0: begin
                case(cur_state)
                    ConV1:begin
                        partial_4 <= ifmap_c0[51] * weights[4];
                    end
                    ConV2 : begin
                        partial_4 <= ifmap_c7[25] * weights[67];
                    end
                    ConV3 : begin
                        partial_4 <= ifmap_c11[23] * weights[103];
                    end
                    default : begin
                        partial_4 <= partial_4;
                    end
                endcase                                       
            end
            4'd1: begin
                case(cur_state)
                    ConV2 : begin
                        partial_4 <= ifmap_c0[25] * weights[4]; 
                    end
                    ConV3 : begin
                        partial_4 <=  ifmap_c0[23] * weights[4];
                    end
                    default:begin
                        partial_4 <= partial_4;
                    end
                endcase
            end
            4'd2: begin
                case(cur_state)
                    ConV2 : begin
                        partial_4 <= ifmap_c1[25] * weights[13];
                    end
                    ConV3 : begin
                        partial_4 <= ifmap_c1[23] * weights[13];
                    end
                    default:begin
                        partial_4 <= partial_4;
                    end
                endcase
            end
            4'd3: begin
                case(cur_state)
                    ConV2 : begin
                        partial_4 <= ifmap_c2[25] * weights[22];
                    end
                    ConV3 : begin
                        partial_4 <=  ifmap_c2[23] * weights[22];
                    end
                    default:begin
                        partial_4 <= partial_4;
                    end
                endcase
             end
            4'd4: begin
                case(cur_state)
                    ConV2 : begin
                        partial_4 <= ifmap_c3[25] * weights[31];
                    end
                    ConV3 : begin
                        partial_4 <= ifmap_c3[23] * weights[31];
                    end
                    default:begin
                        partial_4 <= partial_4;
                    end
                endcase           
            end
            4'd5: begin
                case(cur_state)
                    ConV2 : begin
                        partial_4 <=  ifmap_c4[25] * weights[40];
                    end
                    ConV3 : begin
                        partial_4 <=  ifmap_c4[23] * weights[40] ;
                    end
                    default:begin
                        partial_4 <= partial_4;
                    end
                endcase  
            end
            4'd6: begin
                case(cur_state)
                    ConV2 : begin
                        partial_4 <=  ifmap_c5[25] * weights[49];
                    end
                    ConV3 : begin
                        partial_4 <=  ifmap_c5[23] * weights[49];
                    end
                    default:begin
                        partial_4 <= partial_4;
                    end
                endcase
            end
            4'd7: begin
                case(cur_state)
                    ConV2 : begin
                        partial_4 <=  ifmap_c6[25] * weights[58];
                    end
                    ConV3 : begin
                        partial_4 <=  ifmap_c6[23] * weights[58];
                    end
                    default:begin
                        partial_4 <= partial_4;
                    end
                endcase                  
            end
            4'd8: begin
                partial_4 <=  ifmap_c7[23] * weights[67];
            end
            4'd9: begin
                partial_4 <=  ifmap_c8[23] * weights[76];
            end
            4'd10: begin
                partial_4 <=  ifmap_c9[23] * weights[85];
            end
            4'd11: begin
                partial_4 <=  ifmap_c10[23] * weights[94];
            end
            default : begin
                partial_4 <= partial_4;
            end
        endcase
    end
    else begin
        partial_4 = partial_4;
    end
end

// multiplier 5
always@(negedge clk) begin
    if(read_stage > start_right_moving) begin
        case(ifmap_channel_counter)
            4'd0: begin
                case(cur_state)
                    ConV1:begin
                        partial_5 <= ifmap_c0[52] * weights[5];
                    end
                    ConV2 : begin
                        partial_5 <= ifmap_c7[26] * weights[68];
                    end
                    ConV3 : begin
                        partial_5 <= ifmap_c11[24] * weights[104];
                    end
                    default : begin
                        partial_5 <= partial_5;
                    end
                endcase                                       
            end
            4'd1: begin
                case(cur_state)
                    ConV2 : begin
                        partial_5 <= ifmap_c0[26] * weights[5]; 
                    end
                    ConV3 : begin
                        partial_5 <=  ifmap_c0[24] * weights[5];
                    end
                    default:begin
                        partial_5 <= partial_5;
                    end
                endcase
            end
            4'd2: begin
                case(cur_state)
                    ConV2 : begin
                        partial_5 <= ifmap_c1[26] * weights[14];
                    end
                    ConV3 : begin
                        partial_5 <= ifmap_c1[24] * weights[14];
                    end
                    default:begin
                        partial_5 <= partial_5;
                    end
                endcase
            end
            4'd3: begin
                case(cur_state)
                    ConV2 : begin
                        partial_5 <= ifmap_c2[26] * weights[23];
                    end
                    ConV3 : begin
                        partial_5 <=  ifmap_c2[24] * weights[23];
                    end
                    default:begin
                        partial_5 <= partial_5;
                    end
                endcase
             end
            4'd4: begin
                case(cur_state)
                    ConV2 : begin
                        partial_5 <= ifmap_c3[26] * weights[32];
                    end
                    ConV3 : begin
                        partial_5 <= ifmap_c3[24] * weights[32];
                    end
                    default:begin
                        partial_5 <= partial_5;
                    end
                endcase           
            end
            4'd5: begin
                case(cur_state)
                    ConV2 : begin
                        partial_5 <=  ifmap_c4[26] * weights[41];
                    end
                    ConV3 : begin
                        partial_5 <=  ifmap_c4[24] * weights[41] ;
                    end
                    default:begin
                        partial_5 <= partial_5;
                    end
                endcase  
            end
            4'd6: begin
                case(cur_state)
                    ConV2 : begin
                        partial_5 <=  ifmap_c5[26] * weights[50];
                    end
                    ConV3 : begin
                        partial_5 <=  ifmap_c5[24] * weights[50];
                    end
                    default:begin
                        partial_5 <= partial_5;
                    end
                endcase
            end
            4'd7: begin
                case(cur_state)
                    ConV2 : begin
                        partial_5 <=  ifmap_c6[26] * weights[59];
                    end
                    ConV3 : begin
                        partial_5 <=  ifmap_c6[24] * weights[59];
                    end
                    default:begin
                        partial_5 <= partial_5;
                    end
                endcase                  
            end
            4'd8: begin
                partial_5 <=  ifmap_c7[24] * weights[68];
            end
            4'd9: begin
                partial_5 <=  ifmap_c8[24] * weights[77];
            end
            4'd10: begin
                partial_5 <=  ifmap_c9[24] * weights[86];
            end
            4'd11: begin
                partial_5 <=  ifmap_c10[24] * weights[95];
            end
            default : begin
                partial_5 <= partial_5;
            end
        endcase
    end
    else begin
        partial_5 = partial_5;
    end
end

// multiplier 6
always@(negedge clk) begin
    if(read_stage > start_right_moving) begin
        case(ifmap_channel_counter)
            4'd0: begin
                case(cur_state)
                    ConV1:begin
                        partial_6 <= ifmap_c0[100] * weights[6];
                    end
                    ConV2 : begin
                        partial_6 <= ifmap_c7[48] * weights[69];
                    end
                    ConV3 : begin
                        partial_6 <= ifmap_c11[44] * weights[105];
                    end
                    default : begin
                        partial_6 <= partial_6;
                    end
                endcase                                       
            end
            4'd1: begin
                case(cur_state)
                    ConV2 : begin
                        partial_6 <= ifmap_c0[48] * weights[6]; 
                    end
                    ConV3 : begin
                        partial_6 <=  ifmap_c0[44] * weights[6];
                    end
                    default:begin
                        partial_6 <= partial_6;
                    end
                endcase
            end
            4'd2: begin
                case(cur_state)
                    ConV2 : begin
                        partial_6 <= ifmap_c1[48] * weights[15];
                    end
                    ConV3 : begin
                        partial_6 <= ifmap_c1[44] * weights[15];
                    end
                    default:begin
                        partial_6 <= partial_6;
                    end
                endcase
            end
            4'd3: begin
                case(cur_state)
                    ConV2 : begin
                        partial_6 <= ifmap_c2[48] * weights[24];
                    end
                    ConV3 : begin
                        partial_6 <=  ifmap_c2[44] * weights[24];
                    end
                    default:begin
                        partial_6 <= partial_6;
                    end
                endcase
             end
            4'd4: begin
                case(cur_state)
                    ConV2 : begin
                        partial_6 <= ifmap_c3[48] * weights[33];
                    end
                    ConV3 : begin
                        partial_6 <= ifmap_c3[44] * weights[33];
                    end
                    default:begin
                        partial_6 <= partial_6;
                    end
                endcase           
            end
            4'd5: begin
                case(cur_state)
                    ConV2 : begin
                        partial_6 <=  ifmap_c4[48] * weights[42];
                    end
                    ConV3 : begin
                        partial_6 <=  ifmap_c4[44] * weights[42] ;
                    end
                    default:begin
                        partial_6 <= partial_6;
                    end
                endcase  
            end
            4'd6: begin
                case(cur_state)
                    ConV2 : begin
                        partial_6 <=  ifmap_c5[48] * weights[51];
                    end
                    ConV3 : begin
                        partial_6 <=  ifmap_c5[44] * weights[51];
                    end
                    default:begin
                        partial_6 <= partial_6;
                    end
                endcase
            end
            4'd7: begin
                case(cur_state)
                    ConV2 : begin
                        partial_6 <=  ifmap_c6[48] * weights[60];
                    end
                    ConV3 : begin
                        partial_6 <=  ifmap_c6[44] * weights[60];
                    end
                    default:begin
                        partial_6 <= partial_6;
                    end
                endcase                  
            end
            4'd8: begin
                partial_6 <=  ifmap_c7[44] * weights[69];
            end
            4'd9: begin
                partial_6 <=  ifmap_c8[44] * weights[78];
            end
            4'd10: begin
                partial_6 <=  ifmap_c9[44] * weights[87];
            end
            4'd11: begin
                partial_6 <=  ifmap_c10[44] * weights[96];
            end
            default : begin
                partial_6 <= partial_6;
            end
        endcase
    end
    else begin
        partial_6 = partial_6;
    end
end

// multiplier 7
always@(negedge clk) begin
    if(read_stage > start_right_moving) begin
        case(ifmap_channel_counter)
            4'd0: begin
                case(cur_state)
                    ConV1:begin
                        partial_7 <= ifmap_c0[101] * weights[7];
                    end
                    ConV2 : begin
                        partial_7 <= ifmap_c7[49] * weights[70];
                    end
                    ConV3 : begin
                        partial_7 <= ifmap_c11[45] * weights[106];
                    end
                    default : begin
                        partial_7 <= partial_7;
                    end
                endcase                                       
            end
            4'd1: begin
                case(cur_state)
                    ConV2 : begin
                        partial_7 <= ifmap_c0[49] * weights[7]; 
                    end
                    ConV3 : begin
                        partial_7 <=  ifmap_c0[45] * weights[7];
                    end
                    default:begin
                        partial_7 <= partial_7;
                    end
                endcase
            end
            4'd2: begin
                case(cur_state)
                    ConV2 : begin
                        partial_7 <= ifmap_c1[49] * weights[16];
                    end
                    ConV3 : begin
                        partial_7 <= ifmap_c1[45] * weights[16];
                    end
                    default:begin
                        partial_7 <= partial_7;
                    end
                endcase
            end
            4'd3: begin
                case(cur_state)
                    ConV2 : begin
                        partial_7 <= ifmap_c2[49] * weights[25];
                    end
                    ConV3 : begin
                        partial_7 <=  ifmap_c2[45] * weights[25];
                    end
                    default:begin
                        partial_7 <= partial_7;
                    end
                endcase
             end
            4'd4: begin
                case(cur_state)
                    ConV2 : begin
                        partial_7 <= ifmap_c3[49] * weights[34];
                    end
                    ConV3 : begin
                        partial_7 <= ifmap_c3[45] * weights[34];
                    end
                    default:begin
                        partial_7 <= partial_7;
                    end
                endcase           
            end
            4'd5: begin
                case(cur_state)
                    ConV2 : begin
                        partial_7 <=  ifmap_c4[49] * weights[43];
                    end
                    ConV3 : begin
                        partial_7 <=  ifmap_c4[45] * weights[43] ;
                    end
                    default:begin
                        partial_7 <= partial_7;
                    end
                endcase  
            end
            4'd6: begin
                case(cur_state)
                    ConV2 : begin
                        partial_7 <=  ifmap_c5[49] * weights[52];
                    end
                    ConV3 : begin
                        partial_7 <=  ifmap_c5[45] * weights[52];
                    end
                    default:begin
                        partial_7 <= partial_7;
                    end
                endcase
            end
            4'd7: begin
                case(cur_state)
                    ConV2 : begin
                        partial_7 <=  ifmap_c6[49] * weights[61];
                    end
                    ConV3 : begin
                        partial_7 <=  ifmap_c6[45] * weights[61];
                    end
                    default:begin
                        partial_7 <= partial_7;
                    end
                endcase                  
            end
            4'd8: begin
                partial_7 <=  ifmap_c7[45] * weights[70];
            end
            4'd9: begin
                partial_7 <=  ifmap_c8[45] * weights[79];
            end
            4'd10: begin
                partial_7 <=  ifmap_c9[45] * weights[88];
            end
            4'd11: begin
                partial_7 <=  ifmap_c10[45] * weights[97];
            end
            default : begin
                partial_7 <= partial_7;
            end
        endcase
    end
    else begin
        partial_7 = partial_7;
    end
end

// multiplier 8
always@(negedge clk) begin
    if(read_stage > start_right_moving) begin
        case(ifmap_channel_counter)
            4'd0: begin
                case(cur_state)
                    ConV1:begin
                        partial_8 <= ifmap_c0[102] * weights[8];
                    end
                    ConV2 : begin
                        partial_8 <= ifmap_c7[50] * weights[71];
                    end
                    ConV3 : begin
                        partial_8 <= ifmap_c11[46] * weights[107];
                    end
                    default : begin
                        partial_8 <= partial_8;
                    end
                endcase                                       
            end
            4'd1: begin
                case(cur_state)
                    ConV2 : begin
                        partial_8 <= ifmap_c0[50] * weights[8]; 
                    end
                    ConV3 : begin
                        partial_8 <=  ifmap_c0[46] * weights[8];
                    end
                    default:begin
                        partial_8 <= partial_8;
                    end
                endcase
            end
            4'd2: begin
                case(cur_state)
                    ConV2 : begin
                        partial_8 <= ifmap_c1[50] * weights[17];
                    end
                    ConV3 : begin
                        partial_8 <= ifmap_c1[46] * weights[17];
                    end
                    default:begin
                        partial_8 <= partial_8;
                    end
                endcase
            end
            4'd3: begin
                case(cur_state)
                    ConV2 : begin
                        partial_8 <= ifmap_c2[50] * weights[26];
                    end
                    ConV3 : begin
                        partial_8 <=  ifmap_c2[46] * weights[26];
                    end
                    default:begin
                        partial_8 <= partial_8;
                    end
                endcase
             end
            4'd4: begin
                case(cur_state)
                    ConV2 : begin
                        partial_8 <= ifmap_c3[50] * weights[35];
                    end
                    ConV3 : begin
                        partial_8 <= ifmap_c3[46] * weights[35];
                    end
                    default:begin
                        partial_8 <= partial_8;
                    end
                endcase           
            end
            4'd5: begin
                case(cur_state)
                    ConV2 : begin
                        partial_8 <=  ifmap_c4[50] * weights[44];
                    end
                    ConV3 : begin
                        partial_8 <=  ifmap_c4[46] * weights[44] ;
                    end
                    default:begin
                        partial_8 <= partial_8;
                    end
                endcase  
            end
            4'd6: begin
                case(cur_state)
                    ConV2 : begin
                        partial_8 <=  ifmap_c5[50] * weights[53];
                    end
                    ConV3 : begin
                        partial_8 <=  ifmap_c5[46] * weights[53];
                    end
                    default:begin
                        partial_8 <= partial_8;
                    end
                endcase
            end
            4'd7: begin
                case(cur_state)
                    ConV2 : begin
                        partial_8 <=  ifmap_c6[50] * weights[62];
                    end
                    ConV3 : begin
                        partial_8 <=  ifmap_c6[46] * weights[62];
                    end
                    default:begin
                        partial_8 <= partial_8;
                    end
                endcase                  
            end
            4'd8: begin
                partial_8 <=  ifmap_c7[46] * weights[71];
            end
            4'd9: begin
                partial_8 <=  ifmap_c8[46] * weights[80];
            end
            4'd10: begin
                partial_8 <=  ifmap_c9[46] * weights[89];
            end
            4'd11: begin
                partial_8 <=  ifmap_c10[46] * weights[98];
            end
            default : begin
                partial_8 <= partial_8;
            end
        endcase
    end
    else begin
        partial_8 = partial_8;
    end
end

// getting input feature map from RAM
always@(posedge clk) begin
    if((read_stage >= 13'd0 && read_stage <= 13'd2) || cur_state == idle) begin
        ifmap_channel_counter <= 4'd0;
        channel_vector_counter <= 8'd0;
    end
    else if(read_stage >= 13'd3 && read_stage <= (start_right_moving + ifmap_c)) begin
        case(ifmap_channel_counter)
            4'd0: begin
				case(cur_state)
					ConV1 : begin
					    ifmap_c0[read_stage-13'd3] <= rom_data_ri;
						ifmap_channel_counter <= 4'd0;
					end
					ConV2, ConV3 : begin
					    ifmap_c0[channel_vector_counter] <= ram_data_ri;
						ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
					end
					default : begin
					   ifmap_channel_counter <= ifmap_channel_counter;
					end
				endcase
            end
            4'd1: begin
                ifmap_c1[channel_vector_counter] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd2: begin
                ifmap_c2[channel_vector_counter] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd3: begin
                ifmap_c3[channel_vector_counter] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd4: begin
                ifmap_c4[channel_vector_counter] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd5: begin
                ifmap_c5[channel_vector_counter] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd6: begin
                ifmap_c6[channel_vector_counter] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd7: begin
                ifmap_c7[channel_vector_counter] <= ram_data_ri;
				case(cur_state)
					ConV2 : begin
						ifmap_channel_counter <= 4'd0;
						channel_vector_counter <= channel_vector_counter + 8'd1;
					end
					ConV3 : begin
						ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
					end
					default : begin
					   ifmap_channel_counter <= ifmap_channel_counter;
					end
				endcase
            end
            4'd8: begin
                ifmap_c8[channel_vector_counter] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd9: begin
                ifmap_c9[channel_vector_counter] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd10: begin
                ifmap_c10[channel_vector_counter] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd11: begin
                ifmap_c11[channel_vector_counter] <= ram_data_ri;
                ifmap_channel_counter <= 4'd0;
                channel_vector_counter <= channel_vector_counter + 8'd1;
            end
			default : begin
				ifmap_channel_counter <= ifmap_channel_counter;
			end
        endcase
    end
    else begin
        case(ifmap_channel_counter)
            4'd0: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c0[i] <= ifmap_c0[i + 1];
                end
				case(cur_state)
					ConV1 : begin
					    ifmap_c0[enough_size] <= rom_data_ri;
						ifmap_channel_counter <= 4'd0;
					end
					ConV2, ConV3 : begin
					    ifmap_c0[enough_size] <= ram_data_ri;
						ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
					end
					default:begin
					    ifmap_channel_counter <= ifmap_channel_counter;
					end
				endcase
            end
            4'd1: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c1[i] <= ifmap_c1[i + 1];
                end
                ifmap_c1[enough_size] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd2: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c2[i] <= ifmap_c2[i + 1];
                end
                ifmap_c2[enough_size] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd3: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c3[i] <= ifmap_c3[i + 1];
                end
                ifmap_c3[enough_size] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd4: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c4[i] <= ifmap_c4[i + 1];
                end
                ifmap_c4[enough_size] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd5: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c5[i] <= ifmap_c5[i + 1];
                end
                ifmap_c5[enough_size] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd6: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c6[i] <= ifmap_c6[i + 1];
                end
                ifmap_c6[enough_size] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd7: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c7[i] <= ifmap_c7[i + 1];
                end
                ifmap_c7[enough_size] <= ram_data_ri;
                case(cur_state)
					ConV2 : begin
						ifmap_channel_counter <= 4'd0;
					end
					ConV3 : begin
						ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
					end
					default:begin
					    ifmap_channel_counter <= ifmap_channel_counter;
					end
				endcase
            end
            4'd8: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c8[i] <= ifmap_c8[i + 1];
                end
                ifmap_c8[enough_size] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd9: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c9[i] <= ifmap_c9[i + 1];
                end
                ifmap_c9[enough_size] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd10: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c10[i] <= ifmap_c10[i + 1];
                end
                ifmap_c10[enough_size] <= ram_data_ri;
                ifmap_channel_counter <= ifmap_channel_counter + 4'd1;
            end
            4'd11: begin
                for(i = 0; i < enough_size; i = i + 1) begin
                    ifmap_c11[i] <= ifmap_c11[i + 1];
                end
                ifmap_c11[enough_size] <= ram_data_ri;
                ifmap_channel_counter <= 4'd0;
            end
			default : begin
				ifmap_channel_counter <= ifmap_channel_counter;
			end
        endcase
    end
end

// getting weights from ROM
always@(posedge clk) begin
    if(cur_state !== idle) begin
        if(read_stage >= 13'd3 && read_stage <= (weighs_size + 7'd2)) begin
            weights[read_stage - 13'd3] <= rom_data_rw;
        end
        else begin
            weights[0] <= weights[0];
        end
    end
    else begin
        weights[0] <= weights[0];
    end
end

// getting other weights from ROM
always@(posedge clk) begin
    if(cur_state !== idle) begin
        case(read_stage)
            13'd3:begin
                M0 <= rom_data_row;
            end
            13'd4:begin
                Z1a2 <= rom_data_row;
            end
            13'd5:begin
                bias <= rom_data_row;
            end
            default:begin
                bias <= bias;
            end
        endcase
    end
    else begin
        bias = bias;
    end
end
endmodule