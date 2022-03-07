.include "config.inc"                                   ; TASK_TABLE_START

.equ    TASK_COUNTER,       TASK_TABLE_START            ; Task counter
.equ    TASK_POINTER,       TASK_TABLE_START + 1        ; Current task pointer


taskmanager_init:
    sts TASK_COUNTER, 0x0
    sts TASK_POINTER, 0x0
    ret


taskmanager_add:                                ; expects task address loaded in r17:r16
    in r15, SREG
    .irp param,16,17,18,26,27
        push r\param
    .endr

    lds r18, TASK_COUNTER
    inc r18
    sts TASK_COUNTER, r18

    lsl r18     ; r18 = r18 * 2 -> because program memory addresses are in words
    ldi r26, TASK_TABLE_START       ; set XL to start of task manager table
    add r26, r18      ; add TASK_COUNTER value to X register (r27:r26) to move to the end of the table
    clr r27                                 ; clear XH

    lsr r17                     ; Divide r17:r16 by 2
    ror r16                     ; r17:r16 is an unsigned 2-byte integer
                                ; division by 2 seems important here
                                ; because icall seems to be multiplying the value by 2 before calling :/
    st X+, r16
    st X, r17

    .irp param,27,26,18,17,16
        pop r\param
    .endr
    out SREG, r15
    ret



taskmanager_exec_next:
    in r15, SREG
    .irp param,16,17,18,26,27,30,31
        push r\param
    .endr

    lds r16, TASK_COUNTER
    cpi r16, 0                  ; if TASK_COUNTER is 0, no tasks are registered
    brne _tasks_available
    rjmp _tasks_done            ; return if TASK_COUNTER = 0
_tasks_available:
    lds r17, TASK_POINTER
    inc r17                     ; go to next task
    sts TASK_POINTER, r17

    mov r18, r17                    ; use r18 as tmp variable
    lsl r18                         ; r18 = r18 * 2 -> because program memory addresses are in words
    ldi r26, TASK_TABLE_START       ; set XL to end of task manager table
    add r26, r18                    ; add counter value to X register (r27:r26)
    clr r27                         ; clear XH

    ld r30,X+                   ; load task address using X into Z register
    ld r31,X
    icall                       ; call the current task subroutine

    cpse r17, r16
    rjmp _tasks_done                         ; return if TASK_POINTER is still not equal to TASK_COUNTER

    sts TASK_POINTER, 0x0                    ; if TASK_POINTER == TASK_COUNTER, we've reached the end. So, reset TASK_POINTER
_tasks_done:
    .irp param,31,30,27,26,18,17,16
        pop r\param
    .endr
    out SREG, r15
    ret
