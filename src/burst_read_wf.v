module burst_read_wf
  (
   clk,
   reset,

   master_address,
   master_read,
   master_readdata,
   master_burstcount,
   //master_byteenable,
   master_waitrequest,
   master_readdatavalid,

   ctrl_start,
   ctrl_baseaddress,
   ctrl_burstcount,
   ctrl_busy,
   ctrl_address,
   ctrl_readdatavalid,
   ctrl_readdata,
   ctrl_read
   );


  parameter ADDRESS_WIDTH = 32;          // derived parameter (using system info)
  parameter LENGTH_WIDTH = 32;           // any value from 4-32 (larger the value the slower the logic will be), LENGTH_WIDTH shouldn't be larger than ADDRESS_WIDTH and should be reduced to increase the Fmax of the master.
  parameter DATA_WIDTH = 32;             // 16, 32, 64, 128, 256, 512, 1024 are valid choices
  parameter BYTE_ENABLE_WIDTH = 4;       // derived parameter
  parameter BYTE_ENABLE_WIDTH_LOG2 = 2;  // derived parameter
  parameter BURST_COUNT = 2;         // must be a multiple of 2 between 2 and 1024, when bursting is disabled this value must be set to 1
  parameter BURST_WIDTH = 2;             // derived parameter


   localparam ST_START = 4'b0001, ST_WAITREQUEST = 4'b0010, ST_BURST = 4'b0100, ST_WAITONWRITE = 4'b1000;
   
   input clk;
   input reset;					// 

   
   output reg [ADDRESS_WIDTH-1:0] master_address;
   output reg master_read;
   //output reg 				   master_beginbursttransfer;
   output reg [BURST_WIDTH-1:0] master_burstcount;
   //output wire [BYTE_ENABLE_WIDTH-1:0] master_byteenable;
   input 	   master_waitrequest;
   input 	   master_readdatavalid;
   input [DATA_WIDTH-1:0] master_readdata;
   input [BURST_WIDTH-1:0] ctrl_address;
	   

   input 	   ctrl_start;
   input [ADDRESS_WIDTH-1:0] 	   ctrl_baseaddress;
   input [BURST_WIDTH-1:0] 		   ctrl_burstcount;
   output reg  ctrl_busy;
   output reg ctrl_readdatavalid;
   output wire [DATA_WIDTH-1:0] ctrl_readdata;
   input 						ctrl_read;
   
   



   reg [BURST_WIDTH-1:0] burstCount;
   reg [3:0] 			 state;
   reg [DATA_WIDTH-1:0] storage;
   
   

   wire 				 local_ctrl_start;
   reg [BURST_WIDTH-1:0] buffer_address;
   
   wire 				 fifo_full;
   wire 				 fifo_empty;
   wire [2:0] 			 fifo_used;


   assign local_ctrl_start = ~ctrl_busy;
   
   // always @(ctrl_busy)
   // 	 begin
   // 		if (ctrl_busy == 0)
   // 		  begin
   // 			 local_ctrl_start = 1;
   // 		  end


   
   

   always @(posedge clk or posedge reset)
	 begin
		if (reset == 1)
		  begin
				  master_address <= 0;
				  master_burstcount <= 0;
				  master_read <= 1'b0;
				  ctrl_busy <= 1'b0;
				  burstCount <= 0;
			 storage <= 0;
			 ctrl_readdatavalid <= 0;
			 
			 
			 state <= ST_START;
			 
		  end
		else
		  begin
			 case (state)
			   ST_START:
				 if (ctrl_start == 1)
				   begin
					  master_address <= 32'h39000000;
					  master_burstcount <= 8;
					  master_read <= 1'b1;

					  ctrl_busy <= 1'b1;

					  burstCount <= 0;
					  state <= ST_WAITREQUEST;
					  
				   end // if (local_ctrl_start == 1)
			   ST_WAITREQUEST:
				 if (master_waitrequest == 0)
				   begin
					  master_read <= 1'b0;
					  
					  state <= ST_BURST;
				   end
			   ST_BURST:
				 if (master_readdatavalid)
				   begin
					  //storage <= master_readdata;
					  
					   //if (burstCount == (ctrl_burstcount-1))
					   if (burstCount == 7)
						 begin
							ctrl_busy <= 1'b0;
							burstCount <= 0;
							ctrl_readdatavalid <= 1;
							
							state <= ST_WAITONWRITE;
							
						 end
					   else
						 begin
							burstCount <= burstCount + 1;
						 end
				   end // if (master_waitrequest == 0)
			   ST_WAITONWRITE:
				 if (ctrl_start == 0)
				   begin
					  ctrl_readdatavalid <= 0;
					  
					  state <= ST_START;
				   end
			   default:
				 state <= ST_START;
			   
			 endcase // case (state)
		  end
	 end		
					   
					   
   //assign ctrl_readdatavalid = master_readdatavalid;
   //assign ctrl_readdata = storage;
//master_readdata;

   always @ ( /*AUTOSENSE*/burstCount or ctrl_address or ctrl_busy) begin
	  if (ctrl_busy == 1)
		begin
		   buffer_address = burstCount;
		end
	  else
		begin
		   buffer_address = ctrl_address;
		end
	  
end
   

   // burst_read_buffer burstReadBuffer(
   // 									 // Outputs
   // 									 .q					(ctrl_readdata[31:0]),
   // 									 // Inputs
   // 									 .address			(buffer_address[2:0]),
   // 									 .clock				(clk),
   // 									 .data				(master_readdata[31:0]),
   // 									 .wren				(master_readdatavalid));
   

  scfifo master_to_st_fifo (
    .aclr   (reset),
    .clock  (clk),
    .data   (master_readdata[31:0]),
    .full   (fifo_full),
    .empty  (fifo_empty),
    .usedw  (fifo_used[2:0]),
    .q      (ctrl_readdata[31:0]),
    .rdreq  (ctrl_read),
    .wrreq  (master_readdatavalid)
  );
  defparam master_to_st_fifo.lpm_width = DATA_WIDTH;
   defparam master_to_st_fifo.lpm_numwords = 8;
     defparam master_to_st_fifo.lpm_widthu = 3;
  defparam master_to_st_fifo.lpm_showahead = "ON";
  defparam master_to_st_fifo.use_eab = "ON";
  defparam master_to_st_fifo.add_ram_output_register = "ON";  // FIFO latency of 2
  defparam master_to_st_fifo.underflow_checking = "OFF";
  defparam master_to_st_fifo.overflow_checking = "OFF";

				  
endmodule // burst_write_wf



   
