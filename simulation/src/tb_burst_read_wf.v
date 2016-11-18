module tb_burst_read_wf(/*AUTOARG*/);

  localparam CONST_ADDRESS_WIDTH = 32;          // derived parameter (using system info)
  localparam CONST_LENGTH_WIDTH = 32;           // any value from 4-32 (larger the value the slower the logic will be), LENGTH_WIDTH shouldn't be larger than ADDRESS_WIDTH and should be reduced to increase the Fmax of the master.
  localparam CONST_DATA_WIDTH = 32;             // 16, 32, 64, 128, 256, 512, 1024 are valid choices
  localparam CONST_BYTE_ENABLE_WIDTH = 4;       // derived parameter
  localparam CONST_BYTE_ENABLE_WIDTH_LOG2 = 2;  // derived parameter
  localparam CONST_BURST_COUNT = 8;         // must be a multiple of 2 between 2 and 1024, when bursting is disabled this value must be set to 1
  localparam CONST_BURST_WIDTH = 4;             // derived parameter
   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire					ctrl_busy;				// From dut of burst_write_wf.v
   wire [CONST_ADDRESS_WIDTH-1:0] master_address;		// From dut of burst_write_wf.v
   wire [CONST_BURST_WIDTH-1:0] master_burstcount;	// From dut of burst_write_wf.v
   wire					master_read;			// From dut of burst_write_wf.v
   // End of automatics

   wire 					   ctrl_start;

   

   /*AUTOREG*/
   reg [CONST_ADDRESS_WIDTH-1:0] ctrl_baseaddress;
   reg [CONST_BURST_WIDTH-1:0]   ctrl_burstcount;
   reg 					 clk;
   reg 					 reset;
   reg 						  master_waitrequest;
   reg 						  master_readdatavalid;
   reg [CONST_DATA_WIDTH-1:0] master_readdata;		// From dut of burst_write_wf.v
   


   assign ctrl_start = ~ctrl_busy;


   
   
   burst_read_wf dut(/*AUTOINST*/
					  // Outputs
					  .master_address	(master_address[CONST_ADDRESS_WIDTH-1:0]),
					  .master_read		(master_read),
					  .master_readdata	(master_readdata[CONST_DATA_WIDTH-1:0]),
					  .master_burstcount(master_burstcount[CONST_BURST_WIDTH-1:0]),
					  .ctrl_busy		(ctrl_busy),
					  // Inputs
					  .clk				(clk),
					  .reset			(reset),
					  .master_waitrequest(master_waitrequest),
					 .master_readdatavalid(master_readdatavalid),
					  .ctrl_start		(ctrl_start),
					  .ctrl_baseaddress	(ctrl_baseaddress[CONST_ADDRESS_WIDTH-1:0]),
					  .ctrl_burstcount	(ctrl_burstcount[CONST_BURST_WIDTH-1:0]));
   
  defparam dut.ADDRESS_WIDTH = CONST_ADDRESS_WIDTH;
  defparam dut.LENGTH_WIDTH = CONST_LENGTH_WIDTH;
  defparam dut.DATA_WIDTH = CONST_DATA_WIDTH;
  defparam dut.BYTE_ENABLE_WIDTH = CONST_BYTE_ENABLE_WIDTH;
  defparam dut.BYTE_ENABLE_WIDTH_LOG2 = CONST_BYTE_ENABLE_WIDTH_LOG2;
  defparam dut.BURST_COUNT = CONST_BURST_COUNT;  // FIFO latency of 2
  defparam dut.BURST_WIDTH = CONST_BURST_WIDTH;


   initial begin
	  clk = 1'b0;
	  reset = 1'b1;
	  repeat(4) #10 clk = ~clk;
	  reset = 1'b0;
	  forever #10 clk = ~clk;
	  
   end
   

   initial begin
	  ctrl_baseaddress = 32'h38000000;
	  ctrl_burstcount = 8;
	  master_waitrequest = 1'b0;
	  @(negedge reset);
	  @(posedge ctrl_busy);
	  master_waitrequest = 1'b1;
	  @(posedge clk);
	  master_waitrequest = 1'b0;
	  @(posedge clk);
	  master_waitrequest = 1'b1;
	  repeat(2) @(posedge clk);
	  master_waitrequest = 1'b0;
	  
end

   
   always @ (posedge master_read or posedge reset) begin
	  if (reset == 1)
		begin
		   master_readdatavalid <= 0;
		   master_readdata <= 32'h88990011;
		end
	  else
		begin
		   master_readdatavalid <= 0;
		   master_readdata <= 32'h88990011;
		   repeat(2) @(posedge clk);
		   master_readdatavalid <= 1;
		   @(posedge clk);
		   master_readdatavalid <= 0;
		   @(posedge clk);
		   master_readdatavalid <= 1;
		   repeat(7) @(posedge clk);
		   master_readdatavalid <= 0;
		end
   end
   
   
endmodule // tb_burst_write_wf
