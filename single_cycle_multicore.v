`define WORD    [15:0]
`define INST    [15:0]
`define OP      [5:0]
`define TYPE    [1:0]
`define REG     [3:0]
`define REGSIZE [15:0]
`define MEMSIZE [65535:0]
`define UPTR    [3:0]
`define USIZE   [15:0]

// instruction fields
`define IOPLEN  [15]
`define IL_OP   [15:10]
`define IL_TYPE [9:8]
`define IL_DEST [7:4]
`define IL_SRC  [3:0]
`define IL_SRCS [3]
`define IS_OP   [15:12]
`define IS_SRCH [11:8]
`define IS_DEST [7:4]
`define IS_SRCL [3:0]
`define IS_SRCS [11]

// op components
`define OP_PUSHES [2]
`define OP_LEN    [5]
`define OP_GROUP  [5:3]

// op codes
`define OPxhi  6'b000000 // First 4 only have the high 4 bits as real op code
`define OPlhi  6'b000100
`define OPxlo  6'b001000
`define OPllo  6'b001100 // The rest are the full op code
`define OPadd  6'b100000
`define OPsub  6'b100001
`define OPxor  6'b100010
`define OProl  6'b100011
`define OPshr  6'b100100
`define OPor   6'b100101
`define OPand  6'b100110
`define OPdup  6'b100111
`define OPbz   6'b101000 // same as... jz
`define OPbnz  6'b101001 //  jnz
`define OPbn   6'b101010 //  jn
`define OPbnn  6'b101011 //  jnn
`define OPjerr 6'b110000
`define OPfail 6'b110001
`define OPex   6'b110010
`define OPcom  6'b110011
`define OPland 6'b110100
`define OPsys  6'b111000
`define OPnop  6'b111010 // internal, not part of AXA

`define NOP {`OPnop, 10'b0}

`define ILTypeImm 2'b00
`define ILTypeReg 2'b01
`define ILTypeMem 2'b10
`define ILTypeUnd 2'b11

// slow memory definitions
`define LINEADDR [15:0]
`define LINE [15:0]
`define LINES [65535:0]
`define MEMDELAY 4

//Mask identifier - Added by Praneeth
`define SIGILL 4'b0001
`define SIGTMV 4'b0010
`define SIGCHK 4'b0100
`define SIGLEX 4'b1000

// cache definitions
`define CLINE [33:0]
`define CLINES [7:0]
`define DATABITS [15:0]
`define ADDRBITS [31:16]
`define DIRTYBIT [32]
`define TIMEBIT [33]
`define CPTR [2:0]

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
	$dumpfile;
	$dumpvars(0, PE);
	#10 reset = 1;
	#10 clk = 1;
	#10 clk = 0;
	#10 reset = 0;
	while (!halted) begin
		#10 clk = 1;
		#10 clk = 0;
	end
	$finish;
end
endmodule

module processor(halt, reset, clk);
output reg halt;
input reset, clk;

wire rdy;
reg `LINE rdata, rdata0, rdata1, ccrdata0, ccrdata1, smrdata0, smrdata1;
reg `LINE wdata, wdata0, wdata1, ccwdata0, ccwdata1, smwdata0, smwdata1;
reg `LINEADDR addr, addr0, addr1, ccaddr0, ccaddr1, smaddr0, smaddr1;
wire wtoo, wtoo0, wtoo1;
wire strobe, strobe0, strobe1;
wire ccstrobe0, ccstrobe1, smstrobe0, smstrobe1;
wire ccupdate0, ccupdate1;
wire ccupdatedone0, ccupdatedone1;
wire ccmiss0, ccmiss1;
wire ccdatadirty0, ccdatadirty1;
wire in_tr0, in_tr1;
wire stall0, stall1;
wire smwrite0, smwrite1;
wire smupdate0, smupdate1;
wire fetching;
wire whichcache;
wire sig_tmv1, sig_tmv0;
wire sig_tmv;
assign sig_tmv = sig_tmv1 | sig_tmv0;



// TODO: David, here are examples of how to fix wire, reg problems
// wire clocked assignment
reg smupdate1_reg;
assign smupdate1 = smupdate1_reg;
reg smupdate0_reg;
assign smupdate0 = smupdate0_reg;
reg wtoo_reg;
assign wtoo = wtoo_reg;
reg strobe1_reg;
assign strobe1 = strobe1_reg;
reg strobe0_reg;
assign stobe0 = strobe0_reg;
reg strobe_reg;
assign strobe = strobe_reg;
// wire module inout to reg assignment
wire `LINEADDR ccaddr0_wire;
always @(posedge clk) begin
   ccaddr0 <= ccaddr0_wire;
end

slowmem16 DATAMEM(rdy, rdata, addr, wdata, wtoo, strobe, clk);

core PE0(halt0, reset, clk, rdata0, addr0, wdata0, wtoo0, strobe0, in_tr0, stall0, sig_tmv);
cache C0(reset, rdata0, addr0, wdata0, wtoo0, strobe0, clk, in_tr0,
ccstrobe0, ccupdate0, ccupdatedone0, ccmiss0, ccrdata0, ccaddr0_wire, ccwdata0, ccdatadirty0, ccstrobe1,
ccupdate1, ccupdatedone1, ccmiss1, ccrdata1, ccaddr1, ccwdata1, ccdatadirty1, stall0, smstrobe0,
smwrite0, smupdate0, smrdata0, smaddr0, smwdata0, sig_tmv0);

core PE1(halt1, reset, clk, rdata1, addr1, wdata1, wtoo1, strobe1, in_tr1, stall1, sig_tmv);
cache C1(reset, rdata1, addr1, wdata1, wtoo1, strobe1, clk, in_tr1,
ccstrobe1, ccupdate1, ccupdatedone1, ccmiss1, ccrdata1, ccaddr1, ccwdata1, ccdatadirty1, ccstrobe0,
ccupdate0, ccupdatedone0, ccmiss0, ccrdata0, ccaddr0_wire, ccwdata0, ccdatadirty0, stall1, smstrobe1,
smwrite1, smupdate1, smrdata1, smaddr1, smwdata1, sig_tmv1);

//Halting logic
always @(posedge clk) begin
  if(halt0 && halt1) begin
	  halt <= 1;
	end
end

//Strobe resolver
always @(posedge clk) begin
  if(strobe) begin
	  strobe_reg <= 0;
	end
	if(strobe0) begin
	  strobe0_reg <= 0;
	end
	if(strobe1) begin
	  strobe1_reg <= 0;
	end
	if(smupdate0) begin
	  smupdate0_reg <= 0;
	end
	if(smupdate1) begin
    smupdate1_reg <= 0;
	end
end

//Arbitration logic for slow memory fetches
always @(posedge clk) begin
  if(!fetching) begin
	  //Always prioritize cache0 requests
	  if(smstrobe0) begin
		  addr <= smaddr0;
			strobe <= 1;
			fetching <= 1;
			whichcache <= 0;
			if(smwrite0) begin
			  wdata <= smwdata0;
				wtoo_reg <= 1;
			end else begin
			  wtoo_reg <= 0;
			end
		end else if(smstrobe1) begin
		  addr <= smaddr1;
			strobe <= 1;
			fetching <= 1;
			whichcache <= 1;
			if(smwrite1) begin
			  wdata <= smwdata1;
				wtoo_reg <= 1;
			end else begin
			  wtoo_reg <= 0;
			end
    end
	end else if(rdy) begin
	  fetching <= 0;
		if(!whichcache) begin
		  smupdate0_reg <= 1;
			smrdata0 <= rdata;
			rdata0 <= rdata;
		end else begin
		  smupdate1_reg <= 1;
			smrdata1 <= rdata;
			rdata1 <= rdata;
    end
  end
end
endmodule

module slowmem16 (rdy, rdata, addr, wdata, wtoo, strobe, clk);
output reg rdy = 0;
output reg `LINE rdata;
input `LINEADDR addr;
input `LINE wdata;
input wtoo, strobe, clk;
reg [7:0] busy = 0;
reg `LINEADDR maddr;
reg mwtoo;
reg `LINE mwdata;
reg `LINE m `LINES;

initial begin
  // put your memory initialization code here
end

always @(posedge clk) begin
  if (busy == 1) begin
    // complete request
    rdata <= m[maddr];
    if (mwtoo) m[maddr] <= mwdata;
    busy <= 0;
    rdy <= 1;
  end else if (busy > 1) begin
    // still waiting
    busy <= busy - 1;
  end else if (strobe) begin
    // idle and new request
    rdata <= 16'hxxxx;
    maddr <= addr;
    mwdata <= wdata;
    mwtoo <= wtoo;
    busy <= `MEMDELAY;
    rdy <= 0;
  end
end
endmodule

module cache (reset, rdata, addr, wdata, wtoo, strobe, clk,
in_tr, ccstrobe, ccupdate, ccupdatedone, ccmiss, ccrdata, ccaddr, ccwdata, ccdatadirty, occstrobe,
occupdate, occupdatedone, occmiss, occrdata, occaddr, occwdata, occdatadirty, stall, smstrobe,
smwrite, smupdate, smrdata, smaddr, smwdata, sig_tmv);
input reset;

// Basic cache connections
output reg `LINE rdata; //Read data
input `LINEADDR addr; //Address
input `LINE wdata; //Write data
input wtoo, strobe, clk;
input in_tr; //Is my core in transaction?

// Cache coherency connections
inout ccstrobe; //Cache coherency enable
inout ccupdate; //Cache miss looking at other cache
inout ccupdatedone; //Did the other cache finish fetching?
input ccmiss; //Cache coherency miss
input `LINE ccrdata; //Cache coherency read data
inout `LINEADDR ccaddr; //Cache coherency address
output `LINE ccwdata; //Cache coherency write data

output ccdatadirty;
input occdatadirty;

// Other cache coherency connections
inout occstrobe; //Is the other cache updating me?
inout occupdate; //Is the other cache fetching data?
inout occupdatedone; //Am I done fetching data?
output occmiss; //Other cache coherency miss
output `LINE occrdata; //Other cache coherency read data
input `LINEADDR occaddr; //Other cache coherency address
input `LINE occwdata; //Other cache coherency write data

output stall; //Should my core stall?

// Slow memory connections
inout smstrobe; //Slow memory enable
output smwrite; //Slow memory write
input smupdate; //Slow memory update
input `LINE smrdata; //Slow memory read data
inout `LINEADDR smaddr; //Slow memory address
output `LINE smwdata; //Slow memory write data

output sig_tmv;
wire sig_tmv;

reg `CLINE cmem `CLINES; //Cache memory
reg `CPTR cindex; //Current number of cache lines
wire timereset; //Checks if all time bits are 1
wire cachefull; //Checks if cache is full

assign timereset = (cmem[0] `DIRTYBIT) && (cmem[1] `DIRTYBIT) && (cmem[2] `DIRTYBIT)
&& (cmem[3] `DIRTYBIT) && (cmem[4] `DIRTYBIT) && (cmem[5] `DIRTYBIT)
&& (cmem[6] `DIRTYBIT) && (cmem[7] `DIRTYBIT);

assign cachefull = (cmem[0] != 0) && (cmem[1] != 0) && (cmem[2] != 0)
&& (cmem[3] != 0) && (cmem[4] != 0) && (cmem[5] != 0) && (cmem[6] != 0)
&& (cmem[7] != 0);

//Reset
always @(reset) begin
  cindex <= 0;
end

//Cache retrieval
always @(posedge clk) begin
  if(strobe) begin
	  //Cache Hit
	  if(cmem[0] `ADDRBITS == addr) begin
		  rdata <= cmem[0] `DATABITS;
			cmem[0] `TIMEBIT <= 1;
			if(wtoo) begin
			  cmem[0] `DATABITS <= wdata;
				cmem[0] `DIRTYBIT <= 1;
				ccstrobe <= 1;
				ccaddr <= addr;
				ccwdata <= wdata;
			end
		end else if(cmem[1] `ADDRBITS == addr) begin
		  rdata <= cmem[1] `DATABITS;
		  cmem[1] `TIMEBIT <= 1;
		  if(wtoo) begin
			  cmem[1] `DATABITS <= wdata;
			  cmem[1] `DIRTYBIT <= 1;
			  ccstrobe <= 1;
			  ccaddr <= addr;
			  ccwdata <= wdata;
		  end
    end else if(cmem[2] `ADDRBITS == addr) begin
		  rdata <= cmem[2] `DATABITS;
		  cmem[2] `TIMEBIT <= 1;
		  if(wtoo) begin
			  cmem[2] `DATABITS <= wdata;
			  cmem[2] `DIRTYBIT <= 1;
			  ccstrobe <= 1;
			  ccaddr <= addr;
			  ccwdata <= wdata;
		  end
		end else if(cmem[3] `ADDRBITS == addr) begin
		  rdata <= cmem[3] `DATABITS;
		  cmem[3] `TIMEBIT <= 1;
		  if(wtoo) begin
			  cmem[3] `DATABITS <= wdata;
			  cmem[3] `DIRTYBIT <= 1;
			  ccstrobe <= 1;
			  ccaddr <= addr;
			  ccwdata <= wdata;
		  end
		end else if(cmem[4] `ADDRBITS == addr) begin
		  rdata <= cmem[4] `DATABITS;
		  cmem[4] `TIMEBIT <= 1;
		  if(wtoo) begin
			  cmem[4] `DATABITS <= wdata;
			  cmem[4] `DIRTYBIT <= 1;
			  ccstrobe <= 1;
			  ccaddr <= addr;
			  ccwdata <= wdata;
		  end
		end else if(cmem[5] `ADDRBITS == addr) begin
		  rdata <= cmem[5] `DATABITS;
		  cmem[5] `TIMEBIT <= 1;
		  if(wtoo) begin
			  cmem[5] `DATABITS <= wdata;
			  cmem[5] `DIRTYBIT <= 1;
			  ccstrobe <= 1;
			  ccaddr <= addr;
			  ccwdata <= wdata;
		  end
		end else if(cmem[6] `ADDRBITS == addr) begin
		  rdata <= cmem[6] `DATABITS;
		  cmem[6] `TIMEBIT <= 1;
		  if(wtoo) begin
			  cmem[6] `DATABITS <= wdata;
			  cmem[6] `DIRTYBIT <= 1;
			  ccstrobe <= 1;
			  ccaddr <= addr;
			  ccwdata <= wdata;
		  end
		end else if(cmem[7] `ADDRBITS == addr) begin
		  rdata <= cmem[7] `DATABITS;
		  cmem[7] `TIMEBIT <= 1;
		  if(wtoo) begin
			  cmem[7] `DATABITS <= wdata;
			  cmem[7] `DIRTYBIT <= 1;
			  ccstrobe <= 1;
			  ccaddr <= addr;
			  ccwdata <= wdata;
		  end
		end else begin //Cache Miss
		  //Clear cache line if cache is full
      if(cachefull) begin
			  if(cmem[0] `TIMEBIT == 0) begin
				  if(cmem[0] `DIRTYBIT) begin
					  smaddr <= cmem[0] `ADDRBITS;
					  smwdata <= cmem[0] `DATABITS;
					  smstrobe <= 1;
						smwrite <= 1;
					end
					cmem[0] `ADDRBITS <= addr;
					cmem[0] `DATABITS <= 0;
					cmem[0] `DIRTYBIT <= 0;
					cmem[0] `TIMEBIT <= 1;
				end else if(cmem[1] `TIMEBIT == 0) begin
				  if(cmem[1] `DIRTYBIT) begin
					  smaddr <= cmem[1] `ADDRBITS;
					  smwdata <= cmem[1] `DATABITS;
					  smstrobe <= 1;
						smwrite <= 1;
					end
					cmem[1] `ADDRBITS <= addr;
					cmem[1] `DATABITS <= 0;
					cmem[1] `DIRTYBIT <= 0;
					cmem[1] `TIMEBIT <= 1;
				end else if(cmem[2] `TIMEBIT == 0) begin
				  if(cmem[2] `DIRTYBIT) begin
					  smaddr <= cmem[2] `ADDRBITS;
					  smwdata <= cmem[2] `DATABITS;
					  smstrobe <= 1;
						smwrite <= 1;
					end
					cmem[2] `ADDRBITS <= addr;
					cmem[2] `DATABITS <= 0;
					cmem[2] `DIRTYBIT <= 0;
					cmem[2] `TIMEBIT <= 1;
				end else if(cmem[3] `TIMEBIT == 0) begin
				  if(cmem[3] `DIRTYBIT) begin
					  smaddr <= cmem[3] `ADDRBITS;
					  smwdata <= cmem[3] `DATABITS;
					  smstrobe <= 1;
						smwrite <= 1;
					end
					cmem[3] `ADDRBITS <= addr;
					cmem[3] `DATABITS <= 0;
					cmem[3] `DIRTYBIT <= 0;
					cmem[3] `TIMEBIT <= 1;
				end else if(cmem[4] `TIMEBIT == 0) begin
				  if(cmem[4] `DIRTYBIT) begin
					  smaddr <= cmem[4] `ADDRBITS;
					  smwdata <= cmem[4] `DATABITS;
					  smstrobe <= 1;
						smwrite <= 1;
					end
					cmem[4] `ADDRBITS <= addr;
					cmem[4] `DATABITS <= 0;
					cmem[4] `DIRTYBIT <= 0;
					cmem[4] `TIMEBIT <= 1;
				end else if(cmem[5] `TIMEBIT == 0) begin
				  if(cmem[5] `DIRTYBIT) begin
					  smaddr <= cmem[5] `ADDRBITS;
					  smwdata <= cmem[5] `DATABITS;
					  smstrobe <= 1;
						smwrite <= 1;
					end
					cmem[5] `ADDRBITS <= addr;
					cmem[5] `DATABITS <= 0;
					cmem[5] `DIRTYBIT <= 0;
					cmem[5] `TIMEBIT <= 1;
				end else if(cmem[6] `TIMEBIT == 0) begin
				  if(cmem[6] `DIRTYBIT) begin
					  smaddr <= cmem[6] `ADDRBITS;
					  smwdata <= cmem[6] `DATABITS;
					  smstrobe <= 1;
						smwrite <= 1;
					end
					cmem[6] `ADDRBITS <= addr;
					cmem[6] `DATABITS <= 0;
					cmem[6] `DIRTYBIT <= 0;
					cmem[6] `TIMEBIT <= 1;
				end else if(cmem[7] `TIMEBIT == 0) begin
				  if(cmem[7] `DIRTYBIT) begin
					  smaddr <= cmem[7] `ADDRBITS;
					  smwdata <= cmem[7] `DATABITS;
					  smstrobe <= 1;
						smwrite <= 1;
					end
					cmem[7] `ADDRBITS <= addr;
					cmem[7] `DATABITS <= 0;
					cmem[7] `DIRTYBIT <= 0;
					cmem[7] `TIMEBIT <= 1;
				end
			end else begin
			  //Cache not full, append to end
				cmem[cindex] `ADDRBITS <= addr;
				cmem[cindex] `DATABITS <= 0;
				cmem[cindex] `DIRTYBIT <= 0;
				cmem[cindex] `TIMEBIT <= 1;
				cindex <= cindex + 1;
			end
			//Stall and check other cache for data
			stall = 1;
		  ccupdate <= 1;
			ccaddr <= addr;
		end
	end
end

//Other cache coherency updates
always @(posedge clk) begin
  if(occstrobe) begin
	  if(cmem[0] `ADDRBITS == occaddr) begin
		  cmem[0] `DATABITS <= occwdata; cmem[0] `DIRTYBIT <= 1; end
		else if(cmem[1] `ADDRBITS == occaddr) begin
			cmem[1] `DATABITS <= occwdata; cmem[1] `DIRTYBIT <= 1; end
		else if(cmem[2] `ADDRBITS == occaddr) begin
		  cmem[2] `DATABITS <= occwdata; cmem[2] `DIRTYBIT <= 1; end
		else if(cmem[3] `ADDRBITS == occaddr) begin
		  cmem[3] `DATABITS <= occwdata; cmem[3] `DIRTYBIT <= 1; end
		else if(cmem[4] `ADDRBITS == occaddr) begin
		  cmem[4] `DATABITS <= occwdata; cmem[4] `DIRTYBIT <= 1; end
		else if(cmem[5] `ADDRBITS == occaddr) begin
		  cmem[5] `DATABITS <= occwdata; cmem[5] `DIRTYBIT <= 1; end
		else if(cmem[6] `ADDRBITS == occaddr) begin
		  cmem[6] `DATABITS <= occwdata; cmem[6] `DIRTYBIT <= 1; end
		else if(cmem[7] `ADDRBITS == occaddr) begin
		  cmem[7] `DATABITS <= occwdata; cmem[7] `DIRTYBIT <= 1; end
	end
end

//Other cache is requesting data
always @(posedge clk) begin
  if(occupdate) begin
    occupdate <= 0;
		occupdatedone <= 1;
    if(cmem[0] `ADDRBITS == occaddr) begin
      ccrdata <= cmem[0] `DATABITS;
      // if this data has been accessed within our transaction, we want to
      // stop others from touching it.
      sig_tmv <= (in_tr & (cmem[0] `DIRTYBIT | cmem[0] `TIMEBIT));
      // send the dirty bit over as well so that the other cache can
      // comprehend if it is also in transaction
      ccdatadirty <= cmem[0] `DIRTYBIT;
    end
		else if(cmem[1] `ADDRBITS == occaddr) begin
      ccrdata <= cmem[1] `DATABITS;
      // if this data has been accessed within our transaction, we want to
      // stop others from touching it.
      sig_tmv <= (in_tr & (cmem[1] `DIRTYBIT | cmem[1] `TIMEBIT));
      // send the dirty bit over as well so that the other cache can
      // comprehend if it is also in transaction
      ccdatadirty <= cmem[1] `DIRTYBIT;
    end
		else if(cmem[2] `ADDRBITS == occaddr) begin
      ccrdata <= cmem[2] `DATABITS;
      // if this data has been accessed within our transaction, we want to
      // stop others from touching it.
      sig_tmv <= (in_tr & (cmem[2] `DIRTYBIT | cmem[2] `TIMEBIT));
      // send the dirty bit over as well so that the other cache can
      // comprehend if it is also in transaction
      ccdatadirty <= cmem[2] `DIRTYBIT;
    end
		else if(cmem[3] `ADDRBITS == occaddr) begin
      ccrdata <= cmem[3] `DATABITS;
      // if this data has been accessed within our transaction, we want to
      // stop others from touching it.
      sig_tmv <= (in_tr & (cmem[3] `DIRTYBIT | cmem[3] `TIMEBIT));
      // send the dirty bit over as well so that the other cache can
      // comprehend if it is also in transaction
      ccdatadirty <= cmem[3] `DIRTYBIT;
    end
		else if(cmem[4] `ADDRBITS == occaddr) begin
      ccrdata <= cmem[4] `DATABITS;
      // if this data has been accessed within our transaction, we want to
      // stop others from touching it.
      sig_tmv <= (in_tr & (cmem[4] `DIRTYBIT | cmem[4] `TIMEBIT));
      // send the dirty bit over as well so that the other cache can
      // comprehend if it is also in transaction
      ccdatadirty <= cmem[4] `DIRTYBIT;
    end
		else if(cmem[5] `ADDRBITS == occaddr) begin
      ccrdata <= cmem[5] `DATABITS;
      // if this data has been accessed within our transaction, we want to
      // stop others from touching it.
      sig_tmv <= (in_tr & (cmem[5] `DIRTYBIT | cmem[5] `TIMEBIT));
      // send the dirty bit over as well so that the other cache can
      // comprehend if it is also in transaction
      ccdatadirty <= cmem[5] `DIRTYBIT;
    end
		else if(cmem[6] `ADDRBITS == occaddr) begin
      ccrdata <= cmem[6] `DATABITS;
      // if this data has been accessed within our transaction, we want to
      // stop others from touching it.
      sig_tmv <= (in_tr & (cmem[6] `DIRTYBIT | cmem[6] `TIMEBIT));
      // send the dirty bit over as well so that the other cache can
      // comprehend if it is also in transaction
      ccdatadirty <= cmem[6] `DIRTYBIT;
    end
		else if(cmem[7] `ADDRBITS == occaddr) begin
      ccrdata <= cmem[7] `DATABITS;
      // if this data has been accessed within our transaction, we want to
      // stop others from touching it.
      sig_tmv <= (in_tr & (cmem[7] `DIRTYBIT | cmem[7] `TIMEBIT));
      // send the dirty bit over as well so that the other cache can
      // comprehend if it is also in transaction
      ccdatadirty <= cmem[7] `DIRTYBIT;
    end
		else begin occmiss <= 1; end
	end
end

//Finished checking other cache
always @(posedge clk) begin
  if(ccupdatedone) begin
	  ccupdatedone <= 0;
		if(ccmiss) begin
      //Data not found in other cache, grab from slow memory
      smaddr <= addr;
			smstrobe <= 1;
			smwrite <= 0;
		end else begin
      sig_tmv <= (in_tr & (wtoo | occdatadirty));
      //TODO: shouldnt this be occrdata?
      //Found data in other cache
		  if(cmem[0] `ADDRBITS == ccaddr) begin
			  if(wtoo) begin cmem[0] `DATABITS <= wdata; end
				else begin cmem[0] `DATABITS <= ccrdata; end
				rdata <= ccrdata;
			end
		  else if(cmem[1] `ADDRBITS == ccaddr) begin
			  if(wtoo) begin cmem[1] `DATABITS <= wdata; end
				else begin cmem[1] `DATABITS <= ccrdata; end
				rdata <= ccrdata;
		  end
		  else if(cmem[2] `ADDRBITS == ccaddr) begin
			  if(wtoo) begin cmem[2] `DATABITS <= wdata; end
				else begin cmem[2] `DATABITS <= ccrdata; end
				rdata <= ccrdata;
			end
		  else if(cmem[3] `ADDRBITS == ccaddr) begin
			  if(wtoo) begin cmem[3] `DATABITS <= wdata; end
				else begin cmem[3] `DATABITS <= ccrdata; end
				rdata <= ccrdata;
			end
		  else if(cmem[4] `ADDRBITS == ccaddr) begin
			  if(wtoo) begin cmem[4] `DATABITS <= wdata; end
		                else begin cmem[4] `DATABITS <= ccrdata; end
				rdata <= ccrdata;
			end
		  else if(cmem[5] `ADDRBITS == ccaddr) begin
			  if(wtoo) begin cmem[5] `DATABITS <= wdata; end
				else begin cmem[5] `DATABITS <= ccrdata; end
				rdata <= ccrdata;
			end
		  else if(cmem[6] `ADDRBITS == ccaddr) begin
			  if(wtoo) begin cmem[6] `DATABITS <= wdata; end
				else begin cmem[6] `DATABITS <= ccrdata; end
				rdata <= ccrdata;
			end
		  else if(cmem[7] `ADDRBITS == ccaddr) begin
			  if(wtoo) begin cmem[7] `DATABITS <= wdata; end
				else begin cmem[7] `DATABITS <= ccrdata; end
				rdata <= ccrdata;
			end
			//Unstall core
			stall <= 0;
	  end
	end
end

//Finished retrieving from slow memory
always @(posedge clk) begin
  if(smupdate) begin
	  if(cmem[0] `ADDRBITS == smaddr) begin
		  if(wtoo) begin cmem[0] `DATABITS <= wdata; end
			else begin cmem[0] `DATABITS <= smrdata; end
		end
		else if(cmem[1] `ADDRBITS == smaddr) begin
		  if(wtoo) begin cmem[1] `DATABITS <= wdata; end
			else begin cmem[1] `DATABITS <= smrdata; end
		end
		else if(cmem[2] `ADDRBITS == smaddr) begin
		  if(wtoo) begin cmem[2] `DATABITS <= wdata; end
			else begin cmem[2] `DATABITS <= smrdata; end
		end
		else if(cmem[3] `ADDRBITS == smaddr) begin
		  if(wtoo) begin cmem[3] `DATABITS <= wdata; end
			else begin cmem[3] `DATABITS <= smrdata; end
		end
		else if(cmem[4] `ADDRBITS == smaddr) begin
		  if(wtoo) begin cmem[4] `DATABITS <= wdata; end
			else begin cmem[4] `DATABITS <= smrdata; end
		end
		else if(cmem[5] `ADDRBITS == smaddr) begin
		  if(wtoo) begin cmem[5] `DATABITS <= wdata; end
			else begin cmem[5] `DATABITS <= smrdata; end
		end
		else if(cmem[6] `ADDRBITS == smaddr) begin
		  if(wtoo) begin cmem[6] `DATABITS <= wdata; end
			else begin cmem[6] `DATABITS <= smrdata; end
		end
		else if(cmem[7] `ADDRBITS == smaddr) begin
		  if(wtoo) begin cmem[7] `DATABITS <= wdata; end
			else begin cmem[7] `DATABITS <= smrdata; end
		end
	end
	//Unstall core
	stall <= 0;
end

//Clear timebits
always @(posedge clk) begin
  if(timereset) begin
	  cmem[0] `TIMEBIT <= 0;
		cmem[1] `TIMEBIT <= 0;
		cmem[2] `TIMEBIT <= 0;
		cmem[3] `TIMEBIT <= 0;
		cmem[4] `TIMEBIT <= 0;
		cmem[5] `TIMEBIT <= 0;
		cmem[6] `TIMEBIT <= 0;
		cmem[7] `TIMEBIT <= 0;
	end
end
endmodule

module core (halt, reset, clk, rdata, addr, wdata, wtoo, strobe, in_tr, stall, sig_tmv);
output reg halt;
input reset, clk, sig_tmv;
wire sig_tmv;
reg `WORD  r  `REGSIZE;
reg `WORD  dm `MEMSIZE;
reg `WORD  im `MEMSIZE;
reg `WORD  u  `USIZE;

reg `WORD  s0pc;
reg `WORD  s0lastpc;
wire `WORD s0jmptarget;

reg `INST  s1ir;
reg `WORD  s1lastpc;
wire `OP   s1op;
wire `TYPE s1typ;
wire `WORD s1src;
wire `REG  s1dst;

reg `OP    s2op;
reg `TYPE  s2typ;
reg `WORD  s2src;
reg `WORD  s2dst;
reg `REG   s2dstreg;
reg `UPTR  s2usp;
wire `UPTR  s2undidx;

reg `OP    s3op;
reg `WORD  s3src;
reg `WORD  s3dst;
reg `REG   s3dstreg;

reg `OP    s4op;
reg `WORD  s4alu;
reg `REG   s4dstreg;

// Stage 0: Update PC
assign s0blocked = (opIsBranch(s1op) || opIsBranch(s2op));
assign s0waiting = s1blocked || s1waiting;
assign s0shouldjmp =
	   (s2op == `OPbz && s2dst == 0)
	|| (s2op == `OPbnz && s2dst != 0)
	|| (s2op == `OPbn && s2dst[15] == 1)
	|| (s2op == `OPbnn && s2dst[15] == 0);
assign s0jmptarget = (s2typ == `ILTypeImm) ? (s0pc + s2src - 1) : s2src;

always @(posedge clk) begin
	if (reset) begin
		s0pc <= 0;
		s0lastpc <= 0;
		$readmemh0(r);
		$readmemh1(im);
		$readmemh2(dm);
	end else if (s0shouldjmp) begin
		// save pc before jumping so land can push it to undo stack
		// -1 because stage 0 blocks one instruction after the branch
		s0lastpc <= s0pc - 1;
		s0pc <= s0jmptarget;
	end else if (!s0blocked && !s0waiting) begin
		s0lastpc <= s0pc;
		s0pc <= s0pc + 1;
	end
	#1 $display($time, ": 0: s0pc: %d, should jump: %b, lastpc: %d", s0pc, s0shouldjmp, s0lastpc);
end

// Stage 1 (part 1): Fetch instruction
assign s1blocked = (opIsBlocking(s1op) || opIsBlocking(s2op)
                 || opIsBlocking(s3op) || opIsBlocking(s4op));
assign s1waiting = s2blocked || s2waiting;

always @(posedge clk) begin
	// s0blocked: Special case, s0 can't emit NOPs, so s1 needs to do that for it.
	if (reset || ((s0blocked || s1blocked) && !s1waiting)) begin
		s1ir <= `NOP;
		if (reset)
			s1lastpc <= 0;
	end else if (!s1waiting) begin
		s1ir <= im[s0pc];
		s1lastpc <= s0lastpc;
	end
	#2 $display($time, ": 1: ir: %x, op: %s, typ: %b, src: %x, dst: %x, lastpc: %d", s1ir, opStr(s1op), s1typ, s1src, s1dst, s1lastpc);
end

// Stage 1 (part 2): Instruction decode
assign s1op  = (s1ir `IOPLEN == 0) ? {s1ir `IS_OP, 2'b00} : s1ir `IL_OP;
assign s1typ = (s1ir `IOPLEN == 0) ? `ILTypeImm : s1ir `IL_TYPE; // All short ops are Imm type
assign s1dst = (s1ir `IOPLEN == 0) ? s1ir `IS_DEST : s1ir `IL_DEST;
assign s1src = (s1ir `IOPLEN == 0)
		// sign extend short instructions (always immediate)
		? {{8{s1ir `IS_SRCS}}, s1ir `IS_SRCH, s1ir `IS_SRCL}
		// only sign extend long instructions if immediate
		: ((s1typ == `ILTypeImm) ? {{12{s1ir `IL_SRCS}}, s1ir `IL_SRC} : s1ir `IL_SRC);

assign in_tr = (s1op == `OPjerr || s1op == `OPfail) ? 1:0;                    //added by praneeth
assign in_tr = (s1op == `OPcom)? 0 : in_tr;

// Stage 2: Read registers
assign s2blocked =
	// Block until dst register isn't being written to later in the pipeline
	   (opHasDst(s1op) && (
		   (s1dst == s2dstreg && opWritesToDst(s2op))
		|| (s1dst == s3dstreg && opWritesToDst(s3op))
		|| (s1dst == s4dstreg && opWritesToDst(s4op))))
	// If src requires a register read (TypeReg or TypeMem) block until it
	// isn't being written to later in the pipeline
	|| (opHasSrc(s1op) && (s1typ == `ILTypeReg || s1typ == `ILTypeMem) && (
		   (s1src == s2dstreg && opWritesToDst(s2op))
		|| (s1src == s3dstreg && opWritesToDst(s3op))
		|| (s1src == s4dstreg && opWritesToDst(s4op))));
assign s2waiting = 0;
assign s2undidx = s2usp - s1src - 1; // In own assign to clip value to `UPTR

always @(posedge clk) begin
	if (reset || (s2blocked && !s2waiting)) begin
		s2op  <= `OPnop;
		s2typ <= 0;
		s2src <= 0;
		s2dst <= 0;
		s2dstreg <= 0;
		if (reset)
			s2usp <= 0;
	end else if (!s2waiting) begin
		s2op  <= s1op;
		s2typ <= s1typ;
		// Not all instructions have a valid src or dst to read, but
		// it doesn't hurt to always read them
		case (s1typ)
			`ILTypeImm: s2src <= s1src;
			// 4 bit wrapping offset for undo stack
			`ILTypeUnd: s2src <= u[s2undidx];
//			`ILTypeReg, `ILTypeMem: s2src <= r[s1src];
			`ILTypeReg, `ILTypeMem: address <= s1src; strobe<=1;       //Added by Praneeth
		endcase
		s2dst <= r[s1dst];
		s2dstreg <= s1dst;
		// Push onto undo stack if this is a push instruction
		if (s1op `OP_PUSHES) begin
			// Most instructions push the value of the dst register
			// but land pushes the value of the pc before the most
			// recent jump. To avoid interlocks on the undo stack,
			// this value is pushed here, passed along by s1lastpc
			u[s2usp] <= (s1op == `OPland) ? s1lastpc : r[s1dst];
			s2usp <= s2usp + 1;
			$display($time, ": 2: PUSHING TO UNDO STACK: ", (s1op == `OPland) ? s1lastpc : r[s1dst], ", ", s1op, ", ", s1lastpc, ", ", r[s1dst]);
		end
	end
	#3 $display($time, ": 2:           op: %s, typ: %b, src: %x, dst: %x, dstreg: %d, usp: %d", opStr(s2op), s2typ, s2src, s2dst, s2dstreg, s2usp);
end

// Stage 3: Read / write memory
always @(posedge clk) begin
	if (reset) begin
		s3op <= `OPnop;
		s3src <= 0;
		s3dst <= 0;
		s3dstreg <= 0;
	end else begin
		s3op  <= s2op;
		s3src <= (s2typ == `ILTypeMem) ? dm[s2src] : s2src;
		s3dst <= s2dst;
		s3dstreg <= s2dstreg;
		if (s2op == `OPex) begin
			$display($time, ": 3: WRITING %h to mem addr %d", s2dst, s2src);
			dm[s2src] <= s2dst;
		end
	end
	#4 $display($time, ": 3:           op: %s,          src: %x, dst: %x, dstreg: %d", opStr(s3op), s3src, s3dst, s3dstreg);
end

// Stage 4: ALU
always @(posedge clk) begin
	if (reset) begin
		s4op  <= `OPnop;
		s4alu <= 0;
		s4dstreg <= 0;
	end else begin
		s4op <= s3op;
		s4dstreg <= s3dstreg;
		// This case should handle every instruction for which
		// opWritesToDst is true
		case (s3op)
			`OPxhi: begin s4alu <= {s3dst[15:8] ^ s3src[7:0], s3dst[7:0]}; end
			`OPxlo: begin s4alu <= {s3dst[15:8], s3dst[7:0] ^ s3src[7:0]}; end
			`OPlhi: begin s4alu <= {s3src[7:0], 8'b0}; end
			`OPllo: begin s4alu <= s3src; end
			`OPadd: begin s4alu <= s3dst + s3src; end
			`OPsub: begin s4alu <= s3dst - s3src; end
			`OPxor: begin s4alu <= s3dst ^ s3src; end
			`OProl: begin s4alu <= (s3dst << (s3src & 16'h000f)) | (s3dst >> ((16 - s3src) & 16'h000f)); end
			`OPshr: begin s4alu <= {{16{s3dst[15]}}, s3dst} >> (s3src & 16'h000f); end
			`OPor:  begin s4alu <= s3dst | s3src; end
			`OPand: begin s4alu <= s3dst & s3src; end
			`OPdup, `OPex: begin s4alu <= s3src; end
		endcase
	end
	#5 $display($time, ": 4:           op: %s,          alu: %x,            dstreg: %d", opStr(s4op), s4alu, s4dstreg);
end

// Stage 5: Write registers
// This stage also owns "halt"
always @(posedge clk) begin
	if (reset) begin
		halt <= 0;
		$display($time, ": 5: reset");
	end else if (s4op == `OPsys) begin
		halt <= 1;
		$display($time, ": 5: halting");
	end else if (s4op == `OPfail) begin
		halt <= 1;
		$display($time, ": 5: FAILED");
	end else if (opWritesToDst(s4op)) begin
		r[s4dstreg] <= s4alu;
		$display($time, ": 5: WRITING ", s4alu, " to reg ", s4dstreg);
	end
	#9 $display(""); // Spacer
end

function opHasDst (input `OP op);
	opHasDst = (op `OP_LEN == 1'b0)
		|| (op `OP_GROUP == 3'b100)
		|| (op `OP_GROUP == 3'b101)
		|| (op == `OPex);
endfunction

function opHasSrc (input `OP op);
	opHasSrc = (op `OP_LEN == 1'b0)
		|| (op `OP_GROUP == 3'b100)
		|| (op `OP_GROUP == 3'b101)
		|| (op == `OPjerr || op == `OPfail || op == `OPex);
endfunction

function opWritesToDst (input `OP op);
	opWritesToDst =
		   (op `OP_LEN == 1'b0)
		|| (op `OP_GROUP == 3'b100)
		|| (op == `OPex);
endfunction

function opIsBranch (input `OP op);
	opIsBranch = (op `OP_GROUP == 3'b101);
endfunction

// Don't fetch any instructions when one of these is already in the pipeline.
// Prevents reading instructions past the end of the program (not really
// harmful in simulation, but nice) and also prevents memory writes from
// instructions immediately following the sys or halt.
function opIsBlocking (input `OP op);
	opIsBlocking = (op == `OPsys || op == `OPfail);
endfunction

// Just for the debug prints because I'm tired of reading hex
function [31:0] opStr (input `OP op); // [31:0] -> 4 bytes (chars)
	case (op)
	`OPxhi: opStr = "xhi"; `OPlhi:  opStr = "lhi"; `OPxlo:  opStr = "xlo";
	`OPllo: opStr = "llo"; `OPadd:  opStr = "add"; `OPsub:  opStr = "sub";
	`OPxor: opStr = "xor"; `OProl:  opStr = "rol"; `OPshr:  opStr = "shr";
	`OPor:  opStr = "or";  `OPand:  opStr = "and"; `OPdup:  opStr = "dup";
	`OPbz : opStr = "bz";  `OPbnz:  opStr = "bnz"; `OPbn:   opStr = "bn";
	`OPbnn: opStr = "bnn"; `OPjerr: opStr = "jerr";`OPfail: opStr = "fail";
	`OPex:  opStr = "ex";  `OPcom:  opStr = "com"; `OPland: opStr = "land";
	`OPnop: opStr = "___"; `OPsys:  opStr = "sys";
	endcase
endfunction

endmodule
