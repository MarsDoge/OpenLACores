#
# Copyright (c) 2026 Loongson Technology Corporation Limited. 
#
# OpenLACores is licensed under Mulan PSL v2.
#
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# 
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
#
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
#
# See the Mulan PSL v2 for more details.
#

if {$argc < 3 || $argc > 4} {
    error "usage: jtag_axi_access.tcl read <address> <word-count> | write <address> <data> <word-count>"
}

set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir hardware_config.tcl]
set hardware_config [fpga_hardware_config]
dict with hardware_config {}

proc impl3_access_normalize_hex {value} {
    set normalized [string tolower [string map [list _ ""] [string trim $value]]]
    if {[string first "0x" $normalized] == 0} {
        set normalized [string range $normalized 2 end]
    }
    if {![regexp {^[0-9a-f]+$} $normalized]} {
        error "invalid hexadecimal value: $value"
    }
    return $normalized
}

proc impl3_access_read {
    hw_axi address word_count transaction_name word_bytes word_hex_digits
} {
    set transaction [create_hw_axi_txn $transaction_name $hw_axi \
        -address $address -len $word_count -burst INCR -type read]
    set read_failed [catch {
        run_hw_axi $transaction
        set report [report_hw_axi_txn $transaction \
            -w [expr {$word_count * $word_bytes}] -t x$word_bytes]
    } read_error]
    catch {delete_hw_axi_txn $transaction}
    if {$read_failed} {
        error $read_error
    }
    set fields $report
    if {[llength $fields] != ($word_count + 1)} {
        error "unexpected JTAG AXI read report: $report"
    }
    set words {}
    foreach field [lrange $fields 1 end] {
        set word [impl3_access_normalize_hex $field]
        if {[string length $word] != $word_hex_digits} {
            error "unexpected JTAG AXI word '$field'"
        }
        lappend words $word
    }
    return $words
}

set operation [string tolower [lindex $argv 0]]
set address [impl3_access_normalize_hex [lindex $argv 1]]
if {$operation eq "read"} {
    if {$argc != 3} {
        error "read usage: jtag_axi_access.tcl read <address> <word-count>"
    }
    set word_count [lindex $argv 2]
    set write_data ""
} elseif {$operation eq "write"} {
    if {$argc != 4} {
        error "write usage: jtag_axi_access.tcl write <address> <data> <word-count>"
    }
    set write_data [impl3_access_normalize_hex [lindex $argv 2]]
    set word_count [lindex $argv 3]
} else {
    error "operation must be read or write"
}

if {![string is integer -strict $word_count] ||
    $word_count < 1 || $word_count > $upload_transaction_words} {
    error "word-count must be an integer from 1 through $upload_transaction_words"
}
set address_value [expr "0x$address"]
if {$address_value < 0 || $address_value >= (1 << $jtag_addr_width)} {
    error "address is outside the $jtag_addr_width bit JTAG AXI address space"
}
if {$address_value % $jtag_word_bytes != 0} {
    error "address must be $jtag_word_bytes-byte aligned: 0x$address"
}
if {$operation eq "write" &&
    [string length $write_data] != ($word_count * $jtag_word_hex_digits)} {
    error "write data must contain exactly [expr {$word_count * $jtag_word_hex_digits}] hexadecimal digits"
}

set_param xicom.use_bitstream_version_check false
set_param messaging.defaultLimit 100000
set hw_device [fpga_connect_hw_device $hardware_config]
refresh_hw_device $hw_device
set hw_axi [fpga_get_hw_axi $axi_name]
reset_hw_axi $hw_axi

if {$operation eq "write"} {
    set transaction [create_hw_axi_txn impl3_access_write $hw_axi \
        -address $address -data $write_data -len $word_count \
        -burst INCR -type write]
    set write_failed [catch {run_hw_axi $transaction} write_error]
    catch {delete_hw_axi_txn $transaction}
    if {$write_failed} {
        error $write_error
    }
    set observed [join [lreverse [impl3_access_read \
        $hw_axi $address $word_count impl3_access_verify \
        $jtag_word_bytes $jtag_word_hex_digits]] ""]
    if {$observed ne $write_data} {
        error "JTAG AXI write readback mismatch: wrote $write_data, read $observed"
    }
    puts "INFO: JTAG AXI write/readback passed at 0x$address"
}

set words [impl3_access_read \
    $hw_axi $address $word_count impl3_access_read \
    $jtag_word_bytes $jtag_word_hex_digits]
set index 0
set address_hex_digits [expr {$jtag_addr_width / 4}]
foreach word $words {
    puts [format "JTAG_AXI_READ 0x%0*x = 0x%s" \
        $address_hex_digits \
        [expr {$address_value + $index * $jtag_word_bytes}] $word]
    incr index
}

close_hw_target
disconnect_hw_server
close_hw_manager
