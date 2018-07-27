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
  LDR R1, =0x41220000
  ;@ read initial value of sliders
  LDR R8, [R1, #0]
  LDR R11, =memory
  STR R8, [R11, #0] ;@ At the zero-th position in memory we store the current value of the sliders

  LDR R7, =Zmem ;@ FIXED VALUE DON'T CHANGE R7
  MOV R4, #0 ;@ ZPC
  ;@LDR R10, =0 ;@ initial value of the receiver fifo store counter
  ;@STR R10, [R11, #4] ;@ At the fourth position in memory we store the current value of upload pointer

Check_switch:
  LDR R11, =memory
  LDR R12, =0x41220000 ;@ address of the sliding switches
  LDR R8, [R11, #0] ;@ Getting the value of last state of sliders
  LDR R10, =104800
  LDR R9, [R12, #0]
  CMP R9, R8
  BEQ Check_switch
  BNE Delay
Delay:
  SUBS R10, R10, #1
  BEQ Verify_switch
  BNE Delay
Verify_switch:
  LDR R9, [R12, #0]
  LDR R10, =104800
  CMP R9, R8
  BEQ Check_switch
  MOV R8, R9
  STR R8, [R11, #0]
  BNE Switch_State_Set

Switch_State_Set:
  LDR R11, =memory
  LDR R8, [R11, #0]
  LDR R9, =128
  AND R9, R8, R9
  CMP R9, #128
  BLEQ upload_mode
  LDR R9, =64
  AND R9, R8, R9
  CMP R9, #64
  BLEQ no_header_mode
  BLNE header_mode
  LDR R9, =128
  AND R9, R8, R9
  CMP R9, #128
  BLNE run_mode
  LDR R9, =32
  AND R9, R8, R9
  CMP R9, #32
  BLEQ debug_mode
  BLNE game_mode
  LDR R10, =0x41220000 ;@ address of the sliding switches
  LDR R11, =memory
  LDR R8, [R11, #0]
  LDR R9, [R10, #0]
  CMP R9, R8
  BEQ Switch_State_Set
  BNE Check_switch

upload_mode:
  PUSH {R8-R12, LR}
  MOV R4, #0
  LDR R11, =2000000 ;@ Size of Zmem
  LDR R9, =0 ;@ the null value to store at Zmem offset by R4
  LDR R12, =1000000 ;@ Size of Zstack
  BL Delete_Zmemory
  BL Reset_Zstack
  BL Check_receiver_fifo_and_store
  POP {R8-R12, PC}

Check_receiver_fifo_and_store:
  LDR R11, =2 ;@ 2
  LDR R9, =0xE000102C ;@  XUARTPS_SR_OFFSET
  LDR R10, [R9, #0]
  AND R11, R10, R11
  CMP R11, #2 ;@ Check 2nd bit to see if receiver FIFO is empty
  BEQ Store
  LDR R12,=0x41220000
  LDR R8, [R12, #0]
  CMP R8, #128
  MOVNE PC, LR
  BEQ Store

Store:
  LDR R8, =0xE0001030 ;@ Memory location where hello world is stored
  LDRB R12, [R8, #0] ;@ loading the input from UART memory location to R8
  STRB R12, [R7, R4]
  ADD R4, R4, #1 ;@ Storing
  B Check_receiver_fifo_and_store

Delete_Zmemory:
  STR R9, [R7, R4]
  ADD R4, R4, #1
  CMP R11, R4
  BHI Delete_Zmemory
  LDREQ R4, =0
  MOVEQ PC, LR

Reset_Zstack:
  LDR R10, =Zstack
  STR R9, [R10, R4]
  ADD R4, R4, #1
  CMP R11, R4
  BPL Reset_Zstack
  LDREQ R4, =0
  MOVEQ PC, LR

run_mode:
  MOV PC, LR

no_header_mode:
  MOV PC, LR

header_mode:
  MOV PC, LR

debug_mode:
  MOV PC, LR

game_mode:
  MOV PC, LR

done:
  B done
