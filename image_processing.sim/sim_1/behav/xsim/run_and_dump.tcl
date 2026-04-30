run -all
if {[catch {write_vcd trace.vcd} err]} {
    puts "write_vcd failed: $err"
} else {
    puts "write_vcd ok"
}
exit
