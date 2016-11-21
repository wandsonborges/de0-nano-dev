module tb_burst_read_write_wf(/*AUTOARG*/);

  localparam CONST_ADDRESS_WIDTH = 32;          // derived parameter (using system info)
  localparam CONST_LENGTH_WIDTH = 32;           // any value from 4-32 (larger the value the slower the logic will be), LENGTH_WIDTH shouldn't be larger than ADDRESS_WIDTH and should be reduced to increase the Fmax of the master.
  localparam CONST_DATA_WIDTH = 32;             // 16, 32, 64, 128, 256, 512, 1024 are valid choices
  localparam CONST_BYTE_ENABLE_WIDTH = 4;       // derived parameter
  localparam CONST_BYTE_ENABLE_WIDTH_LOG2 = 2;  // derived parameter
  localparam CONST_BURST_COUNT = 8;         // must be a multiple of 2 between 2 and 1024, when bursting is disabled this value must be set to 1
  localparam CONST_BURST_WIDTH = 4;             // derived parameter
   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire					ctrl_busy;				// From dut of burst_read_wf.v, ...
   wire [CONST_DATA_WIDTH-1:0] ctrl_readdata;			// From dut of burst_read_wf.v
   wire					ctrl_readdatavalid;		// From dut of burst_read_wf.v
   wire 					   ctrl_start;
   wire [CONST_ADDRESS_WIDTH-1:0] master_address;		// From dut of burst_read_wf.v, ...
   wire [CONST_BURST_WIDTH-1:0] master_burstcount;	// From dut of burst_read_wf.v, ...
   wire					master_read;			// From dut of burst_read_wf.v


   wire					ctrl_writebusy;				// From dut of burst_read_wf.v, ...
   wire					ctrl_write;				// From dut_write of burst_write_wf.v
   wire [CONST_DATA_WIDTH-1:0] ctrl_writedata;		// From dut_write of burst_write_wf.v
   wire 					   ctrl_writestart;
   wire [CONST_ADDRESS_WIDTH-1:0] master_writeaddress;		// From dut of burst_read_wf.v, ...
   wire [CONST_BURST_WIDTH-1:0] master_writeburstcount;	// From dut of burst_read_wf.v, ...
   wire [CONST_BYTE_ENABLE_WIDTH-1:0] master_byteenable;// From dut_write of burst_write_wf.v
   wire					master_write;			// From dut_write of burst_write_wf.v
   wire [CONST_DATA_WIDTH-1:0] master_writedata;		// From dut_write of burst_write_wf.v
   wire [CONST_BURST_WIDTH-1:0] ctrl_address;	// From dut of burst_read_wf.v, ...
   // End of automatics


   

   /*AUTOREG*/
   reg [CONST_ADDRESS_WIDTH-1:0] ctrl_baseaddress;
   reg [CONST_BURST_WIDTH-1:0]   ctrl_burstcount;
   reg 					 clk;
   reg 					 reset;
   reg 						  master_waitrequest;
   reg 						  master_readdatavalid;
   reg [CONST_DATA_WIDTH-1:0] master_readdata;		// From dut of burst_write_wf.v

   reg [CONST_ADDRESS_WIDTH-1:0] ctrl_writebaseaddress;
   reg [CONST_BURST_WIDTH-1:0]   ctrl_writeburstcount;
   reg 						  master_writewaitrequest;
   


   assign ctrl_start = ~ctrl_busy;


   
   
   burst_read_wf dut(/*AUTOINST*/
					 // Outputs
					 .master_address	(master_address[CONST_ADDRESS_WIDTH-1:0]),
					 .master_read		(master_read),
					 .master_burstcount	(master_burstcount[CONST_BURST_WIDTH-1:0]),
					 .ctrl_busy			(ctrl_busy),
					 .ctrl_readdatavalid(ctrl_readdatavalid),
					 .ctrl_readdata		(ctrl_readdata[CONST_DATA_WIDTH-1:0]),
					 // Inputs
					 .clk				(clk),
					 .reset				(reset),
					 .master_waitrequest(master_waitrequest),
					 .master_readdatavalid(master_readdatavalid),
					 .master_readdata	(master_readdata[CONST_DATA_WIDTH-1:0]),
					 .ctrl_start		(~ctrl_writebusy), //(ctrl_start),
					 .ctrl_baseaddress	(ctrl_baseaddress[CONST_ADDRESS_WIDTH-1:0]),
					 .ctrl_address (ctrl_address),
					 .ctrl_burstcount	(ctrl_burstcount[CONST_BURST_WIDTH-1:0]));
   
  defparam dut.ADDRESS_WIDTH = CONST_ADDRESS_WIDTH;
  defparam dut.LENGTH_WIDTH = CONST_LENGTH_WIDTH;
  defparam dut.DATA_WIDTH = CONST_DATA_WIDTH;
  defparam dut.BYTE_ENABLE_WIDTH = CONST_BYTE_ENABLE_WIDTH;
  defparam dut.BYTE_ENABLE_WIDTH_LOG2 = CONST_BYTE_ENABLE_WIDTH_LOG2;
  defparam dut.BURST_COUNT = CONST_BURST_COUNT;  // FIFO latency of 2
  defparam dut.BURST_WIDTH = CONST_BURST_WIDTH;




   burst_write_wf dut_write(/*AUTOINST*/
							// Outputs
							.master_address		(master_writeaddress[CONST_ADDRESS_WIDTH-1:0]),
							.master_write		(master_write),
							.master_writedata	(master_writedata[CONST_DATA_WIDTH-1:0]),
							.master_burstcount	(master_writeburstcount[CONST_BURST_WIDTH-1:0]),
							.master_byteenable	(master_byteenable[CONST_BYTE_ENABLE_WIDTH-1:0]),
							.ctrl_busy			(ctrl_writebusy),
							// Inputs
							.clk				(clk),
							.reset				(reset),
							.master_waitrequest	(master_writewaitrequest),
							.ctrl_write			(ctrl_readdatavalid),
							.ctrl_writedata		(ctrl_readdata[CONST_DATA_WIDTH-1:0]),
							.ctrl_start			(ctrl_readdatavalid), //ctrl_start),
							.ctrl_baseaddress	(ctrl_writebaseaddress[CONST_ADDRESS_WIDTH-1:0]),
							.ctrl_address (ctrl_address),
							.ctrl_burstcount	(ctrl_writeburstcount[CONST_BURST_WIDTH-1:0]));
   
  defparam dut_write.ADDRESS_WIDTH = CONST_ADDRESS_WIDTH;
  defparam dut_write.LENGTH_WIDTH = CONST_LENGTH_WIDTH;
  defparam dut_write.DATA_WIDTH = CONST_DATA_WIDTH;
  defparam dut_write.BYTE_ENABLE_WIDTH = CONST_BYTE_ENABLE_WIDTH;
  defparam dut_write.BYTE_ENABLE_WIDTH_LOG2 = CONST_BYTE_ENABLE_WIDTH_LOG2;
  defparam dut_write.BURST_COUNT = CONST_BURST_COUNT;  // FIFO latency of 2
  defparam dut_write.BURST_WIDTH = CONST_BURST_WIDTH;
   
   
   initial begin
	  clk = 1'b0;
	  reset = 1'b1;
	  repeat(4) #10 clk = ~clk;
	  reset = 1'b0;
	  forever #10 clk = ~clk;
	  
   end
   



   initial begin
	  ctrl_writebaseaddress = 32'h38000000;
	  ctrl_writeburstcount = 8;
	  master_writewaitrequest = 1'b0;
	  
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
		end
	  else
		begin
		   master_readdatavalid <= 0;
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

   always @ ( /*AUTOSENSE*/ posedge clk) begin
   	  if (reset == 1)
   		begin
   		   master_readdata <= 0;
   		end
   	  else
   		begin
   		if (master_readdatavalid == 1)
   		  begin
   			 master_readdata <= master_readdata + 1;
   		  end
   		end
   end
   
   
endmodule // tb_burst_write_wf
