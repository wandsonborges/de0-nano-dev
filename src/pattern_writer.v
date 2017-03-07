module pattern_writer
  (
   clk,
   reset,

   master_address,
   master_write,
   master_writedata,
   //master_beginbursttransfer,
   master_burstcount,
   master_byteenable,
   master_waitrequest

   //ctrl_start,
   //ctrl_baseaddress,
   //ctrl_burstcount,
   //ctrl_busy,
   //ctrl_address,
   //ctrl_write,
   //ctrl_writedata,
   //ctrl_read
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
   output reg [DATA_WIDTH-1:0] master_writedata;
   //output reg 				   master_beginbursttransfer;
   output reg [BURST_WIDTH-1:0] master_burstcount;
   output wire [BYTE_ENABLE_WIDTH-1:0] master_byteenable;
   input 	   master_waitrequest;

   // input 	   ctrl_start;
   // input [ADDRESS_WIDTH-1:0] 	   ctrl_baseaddress;
   // input [BURST_WIDTH-1:0] 		   ctrl_burstcount;
   // output reg  ctrl_busy;
   // input ctrl_write;
   // input [DATA_WIDTH-1:0] ctrl_writedata;
   // output wire [BURST_WIDTH-1:0] ctrl_address;
   // output wire 					 ctrl_read;
   
   



   reg [BURST_WIDTH-1:0] burstCount;
   integer 			 counter;
   reg [31:0] 		 incrementer;
   integer 			 pxlCounter;
			 
   
   
   wire 				 local_ctrl_start;
   


   //assign local_ctrl_start = ~ctrl_busy;
   
   
   

   always @(posedge clk or posedge reset)
	 begin
		if (reset == 1)
		  begin
			 master_address <= 32'h38000000;
			 master_burstcount <= 8;
			 master_write <= 1'b0;
			 //master_writedata <= 0;
			 //ctrl_busy <= 1'b0;
			 burstCount <= 0;
			 //ctrl_writedata;
			 master_write <= 0;
			 //ctrl_write;
		     master_writedata <= 0;
		     counter <= 0;
		     incrementer <= 32'h01020304;
			 pxlCounter <= 0;
			 
		  end
		else
		  begin
		     if (counter == 65536)
		       begin
				  master_address <= 32'h38000000;
				  master_burstcount <= 8;
				  burstCount <= 0;
				  master_writedata <= 32'h00010203;
				  counter <= 0;
				  incrementer <= 32'h01020304;
				  pxlCounter <= 0;
				  
		       end
		     else
		       begin
				  if (burstCount == 0)
					begin
					   master_write <= 1'b1;
					   burstCount <= 1;
					   
					end
				  else 
					begin
					   
					   // if (ctrl_busy == 1)
					   // 	begin
					   if (master_waitrequest == 0)
						 begin
							if (burstCount == 8)
							  begin
								 master_write <= 1'b0;
								 //ctrl_busy <= 1'b0;
								 burstCount <= 0;
								 counter <= counter + 1;
								 master_address <= master_address + 8*4;
								 
							  end
							else
							  begin
								 burstCount <= burstCount + 1;
							  end // else: !if(burstCount == 8)

							pxlCounter <= pxlCounter + 1;

							if (pxlCounter == 31)
							  begin
								 pxlCounter <= 0;
								 
								 master_writedata <= incrementer;
								 if (incrementer == 32'h7c7d7e7f)
								   incrementer <= 32'h7d7e7f00;
								 else if (incrementer == 32'h7d7e7f00)
								   incrementer <= 32'h7e7f0001;
								 else if (incrementer == 32'h7e7f0001)
								   incrementer <= 32'h7f000102;
								 else if (incrementer == 32'h7f000102)
								   incrementer <= 32'h00010203;
								 else
								   incrementer <= incrementer + 32'h01010101;
							  end // if (pxlCounter == 127)
							else
							  begin
								 if (master_writedata == 32'h797a7b7c)
								   master_writedata <= 32'h7d7e7f00;
								 else if (master_writedata == 32'h7a7b7c7d)
								   master_writedata <= 32'h7e7f0001;
								 else if (master_writedata == 32'h7b7c7d7e)
								   master_writedata <= 32'h7f000102;
								 else if (master_writedata == 32'h7c7d7e7f)
								   master_writedata <= 32'h00010203;
								 else if (master_writedata == 32'h7d7e7f00)
								   master_writedata <= 32'h01020304;
								 else if (master_writedata == 32'h7e7f0001)
								   master_writedata <= 32'h02030405;
								 else if (master_writedata == 32'h7f000102)
								   master_writedata <= 32'h03040506;
								 
								 else
								   master_writedata <= master_writedata+32'h04040404;
							  end
						 end // if (master_waitrequest == 0)
					   //end // if (ctrl_busy == 1)
					end
		       end // else: !if(counter == 65536)
		  end
	 end		
   
   

 //ctrl_writedata;
   assign master_byteenable = 4'b1111;
   //assign ctrl_address = burstCount;
   //assign ctrl_read = master_write && ~master_waitrequest;
   

   
   
				  
endmodule // burst_write_wf



   
