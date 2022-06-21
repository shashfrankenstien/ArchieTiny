.include "config.inc"                                   ; FS*


; file system (fat-8) - structure is basically very similar to mem.asm
; uses driver/eeprom.asm to read and write
; FS_MAX_CLUSTERS
; - FATFREECTR (1 byte)
;   - this counter tracks the number of free clusters available
;   - intially, this is set to FS_MAX_CLUSTERS
;
; - file allocation table / FAT (FAT_BYTE_SIZE bytes)
;        |_________|
;        |_________| --> FATFREECTR
;        |         | --> FAT index 0 (FAT_START) - 2 byte entries
;        |         |     .
;        |         |     .
;        |         |     .
;        |_________|     FAT index FAT_BYTE_SIZE (FAT_END - 1)
;        |         | --> start of fs clusters (FAT_END)
;
;   - this implementation of FAT is set of doubly linked lists. this makes it easier/faster to scroll (thinking i2c in the future)
;   - a pair of bytes in the FAT are indexed starting with 0 and counting up to FS_MAX_CLUSTERS
;   - each pair corresponds to a cluster of memory of the same index
;   - first byte is the index of previous cluster (PREV_IDX), and second byte is the index of next cluster (NEXT_IDX)
;      -------------------------------------------
;      | PREV_IDX(1) | NEXT_IDX(1) | .......
;      -------------------------------------------
;   - the cluster at the corresponding index is free if the value of both bytes (PREV_IDX and NEXT_IDX) are FAT_FREE_CLUSTER_VAL
;   - if the value of both bytes are FAT_END_CLUSTER_VAL, it means that one cluster of data is allocated at the index
;   - if the value of either byte is any other number, that number is the index of the prev/next cluster of the allocated disk space
;       - the first cluster in a chain of clusters has PREV_IDX value of FAT_END_CLUSTER_VAL
;       - a chain of clusters terminate when the NEXT_IDX value is FAT_END_CLUSTER_VAL
.equ    FAT_FREE_CLUSTER_VAL,         0xff
.equ    FAT_END_CLUSTER_VAL,          0xfe
;
; dirent
; - directories make up a tree structure across the file system
; - when formatted, the fs will have the first cluster allocated to be the root directory
; - the root directory may contain entries to more directories
; - directory entry cluster - 10 bytes per entry -> 2 entries per cluster of 20 bytes
;      --------------------------------------------------
;      | SIGNATURE(1) |     NAME(8)     | START_ADDR(1) |
;      --------------------------------------------------
;       - NAME (8 bytes)
;       - SIGNATURE (1 byte) -> information about the item (is_directory, read_only flags, external mount info)
;       - START_ADDR (1 byte) -> cluster address of the first cluster. use FAT to find additional clusters
; - unlike typical FAT file systems, directory clusters do not have a '.' or '..' entry (to save space)
;       instead, the caller should save parent directory pointers before opening a file or subdirectory
.equ    FS_DIR_ENTRY_SIZE,            10
.equ    FS_DIR_ENTRY_NAME_MAX_LEN,    8
;
; fs pointers
; - to avoid 16 bit math, fs subroutines work on a pair of values
; - when reading raw data (file / directory names or file contents):
;       - r16 points to cluster index (possible values: 0 to FS_MAX_CLUSTERS - 1)
;       - r17 points to byte index within cluster (possible values: 0 to FS_CLUSTER_SIZE - 1)
; - for directory related operations:
;       - r16 will contain index to starting cluster
;       - r17 will be used to index an item within a directory (may span across clusters. max is 256 items in a dir??)
;             - also, r17 index needs to skip over deleted items??? Ugh
;
; signature byte
;      --------------------------------------------------------------------------------------------------
;      |  IS_EXT_MOUNT  |  N/A  |  N/A  |  N/A  |  N/A  |  FS_IS_DIR  |  FS_IS_DELETED  |  FS_IS_ENTRY  |
;      --------------------------------------------------------------------------------------------------
.equ    FS_IS_ENTRY,                   0               ; this bit is always set -> purely to avoid a 0x00 signature
.equ    FS_IS_DELETED,                 1
.equ    FS_IS_DIR,                     2

.equ    FS_DIR_SIGNATURE,           (1<<FS_IS_ENTRY) | (1<<FS_IS_DIR)
.equ    FS_FILE_SIGNATURE,          (1<<FS_IS_ENTRY) | (0<<FS_IS_DIR)



fs_format:
    .irp param,16,17,24,25
        push r\param
    .endr

    ldi r24, lo8(FAT_END)                      ; load address low byte into register pair r25:r24
    ldi r25, hi8(FAT_END)                      ; load address high byte into register pair r25:r24
    clr r16
    rcall eeprom_update                        ; set cluster as allocated, but empty by setting the first byte to 0

    ldi r24, lo8(FAT_START)                    ; load address low byte into register pair r25:r24
    ldi r25, hi8(FAT_START)                    ; load address high byte into register pair r25:r24
    ldi r16, FAT_END_CLUSTER_VAL               ; create empty root directory
    rcall eeprom_update                        ; update PREV_IDX
    adiw r24, 1
    rcall eeprom_update                        ; update NEXT_IDX

    ldi r17, FAT_BYTE_SIZE - 2                 ; iterate through FAT (first cluster is occupied by root dir)
    ldi r16, FAT_FREE_CLUSTER_VAL
_fs_format_wipe:
    adiw r24, 1                                ; go to next address
    rcall eeprom_update                        ; wipe FAT
    dec r17
    brne _fs_format_wipe

    ldi r16, FS_MAX_CLUSTERS - 1               ; intially, this is set to FS_MAX_CLUSTERS - 1 (first cluster is occupied by root dir)
    ldi r24, lo8(FATFREECTR)
    ldi r25, hi8(FATFREECTR)
    rcall eeprom_update

    .irp param,25,24,17,16
        pop r\param
    .endr
    ret





; fs_raw_read takes cluster index in r16 and byte index in r17
; returns read value in r18
fs_raw_read:
    .irp param,16,24,25
        push r\param
    .endr

    rcall internal_fs_cluster_idx_to_raw

    add r24, r17
    clr r18
    adc r25, r18
    rcall eeprom_read
    mov r18, r16                                ; return valu in r18

    .irp param,25,24,16
        pop r\param
    .endr
    ret






; create a new directory
;   - take a pointer to the parent directory cluster in r16
;   - we also need the name (limited to 8 bytes) - sounds like a job for malloc pointer in r17
fs_dir_make:
    push r18
    ldi r18, FS_DIR_SIGNATURE
    rcall internal_fs_create_item
    pop r18
    ret


; is the wrapper necessary?
;   - take a pointer to the parent directory cluster in r16
;   - take index to item in r17
fs_dir_remove:
    rcall internal_fs_remove_item
    ret



; the action of opening a directory
;   - takes a parent directory starting cluster index in r16
;   - takes index of the directory to be opened in r17
;   - checks if the entry is a directory using the signature
;   - return the directory starting cluster index in r16
fs_dir_open:
    ret









; translates cluster index to FAT table entry address (r25:r24)
internal_fs_cluster_idx_to_fat:
    push r16
    push r17

    clr r17
    lsl r16                                 ; multiply by 2 since each FAT entry is 2 bytes
    rol r17

    ldi r24, lo8(FAT_START)
    ldi r25, hi8(FAT_START)
    add r24, r16                            ; load r25:r24 with index
    adc r25, r17

    pop r17
    pop r16
    ret


; translates cluster index in r16 to eeprom fs address (r25:r24) compatible with eeprom_read, eeprom_write, eeprom_update
internal_fs_cluster_idx_to_raw:
    push r16
    push r17
    ldi r17, FS_CLUSTER_SIZE
    rcall mul8

    ldi r24, lo8(FAT_END)
    ldi r25, hi8(FAT_END)

    add r24, r16
    adc r25, r17

    pop r17
    pop r16
    ret


; translates cluster index in r16 and directory item index in r17
;   - to eeprom fs address (r25:r24) compatible with eeprom_read, eeprom_write, eeprom_update
;   - returns signature byte in r16
internal_fs_dir_item_idx_to_raw:
    push r17
    push r18
    push r19
    push r20

    mov r19, r16                            ; save cluster index for later
    rcall internal_fs_cluster_idx_to_raw

    ldi r18, FS_DIR_ENTRY_SIZE
    inc r17
_fs_dir_item_to_raw_index_next_cluster:
    clr r20
_fs_dir_item_to_raw_index:
    rcall eeprom_read                       ; read signature byte
    tst r16
    breq _fs_dir_item_not_found

    sbrs r16, FS_IS_DELETED
    dec r17

    tst r17
    breq _fs_dir_item_found

    clr r16
    add r24, r18
    adc r25, r16
    inc r20
    cpi r20, (FS_CLUSTER_SIZE / FS_DIR_ENTRY_SIZE)
    brne _fs_dir_item_to_raw_index

    ; go to new cluster. hmmmm
    mov r16, r19
    rcall internal_fs_cluster_idx_to_fat
    adiw r24, 1
    rcall eeprom_read                       ; read NEXT_IDX
    cpi r16, FAT_END_CLUSTER_VAL
    brsh _fs_dir_item_not_found             ; checks for both FAT_END_CLUSTER_VAL and FAT_FREE_CLUSTER_VAL

    mov r19, r16                            ; save cluster index for later
    rcall internal_fs_cluster_idx_to_raw    ; go to new cluster
    rjmp _fs_dir_item_to_raw_index_next_cluster

_fs_dir_item_not_found:
    clr r16
    ldi r24, 0xff
    ldi r25, 0xff

_fs_dir_item_found:
    pop r20
    pop r19
    pop r18
    pop r17
    ret







; takes index to previous cluster in r16
;   - if no previous cluster, r16 much contain FAT_END_CLUSTER_VAL
; searches and allocates 1 cluster
;   - the cluster at the corresponding index is free if the value of both FAT bytes (PREV_IDX and NEXT_IDX) are FAT_FREE_CLUSTER_VAL
;       so it's probably okay just to check 1 byte (PREV_IDX) to determine that a cluster is free
; returns raw address in r25:r24 and cluster index in r16
internal_fs_search_alloc_cluster:
    push r17
    push r18

    push r16                                   ; store input in stack

    ldi r24, lo8(FATFREECTR)
    ldi r25, hi8(FATFREECTR)
    rcall eeprom_read
    mov r18, r16
    tst r16
    brne _fs_util_search_start

_fs_util_search_error:
    ldi r24, 0xff
    ldi r25, 0xff
    ldi r16, 0xff
    rjmp _fs_util_search_cluster_done

_fs_util_search_start:
    ldi r24, lo8(FAT_START)                    ; load address low byte into register pair r25:r24
    ldi r25, hi8(FAT_START)                    ; load address high byte into register pair r25:r24

    clr r17
_fs_util_search_next:
    rcall eeprom_read
    cpi r16, FAT_FREE_CLUSTER_VAL
    breq _fs_util_search_cluster_found

    adiw r24, 2                                ; go to next FAT entry
    inc r17
    cpi r17, FS_MAX_CLUSTERS
    brne _fs_util_search_next

    rjmp _fs_util_search_error                 ; free cluster not found

_fs_util_search_cluster_found:
    pop r16                                    ; retrieve prev cluster index input
    rcall eeprom_update                        ; r25:r24 are now pointing to the new clusted in FAT. update r16 into PREV_IDX

    cpi r16, FAT_END_CLUSTER_VAL
    breq _fs_util_search_prev_cluster_done

    ; if r16 was not FAT_END_CLUSTER_VAL, write new index in previous cluster NEXT_IDX byte
    rcall internal_fs_cluster_idx_to_fat       ; convert r16 to FAT address (previous cluster)
    adiw r24, 1
    mov r16, r17
    rcall eeprom_update                        ; update previous cluster NEXT_IDX byte
    rcall internal_fs_cluster_idx_to_fat       ; convert r16 to FAT address (new cluster)

_fs_util_search_prev_cluster_done:
    adiw r24, 1
    ldi r16, FAT_END_CLUSTER_VAL               ; mark FAT entry as occupied
    rcall eeprom_update                        ; update NEXT_IDX with FAT_END_CLUSTER_VAL

    ldi r24, lo8(FATFREECTR)
    ldi r25, hi8(FATFREECTR)
    mov r16, r18
    dec r16
    rcall eeprom_update                        ; decrement FATFREECTR

    mov r16, r17
    rcall internal_fs_cluster_idx_to_raw       ; set r25:r24 to raw address of the cluster

    clr r16
    rcall eeprom_update                        ; set cluster as allocated, but empty by setting the first byte to 0

    mov r16, r17                               ; restore index return value into r16

_fs_util_search_cluster_done:
    pop r18
    pop r17
    ret





; can be used to create files or directories
; to create a new item, we
;   - take a pointer to the parent directory cluster in r16
;   - we also need the name (limited to 8 bytes) - sounds like a job for malloc pointer in r17
;   - take signature in r18
; first, we need to make room in the parent directory for the new entry
internal_fs_create_item:
    .irp param,17,18,19,20,21,22,24,25
        push r\param
    .endr

    mov r20, r16                                ; save parent directory cluster index for later

    ldi r16, FAT_END_CLUSTER_VAL
    rcall internal_fs_search_alloc_cluster      ; allocate a new cluster for the new item

    cpi r16, 0xff
    breq _fs_create_item_done ; NOT!

    mov r19, r16                                ; save newly allocated cluster index in r19
    mov r16, r20                                ; restore parent directory cluster index to r16

_fs_create_item_find_end_cluster:
    mov r20, r16
    rcall internal_fs_cluster_idx_to_fat
    adiw r24, 1                                 ; just read the next address
    rcall eeprom_read
    cpi r16, FAT_END_CLUSTER_VAL
    brlo _fs_create_item_find_end_cluster       ; checks for both FAT_END_CLUSTER_VAL and FAT_FREE_CLUSTER_VAL

    mov r16, r20                                ; r20 now has last cluster index of the parent directory
    rcall internal_fs_cluster_idx_to_raw

    ldi r21, FS_DIR_ENTRY_SIZE                  ; look for bottom of the directory contents
    clr r22
_fs_create_item_find_slot:
    rcall eeprom_read                           ; read signature byte
    tst r16
    breq _fs_create_item_slot_found

    add r24, r21
    clr r16
    adc r25, r16
    inc r22
    cpi r22, (FS_CLUSTER_SIZE / FS_DIR_ENTRY_SIZE)
    brne _fs_create_item_find_slot

    ; no free slots. need to extend the directory to a new cluster
    mov r16, r20
    rcall internal_fs_search_alloc_cluster
    cpi r16, 0xff
    breq _fs_create_item_done ; NOT!

_fs_create_item_slot_found:
    mov r16, r18                               ; write signature byte
    rcall eeprom_write                         ; eeprom contains 0 at this address. so use eeprom_write instead of eeprom_update
    adiw r24, 1

    mov r16, r17                               ; get pointer to name
    ldi r18, FS_DIR_ENTRY_NAME_MAX_LEN
_fs_create_item_write_name:
    rcall mem_load
    rcall mem_pointer_inc

    mov r21, r16                               ; save pointer
    mov r16, r17
    rcall eeprom_write
    adiw r24, 1
    mov r16, r21                               ; save pointer

    tst r17
    breq _fs_create_item_write_name_done

    dec r18
    brne _fs_create_item_write_name

_fs_create_item_write_name_done:
    tst r18
    breq _fs_create_item_write_addr
    dec r18                                    ; if r18 hasn't reached 0, that means a '\0' string was encountered. so we need to dec r18 once and add to r25:r24
    add r24, r18
    clr r18
    adc r25, r18

_fs_create_item_write_addr:
    mov r16, r19
    rcall eeprom_write                         ; use eeprom_write instead of eeprom_update

    cpi r22, (FS_CLUSTER_SIZE / FS_DIR_ENTRY_SIZE) - 1
    breq _fs_create_item_done

    adiw r24, 1
    clr r16
    rcall eeprom_update
    mov r16, r19

_fs_create_item_done:
    .irp param,25,24,22,21,20,19,18,17
        pop r\param
    .endr
    ret








; can be used to remove files or directories
; to remove an item, we
;   - take a pointer to the parent directory cluster in r16
;   - take item index in r17
; first, we need to remove allocated cluster, then check if any clusters can be freed in the parent
internal_fs_remove_item:
    .irp param,16,17,18,24,25
        push r\param
    .endr

    push r16
    ldi r24, lo8(FATFREECTR)
    ldi r25, hi8(FATFREECTR)
    rcall eeprom_read
    mov r18, r16
    pop r16

    cpi r18, FS_MAX_CLUSTERS - 1                ; excluding root directory
    brsh _fs_remove_item_done ; NOT!

    rcall internal_fs_dir_item_idx_to_raw

    tst r16                                     ; test signature byte
    breq _fs_remove_item_done ; NOT!

    ori r16, (1<<FS_IS_DELETED)
    rcall eeprom_write

    adiw r24, FS_DIR_ENTRY_NAME_MAX_LEN + 1
    rcall eeprom_read

_fs_remove_item_clean_fat:
    rcall internal_fs_cluster_idx_to_fat
    ldi r16, FAT_FREE_CLUSTER_VAL
    rcall eeprom_write
    adiw r24, 1                                 ; read NEXT_IDX
    rcall eeprom_read
    mov r17, r16
    ldi r16, FAT_FREE_CLUSTER_VAL
    rcall eeprom_write
    mov r16, r17
    inc r18
    cpi r16, FAT_END_CLUSTER_VAL
    brlo _fs_remove_item_clean_fat              ; checks for both FAT_END_CLUSTER_VAL and FAT_FREE_CLUSTER_VAL

    ldi r24, lo8(FATFREECTR)
    ldi r25, hi8(FATFREECTR)
    mov r16, r18
    rcall eeprom_write

_fs_remove_item_done:
    .irp param,25,24,18,17,16
        pop r\param
    .endr
    ret
