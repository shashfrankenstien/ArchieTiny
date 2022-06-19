.include "config.inc"                                   ; MALLOC*


; dynamic heap memory management
;
; - MALLOCFREECTR (1 byte)
;   - this counter tracks the number of free blocks available
;   - intially, this is set to MALLOC_MAX_BLOCKS
;
; - malloc table (MALLOC_TABLE_SIZE bytes)
;        |_________|
;        |_________| --> MALLOCFREECTR
;        |         | --> malloc table index 0 (MALLOC_TABLE_START)
;        |         |     .
;        |         |     .
;        |         |     .
;        |_________|     malloc table index MALLOC_MAX_BLOCKS (MALLOC_TABLE_END - 1)
;        |         | --> start of malloc blocks (MALLOC_TABLE_END)
;
;   - bytes in the malloc table are indexed starting with 0 and counting up to MALLOC_MAX_BLOCKS
;   - each byte corresponds to a block of memory of the same index
;   - if the value of the byte is MEM_FREE_BLOCK_VAL, the block at the corresponding index is free
;   - if the value of the byte is MEM_END_BLOCK_VAL, it means that one block of data is allocated at the index
;   - if the value of the byte is any other number, that number is the index of the next block of the allocated memory
;       - a chain of blocks terminate when the value is MEM_END_BLOCK_VAL
.equ    MEM_FREE_BLOCK_VAL,         0xff
.equ    MEM_END_BLOCK_VAL,          0xfe
;   - during allocation of multiple blocks, the final block is allocated first, all the way up to the first block
;   - this is just because it works with simpler code. should make no other difference
;
; - mallock blocks (MALLOC_BLOCK_SIZE * MALLOC_MAX_BLOCKS bytes)
;   - free RAM is allocated in blocks of MALLOC_BLOCK_SIZE
;   - block chaining is handled by the malloc table
;
;   - min(MALLOC_FREE_RAM, 256) is divided into blocks of MALLOC_BLOCK_SIZE bytes
;       - capped at 256 so that we can use 8 bit pointers and 8 bit MALLOCFREECTR
;
; - MALLOC_MAX_BLOCKS can't be greater than 250 (never gonna happen on this device, but whatever)
;   - MALLOC_MAX_BLOCKS is capped at 250 because the last few address values are used as control bytes in the malloc table (0xff, 0xfe, ..)


mem_init:
    .irp param,16,17,26,27
        push r\param
    .endr

    ldi r16, MALLOC_MAX_BLOCKS
    sts MALLOCFREECTR, r16                     ; intially, this is set to MALLOC_MAX_BLOCKS

    ldi r26, lo8(MALLOC_TABLE_START)           ; load address low byte into X register
    ldi r27, hi8(MALLOC_TABLE_START)           ; load address high byte into X register

    ldi r17, MALLOC_TABLE_SIZE
    ldi r16, MEM_FREE_BLOCK_VAL
_mem_init_wipe:
    st X+, r16                                 ; wipe malloc table
    dec r17
    brne _mem_init_wipe

    .irp param,27,26,17,16
        pop r\param
    .endr
    ret




; allocate memory
; number of bytes required is passed in through r16
mem_alloc:
    .irp param,17,18,19,20,26,27
        push r\param
    .endr

    tst r16
    breq _mem_alloc_failed                     ; bad input value 0

    ldi r17, MALLOC_BLOCK_SIZE
    rcall div8                                 ; dividend (r16) contains number of bytes required

    tst r17                                    ; check if there was any remainder
    breq .+2
    inc r16                                    ; number of required blocks

    lds r17, MALLOCFREECTR
    inc r17
    cp r16, r17
    brsh _mem_alloc_failed                     ; memory is full or insufficient

    dec r17
    sub r17, r16
    sts MALLOCFREECTR, r17                     ; update free blocks counter

    ldi r26, lo8(MALLOC_TABLE_START)           ; load MALLOC_TABLE_START address into X register
    ldi r27, hi8(MALLOC_TABLE_START)

    ldi r18, 0xff                              ; block index -> start at -1, will be incremented to 0 at the beginning of the search
    clr r19                                    ; will hold chain prev block index
    clr r20                                    ; flag to indicate if chain blocks are being allocated
_mem_alloc_find_free_block:
    inc r18
    cpi r18, MALLOC_MAX_BLOCKS                 ; check if we have exhausted malloc table - ideally, this should never run
    breq _mem_alloc_failed

    ld r17, X+                                 ; read value from malloc table
    cpi r17, MEM_FREE_BLOCK_VAL                ; allocate block if free
    brne _mem_alloc_find_free_block

    ; allocate!
    tst r20                                    ; if this is the first block being allocated, write MEM_END_BLOCK_VAL
    brne _mem_alloc_chain_block                ; else, write the previous block index
    ldi r17, MEM_END_BLOCK_VAL
    rjmp _mem_alloc_reserve_block
_mem_alloc_chain_block:
    mov r17, r19                               ; write the previous block index
_mem_alloc_reserve_block:
    ldi r20, 1                                 ; flag that first allocation has been completed
    st -X, r17
    dec r16
    breq _mem_alloc_success                    ; allocated all required blocks

    adiw r26, 1                                ; move up X pointer to the next address
    mov r19, r18                               ; save current block index
    rjmp _mem_alloc_find_free_block            ; look for more!


_mem_alloc_failed:
    ldi r16, 0xff                              ; return 0xff for failure. highly likely this is never going to be a valid pointer
    rjmp _mem_alloc_done

_mem_alloc_success:
    mov r16, r18
    ldi r17, MALLOC_BLOCK_SIZE
    rcall mul8

_mem_alloc_done:
    .irp param,27,26,20,19,18,17
        pop r\param
    .endr
    ret





; free memory
; pointer is passed in r16
; pointer may be at any position of the allocated memory -
;   - free walks forward till the last block
;   - free also walks back till a block that is not referenced by any other block (first block)
mem_free:
    .irp param,17,18,19,20,26,27
        push r\param
    .endr
    clr r18                                    ; acts as 0 for adc command
    lds r20, MALLOCFREECTR

    ldi r17, MALLOC_BLOCK_SIZE
    rcall div8

    mov r17, r16                               ; save current block index for later
    ldi r19, MEM_FREE_BLOCK_VAL

_mem_free_till_end:
    ldi r26, lo8(MALLOC_TABLE_START)           ; load MALLOC_TABLE_START address into X register
    ldi r27, hi8(MALLOC_TABLE_START)

    add r26, r16                               ; jump to block index pointed by r16 (input / MALLOC_BLOCK_SIZE)
    adc r27, r18

    ld r16, X                                  ; read index of next block
    st X, r19                                  ; mark block as free
    inc r20                                    ; indicate that we have gained a free block (stored to MALLOCFREECTR at the end)

    cpi r16, MEM_FREE_BLOCK_VAL
    breq _mem_free_done

    cpi r16, MEM_END_BLOCK_VAL
    brne _mem_free_till_end

    mov r16, r17                               ; restore original block index
_mem_free_till_root:                           ; repeatedly search all blocks for block index in r16 until index is not found (everything is freed)
    ldi r26, lo8(MALLOC_TABLE_START)           ; load MALLOC_TABLE_START address into X register
    ldi r27, hi8(MALLOC_TABLE_START)

    ldi r18, 0xff                              ; block index -> start at -1, will be incremented to 0 at the beginning of the search
_mem_free_search_all:                          ; search all blocks
    inc r18
    cpi r18, MALLOC_MAX_BLOCKS                 ; check if we have exhausted malloc table
    breq _mem_free_done

    ld r17, X+                                 ; read block index
    cp r16, r17                                ; check if it matches index we are looking for
    brne _mem_free_search_all                  ; no match -> go to next block

    st -X, r19                                 ; if matched, mark block as free
    inc r20                                    ; indicate that we have gained a free block (stored to MALLOCFREECTR at the end)
    mov r16, r18                               ; r18 counter contains the block to search for next
    rjmp _mem_free_till_root

_mem_free_done:
    sts MALLOCFREECTR, r20                     ; update free blocks counter

    .irp param,27,26,20,19,18,17
        pop r\param
    .endr
    ret



; increment pointer
; pointer is passed in r16
; if r17 is 0,
; - return 0xff on overflow
; else if r17 is anything else (probably 0x01)
; - automatically allocate 1 new block on overflow
; - return 0xff if a new block allocation failed
internal_mem_pointer_inc:
    .irp param,18,19,26,27
        push r\param
    .endr
    mov r18, r16                                ; save input for later
    mov r19, r17

    ldi r17, MALLOC_BLOCK_SIZE
    rcall div8

    cpi r17, MALLOC_BLOCK_SIZE - 1              ; check if the pointer is at the last byte of the block
    breq _mem_pointer_inc_roll_block            ; if so, we need to roll over to the next allocated block

    mov r16, r18                                ; else, simply increment the input pointer by 1
    inc r16
    rjmp _mem_pointer_inc_done

_mem_pointer_inc_roll_block:
    ldi r26, lo8(MALLOC_TABLE_START)            ; load MALLOC_TABLE_START address into X register
    ldi r27, hi8(MALLOC_TABLE_START)

    clr r18                                     ; acts as 0 for adc command
    add r26, r16                                ; jump to block index pointed by r16 (input / MALLOC_BLOCK_SIZE)
    adc r27, r18

    ld r16, X                                   ; read next block address which is stored in current block index in the malloc table

    cpi r16, MEM_FREE_BLOCK_VAL                 ; if next block address is not valid, fail
    breq _mem_pointer_inc_failed

    cpi r16, MEM_END_BLOCK_VAL                  ; if end of allocated memory reached, allocate 1 new block
    breq _mem_pointer_inc_alloc_block

    ldi r17, MALLOC_BLOCK_SIZE
    rcall mul8                                  ; normalize next block index and return
    rjmp _mem_pointer_inc_done

_mem_pointer_inc_alloc_block:                   ; if r17 input was not 0, try to extend by allocating 1 new block of memory
    tst r19                                     ; input r17 was moved to r19. if this is 0, memory is not extended. return as failed
    breq _mem_pointer_inc_failed

    mov r16, r26                                ; save address to current malloc table entry
    mov r17, r27

    ldi r26, lo8(MALLOC_TABLE_START)            ; load MALLOC_TABLE_START address into X register
    ldi r27, hi8(MALLOC_TABLE_START)

    ldi r18, 0xff                               ; block index -> start at -1, will be incremented to 0 at the beginning of the search
_mem_pointer_inc_find_free_block:
    inc r18
    cpi r18, MALLOC_MAX_BLOCKS                  ; check if we have exhausted malloc table - ideally, this should never run
    breq _mem_pointer_inc_failed

    ld r19, X+                                  ; read value from malloc table
    cpi r19, MEM_FREE_BLOCK_VAL                 ; check if free
    brne _mem_pointer_inc_find_free_block

    ldi r19, MEM_END_BLOCK_VAL
    st -X, r19                                  ; allocate block if free

    mov r26, r16                                ; restore address of previous entry to X
    mov r27, r17
    mov r16, r18                                ; get the new index and store it in previous malloc table entry
    st X, r16

    lds r19, MALLOCFREECTR
    dec r19                                     ; decrement number of free blocks
    sts MALLOCFREECTR, r19                      ; update free blocks counter

    ldi r17, MALLOC_BLOCK_SIZE
    rcall mul8                                  ; normalize next block index and return
    rjmp _mem_pointer_inc_done

_mem_pointer_inc_failed:
    ldi r16, 0xff                               ; indicate failure by returning 0xff

_mem_pointer_inc_done:
    .irp param,27,26,19,18
        pop r\param
    .endr
    ret




; increment pointer
; - return 0xff on overflow
mem_pointer_inc:
    push r17
    clr r17
    rcall internal_mem_pointer_inc
    pop r17
    ret



; increment pointer
; - this routine automatically allocates 1 new block on overflow
; - return 0xff if a new block allocation failed
mem_pointer_inc_realloc:
    push r17
    ldi r17, 1
    rcall internal_mem_pointer_inc
    pop r17
    ret




; ; decrement pointer
; ; pointer is passed in r16
; ; - return input back on overflow
; mem_pointer_dec:
;     .irp param,17,18,19,26,27
;         push r\param
;     .endr
;     mov r19, r16                                ; save input for later

;     ldi r17, MALLOC_BLOCK_SIZE
;     rcall div8

;     cpi r17, 1                                  ; check if the pointer is at the first byte of the block
;     brlo _mem_pointer_dec_roll_block            ; if so, we need to roll over to the prev allocated block

;     mov r16, r18                                ; else, simply decrement the input pointer by 1
;     dec r16
;     rjmp _mem_pointer_dec_done

; _mem_pointer_dec_roll_block:
;     ldi r26, lo8(MALLOC_TABLE_START)           ; load MALLOC_TABLE_START address into X register
;     ldi r27, hi8(MALLOC_TABLE_START)

;     ldi r18, 0xff                              ; block index -> start at -1, will be incremented to 0 at the beginning of the search
; _mem_pointer_dec_search_all:                          ; search all blocks
;     inc r18
;     cpi r18, MALLOC_MAX_BLOCKS                 ; check if we have exhausted malloc table
;     breq _mem_pointer_dec_failed

;     ld r17, X+                                 ; read block index
;     cp r16, r17                                ; check if it matches index we are looking for
;     brne _mem_pointer_dec_search_all           ; no match -> go to next block

;     mov r16, r18                               ; r18 counter contains the block to go to
;     ldi r17, MALLOC_BLOCK_SIZE
;     rcall mul8                                 ; if matched, move pointer to block
;     ldi r17, MALLOC_BLOCK_SIZE - 1
;     add r16, r17
;     rjmp _mem_pointer_dec_done

; _mem_pointer_dec_failed:
;     mov r16, r19

; _mem_pointer_dec_done:
;     .irp param,27,26,19,18,17
;         pop r\param
;     .endr
;     ret




; store a byte r17 at pointer r16
mem_store:
    push r18
    push r26
    push r27

    ldi r26, lo8(MALLOC_TABLE_END)           ; load MALLOC_TABLE_END address into X register
    ldi r27, hi8(MALLOC_TABLE_END)           ; this is the start of malloc blocks

    clr r18                                    ; acts as 0 for adc command
    add r26, r16
    adc r27, r18

    st X, r17

    pop r27
    pop r26
    pop r18
    ret


; load a byte into r17 from pointer r16
mem_load:
    push r18
    push r26
    push r27

    ldi r26, lo8(MALLOC_TABLE_END)           ; load MALLOC_TABLE_END address into X register
    ldi r27, hi8(MALLOC_TABLE_END)           ; this is the start of malloc blocks

    clr r18                                    ; acts as 0 for adc command
    add r26, r16
    adc r27, r18

    ld r17, X

    pop r27
    pop r26
    pop r18
    ret
