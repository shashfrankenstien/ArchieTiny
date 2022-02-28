# set debug infrun 1
# layout next
file build/main.elf
target remote: 1234

# b main
# command
# info r r16
# info r r17
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
continue
end

b test1_breakpoint
command
info r r16
info r r17
info r r18
info r r19
end
