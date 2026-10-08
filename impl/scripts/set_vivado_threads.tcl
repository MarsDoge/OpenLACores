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

set vivado_threads 8
if {[info exists ::env(VIVADO_THREADS)] &&
    $::env(VIVADO_THREADS) ne ""} {
    set vivado_threads $::env(VIVADO_THREADS)
}
if {![string is integer -strict $vivado_threads] ||
    $vivado_threads < 1 || $vivado_threads > 20} {
    error "VIVADO_THREADS must be an integer from 1 through 20"
}

set_param general.maxThreads $vivado_threads

puts "INFO: Vivado run configured for $vivado_threads threads"
