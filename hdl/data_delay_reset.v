`timescale 1ns / 1ps

// data_delay_reset.v
//
// This module generates an active-high reset for the variable loadable tap
// delay on the data bus line in the SelectIO Interface Wizard.
//

module data_delay_reset(
	input clk,                  // must be 50 MHz or lower clock
	input reset,                // start-up reset to initialize SM
	input [4:0] delay_tap,      // set tap delay from register block
	output reg delay_data_reset // active-high reset
);

parameter S1 = 1'b0; // idle
parameter S2 = 1'b1; // active-high reset

(* mark_debug = "true" *) reg state = S1;
(* mark_debug = "true" *) reg [4:0] curr_delay_tap = 5'b0;
(* mark_debug = "true" *) reg [3:0] counter = 4'b0; // 15 clk cycles max

always @ (posedge clk)
begin
	if (reset)
        begin
            delay_data_reset <= 1'b0;
            counter <= 4'b0;
            state <= S1;
        end
	else
	    begin
            case (state)
                // idle
                S1 : begin
                    if (curr_delay_tap != delay_tap) // delay tap changed!
                	    begin
                	    	delay_data_reset <= 1'b1;
                		  	state <= S2;
                	    end
                    else                             // no delay tap change
                	    begin
                	     	delay_data_reset <= 1'b0;
                		 	state <= S1;
                	    end
                end
        
                // active-high reset
                S2 : begin
                    if (counter < 4'b0100)           // high for 5 clk cycles
                    	begin
                    		delay_data_reset <= 1'b1;
                            counter <= counter + 1;
    		     	    	state <= S2;
    		     	    end
    			    else
    			    	begin
    			    		delay_data_reset <= 1'b0;
                            counter <= 4'b0;
                            curr_delay_tap <= delay_tap;
    		     	    	state <= S1;
    		     	    end
    		    end
	        endcase
        end
end


endmodule