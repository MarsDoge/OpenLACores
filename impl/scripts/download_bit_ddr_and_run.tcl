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

if {$argc < 2 || $argc > 5} {
    error "usage: download_bit_ddr_and_run.tcl <work-path> <payload> ?none|sample|full? ?status-address|none? ?release|hold?"
}

set work_path [file normalize [lindex $argv 0]]
set payload_file [file normalize [lindex $argv 1]]
set verify_mode sample
if {$argc >= 3} {
    set verify_mode [string tolower [lindex $argv 2]]
}
if {$verify_mode ni {none sample full}} {
    error "invalid verification mode '$verify_mode'; expected none, sample, or full"
}
set status_address none
if {$argc >= 4} {
    set status_address [string tolower [lindex $argv 3]]
}
set cpu_action release
if {$argc == 5} {
    set cpu_action [string tolower [lindex $argv 4]]
}
if {$cpu_action ni {release hold}} {
    error "invalid CPU action '$cpu_action'; expected release or hold"
}
if {$cpu_action eq "hold" && $status_address ne "none"} {
    error "a post-run status address cannot be used while CPU reset remains held"
}

set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir hardware_config.tcl]
set hardware_config [fpga_hardware_config]
dict with hardware_config {}

set project_name $default_project_name
if {[info exists ::env(FPGA_PROJECT_NAME)] &&
    [string trim $::env(FPGA_PROJECT_NAME)] ne ""} {
    set project_name $::env(FPGA_PROJECT_NAME)
}
set top_module $default_top_module
if {[info exists ::env(FPGA_TOP_MODULE)] &&
    [string trim $::env(FPGA_TOP_MODULE)] ne ""} {
    set top_module $::env(FPGA_TOP_MODULE)
}
set bit_path [file join $work_path $project_name \
    ${project_name}.runs impl_1 ${top_module}.bit]
set ltx_path [file rootname $bit_path].ltx
foreach required_file [list $bit_path $ltx_path $payload_file] {
    if {![file isfile $required_file]} {
        error "required file does not exist: $required_file"
    }
}

proc impl_normalize_hex {value} {
    set normalized [string tolower [string map [list _ ""] [string trim $value]]]
    if {[string first "0x" $normalized] == 0} {
        set normalized [string range $normalized 2 end]
    }
    return $normalized
}

proc impl_validate_address {address address_width} {
    set normalized [impl_normalize_hex $address]
    if {![regexp {^[0-9a-f]+$} $normalized]} {
        error "invalid hexadecimal payload address: $address"
    }
    set value [expr "0x$normalized"]
    if {$value < 0 || $value >= (1 << $address_width)} {
        error "payload address is outside the $address_width bit address space: $address"
    }
    if {$value < (1 << 32)} {
        set la32_vseg [expr {($value >> 29) & 0x7}]
        if {$la32_vseg == 4 || $la32_vseg == 5} {
            set value [expr {$value & 0x1fffffff}]
            set normalized [format %x $value]
        }
    }
    return [list $normalized $value]
}

proc impl_validate_data {data expected_digits} {
    set normalized [impl_normalize_hex $data]
    if {[string length $normalized] != $expected_digits ||
        ![regexp {^[0-9a-f]+$} $normalized]} {
        error "expected $expected_digits hexadecimal data digits, got [string length $normalized]"
    }
    return $normalized
}

proc impl_next_payload_field {file_handle} {
    while {[gets $file_handle line] >= 0} {
        set line [string trim [lindex [split $line "#"] 0]]
        if {$line ne ""} {
            return [lindex $line 0]
        }
    }
    return ""
}

proc impl_write_words {hw_axi address data word_count transaction_name} {
    set transaction [create_hw_axi_txn $transaction_name $hw_axi \
        -address $address \
        -data $data \
        -len $word_count \
        -burst INCR \
        -type write]
    set run_failed [catch {run_hw_axi $transaction} run_error]
    catch {delete_hw_axi_txn $transaction}
    if {$run_failed} {
        error $run_error
    }
}

proc impl_read_words {
    hw_axi address word_count transaction_name word_bytes word_hex_digits
} {
    set transaction [create_hw_axi_txn $transaction_name $hw_axi \
        -address $address \
        -len $word_count \
        -burst INCR \
        -type read]
    set read_failed [catch {
        run_hw_axi $transaction
        set report [report_hw_axi_txn $transaction \
            -w [expr {$word_count * $word_bytes}] -t x$word_bytes]
    } read_error]
    catch {delete_hw_axi_txn $transaction}
    if {$read_failed} {
        error $read_error
    }

    # report_hw_axi_txn returns one address field followed by address-ascending
    # data fields. The display radix is one complete configured AXI word.
    set fields $report
    if {[llength $fields] != ($word_count + 1)} {
        error "unexpected JTAG AXI read report at 0x$address: $report"
    }
    set words {}
    foreach field [lrange $fields 1 end] {
        set word [impl_normalize_hex $field]
        if {[string length $word] != $word_hex_digits ||
            ![regexp {^[0-9a-f]+$} $word]} {
            error "unexpected JTAG AXI data field '$field' at 0x$address"
        }
        lappend words $word
    }
    return $words
}

proc impl_read_stream {
    hw_axi address word_count transaction_name word_bytes word_hex_digits
} {
    # Vivado's write-data string is high-address word first, whereas the read
    # report lists low addresses first.
    return [join [lreverse [impl_read_words \
        $hw_axi $address $word_count $transaction_name \
        $word_bytes $word_hex_digits]] ""]
}

proc impl_verify_record {
    hw_axi address expected transaction_index transaction_words \
    word_bytes word_hex_digits
} {
    set actual [impl_read_stream \
        $hw_axi $address $transaction_words \
        [format "impl_verify_%s" $transaction_index] \
        $word_bytes $word_hex_digits]
    if {$actual ne $expected} {
        error "DDR readback mismatch in transaction $transaction_index at 0x$address"
    }
}

proc impl_jtag_ddr_sanity_check {
    hw_axi address word_bytes word_hex_digits
} {
    # This address is inside the newly extended impl JTAG/CPU DDR aperture and
    # outside the loader, Linux image, stack, and CSR-test status locations.
    set sanity_word_count [expr {16 / $word_bytes}]
    set original [impl_read_stream \
        $hw_axi $address $sanity_word_count impl_sanity_save \
        $word_bytes $word_hex_digits]
    set pattern fedcba98765432100123456789abcdef
    set test_failed [catch {
        impl_write_words $hw_axi $address $pattern \
            $sanity_word_count impl_sanity_write
        set observed [impl_read_stream \
            $hw_axi $address $sanity_word_count impl_sanity_read \
            $word_bytes $word_hex_digits]
        if {$observed ne $pattern} {
            error "JTAG AXI DDR sanity mismatch at 0x$address: wrote $pattern, read $observed"
        }
    } test_error]
    set restore_failed [catch {
        impl_write_words $hw_axi $address $original \
            $sanity_word_count impl_sanity_restore
    } restore_error]
    if {$restore_failed} {
        error "failed to restore JTAG AXI DDR sanity location 0x$address: $restore_error"
    }
    set restored [impl_read_stream \
        $hw_axi $address $sanity_word_count impl_sanity_restored \
        $word_bytes $word_hex_digits]
    if {$restored ne $original} {
        error "failed to restore JTAG AXI DDR sanity location 0x$address"
    }
    if {$test_failed} {
        error $test_error
    }
    puts "INFO: JTAG AXI DDR write/read/order check passed at 0x$address"
}

proc impl_append_unique_record {records_name seen_name record} {
    upvar 1 $records_name records $seen_name seen
    set address [lindex $record 0]
    if {![dict exists $seen $address]} {
        dict set seen $address 1
        lappend records $record
    }
}

proc impl_upload_payload {
    payload_file hw_axi verify_mode address_width transaction_bytes \
    transaction_words word_bytes word_hex_digits
} {
    set file_handle [open $payload_file r]
    set transaction_count 0
    set seen_addresses [dict create]
    set sample_records {}
    set sample_seen [dict create]
    set previous_record {}
    set previous_address_value ""

    set upload_failed [catch {
        while {1} {
            set raw_address [impl_next_payload_field $file_handle]
            if {$raw_address eq ""} {
                break
            }
            set raw_data [impl_next_payload_field $file_handle]
            if {$raw_data eq ""} {
                error "payload has an address without data: $raw_address"
            }

            lassign [impl_validate_address \
                $raw_address $address_width] address address_value
            if {$address_value % $transaction_bytes != 0} {
                error "payload address is not $transaction_bytes-byte aligned: 0x$address"
            }
            if {[dict exists $seen_addresses $address]} {
                error "duplicate payload address: 0x$address"
            }
            dict set seen_addresses $address 1
            set data [impl_validate_data \
                $raw_data [expr {$transaction_bytes * 2}]]
            set record [list $address $data]

            if {$transaction_count == 0} {
                impl_append_unique_record sample_records sample_seen $record
            } elseif {$address_value !=
                ($previous_address_value + $transaction_bytes)} {
                impl_append_unique_record sample_records sample_seen $previous_record
                impl_append_unique_record sample_records sample_seen $record
            }

            impl_write_words $hw_axi $address $data $transaction_words \
                [format "impl_write_%s" $transaction_count]
            if {$verify_mode eq "full"} {
                impl_verify_record \
                    $hw_axi $address $data $transaction_count \
                    $transaction_words $word_bytes $word_hex_digits
            }

            set previous_record $record
            set previous_address_value $address_value
            incr transaction_count
            if {$transaction_count % 1024 == 0} {
                puts "INFO: Uploaded $transaction_count transactions"
            }
        }
    } upload_error]
    close $file_handle
    if {$upload_failed} {
        error $upload_error
    }

    if {$transaction_count == 0} {
        error "upload payload is empty: $payload_file"
    }
    impl_append_unique_record sample_records sample_seen $previous_record

    if {$verify_mode eq "sample"} {
        set sample_index 0
        foreach record $sample_records {
            lassign $record address data
            impl_verify_record \
                $hw_axi $address $data [format "sample_%s" $sample_index] \
                $transaction_words $word_bytes $word_hex_digits
            incr sample_index
        }
        puts "INFO: Verified [llength $sample_records] boundary transactions"
    } elseif {$verify_mode eq "full"} {
        puts "INFO: Verified all $transaction_count transactions"
    } else {
        puts "WARNING: Payload readback verification is disabled"
    }
    puts "INFO: Uploaded $transaction_count transactions from $payload_file"
}

proc impl_set_cpu_reset {reset_probe value} {
    set_property OUTPUT_VALUE $value $reset_probe
    commit_hw_vio $reset_probe
}

set_param xicom.use_bitstream_version_check false
set_param messaging.defaultLimit 100000
# A Linux payload contains tens of thousands of transactions.  Keep explicit
# progress/error messages while suppressing Vivado's full 1024-byte DATA echo.
catch {set_msg_config -id {Labtoolstcl 44-481} -suppress}
set hw_device [fpga_connect_hw_device $hardware_config]
set_property PROBES.FILE $ltx_path $hw_device
set_property FULL_PROBES.FILE $ltx_path $hw_device
set_property PROGRAM.FILE $bit_path $hw_device
program_hw_devices $hw_device
refresh_hw_device $hw_device
puts "INFO: Programmed $bit_path"

set hw_vios [get_hw_vios -quiet -of_objects $hw_device \
    -filter {CELL_NAME =~ "*xlnx_vio"}]
if {[llength $hw_vios] == 0} {
    error "the programmed $board_name design does not expose xlnx_vio"
}
set reset_probe [get_hw_probes -quiet {*vio_cpu_reset*} \
    -of_objects [lindex $hw_vios 0]]
if {[llength $reset_probe] != 1} {
    error "expected one vio_cpu_reset probe, got [llength $reset_probe]"
}

# CPU reset does not reset DDR, JTAG AXI, or the peripheral fabric in impl.
# Keep it asserted for the entire write/readback interval.
impl_set_cpu_reset $reset_probe 1
puts "INFO: CPU held in VIO reset"
after 1000

set hw_axi [fpga_get_hw_axi $axi_name]
reset_hw_axi $hw_axi

lassign [impl_validate_address \
    $sanity_address $jtag_addr_width] sanity_address sanity_address_value
if {$sanity_address_value % $jtag_word_bytes != 0} {
    error "JTAG AXI sanity address is not word aligned: 0x$sanity_address"
}
impl_jtag_ddr_sanity_check \
    $hw_axi $sanity_address $jtag_word_bytes $jtag_word_hex_digits
impl_upload_payload \
    $payload_file $hw_axi $verify_mode \
    $jtag_addr_width $upload_transaction_bytes $upload_transaction_words \
    $jtag_word_bytes $jtag_word_hex_digits

if {$cpu_action eq "release"} {
    impl_set_cpu_reset $reset_probe 0
    puts "INFO: CPU VIO reset released after successful upload/readback"
} else {
    puts "INFO: CPU remains held in VIO reset after successful upload/readback"
}

if {$status_address ne "none"} {
    lassign [impl_validate_address \
        $status_address $jtag_addr_width] status_address status_value
    if {$status_value % $jtag_word_bytes != 0} {
        error "status address is not word aligned: 0x$status_address"
    }
    after 2000
    set status_word [lindex [impl_read_words \
        $hw_axi $status_address 1 impl_post_run_status \
        $jtag_word_bytes $jtag_word_hex_digits] 0]
    puts "INFO: CPU post-run status at 0x$status_address = 0x$status_word"
}

close_hw_target
disconnect_hw_server
close_hw_manager
