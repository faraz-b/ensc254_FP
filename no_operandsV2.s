.global no_operands
;@ NO_ OPERANDS

no_operands:
  POP {R9} ;@ R9 is the instruction indicator
  CMP R9, #2
  BEQ OP0_2 ;@ PRINT
  BNE no_operands
  CMP R9, #8
  BEQ OP0_8 ;@ RET_POPPED
  CMP R9, #13
  BEQ OP0_D ;@ VERIFY
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
	MOV R12, R10
	PUSH {R8-R12}
	BL Check_transmitter_fifo_and_print
	POP {R8-R12}
	LDR R9, =#32768
	AND R10, R8, R9
	MOV R12, R10
	CMP R12, R9
    BEQ done
    BNE OP0_2

Check_transmitter_fifo_and_print:
  LDR R9, =0xE000102C ;@  XUARTPS_SR_OFFSET
  LDRB R11, [R9]
  TST R11, #8
  BEQ Check_transmitter_fifo_and_print
  BNE print_alpha
  print_alpha:
  LDR R10, =0xE0001030
  CMP R12, #0
  MOVEQ R12, #32
  STREQ R12, [R10]
  MOVEQ PC, LR
  CMP R12, #1
  MOVEQ R12, #10
  STREQ R12, [R10]
  MOVEQ PC, LR
  ADD R12, R12, #91
  MOV R11, #97
  which_letter:
    CMP R11, R12
    BHI else
	STREQ R12, [R10]
	MOVEQ PC, LR
	ADDLO R11, R11, #1
    CMP R11, #122
	BNE which_letter
	BHI else
	else:
	MOV R12, #63
	STR R12, [R10]
    MOV PC, LR

OP0_8: ;@ RET_POPPED
  B done
OP0_D: ;@ VERIFY
  B done