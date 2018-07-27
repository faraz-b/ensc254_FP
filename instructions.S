decode_instructions_loop: 
  LDR R8, [R7, R4] ;@ Fetch byte from Zmem at ZPC -- Opcode
  ADD R4, R4, #1
  LDR R10, =192 ;@ bits 7 & 6  
  AND R9, R8, R10
  CMP R9, #128 ;@ A-Type - 10
  BLEQ a_type
  CMP R9 #192 ;@ C-Type - 11
  BLEQ c_type
  BLNE b_type ;@ 01
  MOV R15, LR
  
a_type:
  LDR R10, =48 ;@ bits 5 & 4
  AND R11, R8, R10
  STR R11, [=memory, #100]
  CMP R11, #48 ;@ operand count is zero - 11
  CMP R11, #0 ;@ two byte constant - 00
  CMP R11, #16 ;@ one byte constant - 01
  CMP R11, #32 ;@ one byte register indicator - 10
  LDR R12, =15 ;@ instruction indicator -- bits 3 - 0
  AND R9, R8, R12
  STR R9, [=memory, #200]

b_type:
  LDR R10, =64
  AND R11, R8, R10
  STR R11, [=memory, #300]
  CMP R11, #0 ;@ 1st operand: one byte constant
  CMP R11, #64 ;@ 1st operand: operand in a register
  LDR R10, =32
  AND R11, R8, R10
  STR R11, [=memory, #400]
  CMP R11, #0 ;@ 2nd operand: one byte constant
  CMP R11, #32 ;@ 2nd operand: operand in register
  
c_type:
  LDR R10, =32
  AND R11, R8, R10
  STR R11, [=memory, #500]
  CMP R11, #0 ;@ two operands
  CMP R11, #32 ;@ variable operand count
  LDR R10, =31
  AND R11, R8, R10 
  STR R11, [=memory, #600] ;@ instruction indicator  
  
