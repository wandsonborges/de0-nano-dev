module burst_write_wf
  (
   clk,
   reset,

   master_address,
   master_write,
   master_writedata,
   //master_beginbursttransfer,
   master_burstcount,
   master_byteenable,
   master_waitrequest,

   ctrl_start,
   ctrl_baseaddress,
   ctrl_burstcount,
   ctrl_busy,
   ctrl_address,
   ctrl_write,
   ctrl_writedata,
   ctrl_read
   );


  parameter ADDRESS_WIDTH = 32;          // derived parameter (using system info)
  parameter LENGTH_WIDTH = 32;           // any value from 4-32 (larger the value the slower the logic will be), LENGTH_WIDTH shouldn't be larger than ADDRESS_WIDTH and should be reduced to increase the Fmax of the master.
  parameter DATA_WIDTH = 32;             // 16, 32, 64, 128, 256, 512, 1024 are valid choices
  parameter BYTE_ENABLE_WIDTH = 4;       // derived parameter
  parameter BYTE_ENABLE_WIDTH_LOG2 = 2;  // derived parameter
  parameter BURST_COUNT = 2;         // must be a multiple of 2 between 2 and 1024, when bursting is disabled this value must be set to 1
  parameter BURST_WIDTH = 2;             // derived parameter


   input clk;
   input reset;					// 

   
   output reg [ADDRESS_WIDTH-1:0] master_address;
   output reg master_write;
   output wire [DATA_WIDTH-1:0] master_writedata;
   //output reg 				   master_beginbursttransfer;
   output reg [BURST_WIDTH-1:0] master_burstcount;
   output wire [BYTE_ENABLE_WIDTH-1:0] master_byteenable;
   input 	   master_waitrequest;

   input 	   ctrl_start;
   input [ADDRESS_WIDTH-1:0] 	   ctrl_baseaddress;
   input [BURST_WIDTH-1:0] 		   ctrl_burstcount;
   output reg  ctrl_busy;
   input ctrl_write;
   input [DATA_WIDTH-1:0] ctrl_writedata;
   output wire [BURST_WIDTH-1:0] ctrl_address;
   output wire 					 ctrl_read;
   
   



   reg [BURST_WIDTH-1:0] burstCount;

   wire 				 local_ctrl_start;
   


   assign local_ctrl_start = ~ctrl_busy;
   
   
   

   always @(posedge clk or posedge reset)
	 begin
		if (reset == 1)
		  begin
			 master_address <= 0;
			 master_burstcount <= 0;
			 master_write <= 1'b0;
			 //master_writedata <= 0;
			 ctrl_busy <= 1'b0;
			 burstCount <= 0;
			 //ctrl_writedata;
			 master_write <= 0;
			 //ctrl_write;
		  end
		else
		  begin
			 //master_writedata <= ctrl_writedata;
			 //master_write <= ctrl_write;

			 //if (ctrl_busy == 0 && ctrl_write == 1)
			 if (ctrl_start == 1 && ctrl_busy == 0)
			   begin
				  master_address <= ctrl_baseaddress;
				  master_burstcount <= ctrl_burstcount;
				  master_write <= 1'b1;
				  //master_writedata <= 19;
				  //32'h556699bb;
				  //0;

				  ctrl_busy <= 1'b1;

				  burstCount <= 0;
				  
			   end
			 else
			   begin
				  if (ctrl_busy == 1)
					begin
					   if (master_waitrequest == 0)
						 begin
							if (burstCount == (ctrl_burstcount-1))
							  begin
								 master_write <= 1'b0;
								 ctrl_busy <= 1'b0;
								 burstCount <= 0;
							  end
							else
							  begin
								 burstCount <= burstCount + 1;
							  end
						 end // if (master_waitrequest == 0)
					end // if (ctrl_busy == 1)
			   end
		  end
	 end		
   
   

   assign master_writedata = ctrl_writedata;
   assign master_byteenable = 4'b1111;
   assign ctrl_address = burstCount;
   assign ctrl_read = master_write && ~master_waitrequest;
   

   
   
				  
endmodule // burst_write_wf



   
