.include "config.inc"                                   ; TASK_TABLE_START

; Task Manager (SRAM)
;         _________
;        |_________| --> TASKCTS - task counter and status register (1)
;        |_________| --> TASKPTR - current task index / pointer (1)
;        |_________| --> task frame addrs vector (TASK_MAX_TASKS*2)
;        |         | --> task frame 1 (TASK_FRAME_SIZE)
;        |_________|
;        |         | --> task frame 2 (TASK_FRAME_SIZE)
;             .
;             .
; TASKCTS - task counter and status vector (1)
;   - register holds task manager status in top 4 bits and a task counter in the bottom 4
;      ----------------------------------------------------------------------
;      | Running | Full | Empty | Error | Count3 | Count2 | Count1 | Count0 |
;      ----------------------------------------------------------------------

.equ    TASKCTS,               TASK_TABLE_START            ; task counter and status vector
.equ    TASKPTR,               TASK_TABLE_START + 1        ; Current task pointer
.equ    TASK_ADRS_VECTOR,      TASK_TABLE_START + 2        ; task frame addrs vector (14)


; task frame addrs vector (TASK_MAX_TASKS*2)
;   - TASK_MAX_TASKS words (TASK_MAX_TASKS*2 bytes) each contain an address to a task frame
;   - a zero in this place indicates that a task frame is free

; Task Frame (SRAM)
;         _________
;        |_________| --> stack pointer (2)
;        |         |
;        |         |
;        |         |
;        |         |
;        |         |
;        |         |
;        |_________|
;        |         | --> manager pushed (registers 0,1,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31)
;        |         |
;        |_________|
;        |_________| --> SREG
;        |         | --> task pushed
;        |_________|
;        |_________| --> function pointer (2) [popped as soon as task starts]
;        |_________| --> return addr (2)




taskmanager_init:
    sts TASKCTS, 0x0                               ; initialize task counter to 0
    sts TASKPTR, 0x0                               ; initialize current task pointer to 0
    .irp param,0,1,2,3,4,5,6                            ; initialize task frame addrs vector to 0s
        sts TASK_ADRS_VECTOR + (\param * 2), 0x0
        sts TASK_ADRS_VECTOR + 1 + (\param * 2), 0x0
    .endr
    ret



taskmanager_add:                                ; expects task address loaded in r17:r16
    .irp param,15,18,19,22,23,26,27,28,29
        push r\param
    .endr
    in r15, SREG

    lds r22, TASKCTS
    sbrc r22, 6
    rjmp _no_slots_found

    ldi r26, lo8(TASK_ADRS_VECTOR)              ; set XL to start of task frame addrs vector
    ldi r27, hi8(TASK_ADRS_VECTOR)              ; set XH to start of task frame addrs vector

    movw r28, r26                               ; copy current X-pointer address
    adiw r28, TASK_MAX_TASKS*2                  ; point Y to the start of task frames

    clr r22
    ldi r23, TASK_FRAME_SIZE                    ; setup Y pointer jump range

_look_for_slot:
    ld r18, X+
    ld r19, X+

    tst r18
    brne _next_slot
    tst r19
    brne _next_slot

    rjmp _slot_found

_next_slot:
    add r28, r23                            ; max adiw value is 63, so splitting it up into steps
    adc r29, 0
    inc r22
    cpi r22, TASK_MAX_TASKS                 ; if r22 reached max allowed tasks, exit
    breq _no_slots_found

    rjmp _look_for_slot

_slot_found:
    sbiw r26, 2                             ; go back 2 bytes to reach the slot
    st X+, r28                              ; r29:r28 contains address to the start of the task frame
    st X+, r29                              ; store this address in the slot

    movw r26, r28                               ; set X pointer to thje task frame start address (SP will be stored here)
    ldi r23, TASK_FRAME_SIZE -1 -3 -18 -1 -1    ; finding where the stack pointer should point -
                                                ;   -1 to reach the last byte
                                                ;   -3 from there to allow for 4 bytes to be filled (entry and return addresses)
                                                ; registers will be popped as soon as the task starts (.irp param,0,1,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31)
                                                ;   -18 bytes for these registers => len([0,1,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31])
                                                ;   -1 for SREG
                                                ;   -1 because the SP should point to the next location
    add r28, r23                                ; add this offset to the start of frame
    adc r29, 0                                  ; this is the address contained in our new stack pointer

    st X+, r28                              ; store the stack pointer low and high bytes
    st X, r29

    clr r23
    .rept 18 + 1 + 1
    st Y+, r23                              ; skip locations to start writing entry and return addresses
    .endr
                                            ;   +18 bytes for these registers => len([0,1,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31])
                                            ;   +1 byte for SREG
                                            ;   +1 because the SP will be point to the next location

    lsr r17                                 ; Divide r17:r16 by 2
    ror r16                                 ; division by 2 seems important here
                                            ; because returning seems to be multiplying the value by 2 before calling :/

    st Y+, r17                              ; store function entry point address high and low bytes
    st Y+, r16                              ; note - stack should be in reverse

    ldi r18, hi8(_taskmanager_task_complete)  ; store function final return address high and low bytes
    ldi r19, lo8(_taskmanager_task_complete)  ; store function final return address high and low bytes

    lsr r18                                 ; Divide r17:r16 by 2
    ror r19                                 ; division by 2 seems important here
                                            ; because returning seems to be multiplying the value by 2 before calling :/
    st Y+, r18
    st Y, r19

    lds r16, TASKCTS                        ; don't forget to increment task counter
    inc r16
    sts TASKCTS, r16

    mov r17, r16                            ; copy current counter
    eor r16, 0x0f                           ; keep the low bits TASKCTS[3:0]
    cpi r16, TASK_MAX_TASKS-1               ; check if counter has reached TASK_MAX_TASKS
    brne _slot_assigned                     ; if not reached yet, finish up and return

    sbr r17, (1<<6)                         ; if counter has reached TASK_MAX_TASKS, set the FULL flag in TASKCTS
    sts TASKCTS, r17

_slot_assigned:
    clr r16                                 ; indicate to the calling function that everything went okay
    rjmp _add_done

_no_slots_found:
    ldi r16, 1                              ; indicate to the calling function that task could not be created

_add_done:
    clr r17
    out SREG, r15
    .irp param,29,28,27,26,23,22,19,18,15
        pop r\param
    .endr
    ret





set_Y_to_frame_r16:
    push r26
    push r27
    push r16

    ldi r26, lo8(TASK_ADRS_VECTOR)    ; set XL to start of task frame addrs vector
    ldi r27, hi8(TASK_ADRS_VECTOR)    ; set XH to start of task frame addrs vector
    add r16, r16                      ; r16 = r16 * 2 -> because program memory addresses are in words
    add r26, r16                      ; move X pointer to vector table address
    adc r27, 0

    ld r28, X+                        ; load task frame address using X into Y registers
    ld r29, X

    pop r16
    pop r27
    pop r26
    ret


taskmanager_exec_next_isr:
    .irp param,16,17
        push r\param
    .endr
    in r5, SREG

    lds r16, TASKCTS
    mov r17, r16
    eor r17, 0x0f                   ; only see low 4 bits of counter
    cpi r17, 0                      ; if TASKCTS[3:0] is 0, no tasks are registered
    brne _tasks_available

    out SREG, r5
    .irp param,17,16                ; unwind and prepare to save data to stack
        pop r\param
    .endr
    rjmp _tasks_done                ; return if TASKCTS[3:0] = 0

_tasks_available:

    sbrc r16, 7                     ; if 7th bit of r16 is clear, then the task manager is not yet running
    rjmp _save_running_task

    sbr r16, (1<<7)                 ; set RUNNING bit in TASKCTS
    sts TASKCTS, r16
    lds r16, TASKPTR
    rjmp _start_next_task

_save_running_task:
    .irp param,17,16                ; unwind and prepare to save data to stack
        pop r\param
    .endr

    push r5                         ; store SREG
    .irp param,0,1,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
        push r\param                ; store r0, r1 and all registers r16 and above
    .endr                           ; rest are not stored in order to conserver space

    lds r16, TASKPTR
    rcall set_Y_to_frame_r16

    in r17, SPL                     ; read in current stack pointer low
    st Y+, r17                      ; store stack pointer at the head of the current task frame
    in r17, SPH
    st Y, r17

    inc r16                         ; go to next task

_start_next_task:                   ; r16 contains pointer to the next task's address
    cpi r16, TASK_MAX_TASKS         ; check if end is reached (overflowed)
    brlo _check_addr
    clr r16                         ; if overflowed, reset to 0
_check_addr:
    rcall set_Y_to_frame_r16

    cpi r28, 0                      ; if task frame address is not 0, then we've found out next task
    brne _addr_avail
    cpi r29, 0
    brne _addr_avail

    inc r16                         ; if we reach here, it means the frame address was 0 (empty)
    rjmp _start_next_task           ; move to the next task until we find one (Oh no!!!!!!! inf loop feels)

_addr_avail:
    sts TASKPTR, r16                ; save the new task index back to TASKPTR

    ld r17, Y+
    out SPL, r17
    ld r17, Y
    out SPH, r17

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
