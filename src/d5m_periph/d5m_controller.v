module d5m_controller_v (
    clk,
    sys_clk,			 
    rst_n,  
    start,       
    frame_valid, 
    line_valid,  
    data_in,     
    sclk,        
    sdata,
    ready,
    rst_sensor,  
    trigger,     
    data_valid,  
    data_out,    
    startofpacket, 
    endofpacket
		       );
   
   input clk;
   input sys_clk;   
   input rst_n;
   input ready;   
   input start;
   input frame_valid;
   input line_valid;
   input [7:0] data_in;     
   output      sclk;
   inout      sdata;
   output rst_sensor;
   output trigger;
   output data_valid;
   output [7:0] data_out;
   output reg startofpacket;
   output reg endofpacket;

   reg 	  line_valid_s;
   reg [7:0] data_out_s;
   reg [7:0] data_out_pattern;

   reg 	     ff_frame_valid, frame_valid_sync, frame_valid_f;
   reg 	     ff_line_valid;
   reg 	     line_valid_sync, line_valid_f;
   reg [7:0] data_in_f, data_in_sync;
   reg [31:0] pxl_counter;

   
   localparam st_idle = 0;
   localparam st_fot = 1;
   localparam st_valid_data = 2;

   localparam COLS = 2592; //800;
   localparam LINES = 1944; //480;
   
   reg [1:0]  state;
   
   Reset_Delay u0(sys_clk,rst_n,rst0,rst_sensor,rst2,rst3,rst4);
   I2C_CCD_Config u1 (				sys_clk,
						rst2,
						iMIRROR_SW,
						iEXPOSURE_ADJ,
						iEXPOSURE_DEC_p,
						//	I2C Side
						sclk,
						sdata
						);
   

   
   always@(posedge clk or negedge rst_n)
     begin
	if (!rst_n)
	  begin
	     state <= st_idle;
	     startofpacket <= 0;
	     endofpacket <= 0;
	     ff_frame_valid <= 0;
	     ff_line_valid <= 0;
	     pxl_counter <= 0;	     
	  end	
	else
	  begin
	     ff_frame_valid <= frame_valid_sync;
	     ff_line_valid <= line_valid_sync;	     
	     case(state)
	       st_idle: begin
		  endofpacket <= 0;
		  if (frame_valid_sync == 1 & ff_frame_valid == 0)		 
		    begin
		       if (line_valid_sync == 1 & ff_line_valid == 0)		      
			 begin
			    state <= st_valid_data;
			    startofpacket <= 1;
			 end
		       else
			 state <= st_fot;
		    end // if (frame_valid == 1 & ff_frame_valid == 0)		  
		  else
		    state <= st_idle;
	       end // case: st_idle	       
	     

	       st_fot: begin		  
		  if(ff_line_valid == 0 &  line_valid_sync == 1)
		    begin
		       state <= st_valid_data;
		       startofpacket <= 1;
		    end		  
		  else
		    state <= st_fot;
	       end	
	
	       
	

	       st_valid_data: begin
		  startofpacket <= 0;
		  if (pxl_counter == COLS*LINES-1)
		    begin
		       pxl_counter <= 0;
		       state <= st_idle;
		       endofpacket <= 0;
		    end
		  else 
		    begin
		       if (line_valid_sync == 1)
			 begin
			    if (pxl_counter == COLS*LINES-2)
			      begin
				 endofpacket <= 1;
				 state <= st_valid_data;
				 pxl_counter <= pxl_counter + 1;
			      end
			    else
			      begin
				 pxl_counter <= pxl_counter + 1;
				 state <= st_valid_data;
				 endofpacket <= 0;
			      end // else: !if(pxl_counter == COLS*LINES-2)
			 end // if (line_valid == 1)
		    end // else: !if(pxl_counter == COLS*LINES-1)
	       end // case: st_valid_data
	     endcase // case (state)	     
	     end // else: !if(!rst_n)
     end // always@ (posedge clk or negedge rst_n)
   
   
   
   
   


   always@(posedge clk or negedge rst_n)
     begin
	if(!rst_n)
	  begin
	     data_out_s <= 0;
	     line_valid_s <= 0;
	  end
	else
	  begin
	     data_out_s <= data_in_sync;
	     line_valid_s <= line_valid_sync;
	     if (line_valid_s == 1 & frame_valid_sync == 1)
	       begin
		  data_out_pattern <= data_out_pattern + 1;
	       end
             else
	       begin
		  data_out_pattern <= 0;
	       end	     	     
	  end
     end // always@ (posedge clk or negedge rst_n)


  always@(posedge clk)
    begin
       frame_valid_f <= frame_valid;
       frame_valid_sync <= frame_valid_f;

       line_valid_f <= line_valid;
       line_valid_sync <= line_valid_f;

       data_in_f <= data_in;
       data_in_sync <= data_in_f;
    end // always@ (posedge clk)
   
   assign data_out = data_out_s;
 //data_out_pattern;
 //data_out_s;   
   assign data_valid = (state == st_valid_data) & (line_valid_s == 1) & (frame_valid_sync == 1);
   
   assign trigger = 1;
		    
endmodule
