`timescale 1ns / 1ps
`include "define.v"

module pipelined_regfile_5stage(clk, rst, PCOUT, INST, rdata1, rdata2, rdata1_ID_EXE, rdata2_ID_EXE,npc_ID_EXE, imm_ID_EXE,rdata2_imm_ID_EXE, aluop_ID_EXE, alusrc_ID_EXE, branch_ID_EXE, waddr_ID_EXE,aluout,waddr_EXE_MEM,aluout_EXE_MEM,rdata2_EXE_MEM, dmemdata, waddr_MEM_WB,aluout_MEM_WB,wdata_WB);

input clk;		
input	rst;

//FETCH
output [`ISIZE-1:0]PCOUT;

//DECODE
output [`DSIZE-1:0] rdata1;
output [`DSIZE-1:0] rdata2;
output [`DSIZE-1:0]INST;

//EXECUTE along with outputs from ID/EXE pipeline
output [`ISIZE-1:0]npc_ID_EXE;
output [`DSIZE-1:0] rdata1_ID_EXE;
output [`DSIZE-1:0] rdata2_ID_EXE;
output [`DSIZE-1:0] imm_ID_EXE;
output [`DSIZE-1:0] rdata2_imm_ID_EXE;
output alusrc_ID_EXE;
output branch_ID_EXE;
output [2:0]aluop_ID_EXE;
output [`ASIZE-1:0] waddr_ID_EXE;

output [`DSIZE-1:0] aluout;

//MEMORY along with outputs from EXE/MEM pipeline
output [`DSIZE-1:0] rdata2_EXE_MEM;
output [`ASIZE-1:0] waddr_EXE_MEM;
output [`DSIZE-1:0] aluout_EXE_MEM;

output [`DSIZE-1:0] dmemdata;		

//WRITEBACK along with outputs from MEM/WB pipeline		
output [`ASIZE-1:0] waddr_MEM_WB;	
output [`DSIZE-1:0] aluout_MEM_WB;
output [`DSIZE-1:0] wdata_WB;								
 	 

//Program counter
wire [`ISIZE-1:0]PCIN;
wire [`ISIZE-1:0]jump_mux;

PC1 pc(.clk(clk),.rst(rst),.nextPC(jump_mux),.currPC(PCOUT));//PCOUT is your PC value and PCIN is your next PC

assign PCIN = PCOUT + 32'b1; //increments PC to PC +1


//instruction memory
memory im( .clk(clk), .rst(rst), .wen(1'b0), .addr(PCOUT), .data_in(32'b0), .fileid(1'b0),.data_out(INST));//note that memory read is having one clock cycle delay as memory is a slow operation

//control logic for all instructions
wire wen;
wire alusrc;
wire regdst;
wire memwrite;
wire memtoreg;
wire jump;
wire branch;
wire [2:0] aluop;
control C0 (.inst_cntrl(INST[31:26]),.wen_cntrl(wen),.alusrc_cntrl(alusrc),.regdst_cntrl(regdst), .aluop_cntrl(aluop), .memwrite_cntrl(memwrite), .memtoreg_cntrl(memtoreg), .branch_cntrl(branch), .jump_cntrl(jump));

//mux for selecting the writeaddress using regdst
wire [`ASIZE-1:0]waddr_mux=regdst ? INST[15:11] : INST[20:16];// mux for selecting write address for R and I type instcutions

//initialization of regfiles is done as hardcoding here
regfile  RF0 ( .clk(clk), .rst(rst), .wen(writeenable_MEM_WB), .raddr1(INST[25:21]), .raddr2(INST[20:16]), .waddr(waddr_MEM_WB), .wdata(wdata_WB), .rdata1(rdata1), .rdata2(rdata2));//note that waddr and wdata needs to come from last pipeline register (EXE/WB stage)

//sign extention
wire [`DSIZE-1:0]extended_imm;
assign extended_imm=({{16{INST[15]}},INST[15:0]});

//first pipeline register between ID and EXE stage
ID_EXE_stage PIPE1(.clk(clk), .rst(rst), .rdata1_in(rdata1),.rdata2_in(rdata2),.imm_in(extended_imm),.opcode_in(aluop), .alusrc_in(alusrc),. branch_in(branch),.memwrite_in(memwrite),.memtoreg_in(memtoreg),.writeenable_in(wen), .waddr_in(waddr_mux),.PC_IN(PCIN), .waddr_out(waddr_ID_EXE),.imm_out(imm_ID_EXE), .rdata1_out(rdata1_ID_EXE), .rdata2_out(rdata2_ID_EXE),.alusrc_out(alusrc_ID_EXE),.branch_out(branch_ID_EXE), .opcode_out(aluop_ID_EXE),.memwrite_out(memwrite_ID_EXE),.memtoreg_out(memtoreg_ID_EXE),.writeenable_out(writeenable_ID_EXE), .PC_OUT(npc_ID_EXE));//immediate value is only zero extended. As we are concentrationg only on R type instuctions, this is not an issue.

//mux for selecting the input to ALU using alusrc
wire [`DSIZE-1:0]rdata2_imm_ID_EXE=alusrc_ID_EXE ? imm_ID_EXE : rdata2_ID_EXE;// mux for selecting immedaite or the rdata2 value

//ALU takes its input from pipeline register and the output of mux
wire zero_flag;
alu ALU0 ( .a(rdata1_ID_EXE), .b(rdata2_imm_ID_EXE), .op(aluop_ID_EXE), .out(aluout), .zero(zero_flag));//ALU takes its input from pipeline register and the output of mux.

//BRANCH
//PC Src signal to select between PC+1 or PC+Immediate
wire PC_src = (branch_ID_EXE & zero_flag);

//get PC value added with immediate value outputted from ID_EXE pipeline register
wire [`ISIZE-1:0]PC_branch_add;
wire [`ISIZE-1:0]PC_branch;
assign PC_branch_add = npc_ID_EXE + imm_ID_EXE;

assign PC_branch=PC_src ? PC_branch_add : PCIN;

//JUMP
//address calculation for jump={ MSB 6 bits of nPC+ INST[25:0]} here it is word addressing
wire [`ISIZE-1:0]extended_address;
assign extended_address={PCIN[31:26],INST[25:0]};

//mux for selecting the whether to jump or not (one input from the jump address and another input from the output of branch mux)
assign jump_mux=jump ?  extended_address: PC_branch;

//second pipeline register between EXE and MEM stage
EXE_MEM_stage PIPE2(.clk(clk),.rst(rst),.alu_in(aluout),.waddr_in(waddr_ID_EXE),.rdata2_in(rdata2_ID_EXE),.memwrite_in(memwrite_ID_EXE),.memtoreg_in(memtoreg_ID_EXE), .writeenable_in(writeenable_ID_EXE),.alu_out(aluout_EXE_MEM),.rdata2_out(rdata2_EXE_MEM),.waddr_out(waddr_EXE_MEM),.memwrite_out(memwrite_EXE_MEM),.memtoreg_out(memtoreg_EXE_MEM),.writeenable_out(writeenable_EXE_MEM));

//data memory
memory dm( .clk(clk), .rst(rst), .wen(memwrite_EXE_MEM), .addr(aluout_EXE_MEM), .data_in(rdata2_EXE_MEM), .fileid(1'b1),.data_out(dmemdata));//note that memory read is having one clock cycle delay as memory is a slow operation

//third pipeline register between MEM and WBstage
MEM_WB_stage PIPE3(.clk(clk),.rst(rst),.alu_in(aluout_EXE_MEM),.waddr_in(waddr_EXE_MEM),.memtoreg_in(memtoreg_EXE_MEM), .writeenable_in(writeenable_EXE_MEM),.alu_out(aluout_MEM_WB),.waddr_out(waddr_MEM_WB),.memtoreg_out(memtoreg_MEM_WB),.writeenable_out(writeenable_MEM_WB));

//mux for selecting the wdata to regfile using memtoreg
assign wdata_WB =memtoreg_MEM_WB ? aluout_MEM_WB : dmemdata;

endmodule


