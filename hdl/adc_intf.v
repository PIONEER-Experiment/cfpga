`timescale 1ns / 1ps
`include "adc_regs.txt"

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


//*************************************************************************
// static assignments
//*************************************************************************
assign sclk = slow_clk_180;
assign sresetb = ~data_inS[2]; // active-low reset to ADS5401
assign enable = 1'b1;   	   // active-high enable to ADS5401


//*************************************************************************
// generate a low speed clock (6.25 MHz / 160 ns)
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
// synchronize state machine inputs (to the slow clock)
//*************************************************************************
reg resetS;
reg [31:0] data_inS;

always @ (posedge slow_clk)
begin
    resetS <= reset;

    if (!startup_finished)
        data_inS[31:0] <= startup_data_in[31:0]; // payload value set by startup SM
    else
        data_inS[31:0] <= data_in[31:0]; // payload value set by IPbus (as usual)
end


// ====================================================================
// startup state machine to configure default settings
// ====================================================================
parameter STARTUP_IDLE       = 3'b000;
parameter STARTUP_WAIT       = 3'b001;
parameter STARTUP_RESET_LOW  = 3'b010;
parameter STARTUP_RESET_HIGH = 3'b011;
parameter STARTUP_LOAD       = 3'b100;
parameter STARTUP_WRITE      = 3'b101;
parameter STARTUP_DONE       = 3'b110;

reg [2:0] startup_state = STARTUP_IDLE;

// the default ADC registers based on header text file values
reg [23:0] default_reg;
reg [3:0]  default_reg_sel = 4'd0;

always @ (posedge slow_clk)
begin
    case (default_reg_sel[3:0])
        4'b0000 : default_reg[23:0] = `ADC_DEF_REG00;
        4'b0001 : default_reg[23:0] = `ADC_DEF_REG01;
        4'b0010 : default_reg[23:0] = `ADC_DEF_REG02;
        4'b0011 : default_reg[23:0] = `ADC_DEF_REG03;
        4'b0100 : default_reg[23:0] = `ADC_DEF_REG0E;
        4'b0101 : default_reg[23:0] = `ADC_DEF_REG0F;
        4'b0110 : default_reg[23:0] = `ADC_DEF_REG2B;
        4'b0111 : default_reg[23:0] = `ADC_DEF_REG2C;
        4'b1000 : default_reg[23:0] = `ADC_DEF_REG37;
        4'b1001 : default_reg[23:0] = `ADC_DEF_REG38;
        4'b1010 : default_reg[23:0] = `ADC_DEF_REG3A;
        4'b1011 : default_reg[23:0] = `ADC_DEF_REG66;
        4'b1100 : default_reg[23:0] = `ADC_DEF_REG3C;
        4'b1101 : default_reg[23:0] = `ADC_DEF_REG3D;
        4'b1110 : default_reg[23:0] = `ADC_DEF_REG3E;
    endcase
end

reg [15:0] startup_cnt = 16'd0;     // counter to wait >3 ms after power up
reg [31:0] startup_data_in = 32'd0; // register value which will be written to the ADC
reg startup_finished = 1'b0;        // flag to tell other state machines that the startup procedure is finished
reg [15:0] write_cnt = 16'd0;       // counter to wait for writing process to occur after driving the access bit high

always @ (posedge slow_clk)
begin
    // no reset is allowed for startup state machine
    // this state machine will only run once, after that IPbus needs to be used for configuration

    case (startup_state)
        STARTUP_IDLE : begin
            startup_cnt[15:0] <= 16'd0;
            startup_finished <= 1'b0;

            startup_state <= STARTUP_WAIT;
        end
        
        // wait for >3 ms after power is delivered to ADC
        STARTUP_WAIT : begin
            startup_cnt[15:0] <= startup_cnt[15:0] + 1'b1;
            startup_finished <= 1'b0;

            if (startup_cnt[15])  // 32,768 slow_clk cycles
                startup_state <= STARTUP_RESET_LOW;
            else
                startup_state <= STARTUP_WAIT;
        end
        
        // drive SRESETb output LOW for >20 ns
        STARTUP_RESET_LOW : begin
            startup_data_in[31:0] <= 32'h00000004; // note: sresetb = ~startup_data_in[2]
            startup_cnt[15:0] <= startup_cnt[15:0] + 1'b1;
            startup_finished <= 1'b0;

            if (startup_cnt[2])  // 4 slow_clk cycles
                startup_state <= STARTUP_RESET_HIGH;
            else
                startup_state <= STARTUP_RESET_LOW;
        end

        // drive SRESETb output HIGH for >100 ns
        STARTUP_RESET_HIGH : begin
            startup_data_in[31:0] <= 32'h00000000; // note: sresetb = ~startup_data_in[2]
            startup_cnt[15:0] <= startup_cnt[15:0] + 1'b1;
            startup_finished <= 1'b0;

            if (startup_cnt[4])  // many slow_clk cycles
                startup_state <= STARTUP_LOAD;
            else
                startup_state <= STARTUP_RESET_HIGH;
        end

        // load new register value payload to be written to ADC
        STARTUP_LOAD : begin
            // load the new payload with 'access' = 0
            // startup_data_in = { register value and address [31:8] , unused [7:3] , sresetb [2] , read/write [1] , access [0] }
            startup_data_in[31:0] <= { default_reg[23:0], 5'b00000, 1'b0, 1'b0, 1'b0 };

            default_reg_sel[3:0] <= default_reg_sel[3:0] + 1'b1; // increment number of written registers
            startup_finished <= 1'b0;
            write_cnt[15:0] <= 16'd0;

            startup_state <= STARTUP_WRITE;
        end

        // write the register value payload to ADC
        STARTUP_WRITE : begin
            // start the CMD SM to write the payload by setting 'access' = 1
            startup_data_in[31:0] <= {startup_data_in[31:1], 1'b1};

            startup_finished <= 1'b0;
            write_cnt[15:0] <= write_cnt[15:0] + 1'b1;

            // access bit goes high =>
            //      5 slow_clks until sdenb goes low
            //      sdenb is low for 24 slow_clks
            //      should wait for at least 1 slow_clk with sdenb high
            // => 5+24+1=30 slow_clk minimum -- using 40 to be safe
            // TODO: find a good flag to signal when the register value has been written to the ADC

            if (write_cnt[15:0] != 16'd40)          // stay here if the register isn't written yet
                startup_state <= STARTUP_WRITE;
            else if (default_reg_sel[3:0] == `ADC_DEF_NUMBER) // check that we've finished writing all the registers
                startup_state <= STARTUP_DONE;
            else                                    // load the new register value to be written
                startup_state <= STARTUP_LOAD;
        end

        // stay in this state forever
        STARTUP_DONE : begin
            startup_data_in[31:0] <= startup_data_in[31:0];
            startup_finished <= 1'b1; // we're done with the setup procedure

            startup_state <= STARTUP_DONE;
        end
    endcase
end


//*************************************************************************
// dual shift register with counter, MSB wired to output of module
//  
// sreg_strobe - starts the shifting mechanism
// payload     - what will be shifted
// sreg_ready  - active high status signal
//*************************************************************************
reg sreg_strobe;
reg [23:0] sreg_in;
reg [23:0] sreg_out;
reg sreg_ready;

parameter SHIFT_IDLE     = 2'b00;
parameter SHIFT_LOAD     = 2'b01;
parameter SHIFT_SHIFTING = 2'b10;

reg [1:0] shift_state = SHIFT_IDLE;

reg [5:0] sreg_cnt = 6'b000000;
reg sreg_cnt_ena;
reg sreg_cnt_reset;

wire sreg_cnt_max;
assign sreg_cnt_max = (sreg_cnt == 6'b010110) ? 1'b1 : 1'b0;

// increment the SREG counter when the SHIFT SM is shifting
// this keeps track that the data is shifted the correct number of times
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

// load the data to be written/read when the SHIFT SM is not shifting
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

// drive SDIO line to ADC
assign sdio = sreg_out[23];

always @ (posedge slow_clk)
begin
    if (resetS)
        begin
            sreg_cnt_reset <= 1'b1;
            sreg_cnt_ena <= 1'b0;
            sreg_load <= 1'b1;
            sdenb <= 1'b1;
            sreg_ready <= 1'b1;

            shift_state <= SHIFT_IDLE;
        end
    else
        begin
            case (shift_state)
                SHIFT_IDLE : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;                    
                    sdenb <= 1'b1;
                    sreg_ready <= 1'b1;

                    if (sreg_strobe)
                        shift_state <= SHIFT_LOAD;
                    else
                        shift_state <= SHIFT_IDLE;
                end
                
                SHIFT_LOAD : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;                    
                    sdenb <= 1'b1;
                    sreg_ready <= 1'b0;

                    if (sreg_strobe)
                        shift_state <= SHIFT_LOAD;
                    else
                        shift_state <= SHIFT_SHIFTING;                
                end
                
                SHIFT_SHIFTING : begin
                    sreg_cnt_reset <= 1'b0;
                    sreg_cnt_ena <= 1'b1;
                    sreg_load <= 1'b0;
                    sdenb <= 1'b0;
                    sreg_ready <= 1'b0;

                    if (sreg_cnt_max)
                        shift_state <= SHIFT_IDLE;
                    else
                        shift_state <= SHIFT_SHIFTING;
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
//   - data_in contains control bits, address bits, and data to be written
//        [31:16] = payload[15:0]
//	         [15] = not used
//         [14:8] = addr
//          [7:3] = not used
//            [2] = active low reset to ADS5401
//            [1] = read/write, 1=read, 0=write (matches ADS5401)
//            [0] = access strobe
//   - data_out gets loaded with the results of the read
//        [31:16] = 0x0000
//         [15:0] = register data
//   - build the payload word       
//************************************************************************
parameter CMD_IDLE  = 3'b000;
parameter CMD_LOAD  = 3'b001;
parameter CMD_SHIFT = 3'b010;
parameter CMD_WAIT  = 3'b011;

reg [2:0] adc_state = CMD_IDLE;

wire access;
assign access = data_inS[0];

// 'payload' is in the SDIO required bit sequence expected by the ADC
wire [23:0] payload;
assign payload = {data_inS[1], data_inS[14:8], data_inS[31:16]};

always @ (posedge slow_clk)
begin
	if (resetS)
        begin
            sreg_strobe <= 1'b0;

            adc_state <= CMD_IDLE;
        end
	else
	    begin
            case (adc_state)
                // idle
                CMD_IDLE : begin
                	sreg_strobe <= 1'b0;

                    if (access)		             // there is new data to shift out						
                    	adc_state <= CMD_LOAD;
                    else
                    	adc_state <= CMD_IDLE;
                end
            
                // load
                CMD_LOAD : begin
                    sreg_strobe <= 1'b1;

                    if (sreg_ready)              // wait here until the shift reg starts shifting						
        		        adc_state <= CMD_SHIFT;
        		    else
        		        adc_state <= CMD_LOAD;
        		end
        		
        	    // shift
                // note: comment about waiting here is not true
                //       the timing is off so that sreg_ready is still high when it checks it
                //       therefore this state directly moves into the CMD_WAIT state without delay
                CMD_SHIFT : begin
                    sreg_strobe <= 1'b0;

                    if (sreg_ready)              // wait here until the shift reg stops shifting
                        adc_state <= CMD_WAIT;
                    else
                        adc_state <= CMD_SHIFT;
                end

        	    // wait until access is cleared
                // which shouldn't happen before the writing process it complete
                // => this isn't an issue using IPbus commands since the delay between processing commands is long
        	    CMD_WAIT : begin
                	sreg_strobe <= 1'b0;

                    if (access)		             // access strobe must be cleared						
                    	adc_state <= CMD_WAIT;
                    else
                    	adc_state <= CMD_IDLE;
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
