`timescale 1ns / 1ps

module adc_intf(
    input clk,
    input reset,
    input [31:0] data_in,
    output reg [31:0] data_out,
    output sclk,
    output sdio,
    input sdi,
    output reg sdenb,
    output sresetb,
    output enable,
    output [7:0] debug 
);

reg resetS;

//*************************************************************************
// static assignments
//*************************************************************************
assign sclk = slow_clk_180;
assign sresetb = data_inS[2];  	//active low reset to ads5401
assign enable = 1'b1;   	//active high enable to ads5401

//*************************************************************************
// synchronize state machine inputs
//*************************************************************************
reg [31:0] data_inS;
reg sdiS;
always @ (posedge slow_clk)
begin
    resetS <= reset;
    data_inS[31:0] <= data_in[31:0];
    sdiS <= sdi;
end

//*************************************************************************
// generate a low speed clock
//*************************************************************************
reg [2:0] clk_cnt;
wire slow_clk;
wire slow_clk_180;

always @ (posedge clk)
begin
	clk_cnt[2:0] <= clk_cnt[2:0] + 1'b1;
end	

assign slow_clk = clk_cnt[2];
assign slow_clk_180 = !slow_clk;


//*************************************************************************
// dual shift register with counter, MSB wired to output of module
//  
// sreg_strobe - starts the shifting mechanism
// payload - what will be shifted
// sreg_ready - active high status signal
//*************************************************************************
reg sreg_strobe;
reg [23:0] sreg_in;
reg [23:0] sreg_out;
wire [23:0] sreg_payload;
//reg [5:0] sreg_cnt = 6'b100000;
reg sreg_ready;
parameter IDLE = 2'b00;
parameter LOAD = 2'b01;
parameter SHIFTING = 2'b10;

reg [1:0] shift_state = IDLE;

reg [5:0] sreg_cnt = 6'b000000;
reg sreg_cnt_ena;
reg sreg_cnt_reset;

wire sreg_cnt_max;
assign sreg_cnt_max = (sreg_cnt == 6'b010110) ? 1'b1 : 1'b0;

always @ (posedge slow_clk)
begin
    if (sreg_cnt_reset)
        sreg_cnt[5:0] <= 6'b000000;
    else if (sreg_cnt_ena)
        sreg_cnt[5:0] <= sreg_cnt[5:0] + 6'b000001; 
    else
        sreg_cnt[5:0] <= sreg_cnt[5:0];
end

reg sreg_load;

always @ (posedge slow_clk)
begin
	if (sreg_load)
		begin
			sreg_out[23:0] <= payload[23:0];
			sreg_in[23:0] <= sreg_in[23:0];
		end
	else
		begin
			sreg_out[23:0] <= {sreg_out[22:0],1'b0};
			sreg_in[23:0] <= {sreg_in[22:0],sdi};
		end		
end

assign sdio = sreg_out[23];

always @ (posedge slow_clk)
begin
    if (resetS)
        begin
            sreg_load <= 1'b1;
            sreg_cnt_reset <= 1'b1;
            sreg_cnt_ena <= 1'b0;
            sdenb <= 1'b1;
            sreg_ready <= 1'b1;
            shift_state <= IDLE;
        end
    else
        begin
            case (shift_state)
                IDLE : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;                    
                    sdenb <= 1'b1;
                    sreg_ready <= 1'b1;
                    if (sreg_strobe)
                        shift_state <= LOAD;
                    else
                        shift_state <= IDLE;
                end
                
                LOAD : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;                    
                    sdenb <= 1'b1;
                    sreg_ready <= 1'b0;
                    if (sreg_strobe)
                        shift_state <= LOAD;
                    else
                        shift_state <= SHIFTING;                
                end
                
                SHIFTING : begin
                    sreg_cnt_reset <= 1'b0;
                    sreg_cnt_ena <= 1'b1;
                    sreg_load <= 1'b0;
                    sdenb <= 1'b0;
                    sreg_ready <= 1'b0;
                    if (sreg_cnt_max)
                        shift_state <= IDLE;
                    else
                        shift_state <= SHIFTING;
                end
            endcase
        end                
end


//*************************************************************************
// latch to offload the shift register
//*************************************************************************
always @ (posedge clk)
begin
	if (sreg_ready)
		data_out[31:0] <= {8'b00000000,sreg_in[23:0]};
	else
		data_out[31:0] <= data_out[31:0];
end	



//*************************************************************************
// command state machine
//   - controls the shift register to read and write
//   - data_in contains control bits, address bits and data to be written
//        [31:16] = payload[15:0]
//	     [15] = not used
//         [14:8] = addr
//          [7:3] = not used
//            [2] = active low reset to ads5401
//            [1] = Read/Write, 1=Read, 0=Write (matches ADS5401)
//            [0] = Access strobe
//   - data_out gets loaded with the results of the read
//        [31:16] = 0x0000
//         [15:0] =  register data
//
//   - build the payload word       
//************************************************************************
parameter S1 = 3'b000;
parameter S2 = 3'b001;
parameter S3 = 3'b010;
parameter S4 = 3'b011;
parameter S5 = 3'b100;

reg [2:0] adc_state = S1;

wire [23:0] payload;

wire access;
assign access = data_inS[0];

wire read_write;
assign read_write = data_inS[1];

assign payload = {read_write, data_inS[14:8],data_inS[31:16]};

always @ (posedge slow_clk)
begin
	if (resetS)
        begin
            sreg_strobe <= 1'b0;
            adc_state <= S1;
        end
	else
	   begin
        case (adc_state)
            // idle
            S1 : begin
            	sreg_strobe <= 1'b0;
                if (access)		     // there is new data to shift out						
                	adc_state <= S2;
                else
                	adc_state <= S1;
                end
        
            // load
            S2 : begin
                sreg_strobe <= 1'b1;
                if (sreg_ready)              // wait here until the shift reg starts shifting						
    		     adc_state <= S3;
    		else
    		     adc_state <= S2;
    		end
    		
    	    // shift
            S3 : begin
                sreg_strobe <= 1'b0;
                if (sreg_ready)             // wait here until the shift reg stops shifting
                    adc_state <= S4;
                else
                    adc_state <= S1;
            end

	    //wait until access is cleared
	    S4 : begin
            	sreg_strobe <= 1'b0;
                if (access)		     // access strobe must be cleared						
                	adc_state <= S4;
                else
                	adc_state <= S1;
        	end        
	endcase
        end
end


//*************************************************************************
// debug assignments
//*************************************************************************
assign debug[7] = clk;
assign debug[6] = slow_clk;
assign debug[5] = sreg_strobe;
assign debug[4] = access;
assign debug[3] = slow_clk_180;
assign debug[2] = sdenb;
assign debug[1] = sreg_out[23];
assign debug[0] = sdi; 

endmodule
