.global no_header_mode
.global header_mode


no_header_mode:
  PUSH {R8-R12, LR}
  LDR R8, =memory
  LDR R9, =#4096 ;@ convert 0x1000 from hex to decimal; this is the location of the object table in no header mode
  STR R9, [R8, #4]
  LDR R9, =#8192 ;@ convert 0x2000 from hex to decimal; this is the location of the dictionary in no header mode
  STR R9, [R8, #8]
  MOV R4, #0 ;@ R4, is ZPC, which is the start of the instructions
  LDR R9, =#16384 ;@ convert 0x4000 from hex to decimal; this is the location of the global registers in Zmem
  STR R9, [R8, #12]
  POP {R8-R12, PC}
  
  
header_mode:
  PUSH {R8-R12, LR}
  ;@ since the header is the first 64 bytes in Zmem
  LDR R8, =memory
  MOV R9, #10 ;@ location of the object table is given at an offset of 0x0A in header mode
  LDR R10, [R7, R9]
  LSL R10, R10, #8
  ADD R9, R9, #1
  LDR R11, [R7, R9] 
  ADD R10, R10, R11 ;@ now R10 has the 16-bit  value providing the location of the object table
  STR R10, [R8, #4]  ;@ storing the object table location in memory so it can be loaded later
  MOV R9, #8 ;@ location of the dictionary is given at an offset of 0x08 in header mode
  LDR R10, [R7, R9]
  LSL R10, R10, #8
  ADD R9, R9, #1
  LDR R11, [R7, R9] 
  ADD R10, R10, R11 ;@ now R10 has the 16-bit  value providing the location of the dictionary
  STR R10, [R8, #8]  ;@ storing the dictionary location in memory so it can be loaded later
  MOV R9, #4 ;@ location of the first instruction is given at an offset of 4 in header mode
  LDR R10, [R7, R9]
  LSL R10, R10, #8
  ADD R9, R9, #1
  LDR R11, [R7, R9] 
  ADD R10, R10, R11 ;@ now R10 has the 16-bit  value providing the location of the star of instructions in zmem
  MOV R4, R10 ;@ R4 is ZPC, which is the start of the instructions
  MOV R9, #12 ;@ location of the global registers is given at an offset of 0x0C in header mode
  LDR R10, [R7, R9]
  LSL R10, R10, #8
  ADD R9, R9, #1
  LDR R11, [R7, R9] 
  ADD R10, R10, R11 ;@ now R10 has the 16-bit  value providing the location of the global registers
  STR R10, [R8, #12]  ;@ storing the global registers location in memory so it can be loaded later
  POP {R8-R12, PC}