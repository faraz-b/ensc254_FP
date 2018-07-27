.global asm_main
.align 4
memory: .space 2000000 ;@ 2MB reserved for own use throughout program
Zmem: .space 2000000 ;@ 2MB for uploading Zprogram
Zstack: .space 1000000 ;@ 1MB for Zstack
FZreg: .space 1000000 ;@ 1MB for function local Zregisters
temp: .space 256 ;@ 256B temporary storage for holding temp operands to variable operand count instructions
.align 4

asm_main:

;@ Set up transmitter to what TeraTerm is expecting
;@ receiver is already set up
LDR R9, =0x20

LDR R8, =0xE0001004 ;@ Mode Register -- Tera Term transmitter
STR R9, [R8, #0]

;@ Start Baud rate setup
LDR R9, =0x3E ;@ 62 in decimal value
LDR R8, =0xE0001018 ;@ Baud rate generator
STR R9, [R8, #0]

;@ Complete baud rate setup
LDR R9, =0x6
LDR R8, =0xE0001034 ;@ Baud rate divider
STR R9, [R8, #0]

;@ Enable and reset the UART
LDR R9, =0x117
LDR R8, =0xE0001000 ;@ Control register
STR R9, [R8, #0]

LDR R4, =0 ;@ ZPC
LDR R5, =Zstack
LDR R6, =0
LDR R7, =Zmem

;@ address of the sliding switches
LDR R11, =0x41220000
;@ read initial value of sliders
LDR R8, [R11, #0]
LDR R12, =memory
STR R8, [R12, #0] ;@ At the zero-th position in memory we store the current value of the sliders

check_switch:
  LDR R12, =memory
  LDR R8, [R12, #0] ;@ Getting the value of last state of sliders
  LDR R10, =104800
  LDR R9, [R11, #0] ;@ new
  CMP R9, R8 ;@ new vs old
  BEQ check_switch
  BNE Delay
Delay:
  SUBS R10, R10, #1
  BEQ Verify_switch
  BNE Delay
Verify_switch:
  LDR R11, =0x41220000
  LDR R9, [R11, #0]
  LDR R10, =104800
  CMP R8, R9
  BEQ check_switch
  BNE switch_changed

switch_changed:
  MOV R8, R9
  LDR R11, =memory
  STR R8, [R11, #0]
  LDR R9, =128
  AND R9, R8, R9
  CMP R9, #128
  BLEQ upload_mode
  BLNE run_mode
  B switch_changed
//  LDR R9, =64
//  AND R9, R8, R9
//  CMP R9, #64
//  BLEQ no_header_mode
//  BLNE header_mode
//  LDR R9, =128
//  AND R9, R8, R9
//  CMP R9, #128
//  BLNE run_mode
//  LDR R9, =32
//  AND R9, R8, R9
//  CMP R9, #32
//  BLEQ debug_mode
//  BLNE game_mode
//  B Check_switch

upload_mode:
  PUSH {R8-R12, LR}
  LDR R11, =20000000
  MOV R9, #0
  ZeroZmem:
  STR R9, [R7, R11]
  SUBS R11, R11, #1
  BNE ZeroZmem
  LDR R8, =0xE0001030
  LDR R9, [R8, #0]
  store:
  STR R9, [R7], R4
  BL check_receiver_fifo
  LDR R11, =0x41220000
  LDR R11, [R11, #0]
  TST R11, #128
  BEQ store
  POP {R8-R12, PC}

run_mode:
  LDR R4, =0
  LDR R8, =0xE0001030
  LDR R10, [R7, R4]
  STR R10, [R8, #0]
  //BL check_transmitter_fifo

delay_loop:
  LDR R10, =500000
  loop:
  SUBS R10, R10, #1
  BNE loop
  MOV R15, R14

check_receiver_fifo:
  PUSH {R8-R12, LR}
  LDR R11, =2 ;@ 2
//  LDR R8, =0xE0001030 ;@ Memory location where hello world is stored
  LDR R9, =0xE000102C ;@  XUARTPS_SR_OFFSET
  LDR R9, [R9, #0]
  AND R11, R9, R11
  CMP R11, #2 ;@ Check 1st bit to see if Transmitter FIFO is empty
  MOVEQ PC, LR
  BLNE check_receiver_fifo

done:
  B done

/*
check_switch:
  PUSH {R8-R12, LR}
  LDR R10, =0x41220000 ;@ load address for slider switches
  LDR R11, [R10, #0]
  CMP R10, #128 ;@ SW07 - Up for upload and down for run mode
  BEQ upload_mode
  CMP R0, #64 ;@ SW06 - no-header mode (raw Zcode)
  BEQ run_mode
  CMP R0, #32 ;@ SW05 - debug
  BEQ debug_mode
  POP {PC}
*/
