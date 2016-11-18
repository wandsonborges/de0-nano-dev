module tb_burst_write_wf(/*AUTOARG*/);

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
   wire [CONST_BYTE_ENABLE_WIDTH-1:0] master_byteenable;// From dut of burst_write_wf.v
   wire					master_write;			// From dut of burst_write_wf.v
   wire [CONST_DATA_WIDTH-1:0] master_writedata;		// From dut of burst_write_wf.v
   // End of automatics

   wire 					   ctrl_start;
   wire [CONST_ADDRESS_WIDTH-1:0] ctrl_baseaddress;
   wire [CONST_BURST_WIDTH-1:0]   ctrl_burstcount;

   wire 						  master_waitrequest;
   

   /*AUTOREG*/
   reg 					 clk;
   reg 					 reset;



   assign ctr_start = 1'b1;
   assign ctr_baseaddress = 32'h38000000;
   assign ctr_burstcount = 8;

   assign master_waitrequest = 1'b0;
   
   
   burst_write_wf dut(/*AUTOINST*/
					  // Outputs
					  .master_address	(master_address[CONST_ADDRESS_WIDTH-1:0]),
					  .master_write		(master_write),
					  .master_writedata	(master_writedata[CONST_DATA_WIDTH-1:0]),
					  .master_burstcount(master_burstcount[CONST_BURST_WIDTH-1:0]),
					  .master_byteenable(master_byteenable[CONST_BYTE_ENABLE_WIDTH-1:0]),
					  .ctrl_busy		(ctrl_busy),
					  // Inputs
					  .clk				(clk),
					  .reset			(reset),
					  .master_waitrequest(master_waitrequest),
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
   

   
endmodule // tb_burst_write_wf
