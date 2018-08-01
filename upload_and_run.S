.global asm_main
.align 4
memory: .space 2000000 ;@ 2MB reserved for own use throughout program
.align 4
Zmem: .space 2000000 ;@ 2MB for uploading Zprogram
.align 4
Zstack: .space 1000000 ;@ 1MB for Zstack
.align 4
FZreg: .space 1000000 ;@ 1MB for function local Zregisters
.align 4
temp: .space 256 ;@ 256B temporary storage for holding temp operands to variable operand count instructions
.align 4

asm_main:
  ;@ Set up transmitter to what TeraTerm is expecting
  LDR R9, =0x20
  LDR R4, =0xE0001004 ;@ Mode Register -- Tera Term transmitter
  STR R9, [R4, #0]
  ;@ Start Baud rate setup
  LDR R9, =0x3E
  LDR R4, =0xE0001018 ;@ Baud rate generator
  STR R9, [R4, #0]
  ;@ Complete baud rate setup
  LDR R9, =6
  LDR R4, =0xE0001034 ;@ Baud rate divider
  STR R9, [R4, #0]
  ;@ Enable and reset the UART
  LDR R9, =0x117
  LDR R4, =0xE0001000 ;@ Control register
  STR R9, [R4, #0]
  ;@ address of the sliding switches
  LDR R10, =0x41220000
  ;@ read initial value of sliders
  LDR R8, [R10, #0]
  LDR R11, =memory
  STR R8, [R11, #0] ;@ At the zero-th position in memory we store the current value of the sliders
  MOV R4, #0 ;@ZPC
  MOV R5, #0 ;@ZSP
  MOV R6, #0 ;@ nesting depth
  LDR R7, =Zmem ;@ FIXED VALUE DONT CHANGE R7

Check_switch:
  LDR R1, =0x41220000 ;@ address of the sliding switches
  LDR R8, [R11, #0] ;@ Getting the value of last state of sliders
  LDR R10, =104800
  LDR R9, [R1, #0]
  CMP R9, R8
  BEQ Check_switch
  BNE Delay
Delay:
  SUBS R10, R10, #1
  BEQ Verify_switch
  BNE Delay
Verify_switch:
  LDR R9, [R1, #0]
  LDR R10, =104800
  CMP R8, R9
  BEQ Check_switch
  MOVNE R8, R9
  LDRNE R11, =memory
  STRNE R8, [R11, #0] ;@ current value of slider is stored @ the 0th offset in memory
  BNE Switch_changed

Switch_changed:
  LDR R9, =128
  AND R9, R8, R9
  CMP R9, #128
  BEQ Delete_All_Mem
  BNE run_mode

Delete_All_Mem:
  LDR R9, =0 ;@ the null value to store at Zmem offset by R8
  LDR R10, =FZreg
  LDR R11, =Zstack
Delete_Zmemory:
  STR R9, [R7, R4]
  ADD R4, R4, #1
  CMP R4, R7
  BPL Delete_Zmemory
  MOV R4, #0
  BEQ Delete_FZreg
Delete_FZreg:
  STR R9, [R10, R4]
  ADD R4, R4, #1
  CMP R4, R10
  BPL Delete_FZreg
  MOV R4, #0
  BEQ Delete_Zstack
Delete_Zstack:
  STR R9, [R11, R5]
  ADD R5, R5, #1
  CMP R5, R11
  BPL Delete_Zstack
  MOV R5, #0
  BEQ upload_mode
  
  
upload_mode:
  LDR R10, =0x41220000 ;@ address of the sliding switches
  LDR R8, =#128
  PUSH {R8-R12}
  BL Check_receiver_fifo_and_store
  POP {R8-R12}
  LDR R11, [R10]
  CMP R11, R8
  BEQ upload_mode
  BNE Check_switch
  
Check_receiver_fifo_and_store:
  LDR R9, =0xE000102C ;@  XUARTPS_SR_OFFSET
  LDR R10, [R9]
  TST R10,#2
  BEQ Store
  MOVNE PC, LR
Store:
  LDR R8, =0xE0001030 ;@ Memory location where hello world is stored
  LDRB R9, [R8] ;@ loading the input from UART memory location to R8
  STRB R9, [R7, R4] ;@ Storing
  ADD R4, #1
  B Check_receiver_fifo_and_store


run_mode:  
  LDR R9, =64
  AND R9, R8, R9
  CMP R9, #64
  BLEQ no_header_mode
  BLNE header_mode
  LDR R9, =32
  AND R9, R8, R9
  CMP R9, #32
  BLEQ debug_mode
  BLNE game_mode ;@supress the debug output
  LDR R9, =0x41220000 ;@ address of the sliding switches
  LDR R11, =memory
  LDR R8, [R11, #0] ;@ loading the previous value of sliders to R8
  LDR R10, [R9, #0] ;@ loadign the current value of sliders to R10
  CMP R8, R10 ;@ comparing both to check if they are the same
  BNE Check_switch
  

decode_instructions_loop:
  LDRB R8, [R7, R4] ;@ Fetch byte from Zmem at ZPC -- Opcode instruction type bits
  ADD R4, R4, #1
  LSR R9, R8, #6 ;@ shift the bits we want to the right end
  CMP R9, #3 ;@ C-Type - 11
  BEQ c_type
  CMP R9, #2 ;@ A-Type - 10
  BEQ a_type
  CMP R9, #1 ;@ B-Type - 01
  BEQ b_type

a_type:
  LDR R10, =15 ;@ instruction indicator -- bits 3 - 0
  AND R9, R8, R10
  PUSH { R9 }
  LDR R10, =48 ;@ bits 5 & 4
  AND R9, R8, R10
  CMP R9, #48 ;@ operand count is zero - 11
  BEQ no_operands
  CMP R9, #0 ;@ two byte constant - 00
  BLEQ sixteen_bit_fetch_for_a_type
  CMP R9, #16 ;@ one byte constant - 01
  BLEQ eight_bit_fetch_for_a_type
  CMP R9, #32 ;@ one byte register indicator - 10
  BLEQ register_indicator_fetch_for_a_type
  B one_operand ;@single operand we need to perform the instruction on is stored in R0 & instruction code is at R9

sixteen_bit_fetch_for_a_type:
  LDRB R10, [R7, R4]
  ADD R4, R4, #1
  LSL R10, R10, #8
  LDRB R11, [R7, R4]
  ADD R4, R4, #1
  ADD R0, R10, R11
  MOVEQ PC, LR

eight_bit_fetch_for_a_type:
  LDRB R0, [R7, R4]
  ADD R4, R4, #1
  MOVEQ PC, LR

register_indicator_fetch_for_a_type:
  LDRB R0, [R7, R4]
  ADD R4, R4, #1
  CMP R0, #0
  BEQ Zstack_change
  CMP R0, #16
  BLT Local_register_change
  B Global _register_change

Local_register_change:
  SUB R0, R0, #1
  LSL R0, R0, #1
  LSL R6, R6, #5
  ADD R0, R0, R6 ;@ this is the value to add to the location of FZreg
  MOVEQ PC, LR

Global_register_change:
  LDR R8, =memory
  MOV R10, #12 ;@loading the location of the global registers from memory into R10
  LDRB R9, [R8, R10]
  LSL R9, R9, #8
  ADD R10, R10, #1
  LDRB R11, [R8, R10]
  ADD R9, R9, R11
  SUB R0, R0, #16
  LSL R0, R0, #1
  ADD R0, R0, R11 ;@ R0 now has the location of the global_register within my Zmem
  MOVEQ PC, LR
  
Zstack_change:
B PUSH_Zstack
B POP_Zstack

PUSH_Zstack:
LDR R10, =Zstack
STRB R0, [R10, R5] ;@ real number or LSB; R5 is a ZSP
ADD R5, R5, #1
STRB R1, [R10, R5] ;@ offset by zeros or MSB; R5 is a ZSP
ADD R5, R5, #1
LDR R10, =FZreg
MOV R9, #40
LSL R11, R6, #5
ADD R9, R9, R11
LDRB R8, [R10, R9]
ADD R8 R8, #1
STRB, [R10, R9]
MOV PC, LR

POP_Zstack:
LDR R10, =Zstack
LDRB R1, [R10, R5] ;@ real number or LSB; R5 is a ZSP
SUB R5, R5, #1
LDRB R0, [R10, R5] ;@ offset by zeros or MSB; R5 is a ZSP
SUB R5, R5, #1
LDR R10, =FZreg
MOV R9, #40
LSL R11, R6, #5
ADD R9, R9, R11
LDRB R8, [R10, R9]
SUB R8 R8, #1
STRB, [R10, R9]
MOV PC, LR




/*
a_type_fetch: //this function will be called from the Zprocedures that have one operand
  LDRB R10, [R7, R4]
  ADD R4, R4, #1
  LDR R11,= 0b11000000
*/
b_type:
  LDR R10, =64
  AND R11, R8, R10
  CMP R11, #0 ;@ 1st operand: one byte constant
  CMP R11, #64 ;@ 1st operand: operand in a register
  LDR R10, =32
  AND R11, R8, R10
  CMP R11, #0 ;@ 2nd operand: one byte constant
  CMP R11, #32 ;@ 2nd operand: operand in register

c_type:
  LDR R10, =31
  AND R9, R8, R10
  PUSH {R9} ;@ instruction indicator
  LDR R10, =32
  AND R9, R8, R10
  CMP R9, #0 ;@ two operands
//  BEQ two_operands
//  BNE var_operands ;@ variable operand count




no_operands:
;@ for basic points
  POP {R9} ;@ R9 is the instruction indicator
  CMP R9, #2
  BEQ OP0_2 ;@ PRINT
  BNE no_operands
  CMP R9, #8
  BEQ OP0_8 ;@ RET_POPPED
  CMP R9, #13
  BEQ OP0_13 ;@ VERIFY
  BNE no_operands ;@ infinite loop here, can send to crash mode later

OP0_2: ;@ PRINT
  LDRB R8, [R7, R4]
  ADD R4, R4, #1
  LDRB R9, [R7, R4]
  ADD R4, R4, #1
  LSL R8, #8
  ADD R8, R8, R9
  read:
    LDR R9, =#31744
	AND R10, R8, R9
	LSR R12, R10, #10
	PUSH {R8-R12}
	BL Check_transmitter_fifo_and_print
	POP {R8-R12}
	LDR R9, =#992
	AND R10, R8, R9
	LSR R12, R10, #5
	PUSH {R8-R12}
	BL Check_transmitter_fifo_and_print
	POP {R8-R12}
	LDR R9, =#31
	AND R10, R8, R9
	PUSH {R8-R12}
	BL Check_transmitter_fifo_and_print
	POP {R8-R12}
	LDR R9, =#32768
	CMP R8, R9
    BEQ done
    BNE OP0_2

Check_transmitter_fifo_and_print:
  LDR R9, =0xE000102C ;@  XUARTPS_SR_OFFSET
  LDRB R11, [R9]
  TST R11, #8
  BEQ Check_transmitter_fifo_and_print
  BNE print
  print:
  LDR R10, =0xE0001030
  CMP R12, #0
  MOVEQ R12, #32
  STREQ R12, [R10]
  CMP R12, #1
  MOVEQ R12, #10
  STREQ R12, [R12]
  ADD R12, R12, #91
  MOV R11, #97
  which_letter:
    CMP R11, R12
	STREQ R12, [R10]
	ADDPL R11, R11, #1
    CMP R11, #122
	BNE which_letter
	MOV R12, #63
	STR R12, [R10]
    MOV PC, LR


/*
print:
  LDR R10, =0xE0001030
  CMP R12, #0
  MOVEQ R12, #32
  STREQ R12, [R10]
  CMP R12, #1
  MOVEQ R12, #10
  STREQ R12, [R12]
  ADD R12, R12, #91
  MOV R11, #97
  which_letter:
    TST R12, R11
	STRNE R12, [R10]
	ADDEQ R11, R11, #1
    CMP R11, #122
	BNE which_letter
	MOV R12, #63
	STR R12, [R10]
    MOV PC, LR

*/


/*
OP0_8: ;@ RET_POPPED
CMP R9, #13
OP0_D: ;@ VERIFY

one_operand:
;@ for basic points
OP1_5: ;@ INC
OP1_6: ;@ DEC
OP1_B: ;@ RET


fetch_for_C:
  LDRB R10, [R7, R4] ;@ fetching a byte from Zmem at ZPC
  ADD R4, R4,#1 ;@ incrementing ZPC
  MOV R8, #0 ;@ temp memory counter
  LDR R11,= 0b11000000
  loop:
	AND R12, R11, R10
	CMP R12, #0
	BEQ sbit_constant
	CMP R12, #1
	BEQ ebit_constant
	CMP R12, #2
	BEQ op_in_reg
	CMP R12, #3
	;@BEQ return Most likely MOV PC, LR
      sbit_constant:
        LDR R12, =temp
        LDRB R9, [R7, R4]
	    ADD R4, R4, #1
	    STRB R9, [R12, R8] ;@ possible logical error
	    ADD R8, R8, #1
        LDRB R9, [R7, R4]
	    ADD R4, R4, #1
	    STRB R9, [R12, R8] ;@ possible logical error
	    ADD R8, R8, #1
	    LSR R11, #2
	    B loop
      ebit_constant:
        LDR R12, =temp
	    LDR R9, [R7, R4]
	    ADD R4, R4, #2
	    STR R9, [R12, R8]
	    ADD R8, R8, #4
	    LSR R11, #2
	    B loop
      op_in_reg:
	    LDR R12, =temp






*/







/*

two_operands:
  POP {R9}
;@ Basic points
  LDR R10, =#0x01
  CMP R9, R10
  BEQ OP2_01 ;@ JE
  LDR R10, =#0x02
  CMP R9, R10
  BEQ OP2_02 ;@ JL
  LDR R10, =#0x03
  CMP R9, R10
  BEQ OP2_03 ;@ JG
  LDR R10, =#0x0A
  CMP R9, R10
  BEQ OP2_0A ;@ TEST_ATTR
  LDR R10, =#0x0B
  CMP R9, R10
  BEQ OP2_0B ;@ SET_ATTR
  LDR R10, =#0x0C
  CMP R9, R10
  BEQ OP2_0C ;@ CLEAR_ATTR
  LDR R10, =#0x14
  CMP R9, R10
  BEQ OP2_14 ;@ ADD
  LDR R10, =#0x15
  CMP R9, R10
  BEQ OP2_15 ;@ SUB
  LDR R10, =#0x16
  CMP R9, R10
  BEQ OP2_16 ;@ MUL
  LDR R10, =#0x17
  CMP R9, R10
  BEQ OP2_17 ;@ DIV
  LDR R10, =#0x18
  CMP R9, R10
  BEQ OP2_18 ;@ MOD
  LDR R10, =#0x19
  CMP R9, R10
  BEQ OP2_19 ;@ CALL_2S
  LDR R10, =#0x1A
  CMP R9, R10
  BEQ OP2_1A ;@ CALL_2N

*/

  /* ;@all go to crash mode
  LDR R10, =#0x00
  CMP R9, R10
  BEQ crash_mode ;@ Illegal instruction
  LDR R10, =#0x04
  CMP R9, R10
  BEQ crash_mode ;@ DEC_CHK
  LDR R10, =#0x05
  CMP R9, R10
  BEQ crash_mode ;@ INC_CHK
  LDR R10, =#0x1C
  CMP R9, R10
  BEQ crash_mode ;@ crash_mode
  LDR R10, =#0x1D
  CMP R9, R10
  BEQ crash_mode ;@ crash_mode
  LDR R10, =#0x1E
  CMP R9, R10
  BEQ OP2_1E ;@ crash_mode
  LDR R10, =#0x1F
  CMP R9, R10
  BEQ crash_mode ;@ crash_mode
*/

OP2_01: ;@ JE
OP2_02: ;@ JL
OP2_03: ;@ JG
OP2_0A: ;@ TEST_ATTR
OP2_0B: ;@ SET_ATTR
OP2_0C: ;@ CLEAR_ATTR

/*
OP2_14: ;@ ADD
  ADD R4, R4, #1
  LDR R8, [R7, R4]
  MOV R10, #6
  PUSH {R8-R12}
  BL fetch_next
  POP {R8-R12}
*/
/*
var_operands:
  POP {R9}
  ;@ for basic points
  CMP R9, #5
  BEQ VAR_05 ;@ PRINT_CHAR
  CMP R9, #0x08
  BEQ PUSH
  CMP R9, #0x09
  BEQ PULL
  CMP R9, #0x18
  BEQ NOT
  BNE var_operands

  ;@BNE carsh
*/
VAR_05: ;@ PRINT_CHAR
  //ADD R4, R4, #2
  LDR R4,=2
  LDR R8, [R7, R4]
  LDR R12, =0xE0001030
  STR R8, [R12,#0]
  B done

done:
  B done
