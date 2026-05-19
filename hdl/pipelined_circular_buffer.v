`timescale 1ns / 1ps
// Acquisition controller for ADC data

module pipelined_circular_buffer (
    // writing inputs
    input adc_clk,                   // 400 MHz ADC clock used by the FIFO
    input cbuf_wr_en,                // enable writing
    input [15:0] circ_buf_wr_addr,   // write address
    input  [1:0] circ_buf_wr_dat,    // the 2 bits of data to be stored in this circular buffer
    // reading input / output
    input [15:0] circ_buf_rd_addr,   // read address
    output [1:0] circ_buf_rd_dat     // the 2 bits of data to be output
);

// insert pipeline registers before all the write information / control
reg [15:0] write_address_pipline, read_address_pipline;
wire [1:0] read_data;
reg  [1:0] write_data_pipeline,   read_data_pipeline;
reg        write_enable_pipeline;
always @ (posedge adc_clk) begin
   // writing to buffer
   write_address_pipline[15:0] <= circ_buf_wr_addr[15:0];
   write_data_pipeline[1:0]    <= circ_buf_wr_dat[1:0];
   write_enable_pipeline       <= cbuf_wr_en;
   // reading from buffer
   read_address_pipline[15:0]  <= circ_buf_rd_addr[15:0];
   read_data_pipeline[1:0]   <= read_data[1:0];
end
assign circ_buf_rd_dat[1:0] = read_data_pipeline[1:0];

circular_buffer_small circular_buffer_small (
    .clka(adc_clk),                      // 400 MHz ADC DDR clock
    .wea(write_enable_pipeline),         // enable writing
    .addra(write_address_pipline[15:0]), // write address
    // for debugging, apply the 1st two bits of the address to the data port
    .dina(write_data_pipeline[1:0]),     // 26-bit wide input data
    //.dina(write_address_pipline[1:0]), // address used to create the 26-bit wide input data
    .clkb(adc_clk),                      // 400 MHz ADC DDR clock
    .addrb(read_address_pipline[15:0]),  // read address
    .doutb(read_data[1:0])      // 2-bit wide output data
);

endmodule
