.include "config.inc"                                   ; TASK_RAM_START, TASKCTS, TASKPTR, TASK_MAX_TASKS, TASK_STACK_SIZE
                                                        ; TASK_SP_VECTOR, TASK_STACKS_TOP

; Task Manager (SRAM)
;         _________
;        |_________| --> TASKCTS - task counter and status register (1)
;        |_________| --> TASKPTR - current task index / pointer (1)
;        |_________| --> task stack pointers vector (TASK_MAX_TASKS*2)
;        |         | --> task stack 1 (TASK_STACK_SIZE)
;        |_________|
;        |         | --> task stack 2 (TASK_STACK_SIZE)
;             .
;             .
;
; TASKCTS - task counter and status register (1)
;   - register holds task manager status in top 4 bits and a task counter in the bottom 4
;      ----------------------------------------------------------------------
;      | RUNNING | FULL | EMPTY | ERROR | COUNT3 | COUNT2 | COUNT1 | COUNT0 |
;      ----------------------------------------------------------------------

; TASKCTS bits
.equ    RUNNING,                7
.equ    FULL,                   6
.equ    EMPTY,                  5
.equ    ERROR,                  4
.equ    COUNT3,                 3
.equ    COUNT2,                 2
.equ    COUNT1,                 1
.equ    COUNT0,                 0

; task stack pointers vector (TASK_MAX_TASKS*2)
;   - TASK_MAX_TASKS words (TASK_MAX_TASKS*2 bytes) each contain a stack pointer per task
;   - a zero in this place indicates that a task stack is free
;
;        |_________|
;        |         | --> stack pointer of task 0
;        |         |     .
;        |         |     .
;        |         |     .
;        |_________|     stack pointer of task TASK_MAX_TASKS
;        |         | --> start of task stacks of TASK_STACK_SIZE bytes each


; Task stack (SRAM)
;
;        |_________| --> stack pointers vector
;        |         | --> start of task stacks of TASK_STACK_SIZE bytes each
;        |         |
;        |         |
;        |         |
;        |         |
;        |         |
;        |_________|
;        |         | --> manager pushed registers (18)
;        |         |
;        |_________|
;        |_________| --> SREG
;        |         | --> task pushed registers
;        |_________|
;        |_________| --> function pointer (2) [popped as soon as task starts]
;        |_________| --> return addr (2)
;        |         | --> next task stack

; manager pushed registers (18)
;   - r0,r1,r16,r17,r18,r19,r20,r21,r22,r23,r24,r25,r26,r27,r28,r29,r30,r31
;   - task manager stores and restores the above list of registers during task swapping
;   - registers r2 through r15 can be used for sharing data between tasks
;       see global register variables - https://gcc.gnu.org/onlinedocs/gcc-4.6.1/gcc/Global-Reg-Vars.html#Global-Reg-Vars


taskmanager_init:
    push r16
    push r17
    push r26
    push r27

    clr r16
    sts TASKCTS, r16                                    ; initialize task counter to 0
    sts TASKPTR, r16                                    ; initialize current task pointer to 0

    ldi r26, lo8(TASK_SP_VECTOR)                        ; set XL to start of task stack pointers vector
    ldi r27, hi8(TASK_SP_VECTOR)                        ; set XH to start of task stack pointers vector

    ldi r17, TASK_MAX_TASKS * 2
_taskmanager_init_wipe:
    st X+, r16                                         ; initialize task stack addrs vector to 0s
    dec r17
    brne _taskmanager_init_wipe

    pop r27
    pop r26
    pop r17
    pop r16
    ret



taskmanager_add:                                ; expects task address loaded in r17:r16
    .irp param,15,18,19,22,23,24,26,27,28,29
        push r\param
    .endr
    in r15, SREG

    clr r24                                     ; r24 will be our NULL register (will be 0 throughout this routine)

    lds r22, TASKCTS
    sbrc r22, FULL                              ; test if tasm manager is full
    rjmp _no_slots_found

    ldi r26, lo8(TASK_SP_VECTOR)                ; set XL to start of task stack pointers vector
    ldi r27, hi8(TASK_SP_VECTOR)                ; set XH to start of task stack pointers vector

    ldi r28, lo8(TASK_STACKS_TOP)               ; set YL to the start of task stacks
    ldi r29, hi8(TASK_STACKS_TOP)               ; set YH to the start of task stacks

    clr r22                                     ; clear r22 to be used as task sp vector index
    ldi r23, TASK_STACK_SIZE                    ; setup Y pointer stack jump range

_look_for_slot:
    ld r18, X+
    ld r19, X+

    tst r18
    brne _next_slot
    tst r19
    brne _next_slot

    rjmp _slot_found

_next_slot:
    add r28, r23                            ; move Y to next task stack
    adc r29, r24                            ; include any carry to the high byte by adding 0 with carry
    inc r22
    cpi r22, TASK_MAX_TASKS                 ; if r22 reached max allowed tasks, exit
    breq _no_slots_found

    rjmp _look_for_slot

_slot_found:
    sbiw r26, 2                                 ; move X back 2 bytes to reach the slot

    ldi r23, TASK_STACK_SIZE -1 -3 -18 -1 -1    ; finding where the stack pointer should point -
                                                ;   -1 to reach the last byte
                                                ;   -3 from there to allow for 4 bytes to be filled (entry and return addresses)
                                                ; registers will be popped as soon as the task starts (.irp param,0,1,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31)
                                                ;   -18 bytes for these registers => len([0,1,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31])
                                                ;   -1 for SREG
                                                ;   -1 because the SP should point to the next location
    add r28, r23                                ; add this offset to the start of stack
    adc r29, r24                                ; this is the address contained in our new stack pointer

    st X+, r28                                  ; store the stack pointer low and high bytes
    st X, r29

    clr r23
    ldi r22, 18 + 1 + 1
_taskmanager_add_clr_reg_spaces:
    st Y+, r23                              ; clear spaces for registers
    dec r22                                 ;   +18 bytes for these registers => len([0,1,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31])
    brne _taskmanager_add_clr_reg_spaces    ;   +1 byte for SREG
                                            ;   +1 because the SP will be point to the next location

    st Y+, r17                              ; store function entry point address high and low bytes
    st Y+, r16                              ; note - stack should be in reverse

    ldi r18, hi8(pm(_taskmanager_task_complete))  ; store function final return address high and low bytes
    ldi r19, lo8(pm(_taskmanager_task_complete))  ; store function final return address high and low bytes

    st Y+, r18
    st Y, r19

    lds r16, TASKCTS                        ; don't forget to increment task counter
    inc r16
    cbr r16, (1<<EMPTY)                     ; clear EMPTY bit in TASKCTS
    sts TASKCTS, r16

    mov r17, r16                            ; copy current counter
    andi r16, 0x0f                          ; keep the low bits TASKCTS[3:0]
    cpi r16, TASK_MAX_TASKS                 ; check if counter has reached TASK_MAX_TASKS
    brne _slot_assigned                     ; if not reached yet, finish up and return

    sbr r17, (1<<FULL)                      ; if counter has reached TASK_MAX_TASKS, set the FULL flag in TASKCTS
    sts TASKCTS, r17

_slot_assigned:
    clr r16                                 ; indicate to the calling function that everything went okay
    rjmp _add_done

_no_slots_found:
    ldi r16, 1                              ; indicate to the calling function that task could not be created

_add_done:
    clr r17
    out SREG, r15
    .irp param,29,28,27,26,24,23,22,19,18,15
        pop r\param
    .endr
    ret





_get_sp_slot_addr_in_X:                ; takes a task index in r16,
                                      ; returns corresponding task stack pointer slot addr in X
    push r16

    ldi r26, lo8(TASK_SP_VECTOR)      ; set XL to start of task stack pointer vector
    ldi r27, hi8(TASK_SP_VECTOR)      ; set XH to start of task stack pointer vector
    add r16, r16                      ; r16 = r16 * 2 -> because address slots are words
    clc
    add r26, r16                      ; move X pointer to vector table address
    clr r16
    adc r27, r16

    pop r16
    ret


taskmanager_exec_next_isr:
    .irp param,16,17
        push r\param
    .endr
    in r5, SREG

    lds r16, TASKCTS
    mov r17, r16
    andi r17, 0x0f                  ; only see low 4 bits of task counter
    cpi r17, 0                      ; if TASKCTS[3:0] is 0, no tasks are registered
    brne _tasks_available

_no_action_required:
    out SREG, r5
    .irp param,17,16                ; unwind
        pop r\param
    .endr
    rjmp _tasks_done                ; return

_tasks_available:
    sbrc r16, RUNNING               ; if RUNNING bit of r16 is clear, then the task manager is not yet running
    rjmp _check_swap_required       ; if task manager has been running, we check if task swapping is required

    sbr r16, (1<<RUNNING)           ; we run the following code only on the first call of this routine
    sts TASKCTS, r16                ; set RUNNING bit in TASKCTS to flag that the first call has been handled
    lds r16, TASKPTR
    rjmp _start_next_task

_check_swap_required:               ; we reach here starting from the second call of this routine
    cpi r17, 2                      ; r17 contains low 4 bits of task counter (TASKCTS[3:0]). if there is only 1 registered task, no task swapping is required
    brsh _save_running_task         ; if there are 2 or more tasks registered, jump to save current task and start the next task

    rjmp _no_action_required        ; there's only 1 registered task. so go to clean up section and finish

_save_running_task:
    .irp param,17,16                ; unwind and prepare to save data to stack
        pop r\param
    .endr

    push r5                         ; store SREG
    .irp param,0,1,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
        push r\param                ; store r0, r1 and all registers r16 and above
    .endr                           ; rest are not stored in order to conserver space

    lds r16, TASKPTR
    rcall _get_sp_slot_addr_in_X

    in r17, SPL                     ; read in current stack pointer low
    st X+, r17                      ; store stack pointer at the vector
    in r17, SPH
    st X, r17

    inc r16                         ; go to next task

_start_next_task:                   ; r16 contains pointer to the next task's address
    cpi r16, TASK_MAX_TASKS         ; check if end is reached (overflowed)
    brlo _check_addr
    clr r16                         ; if overflowed, reset to 0
_check_addr:
    rcall _get_sp_slot_addr_in_X

    ld r18, X+                      ; read stack pointer from vector
    ld r19, X                       ; load r19:r18 with the value of the stack pointer

    cpi r18, 0                      ; if stack pointer is not 0, then we've found out next task
    brne _addr_avail
    cpi r19, 0
    brne _addr_avail

    inc r16                         ; if we reach here, it means the stack address was 0 (empty)
    rjmp _start_next_task           ; move to the next task until we find one (Oh no!!!!!!! inf loop feels)

_addr_avail:
    sts TASKPTR, r16                ; save the new task index back to TASKPTR

    out SPL, r18
    out SPH, r19

    .irp param,31,30,29,28,27,26,25,24,23,22,21,20,19,18,17,16,1,0
        pop r\param                 ; retrieve r0, r1 and all registers r16 and above
    .endr
    pop r5                          ; retrieve SREG
    out SREG, r5

_tasks_done:
    reti





_taskmanager_task_complete:
    in r26, SPL
    in r27, SPH

    ld r16, X


    lds r16, TASKCTS                ; decrement task counter
    dec r16
    sts TASKCTS, r16

                                    ; TODO: also need to remove task from task vector

_wait_loop:
    sleep
    rjmp _wait_loop
