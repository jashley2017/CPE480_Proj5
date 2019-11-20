{\rtf1\ansi\ansicpg1252\deff0\nouicompat\deflang1033{\fonttbl{\f0\fnil\fcharset0 Calibri;}}
{\*\generator Riched20 10.0.18362}\viewkind4\uc1 
\pard\sa200\sl276\slmult1\f0\fs22\lang9 `define WORD    [15:0]\par
`define INST    [15:0]\par
`define OP      [5:0]\par
`define TYPE    [1:0]\par
`define REG     [3:0]\par
`define REGSIZE [15:0]\par
`define MEMSIZE [65535:0]\par
`define UPTR    [3:0]\par
`define USIZE   [15:0]\par
\par
// instruction fields\par
`define IOPLEN  [15]\par
`define IL_OP   [15:10]\par
`define IL_TYPE [9:8]\par
`define IL_DEST [7:4]\par
`define IL_SRC  [3:0]\par
`define IL_SRCS [3]\par
`define IS_OP   [15:12]\par
`define IS_SRCH [11:8]\par
`define IS_DEST [7:4]\par
`define IS_SRCL [3:0]\par
`define IS_SRCS [11]\par
\par
// op components\par
`define OP_PUSHES [2]\par
`define OP_LEN    [5]\par
`define OP_GROUP  [5:3]\par
\par
// op codes\par
`define OPxhi  6'b000000 // First 4 only have the high 4 bits as real op code\par
`define OPlhi  6'b000100\par
`define OPxlo  6'b001000\par
`define OPllo  6'b001100 // The rest are the full op code\par
`define OPadd  6'b100000\par
`define OPsub  6'b100001\par
`define OPxor  6'b100010\par
`define OProl  6'b100011\par
`define OPshr  6'b100100\par
`define OPor   6'b100101\par
`define OPand  6'b100110\par
`define OPdup  6'b100111\par
`define OPbz   6'b101000 // same as... jz\par
`define OPbnz  6'b101001 //  jnz\par
`define OPbn   6'b101010 //  jn\par
`define OPbnn  6'b101011 //  jnn\par
`define OPjerr 6'b110000\par
`define OPfail 6'b110001\par
`define OPex   6'b110010\par
`define OPcom  6'b110011\par
`define OPland 6'b110100\par
`define OPsys  6'b111000\par
`define OPnop  6'b111010 // internal, not part of AXA\par
\par
`define NOP \{`OPnop, 10'b0\}\par
\par
`define ILTypeImm 2'b00\par
`define ILTypeReg 2'b01\par
`define ILTypeMem 2'b10\par
`define ILTypeUnd 2'b11\par
\par
module testbench;\par
reg reset = 0;\par
reg clk = 0;\par
wire halted;\par
processor PE(halted, reset, clk);\par
initial begin\par
\tab $dumpfile;\par
\tab $dumpvars(0, PE);\par
\tab #10 reset = 1;\par
\tab #10 clk = 1;\par
\tab #10 clk = 0;\par
\tab #10 reset = 0;\par
\tab while (!halted) begin\par
\tab\tab #10 clk = 1;\par
\tab\tab #10 clk = 0;\par
\tab end\par
\tab $finish;\par
end\par
endmodule\par
\par
module processor (halt, reset, clk);\par
output reg halt;\par
input reset, clk;\par
reg `WORD  r  `REGSIZE;\par
reg `WORD  dm `MEMSIZE;\par
reg `WORD  im `MEMSIZE;\par
reg `WORD  u  `USIZE;\par
\par
reg `WORD  s0pc;\par
reg `WORD  s0lastpc;\par
wire `WORD s0jmptarget;\par
\par
reg `INST  s1ir;\par
reg `WORD  s1lastpc;\par
wire `OP   s1op;\par
wire `TYPE s1typ;\par
wire `WORD s1src;\par
wire `REG  s1dst;\par
\par
reg `OP    s2op;\par
reg `TYPE  s2typ;\par
reg `WORD  s2src;\par
reg `WORD  s2dst;\par
reg `REG   s2dstreg;\par
reg `UPTR  s2usp;\par
wire `UPTR  s2undidx;\par
\par
reg `OP    s3op;\par
reg `WORD  s3src;\par
reg `WORD  s3dst;\par
reg `REG   s3dstreg;\par
\par
reg `OP    s4op;\par
reg `WORD  s4alu;\par
reg `REG   s4dstreg;\par
\par
// Stage 0: Update PC\par
assign s0blocked = (opIsBranch(s1op) || opIsBranch(s2op));\par
assign s0waiting = s1blocked || s1waiting;\par
assign s0shouldjmp =\par
\tab    (s2op == `OPbz && s2dst == 0)\par
\tab || (s2op == `OPbnz && s2dst != 0)\par
\tab || (s2op == `OPbn && s2dst[15] == 1)\par
\tab || (s2op == `OPbnn && s2dst[15] == 0);\par
assign s0jmptarget = (s2typ == `ILTypeImm) ? (s0pc + s2src - 1) : s2src;\par
\par
always @(posedge clk) begin\par
\tab if (reset) begin\par
\tab\tab s0pc <= 0;\par
\tab\tab s0lastpc <= 0;\par
\tab\tab $readmemh0(r);\par
\tab\tab $readmemh1(im);\par
\tab\tab $readmemh2(dm);\par
\tab end else if (s0shouldjmp) begin\par
\tab\tab // save pc before jumping so land can push it to undo stack\par
\tab\tab // -1 because stage 0 blocks one instruction after the branch\par
\tab\tab s0lastpc <= s0pc - 1;\par
\tab\tab s0pc <= s0jmptarget;\par
\tab end else if (!s0blocked && !s0waiting) begin\par
\tab\tab s0lastpc <= s0pc;\par
\tab\tab s0pc <= s0pc + 1;\par
\tab end\par
\tab #1 $display($time, ": 0: s0pc: %d, should jump: %b, lastpc: %d", s0pc, s0shouldjmp, s0lastpc);\par
end\par
\par
// Stage 1 (part 1): Fetch instruction\par
assign s1blocked = (opIsBlocking(s1op) || opIsBlocking(s2op)\par
                 || opIsBlocking(s3op) || opIsBlocking(s4op));\par
assign s1waiting = s2blocked || s2waiting;\par
\par
always @(posedge clk) begin\par
\tab // s0blocked: Special case, s0 can't emit NOPs, so s1 needs to do that for it.\par
\tab if (reset || ((s0blocked || s1blocked) && !s1waiting)) begin\par
\tab\tab s1ir <= `NOP;\par
\tab\tab if (reset)\par
\tab\tab\tab s1lastpc <= 0;\par
\tab end else if (!s1waiting) begin\par
\tab\tab s1ir <= im[s0pc];\par
\tab\tab s1lastpc <= s0lastpc;\par
\tab end\par
\tab #2 $display($time, ": 1: ir: %x, op: %s, typ: %b, src: %x, dst: %x, lastpc: %d", s1ir, opStr(s1op), s1typ, s1src, s1dst, s1lastpc);\par
end\par
\par
// Stage 1 (part 2): Instruction decode\par
assign s1op  = (s1ir `IOPLEN == 0) ? \{s1ir `IS_OP, 2'b00\} : s1ir `IL_OP;\par
assign s1typ = (s1ir `IOPLEN == 0) ? `ILTypeImm : s1ir `IL_TYPE; // All short ops are Imm type\par
assign s1dst = (s1ir `IOPLEN == 0) ? s1ir `IS_DEST : s1ir `IL_DEST;\par
assign s1src = (s1ir `IOPLEN == 0)\par
\tab\tab // sign extend short instructions (always immediate)\par
\tab\tab ? \{\{8\{s1ir `IS_SRCS\}\}, s1ir `IS_SRCH, s1ir `IS_SRCL\}\par
\tab\tab // only sign extend long instructions if immediate\par
\tab\tab : ((s1typ == `ILTypeImm) ? \{\{12\{s1ir `IL_SRCS\}\}, s1ir `IL_SRC\} : s1ir `IL_SRC);\par
\par
// Stage 2: Read registers\par
assign s2blocked =\par
\tab // Block until dst register isn't being written to later in the pipeline\par
\tab    (opHasDst(s1op) && (\par
\tab\tab    (s1dst == s2dstreg && opWritesToDst(s2op))\par
\tab\tab || (s1dst == s3dstreg && opWritesToDst(s3op))\par
\tab\tab || (s1dst == s4dstreg && opWritesToDst(s4op))))\par
\tab // If src requires a register read (TypeReg or TypeMem) block until it\par
\tab // isn't being written to later in the pipeline\par
\tab || (opHasSrc(s1op) && (s1typ == `ILTypeReg || s1typ == `ILTypeMem) && (\par
\tab\tab    (s1src == s2dstreg && opWritesToDst(s2op))\par
\tab\tab || (s1src == s3dstreg && opWritesToDst(s3op))\par
\tab\tab || (s1src == s4dstreg && opWritesToDst(s4op))));\par
assign s2waiting = 0;\par
assign s2undidx = s2usp - s1src - 1; // In own assign to clip value to `UPTR\par
\par
always @(posedge clk) begin\par
\tab if (reset || (s2blocked && !s2waiting)) begin\par
\tab\tab s2op  <= `OPnop;\par
\tab\tab s2typ <= 0;\par
\tab\tab s2src <= 0;\par
\tab\tab s2dst <= 0;\par
\tab\tab s2dstreg <= 0;\par
\tab\tab if (reset)\par
\tab\tab\tab s2usp <= 0;\par
\tab end else if (!s2waiting) begin\par
\tab\tab s2op  <= s1op;\par
\tab\tab s2typ <= s1typ;\par
\tab\tab // Not all instructions have a valid src or dst to read, but\par
\tab\tab // it doesn't hurt to always read them\par
\tab\tab case (s1typ)\par
\tab\tab\tab `ILTypeImm: s2src <= s1src;\par
\tab\tab\tab // 4 bit wrapping offset for undo stack\par
\tab\tab\tab `ILTypeUnd: s2src <= u[s2undidx];\par
\tab\tab\tab `ILTypeReg, `ILTypeMem: s2src <= r[s1src];\par
\tab\tab endcase\par
\tab\tab s2dst <= r[s1dst];\par
\tab\tab s2dstreg <= s1dst;\par
\tab\tab // Push onto undo stack if this is a push instruction\par
\tab\tab if (s1op `OP_PUSHES) begin\par
\tab\tab\tab // Most instructions push the value of the dst register\par
\tab\tab\tab // but land pushes the value of the pc before the most\par
\tab\tab\tab // recent jump. To avoid interlocks on the undo stack,\par
\tab\tab\tab // this value is pushed here, passed along by s1lastpc\par
\tab\tab\tab u[s2usp] <= (s1op == `OPland) ? s1lastpc : r[s1dst];\par
\tab\tab\tab s2usp <= s2usp + 1;\par
\tab\tab\tab $display($time, ": 2: PUSHING TO UNDO STACK: ", (s1op == `OPland) ? s1lastpc : r[s1dst], ", ", s1op, ", ", s1lastpc, ", ", r[s1dst]);\par
\tab\tab end\par
\tab end\par
\tab #3 $display($time, ": 2:           op: %s, typ: %b, src: %x, dst: %x, dstreg: %d, usp: %d", opStr(s2op), s2typ, s2src, s2dst, s2dstreg, s2usp);\par
end\par
\par
// Stage 3: Read / write memory\par
always @(posedge clk) begin\par
\tab if (reset) begin\par
\tab\tab s3op <= `OPnop;\par
\tab\tab s3src <= 0;\par
\tab\tab s3dst <= 0;\par
\tab\tab s3dstreg <= 0;\par
\tab end else begin\par
\tab\tab s3op  <= s2op;\par
\tab\tab s3src <= (s2typ == `ILTypeMem) ? dm[s2src] : s2src;\par
\tab\tab s3dst <= s2dst;\par
\tab\tab s3dstreg <= s2dstreg;\par
\tab\tab if (s2op == `OPex) begin\par
\tab\tab\tab $display($time, ": 3: WRITING %h to mem addr %d", s2dst, s2src);\par
\tab\tab\tab dm[s2src] <= s2dst;\par
\tab\tab end\par
\tab end\par
\tab #4 $display($time, ": 3:           op: %s,          src: %x, dst: %x, dstreg: %d", opStr(s3op), s3src, s3dst, s3dstreg);\par
end\par
\par
// Stage 4: ALU\par
always @(posedge clk) begin\par
\tab if (reset) begin\par
\tab\tab s4op  <= `OPnop;\par
\tab\tab s4alu <= 0;\par
\tab\tab s4dstreg <= 0;\par
\tab end else begin\par
\tab\tab s4op <= s3op;\par
\tab\tab s4dstreg <= s3dstreg;\par
\tab\tab // This case should handle every instruction for which\par
\tab\tab // opWritesToDst is true\par
\tab\tab case (s3op)\par
\tab\tab\tab `OPxhi: begin s4alu <= \{s3dst[15:8] ^ s3src[7:0], s3dst[7:0]\}; end\par
\tab\tab\tab `OPxlo: begin s4alu <= \{s3dst[15:8], s3dst[7:0] ^ s3src[7:0]\}; end\par
\tab\tab\tab `OPlhi: begin s4alu <= \{s3src[7:0], 8'b0\}; end\par
\tab\tab\tab `OPllo: begin s4alu <= s3src; end\par
\tab\tab\tab `OPadd: begin s4alu <= s3dst + s3src; end\par
\tab\tab\tab `OPsub: begin s4alu <= s3dst - s3src; end\par
\tab\tab\tab `OPxor: begin s4alu <= s3dst ^ s3src; end\par
\tab\tab\tab `OProl: begin s4alu <= (s3dst << (s3src & 16'h000f)) | (s3dst >> ((16 - s3src) & 16'h000f)); end\par
\tab\tab\tab `OPshr: begin s4alu <= \{\{16\{s3dst[15]\}\}, s3dst\} >> (s3src & 16'h000f); end\par
\tab\tab\tab `OPor:  begin s4alu <= s3dst | s3src; end\par
\tab\tab\tab `OPand: begin s4alu <= s3dst & s3src; end\par
\tab\tab\tab `OPdup, `OPex: begin s4alu <= s3src; end\par
\tab\tab endcase\par
\tab end\par
\tab #5 $display($time, ": 4:           op: %s,          alu: %x,            dstreg: %d", opStr(s4op), s4alu, s4dstreg);\par
end\par
\par
// Stage 5: Write registers\par
// This stage also owns "halt"\par
always @(posedge clk) begin\par
\tab if (reset) begin\par
\tab\tab halt <= 0;\par
\tab\tab $display($time, ": 5: reset");\par
\tab end else if (s4op == `OPsys) begin\par
\tab\tab halt <= 1;\par
\tab\tab $display($time, ": 5: halting");\par
\tab end else if (s4op == `OPfail) begin\par
\tab\tab halt <= 1;\par
\tab\tab $display($time, ": 5: FAILED");\par
\tab end else if (opWritesToDst(s4op)) begin\par
\tab\tab r[s4dstreg] <= s4alu;\par
\tab\tab $display($time, ": 5: WRITING ", s4alu, " to reg ", s4dstreg);\par
\tab end\par
\tab #9 $display(""); // Spacer\par
end\par
\par
function opHasDst (input `OP op);\par
\tab opHasDst = (op `OP_LEN == 1'b0)\par
\tab\tab || (op `OP_GROUP == 3'b100)\par
\tab\tab || (op `OP_GROUP == 3'b101)\par
\tab\tab || (op == `OPex);\par
endfunction\par
\par
function opHasSrc (input `OP op);\par
\tab opHasSrc = (op `OP_LEN == 1'b0)\par
\tab\tab || (op `OP_GROUP == 3'b100)\par
\tab\tab || (op `OP_GROUP == 3'b101)\par
\tab\tab || (op == `OPjerr || op == `OPfail || op == `OPex);\par
endfunction\par
\par
function opWritesToDst (input `OP op);\par
\tab opWritesToDst =\par
\tab\tab    (op `OP_LEN == 1'b0)\par
\tab\tab || (op `OP_GROUP == 3'b100)\par
\tab\tab || (op == `OPex);\par
endfunction\par
\par
function opIsBranch (input `OP op);\par
\tab opIsBranch = (op `OP_GROUP == 3'b101);\par
endfunction\par
\par
// Don't fetch any instructions when one of these is already in the pipeline.\par
// Prevents reading instructions past the end of the program (not really\par
// harmful in simulation, but nice) and also prevents memory writes from\par
// instructions immediately following the sys or halt.\par
function opIsBlocking (input `OP op);\par
\tab opIsBlocking = (op == `OPsys || op == `OPfail);\par
endfunction\par
\par
// Just for the debug prints because I'm tired of reading hex\par
function [31:0] opStr (input `OP op); // [31:0] -> 4 bytes (chars)\par
\tab case (op)\par
\tab `OPxhi: opStr = "xhi"; `OPlhi:  opStr = "lhi"; `OPxlo:  opStr = "xlo";\par
\tab `OPllo: opStr = "llo"; `OPadd:  opStr = "add"; `OPsub:  opStr = "sub";\par
\tab `OPxor: opStr = "xor"; `OProl:  opStr = "rol"; `OPshr:  opStr = "shr";\par
\tab `OPor:  opStr = "or";  `OPand:  opStr = "and"; `OPdup:  opStr = "dup";\par
\tab `OPbz : opStr = "bz";  `OPbnz:  opStr = "bnz"; `OPbn:   opStr = "bn";\par
\tab `OPbnn: opStr = "bnn"; `OPjerr: opStr = "jerr";`OPfail: opStr = "fail";\par
\tab `OPex:  opStr = "ex";  `OPcom:  opStr = "com"; `OPland: opStr = "land";\par
\tab `OPnop: opStr = "___"; `OPsys:  opStr = "sys";\par
\tab endcase\par
endfunction\par
\par
endmodule\par
}
 