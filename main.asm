; General registers / addresses

.equ    SRAM_START,     0x0060
.equ    SRAM_SIZE,      512
.equ    RAMEND,         0x025f

.equ    SPL,            0x3d
.equ    SPH,            0x3e
.equ    SREG,           0x3f


; timer / counter control
; .equ    GTCCR,          0x2C        ; GTCCR – General Timer/Counter Control Register
.equ    TCCR0A,         0x2A        ; TCCR0A – Timer/Counter Control Register A
.equ    TCCR0B,         0x33        ; TCCR0B – Timer/Counter Control Register B
.equ    OCR0A,          0x29        ; OCR0A – Output Compare Register A
.equ    TCNT0,          0x32        ; TCNT0 – Timer/Counter Register
.equ    TIMSK,          0x39        ; TIMSK – Timer/Counter Interrupt Mask Registe
.equ    TIFR,           0x38        ; TIFR – Timer/Counter Interrupt Flag Register

.equ    COUNTER_CTRL_A,    0b00000010   ; mode - 10 = Clear Timer on Compare Match (CTC) mode
.equ    COUNTER_CTRL_B,    0b00000011   ; clk setting (011 = 16 MHz / 64)
.equ    TIMER_INT_MASK,    0b00010000   ; Timer 0 compare match A interrupt

.equ    TIMER_COMPVAL_A,   250          ; timer counts from 0 to TIMER_COMPVAL_A, then resets to 0
                                        ; TIMER_COMPVAL_A value 250 = 1 millisecond
                                        ; this was arrived at using the below equation
                                        ; TIMER_COMPVAL_A = 0.001 * f_cpu / prescale_div
                                        ; if f_cpu = 16 MHz and selected prescale_div = 64, TIMER_COMPVAL_A = 250

; built-in LED control
.equ    DDRB,           0x17
.equ    PORTB,          0x18
.equ    LED_PIN,        1
.equ    SOFT_DELAY,     250             ; custom software scaling limit - with current settings, the unit here is millisecond
                                        ; a value of 250 = 0.25 second

; repurpose r25 for gpio flags
; .req    r25,            r25


; settings to read fuse bits
.equ    SPMCSR,          0x37            ; SPMCSR - Store Program Memory Control and Status Register
.equ    RFLB,            3               ; bit 3 allows reading fuse and lock bits
.equ    SPMEN,           0               ; bit 0 enable program memory control



; MAIN PROGRAM

.org 0                              ; origin - address of next statement
; interrupt vector table
rjmp main                           ; Address 0x0000 - RESET
reti                                ; Address 0x0001 - INT0_ISR
reti                                ; Address 0x0002 - PCINT0_ISR
reti                                ; Address 0x0003 - TIM1_COMPA_ISR
reti                                ; Address 0x0004 - TIM1_OVF_ISR
reti                                ; Address 0x0005 - TIM0_OVF_ISR
reti                                ; Address 0x0006 - EE_RDY_ISR
reti                                ; Address 0x0007 - ANA_COMP_ISR
reti                                ; Address 0x0008 - ADC_ISR
reti                                ; Address 0x0009 - TIM1_COMPB_ISR
rjmp timer0_isr                     ; Address 0x000A - TIM0_COMPA_ISR
reti                                ; Address 0x000B - TIM0_COMPB_ISR
reti                                ; Address 0x000C - WDT_ISR
reti                                ; Address 0x000D - USI_START_ISR
reti                                ; Address 0x000E - USI_OVF_ISR

tasks_jump_table:
    .word blink
    .word test1
    .word test2
    .word 0x0000


timer0_isr:
    inc r20
    .irp param,0,1,2,3,4,30,31
        push r\param
    .endr
    in r4, SREG

    lpm r0, Z+                  ; copy low byte
    lpm r1, Z+                  ; copy high byte
    lpm r2, Z+                  ; copy next low byte to check end of jump table
    lpm r3, Z                   ; copy next low byte to check end of jump table
    mov r30, r0                 ; set ZL
    mov r31, r1                 ; set ZH
    lsr r31                     ; Divide r31:r30 by 2
    ror r30                     ; r31:r30 is an unsigned 2-byte integer
                                ; division by 2 seems important here
                                ; because since icall seems to be multiplying the value by 2 :/
    icall                       ; call the current task subroutine
    pop r31
    pop r30
    clr r0
    cpse r2, r0                 ; here r2 and r3 make the next tasks_jump_table word. check to see if end reached (0x0000)
    rjmp timer0_isr_done1       ;
    cpse r3, r0                 ;
    rjmp timer0_isr_done1       ;
    rcall init_taskmanager      ; reached the end. init task manager to reset to the top of tasks_jump_table
    rjmp timer0_isr_done2
timer0_isr_done1:               ; if we jump here, there are more tasks in the jump table
    adiw r30, 2                 ; increment Z pointer by 2 to the next task (16 bit addressing)
timer0_isr_done2:
    out SREG, r4
    .irp param,4,3,2,1,0
        pop r\param
    .endr
    reti



init_timer:
    ldi r16, COUNTER_CTRL_A
    out TCCR0A, r16                 ; mode select

    ldi r16, COUNTER_CTRL_B
    out TCCR0B, r16                 ; clk select

    ldi r16, TIMER_COMPVAL_A
    out OCR0A, r16

    ldi r16, TIMER_INT_MASK
    out TIMSK, r16                  ; enable interrupt
    ret


init_taskmanager:
    ldi r31, hi8(tasks_jump_table)      ; Initialize Z-pointer with address to tasks_jump_table
    ldi r30, lo8(tasks_jump_table)
    ret


init_onboard_led:
    sbi DDRB, LED_PIN               ; setup output pin 1 (P1)
    out PORTB, 0
    ldi r25, (1<<(LED_PIN-1))                ; use r25 to toggle
    clr r20                         ; software scaling counter to blink LED
    ldi r21, SOFT_DELAY             ; software scaling limit
    ret



main:                               ; initialize
    cli
    ldi r16, lo8(RAMEND)            ; set stack pointer low bits to low(RAMEND)
    out SPL, r16
    ldi r16, hi8(RAMEND)            ; set stack pointer high bits to high(RAMEND)
    out SPH, r16

    rcall init_timer                ; set timer / counter options
    rcall init_onboard_led          ; set LED output pin
    rcall init_taskmanager
    sei

pool:
    sleep                           ; (required for simavr to perform correctly)
    rjmp pool




blink:
    cpi r20, SOFT_DELAY             ; Compare registers
    brsh blink_timeout
    ret
blink_timeout:
    clr r20
    sbrc r25, LED_PIN-1             ; if value is unset, continue to "on", else unset it in the "off" label
    rjmp off
on:
    sbi PORTB, LED_PIN              ; set bit
    sbr r25, (1<<(LED_PIN-1))
    ret
off:
    cbi PORTB, LED_PIN              ; clear bit
    cbr r25, (1<<(LED_PIN-1))
    ret



read_fuse:
    ldi r22, (1<<RFLB) | (1<<SPMEN)
    out SPMCSR, r22
    lpm r22,Z+
    ret

test2:
    push r30
    push r31
    push r22
    clr r31
    clr r30
    rcall read_fuse
fuse_low:           ; break here and see r22 for fuse low byte
    rcall read_fuse
lock_bits:           ; break here and see r22 for lock bits
    rcall read_fuse
fuse_ext:           ; break here and see r22 for fuse ext byte
    rcall read_fuse
fuse_high:           ; break here and see r22 for fuse high byte
    pop r22
    pop r31
    pop r30
    ret


test1:
    .irp param,16,17,18,30,31
    push r\param
    .endr
    in r18, SREG

    ldi r31, hi8(data_table_1)      ; Initialize Z-pointer
    ldi r30, lo8(data_table_1)
    lpm r16, Z+                     ; Load constant from Program
                                    ; Memory pointed to by Z (r31:r30)
    lpm r17, Z
test1_breakpoint:
    out SREG, r18
    .irp param,31,30,18,17,16
    pop r\param
    .endr
    ret


data_table_1:
    .word 0x5276                        ; 0x76 is addresses when ZLSB = 0
                                        ; 0x58 is addresses when ZLSB = 1
    .word 0x9911
