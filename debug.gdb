# set debug infrun 1
# layout next
file build/kernel.elf
target remote: 1234



# b pool
# command
# info r r16
# info r r17
# info r r18
# info r r19
# info r r20
# end


# b on
# command
# # xx
# i r r16
# i r r17
# i r r18
# x/3xb 0x800060
# shell echo $(date +%s.%N) - $(cat gdb_timer) | bc -l
# shell echo $(date +%s.%N) > gdb_timer
# continue
# end
# #
# b off
# command
# # xx
# i r r16
# i r r17
# i r r18
# x/3xb 0x800060
# shell echo $(date +%s.%N) - $(cat gdb_timer) | bc -l
# shell echo $(date +%s.%N) > gdb_timer
# continue
# end
# #
# b test3
# command
# # xx
# i r r16
# i r r17
# i r r18
# i r r19
# i r r20
# i r r21
# x/3xb 0x800060
# end

# b time_tick
# command
# x/3xb 0x800060
# end



# b *main+30
# b time_delay_ms
# b _delay_loop
# command
# i r r16
# i r r17
# i r r18
# x/3xb 0x800060
# end


define xx
    i r SP
    x/32xb 0x800240
    print "head"
    x/16xb 0x800060
    print "data"
    x/110xb 0x80006D
end

define xx2
    i r SP
    x/32xb 0x800240
    print "head"
    x/16xb 0x800060
    print "data"
    x/110xb 0x80006D + 110
end


define xsi
    si
    xx
end

define xni
    ni
    xx
end

define xsi2
    si
    xx2
end


define reg
i r r16
i r r17
i r r18
i r r19
i r r20
i r r21
end


b oled_loop

# b i2c_check_addr
# b *i2c_check_addr+26
# b *i2c_check_addr+36

# set $foo = 0
#
# b stopper_count
# command
# set $foo = $foo + 1
# print $foo
# print $r17 * 256 + $r16
# if $foo * 0xff == $r17 * 256 + $r16
#     continue
# end
