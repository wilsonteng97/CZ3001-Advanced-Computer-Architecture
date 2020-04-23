// defines
`define ADD 6'b000000
`define SUB 6'b000001
`define AND 6'b000010
`define XOR 6'b000011
`define COM 6'b000100
`define MUL 6'b000101
`define ADDI 6'b000110
`define LW 6'b000111
`define SW 6'b001000
`define BEQ 6'b001001
`define J 6'b001010


//for fileIO
`timescale 1ns / 10ps
`define EOF 32'hFFFF_FFFF
`define NULL 0
`define MAX_LINE_LENGTH 1000
`define DSIZE 32 // Bitwidth of each register 
`define NREG 32 //Number of registers 
`define ISIZE 32 //instuction size
`define ASIZE 5//Address size

