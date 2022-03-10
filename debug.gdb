# set debug infrun 1
# layout next
file build/main.elf
target remote: 1234

# b blink
# command
# info r r20
# info r r0
# end
#
# b timer0_isr
# command
# info r r20
# info r r0
# end

# b pool
# command
# info r r16
# info r r17
# info r r18
# info r r19
# info r r20
# end


# b timer0_scaled
# command
# info r r16
# shell echo $(date +%s.%N) - $(cat gdb_timer) | bc -l
# shell echo $(date +%s.%N) > gdb_timer
# continue
# end

b on
command
info r r25
shell echo $(date +%s.%N) - $(cat gdb_timer) | bc -l
shell echo $(date +%s.%N) > gdb_timer
continue
end

b off
command
info r r25
shell echo $(date +%s.%N) - $(cat gdb_timer) | bc -l
shell echo $(date +%s.%N) > gdb_timer
x 0x800060
continue
end

b test3
command
info r r20
continue
end

b *main+30
#b taskmanager_exec_next_isr

define xx
    i r SP
    x/32xb 0x800240
    print "head"
    x/16xb 0x800060
    print "data"
    x/64xb 0x800073
end

define xx2
    i r SP
    x/32xb 0x800240
    print "head"
    x/16xb 0x800060
    print "data"
    x/64xb 0x8000b3
end


define xsi
    si
    xx
end

define xsi2
    si
    xx2
end


